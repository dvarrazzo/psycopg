`psycopg2.err` -- Fine-grained database errors
==============================================

.. sectionauthor:: Daniele Varrazzo <daniele.varrazzo@gmail.com>

.. module:: psycopg2.err

.. versionadded:: 2.6

The module `!psycopg2.err` contains exception classes for every PostgreSQL
error code (or SQLSTATE) defined by the server.  The name of the exception is
taken directly from the PostgreSQL `error codes table`__ converting the error
name to CamelCase. For instance the error ``UNIQUE_VIOLATION`` (SQLSTATE
``23505``) is represented by the exception `!psycopg2.err.UniqueViolation`.

Exceptions representing all the error values defined by PostgreSQL versions
between 8.1 and 9.4 are included in the module.

.. __: http://www.postgresql.org/docs/current/static/errcodes-appendix.html#ERRCODES-TABLE

.. note::

    If you can reproduce interactively your error in :program:`psql`, you can
    increase its verbosity to see the errcode returned:

    .. code-block:: psql

        testing=# \set VERBOSITY verbose
        testing=# insert into mytable (id) values (1), (1);
        ERROR:  23505: duplicate key value violates unique constraint "mytable_pkey"
        DETAIL:  Key (id)=(1) already exists.

The first two characters of the error code represent a class of database
error. This hierarchy is represented too with a distinct exception for each
error class. For instance the class ``23`` is mapped to the exception
`!ClassIntegrityConstraintViolation`.  All the class-related exceptions
inherit from `~psycopg2.DatabaseError`.  Their names are somewhat more
arbitrary: they are taken from the PostgreSQL definition too but they are only
associated to a human description; should this description change in the
future the Psycopg exception name will remain unchanged.

The exceptions raised inherit both from the :ref:`DBAPI exception
<dbapi-exceptions-tree>` and from the error class exception, so you can use
either in your try-except clauses to handle them. For instance the
`!UniqueViolation` inheritance graph is::

                             StandardError
                                   ^
                             psycopg2.Error
                                   ^
                         psycopg2.DatabaseError
                                   ^
                  +----------------+----------------+
                  |                                 |
    psycopg2.IntegrityError    err.ClassIntegrityConstraintViolation
                  ^                                 ^
                  +----------------+----------------+
                                   |
                          err.UniqueViolation


.. seealso:: the module `psycopg2.errorcodes` defines symbolic names
    for every PostgreSQL error code.


.. autofunction:: lookup(code)

    .. code-block:: python

        >>> psycopg2.err.lookup('23505')
        <class 'psycopg2.err.UniqueViolation'>

        >>> psycopg2.err.lookup('23')
        <class 'psycopg2.err.ClassIntegrityConstraintViolation'>

    .. hint::

        You can use the `!lookup()` function in the except block too:

        .. code-block:: python

            for record in source:
                try:
                    cur.execute("insert into destination values %s", record)
                except psycopg2.err.lookup('22')
                    raise ValueError("data malformed: %s" % (record,))
