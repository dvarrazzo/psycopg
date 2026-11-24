"""
C optimized functions to manipulate arrays
"""

# Copyright (C) 2022 The Psycopg Team

import cython

from cpython.mem cimport PyMem_Free, PyMem_Realloc
from cpython.ref cimport Py_INCREF
from libc.stdint cimport int32_t, uint32_t
from libc.string cimport strchr
from cpython.list cimport PyList_Append, PyList_Check, PyList_GET_ITEM, PyList_GET_SIZE
from cpython.list cimport PyList_New, PyList_SET_ITEM
from cpython.object cimport PyObject
from cpython.sequence cimport PySequence_Fast, PySequence_Fast_GET_ITEM
from cpython.sequence cimport PySequence_Fast_GET_SIZE
from cpython.bytearray cimport PyByteArray_AS_STRING, PyByteArray_FromStringAndSize
from cpython.bytearray cimport PyByteArray_Resize

from psycopg_c._psycopg cimport endian
from psycopg_c.pq.libpq cimport Oid

from psycopg import errors as e


cdef extern from "Python.h":
    # Not "except -1": on error it returns 1 in some Python versions
    int Py_EnterRecursiveCall(const char *where)
    void Py_LeaveRecursiveCall()
    int Py_GetRecursionLimit()


cdef extern from *:
    """
/* Defined in PostgreSQL in src/include/utils/array.h */
#define MAXDIM 6
    """
    const int MAXDIM

cdef inline int _enter_list() except -1:
    """Guard the recursion into a nested list, raising RecursionError."""
    if Py_EnterRecursiveCall(" while dumping a list"):
        return -1
    return 0


# Allocate the dimensions of the lists to dump by this number of items
cdef enum:
    DIMS_CHUNK = 8


cdef class ArrayLoader(_CRecursiveLoader):

    format = PQ_TEXT
    base_oid = 0
    delimiter = b","

    cdef PyObject *row_loader
    cdef char cdelim

    # A memory area which used to unescape elements.
    # Keep it here to avoid a malloc per element and to set up exceptions
    # to make sure to free it on error.
    cdef char *scratch
    cdef size_t sclen

    def __cinit__(self, oid: int, context: AdaptContext | None = None):
        # Create the element loader now: the connection might be closed
        # by the time data is loaded (#1428).
        self.row_loader = self._tx._c_get_loader(
            <PyObject *>self.base_oid, <PyObject *>PQ_TEXT)
        self.cdelim = self.delimiter[0]

    cdef object cload(self, const char *data, size_t length):
        return _array_load_text(
            data, length, self.row_loader, self.cdelim,
            &(self.scratch), &(self.sclen))

    def __dealloc__(self):
        PyMem_Free(self.scratch)


@cython.final
cdef class ArrayBinaryLoader(_CRecursiveLoader):

    format = PQ_BINARY

    cdef PyObject *row_loader

    def __cinit__(self, oid: int, context: AdaptContext | None = None):
        # The element oid is in the data, but if the array type is known,
        # create the element loader now, while the connection is still open.
        info = self._tx.adapters.types.get(oid)
        if info is not None and info.array_oid == oid:
            self._tx._c_get_loader(<PyObject *>info.oid, <PyObject *>PQ_BINARY)

    cdef object cload(self, const char *data, size_t length):
        rv = _array_load_binary(data, length, self._tx, &(self.row_loader))
        return rv


