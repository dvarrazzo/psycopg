"""
C implementation of waiting functions
"""

# Copyright (C) 2022 The Psycopg Team

cimport cython
from cpython.object cimport PyObject

from os import fstat
from time import monotonic
from typing import TypeVar

from psycopg import errors as e

RV = TypeVar("RV")


cdef extern from *:
    r"""
#if defined(HAVE_POLL) && !defined(HAVE_BROKEN_POLL)

#if defined(HAVE_POLL_H)
#include <poll.h>
#elif defined(HAVE_SYS_POLL_H)
#include <sys/poll.h>
#endif

#else  /* no poll available */

#ifdef MS_WINDOWS
#include <winsock2.h>
#else
#include <sys/select.h>
#endif

#endif  /* HAVE_POLL */

#ifndef MS_WINDOWS
#include <time.h>
#endif

#define SELECT_EV_READ 1
#define SELECT_EV_WRITE 2
#define CWAIT_SELECT_ERROR -1
#define CWAIT_SOCKET_ERROR -2
#define CWAIT_EINTR -3
#define CWAIT_FD_RANGE -4

#define SEC_TO_MS 1000
#define SEC_TO_US (1000 * 1000)

/* Use select to wait for readiness on fileno. Can be called without the GIL.
 *
 * - Return SELECT_EV_* if the file is ready
 * - Return SELECT_EV_NONE on timeout
 * - Return CWAIT_SOCKET_ERROR on poll success but fd error.
 * - Return CWAIT_EINTR if interrupted by a signal.
 * - Return CWAIT_SELECT_ERROR on error, with the error code in *err.
 * - Return CWAIT_FD_RANGE if the fd can't be handled by select().
 *
 * The wisdom of this function comes from:
 *
 * - PostgreSQL libpq (see src/interfaces/libpq/fe-misc.c)
 * - Python select module (see Modules/selectmodule.c)
 */
static int
wait_c_nogil(int fileno, int wait, float timeout, int *err)
{
    int select_rv;
    int rv = 0;

#if defined(HAVE_POLL) && !defined(HAVE_BROKEN_POLL)

    struct pollfd input_fd;
    int timeout_ms;

    input_fd.fd = fileno;
    input_fd.events = POLLERR;
    input_fd.revents = 0;

    if (wait & SELECT_EV_READ) { input_fd.events |= POLLIN; }
    if (wait & SELECT_EV_WRITE) { input_fd.events |= POLLOUT; }

    if (timeout < 0.0) {
        timeout_ms = -1;
    } else {
        timeout_ms = (int)(timeout * SEC_TO_MS);
    }

    errno = 0;
    select_rv = poll(&input_fd, 1, timeout_ms);
    if (select_rv < 0) {
        if (errno == EINTR) { return CWAIT_EINTR; }
        *err = errno;
        return CWAIT_SELECT_ERROR;
    }

    if (input_fd.revents & POLLIN) { rv |= SELECT_EV_READ; }
    if (input_fd.revents & POLLOUT) { rv |= SELECT_EV_WRITE; }
    if (!rv && (input_fd.revents & ~(POLLIN | POLLOUT))) {
        rv = CWAIT_SOCKET_ERROR;
    }

#else

    fd_set ifds;
    fd_set ofds;
    fd_set efds;
    struct timeval tv, *tvptr;

#ifndef MS_WINDOWS
    if (fileno >= 1024) { return CWAIT_FD_RANGE; }
#endif

    FD_ZERO(&ifds);
    FD_ZERO(&ofds);
    FD_ZERO(&efds);

    if (wait & SELECT_EV_READ) { FD_SET(fileno, &ifds); }
    if (wait & SELECT_EV_WRITE) { FD_SET(fileno, &ofds); }
    FD_SET(fileno, &efds);

    /* Compute appropriate timeout interval */
    if (timeout < 0.0) {
        tvptr = NULL;
    }
    else {
        tv.tv_sec = (int)timeout;
        tv.tv_usec = (int)((long)(timeout * SEC_TO_US) % SEC_TO_US);
        tvptr = &tv;
    }

#ifdef MS_WINDOWS
    select_rv = select(fileno + 1, &ifds, &ofds, &efds, tvptr);
    if (select_rv == SOCKET_ERROR) {
        *err = WSAGetLastError();
        return CWAIT_SELECT_ERROR;
    }
#else
    errno = 0;
    select_rv = select(fileno + 1, &ifds, &ofds, &efds, tvptr);
    if (select_rv < 0) {
        if (errno == EINTR) { return CWAIT_EINTR; }
        *err = errno;
        return CWAIT_SELECT_ERROR;
    }
#endif

    if (select_rv > 0) {
        if (!FD_ISSET(fileno, &efds)) {
            if (FD_ISSET(fileno, &ifds)) { rv |= SELECT_EV_READ; }
            if (FD_ISSET(fileno, &ofds)) { rv |= SELECT_EV_WRITE; }
        }
        else {
            /* There is an error on the FD. Assume it means it is closed. We
             * want to raise a chained exception, which is tricky in C, so
             * return the special value CWAIT_SOCKET_ERROR to signal the Cython
             * wrapper to check the fd and raise the appropriate exception.
             */
            rv = CWAIT_SOCKET_ERROR;
        }
    }

#endif  /* HAVE_POLL */

    return rv;
}

/* Set a Python exception after wait_c_nogil() returned an error.
 *
 * Always return -1.
 */
static int
wait_c_set_error(int rv, int err)
{
    if (rv == CWAIT_FD_RANGE) {
        PyErr_SetString(
            PyExc_ValueError,  /* same exception of Python's 'select.select()' */
            "connection file descriptor out of range for 'select()'");
    }
    else if (rv == CWAIT_SELECT_ERROR) {
#ifdef MS_WINDOWS
        PyErr_SetExcFromWindowsErr(PyExc_OSError, err);
#else
        errno = err;
        PyErr_SetFromErrno(PyExc_OSError);
#endif
    }
    else {
        PyErr_SetString(PyExc_OSError, "unexpected error from select()");
    }
    return -1;
}

/* Wait for readiness on fileno, releasing the GIL while waiting.
 *
 * - Return SELECT_EV_* if the file is ready
 * - Return SELECT_EV_NONE on timeout
 * - Return CWAIT_SELECT_ERROR (and set an exception) on error.
 * - Return CWAIT_SOCKET_ERROR on poll success but fd error.
 */
static int
wait_c_impl(int fileno, int wait, float timeout)
{
    int rv;
    int err = 0;

    /* The grace of PEP 475 */
    do {
        Py_BEGIN_ALLOW_THREADS
        rv = wait_c_nogil(fileno, wait, timeout, &err);
        Py_END_ALLOW_THREADS
    } while (rv == CWAIT_EINTR);

    if (PyErr_CheckSignals()) { return CWAIT_SELECT_ERROR; }

    if (rv == CWAIT_SELECT_ERROR || rv == CWAIT_FD_RANGE) {
        wait_c_set_error(rv, err);
        return CWAIT_SELECT_ERROR;
    }

    return rv;
}

/* Return a monotonic time in seconds. Can be called without the GIL. */
static double
monotonic_nogil(void)
{
#ifdef MS_WINDOWS
    static LARGE_INTEGER freq;
    LARGE_INTEGER count;

    if (!freq.QuadPart) { QueryPerformanceFrequency(&freq); }
    QueryPerformanceCounter(&count);
    return (double)count.QuadPart / (double)freq.QuadPart;
#else
    struct timespec ts;

    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec + (double)ts.tv_nsec / 1e9;
#endif
}

/* Return the SELECT_EV_* events fileno is ready for, without waiting.
 *
 * - Return 0 if not ready, or if the fd is in error: the caller will find
 *   out the error once it waits on it.
 * - Return CWAIT_SELECT_ERROR (and set an exception) on error.
 *
 * Unlike wait_c_impl(), don't release the GIL: the call doesn't block.
 */
static int
ready_c_impl(int fileno, int wait)
{
    int select_rv;
    int rv = 0;

#if defined(HAVE_POLL) && !defined(HAVE_BROKEN_POLL)

    struct pollfd input_fd;

    input_fd.fd = fileno;
    input_fd.events = 0;
    input_fd.revents = 0;

    if (wait & SELECT_EV_READ) { input_fd.events |= POLLIN; }
    if (wait & SELECT_EV_WRITE) { input_fd.events |= POLLOUT; }

    do {
        errno = 0;
        select_rv = poll(&input_fd, 1, 0);
    } while (select_rv < 0 && errno == EINTR);

    if (select_rv < 0) {
        PyErr_SetFromErrno(PyExc_OSError);
        return CWAIT_SELECT_ERROR;
    }

    if (input_fd.revents & POLLIN) { rv |= SELECT_EV_READ; }
    if (input_fd.revents & POLLOUT) { rv |= SELECT_EV_WRITE; }

#else

    fd_set ifds;
    fd_set ofds;
    fd_set efds;
    struct timeval tv = {0, 0};

#ifndef MS_WINDOWS
    if (fileno >= 1024) {
        PyErr_SetString(
            PyExc_ValueError,  /* same exception of Python's 'select.select()' */
            "connection file descriptor out of range for 'select()'");
        return CWAIT_SELECT_ERROR;
    }
#endif

    FD_ZERO(&ifds);
    FD_ZERO(&ofds);
    FD_ZERO(&efds);

    if (wait & SELECT_EV_READ) { FD_SET(fileno, &ifds); }
    if (wait & SELECT_EV_WRITE) { FD_SET(fileno, &ofds); }
    FD_SET(fileno, &efds);

    do {
        errno = 0;
        select_rv = select(fileno + 1, &ifds, &ofds, &efds, &tv);
    } while (select_rv < 0 && errno == EINTR);

    if (select_rv < 0) {
#ifdef MS_WINDOWS
        PyErr_SetExcFromWindowsErr(PyExc_OSError, WSAGetLastError());
#else
        PyErr_SetFromErrno(PyExc_OSError);
#endif
        return CWAIT_SELECT_ERROR;
    }

    if (select_rv > 0 && !FD_ISSET(fileno, &efds)) {
        if (FD_ISSET(fileno, &ifds)) { rv |= SELECT_EV_READ; }
        if (FD_ISSET(fileno, &ofds)) { rv |= SELECT_EV_WRITE; }
    }

#endif  /* HAVE_POLL */

    return rv;
}
    """
    cdef int wait_c_impl(int fileno, int wait, float timeout) except -1
    cdef int wait_c_nogil(int fileno, int wait, float timeout, int *err) nogil
    cdef int wait_c_set_error(int rv, int err) except -1
    cdef int ready_c_impl(int fileno, int wait) except -1
    cdef double monotonic_nogil() nogil
    cdef int SELECT_EV_READ
    cdef int SELECT_EV_WRITE
    cdef int CWAIT_SELECT_ERROR
    cdef int CWAIT_SOCKET_ERROR
    cdef int CWAIT_EINTR
    cdef int CWAIT_FD_RANGE


