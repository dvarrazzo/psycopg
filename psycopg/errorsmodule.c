/* errorsmmodule.c - psycopg2.errors module
 *
 * Copyright (C) 2019  Daniele Varrazzo <daniele.varrazzo@gmail.com>
 *
 * This file is part of psycopg.
 *
 * psycopg2 is free software: you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as published
 * by the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition, as a special exception, the copyright holders give
 * permission to link this program with the OpenSSL library (or with
 * modified versions of OpenSSL that use the same license as OpenSSL),
 * and distribute linked combinations including the two.
 *
 * You must obey the GNU Lesser General Public License in all respects for
 * all of the code used other than OpenSSL.
 *
 * psycopg2 is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
 * License for more details.
 */

#include "psycopg/psycopg.h"


static PyObject *errors_map;

/* mapping between exception names and their PyObject */
static struct {
    char *sqlstate;
    char *name;
    PyObject **base;
} exctable[] = {
    { "55P03", "LockNotAvailable", &OperationalError },
    {NULL}  /* Sentinel */
};


RAISES_NEG static int
errors_init(PyObject *module)
{
    int i;
    char namebuf[120];
    char prefix[] = "psycopg2.errors.";
    char *suffix;
    size_t bufsize;
    PyObject *exc;
    int rv = -1;

    Dprintf("errorsmodule: initializing exceptions");

    if (errors_map) {
        PyErr_SetString(PyExc_SystemError, "errors_init(): already called");
        goto exit;
    }
    if (!(errors_map = PyDict_New())) {
        goto exit;
    }
    if (0 > PyModule_AddObject(module, "_by_sqlstate", errors_map)) {
        goto exit;
    }
    Py_INCREF(errors_map);

    strcpy(namebuf, prefix);
    suffix = namebuf + sizeof(prefix) - 1;
    bufsize = sizeof(namebuf) - sizeof(prefix) - 1;
    /* If we delete this 0 the buffer is too small. */
    namebuf[sizeof(namebuf) - 1] = '\0';

    for (i = 0; exctable[i].sqlstate; i++) {
        strncpy(suffix, exctable[i].name, bufsize);
        if (namebuf[sizeof(namebuf) - 1] != '\0') {
            PyErr_SetString(
                PyExc_SystemError, "errors_init(): buffer too small");
            goto exit;
        }
        if (!(exc = PyErr_NewException(namebuf, *exctable[i].base, NULL))) {
            goto exit;
        }
        if (0 > PyDict_SetItemString(errors_map, exctable[i].sqlstate, exc)) {
            goto exit;
        }
        if (0 > PyModule_AddObject(module, extable[i].name, exc)) {
            goto exit;
        }
        exc = NULL;     /* ref stolen by the module */
    }

    rv = 0;

exit:
    Py_XDECREF(exc);
    return rv;
}

static const char errors_lookup_doc[] =
    "Lookup an error code and return its exception class.\n\n"
    "Raise `!KeyError` if the code is not found.";

static PyObject *
errors_lookup(PyObject *self, PyObject *args, PyObject *kwargs)
{
    PyObject *code = NULL;
    PyObject *rv = NULL;

    static char *kwlist[] = {"code", NULL};
    if (!PyArg_ParseTupleAndKeywords(args, kwargs, "O", kwlist, &code)) {
        return NULL;
    }

    rv = PyDict_GetItem(

}

static PyMethodDef errorsMethods[] = {
    {"lookup",  (PyCFunction)errors_lookup,
     METH_VARARGS|METH_KEYWORDS, },
    {NULL, NULL, 0, NULL}        /* Sentinel */
};

#if PY_MAJOR_VERSION > 2
static struct PyModuleDef errorsmodule = {
        PyModuleDef_HEAD_INIT,
        "errors",
        NULL,
        -1,
        errorsMethods,
        NULL,
        NULL,
        NULL,
        NULL
};
#endif

#ifndef PyMODINIT_FUNC	/* declarations for DLL import/export */
#define PyMODINIT_FUNC void
#endif
PyMODINIT_FUNC
INIT_MODULE(errors)(void)
{
    PyObject *module = NULL;

#if PY_MAJOR_VERSION < 3
    module = Py_InitModule("_psycopg", psycopgMethods);
#else
    module = PyModule_Create(&errorsmodule);
#endif
    if (!module) { goto exit; }

    if (0 > errors_init(module)) { goto exit; }

exit:
#if PY_MAJOR_VERSION > 2
    return module;
#else
    return;
#endif
}