cdef object _array_load_text(
    const char *buf, size_t length, PyObject *row_loader, char cdelim,
    char **scratch, size_t *sclen
):
    if length == 0:
        raise e.DataError("malformed array: empty data")

    cdef const char *end = buf + length

    # Remove the dimensions information prefix (``[...]=``)
    if buf[0] == b"[":
        buf = strchr(buf + 1, b'=')
        if buf == NULL:
            raise e.DataError("malformed array: no '=' after dimension information")
        buf += 1

    # TODO: further optimization: pre-scan the array to find the array
    # dimensions, so that we can preallocate the list sized instead of calling
    # append, which is the dominating operation

    cdef list stack = []
    cdef list a = []
    rv = a
    cdef PyObject *tmp

    cdef CLoader cloader = None
    cdef object pyload = None
    if (<RowLoader>row_loader).cloader is not None:
        cloader = (<RowLoader>row_loader).cloader
    else:
        pyload = (<RowLoader>row_loader).loadfunc

    while buf < end:
        if buf[0] == b'{':
            if stack:
                tmp = PyList_GET_ITEM(stack, PyList_GET_SIZE(stack) - 1)
                PyList_Append(<object>tmp, a)
            PyList_Append(stack, a)
            a = []
            buf += 1

        elif buf[0] == b'}':
            if not stack:
                raise e.DataError("malformed array: unexpected '}'")
            rv = stack.pop()
            buf += 1

        elif buf[0] == cdelim:
            buf += 1

        else:
            v = _parse_token(
                &buf, end, cdelim, scratch, sclen, cloader, pyload)
            if not stack:
                raise e.DataError("malformed array: missing initial '{'")
            tmp = PyList_GET_ITEM(stack, PyList_GET_SIZE(stack) - 1)
            PyList_Append(<object>tmp, v)

    return rv


cdef object _parse_token(
    const char **bufptr, const char *bufend, char cdelim,
    char **scratch, size_t *sclen, CLoader cloader, object load
):
    cdef const char *start = bufptr[0]
    cdef int has_quotes = start[0] == b'"'
    cdef int quoted = has_quotes
    cdef int num_escapes = 0
    cdef int escaped = 0

    if has_quotes:
        start += 1
    cdef const char *end = start

    while end < bufend:
        if (end[0] == cdelim or end[0] == b'}') and not quoted:
            break
        elif end[0] == b'\\' and not escaped:
            num_escapes += 1
            escaped = 1
            end += 1
            continue
        elif end[0] == b'"' and not escaped:
            quoted = 0
        escaped = 0
        end += 1
    else:
        raise e.DataError("malformed array: hit the end of the buffer")

    # Return the new position for the buffer
    bufptr[0] = end
    if has_quotes:
        end -= 1

    cdef Py_ssize_t length = (end - start)
    if length == 4 and not has_quotes \
            and start[0] == b'N' and start[1] == b'U' \
            and start[2] == b'L' and start[3] == b'L':
        return None

    cdef const char *src
    cdef char *tgt
    cdef size_t unesclen

    if not num_escapes:
        if cloader is not None:
            return cloader.cload(start, length)
        else:
            b = start[:length]
            return load(b)

    else:
        unesclen = length - num_escapes + 1
        if unesclen > sclen[0]:
            scratch[0] = <char *>PyMem_Realloc(scratch[0], unesclen)
            sclen[0] = unesclen

        src = start
        tgt = scratch[0]
        while src < end:
            if src[0] == b'\\':
                src += 1
            tgt[0] = src[0]
            src += 1
            tgt += 1

        tgt[0] = b'\x00'

        if cloader is not None:
            return cloader.cload(scratch[0], length - num_escapes)
        else:
            b = scratch[0][:length - num_escapes]
            return load(b)


@cython.cdivision(True)
cdef object _array_load_binary(
    const char *buf, size_t length, Transformer tx, PyObject **row_loader_ptr
):
    # head is ndims, hasnull, elem oid
    cdef uint32_t buf32
    memcpy(&buf32, buf, sizeof(buf32))
    cdef int ndims = endian.be32toh(buf32)

    if ndims <= 0:
        return []
    elif ndims > MAXDIM:
        raise e.DataError(
            r"unexpected number of dimensions %s exceeding the maximum allowed %s"
            % (ndims, MAXDIM)
        )

    cdef object oid
    cdef uint32_t beoid
    if row_loader_ptr[0] == NULL:
        memcpy(&beoid, buf + 2 * sizeof(uint32_t), sizeof(beoid))
        oid = <Oid>endian.be32toh(beoid)
        row_loader_ptr[0] = tx._c_get_loader(<PyObject *>oid, <PyObject *>PQ_BINARY)

    cdef Py_ssize_t[MAXDIM] dims
    cdef int i
    cdef uint32_t bedata
    cdef const char *dimptr = buf + 3 * sizeof(uint32_t)
    for i in range(ndims):
        # Every dimension is dim, lower bound
        memcpy(&bedata, dimptr, sizeof(bedata))
        dimptr += 2 * sizeof(uint32_t)
        dims[i] = endian.be32toh(bedata)

    buf += (3 + 2 * ndims) * sizeof(bedata)
    out = _array_load_binary_rec(ndims, dims, &buf, row_loader_ptr[0])
    return out