cdef extern from "Python.h":
    # Resume a generator returning its return value, rather than raising
    # StopIteration, which is costly to catch. Return PYGEN_RETURN or
    # PYGEN_NEXT (PYGEN_ERROR = -1 if an exception is raised).
    int PyIter_Send(object iter, object arg, PyObject **presult) except -1
    int PYGEN_RETURN
    void Py_DecRef(PyObject *o)
    int PyErr_CheckSignals() except -1


cdef inline object _steal(PyObject *o):
    """Return a new reference as a Python object, without increfing it."""
    rv = <object>o
    Py_DecRef(o)
    return rv


def wait_c(gen: PQGen[RV], int fileno, interval = 0.0, timeout = None) -> RV:
    """
    Wait for a generator using poll or select.
    """
    cdef float cinterval, ctimeout
    cdef double deadline = 0.0, remaining
    cdef bint has_deadline = False
    cdef int wait, ready
    cdef object pyready
    cdef PyObject *pyrv

    if interval is None:
        raise ValueError("indefinite wait not supported anymore")

    cinterval = <float>float(interval)
    if cinterval < 0.0:
        cinterval = 0.0

    if timeout is not None:
        # Note: use a double: a float would lose precision on large values.
        has_deadline = True
        deadline = monotonic() + float(timeout)

    # Most of the generators complete without blocking (e.g. at every copy()
    # row): return their value as quickly as possible.
    if PyIter_Send(gen, None, &pyrv) == PYGEN_RETURN:
        return _steal(pyrv)
    wait = _steal(pyrv)

    while True:
        ctimeout = cinterval
        if has_deadline:
            remaining = deadline - monotonic()
            if remaining < ctimeout:
                ctimeout = <float>remaining if remaining > 0.0 else 0.0

        ready = wait_c_impl(fileno, wait, ctimeout)
        if ready == READY_NONE:
            pyready = PY_READY_NONE
        elif ready == READY_R:
            pyready = PY_READY_R
        elif ready == READY_RW:
            pyready = PY_READY_RW
        elif ready == READY_W:
            pyready = PY_READY_W
        elif ready == CWAIT_SOCKET_ERROR:  # FD closed?
            try:
                fstat(fileno)
            except Exception as ex:
                raise e.OperationalError("connection socket closed") from ex
            else:
                raise e.OperationalError("connection socket closed")
        else:
            raise AssertionError(f"unexpected ready value: {ready}")

        if PyIter_Send(gen, pyready, &pyrv) == PYGEN_RETURN:
            return _steal(pyrv)
        wait = _steal(pyrv)

        # Check the deadline after resuming the generator, so that the data
        # already available is processed and a timeout of 0 polls once.
        if has_deadline and monotonic() >= deadline:
            raise e._WaitTimeout("wait timeout expired")