cdef object _array_load_binary_rec(
    Py_ssize_t ndims, Py_ssize_t *dims, const char **bufptr, PyObject *row_loader
):
    cdef const char *buf
    cdef int i
    cdef uint32_t besize
    cdef int32_t size
    cdef object val

    cdef Py_ssize_t nelems = dims[0]
    cdef list out = PyList_New(nelems)

    if ndims == 1:
        buf = bufptr[0]
        for i in range(nelems):
            memcpy(&besize, buf, sizeof(besize))
            size = <int32_t>endian.be32toh(besize)
            buf += sizeof(besize)
            if size == -1:
                val = None
            else:
                if (<RowLoader>row_loader).cloader is not None:
                    val = (<RowLoader>row_loader).cloader.cload(buf, size)
                else:
                    val = (<RowLoader>row_loader).loadfunc(buf[:size])
                buf += size

            Py_INCREF(val)
            PyList_SET_ITEM(out, i, val)

        bufptr[0] = buf

    else:
        for i in range(nelems):
            val = _array_load_binary_rec(ndims - 1, dims + 1, bufptr, row_loader)
            Py_INCREF(val)
            PyList_SET_ITEM(out, i, val)

    return out


def array_dump_binary(obj, cls, sub_dumper) -> bytearray:
    """
    Return the binary representation of a list as Postgres array.

    Nested lists are recognised as instances of `!cls`. The `!sub_dumper` can
    be omitted only if the list contains no item to dump.
    """
    cdef CDumper cdumper = None
    cdef object dumpfunc = None
    # Postgres won't take unknown for element oid: fall back on text
    cdef Oid sub_oid = oids.TEXT_OID

    if sub_dumper is not None:
        if isinstance(sub_dumper, CDumper):
            cdumper = <CDumper>sub_dumper
        else:
            dumpfunc = sub_dumper.dump
        if sub_dumper.oid:
            sub_oid = sub_dumper.oid

    cdef bytearray out = PyByteArray_FromStringAndSize("", 0)
    if not obj:
        _write_array_head(out, 0, 0, sub_oid, NULL)
        return out

    cdef Py_ssize_t *dims = NULL
    try:
        _array_dump_binary_dims(obj, cls, cdumper, dumpfunc, sub_oid, &dims, out)
    finally:
        PyMem_Free(dims)

    return out


cdef int _array_dump_binary_dims(
    object obj, object cls, CDumper cdumper, object dumpfunc, Oid sub_oid,
    Py_ssize_t **pdims, bytearray out
) except -1:
    """
    Write a non-empty list as binary array into *out*.

    The dimensions array is allocated in *pdims*: the caller must free it.
    """
    # Find the dimensions of the array looking at the first item of each list.
    # We don't check the number of dimensions against the server limit, but
    # a list containing itself as first item would go on forever.
    cdef Py_ssize_t *dims = NULL
    cdef int ndims = 0
    L = obj
    while isinstance(L, cls):
        if ndims % DIMS_CHUNK == 0:
            if ndims >= Py_GetRecursionLimit():
                raise RecursionError(
                    "maximum recursion depth exceeded while dumping a list")
            dims = <Py_ssize_t *>PyMem_Realloc(
                dims, (ndims + DIMS_CHUNK) * sizeof(Py_ssize_t))
            if dims is NULL:
                raise MemoryError
            pdims[0] = dims

        dims[ndims] = len(L)
        ndims += 1
        if not L:
            break
        L = L[0]

    if not ndims:
        raise TypeError(
            f"expected {cls.__name__} to dump, got {type(obj).__name__}"
        )

    # Leave the space for the head, to write once we know if there are nulls
    cdef Py_ssize_t pos = (3 + 2 * ndims) * sizeof(uint32_t)
    CDumper.ensure_size(out, 0, pos)

    cdef int hasnull = _array_dump_binary_rec(
        obj, cls, cdumper, dumpfunc, 0, ndims, dims, out, &pos)

    # The lists were only empty lists: after checking that they have a
    # consistent shape, dump them as an empty array, as Postgres would do.
    if not dims[ndims - 1]:
        _write_array_head(out, 0, 0, sub_oid, NULL)
        return 0

    _write_array_head(out, ndims, hasnull, sub_oid, dims)
    PyByteArray_Resize(out, pos)
    return 0


cdef int _write_array_head(
    bytearray out, int ndims, int hasnull, Oid oid, Py_ssize_t *dims
) except -1:
    """
    Write the head and the dimensions of a binary array at the start of *out*.

    If the array has no dimension, truncate *out* after the head.
    """
    cdef Py_ssize_t size = (3 + 2 * ndims) * sizeof(uint32_t)
    if not ndims:
        PyByteArray_Resize(out, size)

    cdef char *buf = PyByteArray_AS_STRING(out)
    cdef uint32_t[2] pair
    cdef int i

    pair[0] = endian.htobe32(<uint32_t>ndims)
    pair[1] = endian.htobe32(<uint32_t>hasnull)
    memcpy(buf, pair, sizeof(pair))
    pair[0] = endian.htobe32(<uint32_t>oid)
    memcpy(buf + sizeof(pair), pair, sizeof(uint32_t))
    buf += 3 * sizeof(uint32_t)

    pair[1] = endian.htobe32(1)  # lower bound
    for i in range(ndims):
        pair[0] = endian.htobe32(<uint32_t>dims[i])
        memcpy(buf + i * sizeof(pair), pair, sizeof(pair))

    return 0


cdef int _array_dump_binary_rec(
    object L, object cls, CDumper cdumper, object dumpfunc,
    int dim, int ndims, Py_ssize_t *dims, bytearray out, Py_ssize_t *pos
) except -1:
    """
    Write the items of a list into *out* at *pos*, advancing *pos*.

    Return 1 if any item is null, else 0.
    """
    fast = PySequence_Fast(L, "the object to dump is not a sequence")
    cdef Py_ssize_t nitems = PySequence_Fast_GET_SIZE(fast)
    if nitems != dims[dim]:
        raise e.DataError("nested lists have inconsistent lengths")

    cdef int hasnull = 0
    cdef Py_ssize_t i
    cdef object item

    if dim < ndims - 1:
        for i in range(nitems):
            item = <object>PySequence_Fast_GET_ITEM(fast, i)
            if not isinstance(item, cls):
                raise e.DataError("nested lists have inconsistent depths")
            _enter_list()
            try:
                hasnull |= _array_dump_binary_rec(
                    item, cls, cdumper, dumpfunc, dim + 1, ndims, dims, out, pos)
            finally:
                Py_LeaveRecursiveCall()

        return hasnull

    cdef Py_ssize_t size
    cdef uint32_t besize
    cdef char *buf
    cdef char *target
    cdef int cls_is_list = cls is list

    for i in range(nitems):
        item = <object>PySequence_Fast_GET_ITEM(fast, i)
        if item is not None:
            if PyList_Check(item) if cls_is_list else isinstance(item, cls):
                raise e.DataError("nested lists have inconsistent depths")

            if cdumper is not None:
                # A cdumper can resize if necessary and copy in place
                size = cdumper.cdump(item, out, pos[0] + sizeof(besize))
                # Also add the size of the item, before the item
                besize = endian.htobe32(<int32_t>size)
                # The buffer might have been moved by cdump
                target = PyByteArray_AS_STRING(out)
                memcpy(target + pos[0], <void *>&besize, sizeof(besize))
                pos[0] += size + sizeof(besize)
                continue

            if dumpfunc is None:
                raise TypeError("no dumper available for the list items")

            # A Python dumper, gotta call it and extract its juices
            item = dumpfunc(item)

        if item is None:
            hasnull = 1
            besize = endian.htobe32(<uint32_t>-1)
            target = CDumper.ensure_size(out, pos[0], sizeof(besize))
            memcpy(target, <void *>&besize, sizeof(besize))
            pos[0] += sizeof(besize)
        else:
            _buffer_as_string_and_size(item, &buf, &size)
            target = CDumper.ensure_size(out, pos[0], size + sizeof(besize))
            besize = endian.htobe32(<int32_t>size)
            memcpy(target, <void *>&besize, sizeof(besize))
            memcpy(target + sizeof(besize), buf, size)
            pos[0] += size + sizeof(besize)

    return hasnull