def ready_c(int fileno, int wait):
    """
    Return the `Ready` state of `!fileno` right now, without waiting.

    Used by `wait_async()` to check if the socket is ready before going
    through the event loop.
    """
    cdef int ready = ready_c_impl(fileno, wait)
    if ready == READY_NONE:
        return PY_READY_NONE
    elif ready == READY_W:
        return PY_READY_W
    elif ready == READY_RW:
        return PY_READY_RW
    elif ready == READY_R:
        return PY_READY_R
    else:
        raise AssertionError(f"unexpected ready value: {ready}")


cdef enum:
    _CONNECT_POLLED = 0  # the connection is complete or failed
    _CONNECT_TIMEOUT  # the deadline expired
    _CONNECT_INTERRUPT  # check for signals and call again
    _CONNECT_WAIT_ERROR  # error waiting on the socket


cdef int _connect_loop(
    libpq.PGconn *pgconn_ptr,
    bint has_deadline,
    double deadline,
    float interval,
    int *poll_status,
    int *wait_rv,
    int *err,
) noexcept nogil:
    """
    Poll a connection in progress until it is established or it fails.

    Don't require the GIL, so that it is not necessary to re-acquire it, and
    to contend it with the other threads, at every step of the handshake.

    Return _CONNECT_INTERRUPT every `!interval` seconds waited, to allow to
    check for signals. The function can be called again with the same
    `!poll_status` to continue waiting. Before the first call `!poll_status`
    must be set to `!PGRES_POLLING_WRITING`.
    """
    cdef int ready
    cdef float timeout
    cdef double remaining

    while True:
        timeout = interval
        if has_deadline:
            remaining = deadline - monotonic_nogil()
            if remaining < timeout:
                timeout = <float>remaining if remaining > 0.0 else 0.0

        # The socket may change during connection (e.g. trying a different
        # address, or changing protocol): ask for it at every wait.
        ready = wait_c_nogil(
            libpq.PQsocket(pgconn_ptr),
            SELECT_EV_READ
            if poll_status[0] == libpq.PGRES_POLLING_READING
            else SELECT_EV_WRITE,
            timeout,
            err,
        )
        if ready == 0:
            if has_deadline and monotonic_nogil() >= deadline:
                return _CONNECT_TIMEOUT
            return _CONNECT_INTERRUPT
        elif ready == CWAIT_EINTR:
            return _CONNECT_INTERRUPT
        elif ready == CWAIT_SELECT_ERROR or ready == CWAIT_FD_RANGE:
            wait_rv[0] = ready
            return _CONNECT_WAIT_ERROR

        # In case of CWAIT_SOCKET_ERROR too, let the libpq find the error.
        poll_status[0] = libpq.PQconnectPoll(pgconn_ptr)
        if not (
            poll_status[0] == libpq.PGRES_POLLING_READING
            or poll_status[0] == libpq.PGRES_POLLING_WRITING
        ):
            return _CONNECT_POLLED

        # Check the deadline after polling, so that the data already available
        # is processed, but a peer always ready can't keep us here forever.
        if has_deadline and monotonic_nogil() >= deadline:
            return _CONNECT_TIMEOUT