def array_dump_text(
    obj, sub_dumper, bytes delimiter, Transformer tx not None
) -> bytearray:
    """
    Return the text representation of a list as Postgres array.

    Dump the items with `!sub_dumper` if specified, otherwise look up a
    dumper for each of them.
    """
    cdef ArrayTextDump state
    state.cdumper = NULL
    state.dumpfunc = NULL
    state.tx = <PyObject *>tx

    if len(delimiter) != 1:
        raise ValueError("the delimiter must be a single byte")
    state.cdelim = delimiter[0]

    # The dumper and its dump function are kept alive by these references.
    cdef object dumpfunc
    if sub_dumper is not None:
        if isinstance(sub_dumper, CDumper):
            state.cdumper = <PyObject *>sub_dumper
        else:
            dumpfunc = sub_dumper.dump
            state.dumpfunc = <PyObject *>dumpfunc

    cdef bytearray out = PyByteArray_FromStringAndSize("", 0)
    cdef Py_ssize_t pos = 0
    _array_dump_text_rec(obj, &state, out, &pos)
    PyByteArray_Resize(out, pos)
    return out


cdef struct ArrayTextDump:
    # How to dump the items: with a C dumper, with a Python dumper, or
    # looking up a dumper for each of them using the transformer.
    PyObject *cdumper
    PyObject *dumpfunc
    PyObject *tx
    char cdelim


cdef int _array_dump_text_rec(
    object L, ArrayTextDump *state, bytearray out, Py_ssize_t *pos
) except -1:
    """
    Write the text representation of a list into *out* at *pos*, advancing it.
    """
    fast = PySequence_Fast(L, "the object to dump is not a sequence")
    cdef Py_ssize_t nitems = PySequence_Fast_GET_SIZE(fast)
    cdef char *target

    if not nitems:
        target = CDumper.ensure_size(out, pos[0], 2)
        target[0] = b"{"
        target[1] = b"}"
        pos[0] += 2
        return 0

    target = CDumper.ensure_size(out, pos[0], 1)
    target[0] = b"{"
    pos[0] += 1

    cdef Py_ssize_t i
    cdef object item
    cdef PyObject *cdumper
    cdef PyObject *dumpfunc
    cdef PyObject *row_dumper

    for i in range(nitems):
        item = <object>PySequence_Fast_GET_ITEM(fast, i)
        if item is None:
            _array_dump_text_null(out, pos)

        elif PyList_Check(item):
            _enter_list()
            try:
                _array_dump_text_rec(item, state, out, pos)
            finally:
                Py_LeaveRecursiveCall()

        else:
            cdumper = state.cdumper
            dumpfunc = state.dumpfunc
            if cdumper == NULL and dumpfunc == NULL:
                row_dumper = (<Transformer>state.tx).get_row_dumper(
                    <PyObject *>item, <PyObject *>PG_TEXT)
                if (<RowDumper>row_dumper).cdumper is not None:
                    cdumper = <PyObject *>(<RowDumper>row_dumper).cdumper
                else:
                    dumpfunc = <PyObject *>(<RowDumper>row_dumper).dumpfunc

            if cdumper != NULL:
                _array_dump_text_item_c(
                    item, <CDumper>cdumper, state.cdelim, out, pos)
            else:
                _array_dump_text_item_py(
                    item, <object>dumpfunc, state.cdelim, out, pos)

        # Leave the space for the delimiter, or for the closing bracket
        target = CDumper.ensure_size(out, pos[0], 1)
        target[0] = state.cdelim
        pos[0] += 1

    (PyByteArray_AS_STRING(out) + pos[0] - 1)[0] = b"}"
    return 0


cdef int _array_dump_text_null(bytearray out, Py_ssize_t *pos) except -1:
    cdef char *target = CDumper.ensure_size(out, pos[0], 4)
    memcpy(target, b"NULL", 4)
    pos[0] += 4
    return 0