def wait_connect_c(
    pq.PGconn pgconn, interval = 0.0, timeout = None, encoding: str = "utf-8"
) -> None:
    """
    Complete a connection started by `connect_start()` using poll or select.

    Unlike `wait_conn()`, don't require a generator, and release the GIL for
    the entire connection process.
    """
    cdef libpq.PGconn *pgconn_ptr
    cdef float cinterval
    cdef double deadline = 0.0
    cdef bint has_deadline = False
    # As per libpq docs, wait for the socket to be writable before polling.
    cdef int poll_status = libpq.PGRES_POLLING_WRITING
    cdef int wait_rv = 0
    cdef int err = 0
    cdef int rv = 0

    if interval is None:
        raise ValueError("indefinite wait not supported anymore")

    cinterval = <float>float(interval)
    if cinterval < 0.0:
        cinterval = 0.0

    if timeout is not None:
        has_deadline = True
        deadline = monotonic_nogil() + float(timeout)

    while True:
        with cython.critical_section(pgconn), nogil:
            if (pgconn_ptr := pgconn._pgconn_ptr) is not NULL:
                rv = _connect_loop(
                    pgconn_ptr,
                    has_deadline,
                    deadline,
                    cinterval,
                    &poll_status,
                    &wait_rv,
                    &err,
                )
        if pgconn_ptr is NULL:
            raise e.OperationalError("the connection is closed")

        PyErr_CheckSignals()

        if rv == _CONNECT_INTERRUPT:
            continue
        elif rv == _CONNECT_POLLED:
            break
        elif rv == _CONNECT_TIMEOUT:
            pgconn.finish()
            raise e._WaitTimeout("wait timeout expired")
        else:
            pgconn.finish()
            wait_c_set_error(wait_rv, err)

    if poll_status != libpq.PGRES_POLLING_OK:
        _raise_connect_failed(pgconn, encoding, poll_status)

    pgconn.nonblocking = 1