cdef int _array_dump_text_item_c(
    object item, CDumper cdumper, char cdelim, bytearray out, Py_ssize_t *pos
) except -1:
    """
    Dump an item using a C dumper, writing it in place and quoting it after.
    """
    cdef Py_ssize_t size = cdumper.cdump(item, out, pos[0])
    cdef Py_ssize_t nescs = _array_count_escapes(
        PyByteArray_AS_STRING(out) + pos[0], size, cdelim)
    if nescs < 0:
        pos[0] += size
        return 0

    # Make room for the quotes and the escapes and move the data to the end
    # of it, starting from the last char, adding the escapes on the way.
    cdef Py_ssize_t newsize = size + nescs + 2
    cdef char *start = CDumper.ensure_size(out, pos[0], newsize)
    cdef char *src = start + size - 1
    cdef char *tgt = start + newsize - 1

    tgt[0] = b'"'
    tgt -= 1
    while src >= start:
        tgt[0] = src[0]
        tgt -= 1
        if src[0] == b'"' or src[0] == b"\\":
            tgt[0] = b"\\"
            tgt -= 1
        src -= 1
    tgt[0] = b'"'

    pos[0] += newsize
    return 0


cdef int _array_dump_text_item_py(
    object item, object dumpfunc, char cdelim, bytearray out, Py_ssize_t *pos
) except -1:
    """
    Dump an item using the dump function of a Python dumper.
    """
    data = dumpfunc(item)
    if data is None:
        return _array_dump_text_null(out, pos)

    cdef char *src
    cdef Py_ssize_t size
    _buffer_as_string_and_size(data, &src, &size)

    cdef Py_ssize_t nescs = _array_count_escapes(src, size, cdelim)
    cdef char *tgt
    if nescs < 0:
        tgt = CDumper.ensure_size(out, pos[0], size)
        memcpy(tgt, src, size)
        pos[0] += size
        return 0

    cdef Py_ssize_t newsize = size + nescs + 2
    cdef const char *end = src + size
    tgt = CDumper.ensure_size(out, pos[0], newsize)

    tgt[0] = b'"'
    tgt += 1
    while src < end:
        if src[0] == b'"' or src[0] == b"\\":
            tgt[0] = b"\\"
            tgt += 1
        tgt[0] = src[0]
        tgt += 1
        src += 1
    tgt[0] = b'"'

    pos[0] += newsize
    return 0


cdef Py_ssize_t _array_count_escapes(
    const char *data, Py_ssize_t size, char cdelim
) noexcept nogil:
    """
    Return the number of chars to escape in an array item if it needs quotes.

    Return -1 if the item doesn't need quotes.

    This is the equivalent of the regexp in `_get_needs_quotes_regexp()` in
    the Python implementation.
    """
    # The empty string
    if size == 0:
        return 0

    cdef const unsigned char *buf = <const unsigned char *>data
    cdef unsigned char c
    cdef Py_ssize_t i
    cdef Py_ssize_t nescs = 0
    cdef int quote = 0

    for i in range(size):
        c = buf[i]
        if c == b'"' or c == b"\\":
            nescs += 1

        elif (
            c == b"{" or c == b"}" or c == <unsigned char>cdelim
            # White space, as matched by the '\s' regexp
            or c == b" " or (9 <= c <= 13)
        ):
            quote = 1

        # UTF-8 Unicode spaces stripped by CockroachDB
        elif 0xE1 <= c <= 0xE3 and i + 2 < size:
            if c == 0xE1:
                # U+1680
                if buf[i + 1] == 0x9A and buf[i + 2] == 0x80:
                    quote = 1
            elif c == 0xE2:
                if buf[i + 1] == 0x80:
                    # U+2000-U+200A, U+2028, U+2029, U+202F
                    c = buf[i + 2]
                    if 0x80 <= c <= 0x8A or c == 0xA8 or c == 0xA9 or c == 0xAF:
                        quote = 1
                elif buf[i + 1] == 0x81:
                    # U+205F
                    if buf[i + 2] == 0x9F:
                        quote = 1
            else:
                # U+3000
                if buf[i + 1] == 0x80 and buf[i + 2] == 0x80:
                    quote = 1

    if nescs or quote:
        return nescs

    # The word NULL
    if (
        size == 4
        and (buf[0] == b"N" or buf[0] == b"n")
        and (buf[1] == b"U" or buf[1] == b"u")
        and (buf[2] == b"L" or buf[2] == b"l")
        and (buf[3] == b"L" or buf[3] == b"l")
    ):
        return 0

    return -1
