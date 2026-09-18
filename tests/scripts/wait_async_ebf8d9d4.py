"""The wait_async() implementation before the #1331 optimisation.

Copied verbatim from `git show ebf8d9d4:psycopg/psycopg/waiting.py`, which is
the merge of #1411, right after the `timeout` parameter refactoring: the first
commit whose signature matches what `AsyncConnection.wait()` passes today, so
no adaptation was needed. Only the function name differs.

It is NOT the 3.3.5 code: that one has no `timeout` parameter at all and would
raise a TypeError when called by the current connection classes.

Compared to the current implementation this one:

- blocks on an `asyncio.Event` awaited through `wait_for()`, which wraps every
  single wait in a Task and raises a TimeoutError on every interval tick;
- looks up the event loop with the deprecated `get_event_loop()`, and does so
  before knowing whether it will have to wait at all.

Use it to measure the difference:

    ./waittest.py bench --wait-async wait_async_ebf8d9d4:wait_async_ebf8d9d4

This file is a frozen historical copy: don't fix it, don't refactor it, and
don't import it from the library. It will stop resembling `waiting.py` as soon
as that module changes again, which is exactly the point.
"""

from __future__ import annotations

from time import monotonic
from asyncio import Event, TimeoutError, get_event_loop, wait_for

from psycopg import errors as e
from psycopg.abc import RV, PQGen
from psycopg._enums import Ready, Wait
from psycopg.waiting import _wait_time

WAIT_R = Wait.R
WAIT_W = Wait.W
READY_R = Ready.R
READY_W = Ready.W


async def wait_async_ebf8d9d4(
    gen: PQGen[RV], fileno: int, interval: float = 0.0, timeout: float | None = None
) -> RV:
    """
    Coroutine waiting for a generator to complete.

    :param gen: a generator performing database operations and yielding
        `Ready` values when it would block.
    :param fileno: the file descriptor to wait on.
    :param interval: interval (in seconds) to check for other interrupt, e.g.
        to allow Ctrl-C.
    :param timeout: maximum time (in seconds) to wait for `!gen` to complete.
        Raise `~psycopg.errors._WaitTimeout` when it expires. `!None` means no
        timeout.
    :return: whatever `!gen` returns on completion.

    Behave like in `wait()`, but exposing an `asyncio` interface.
    """
    if interval is None:
        raise ValueError("indefinite wait not supported anymore")
    deadline = monotonic() + timeout if timeout is not None else None

    # Use an event to block and restart after the fd state changes.
    # Not sure this is the best implementation but it's a start.
    ev = Event()
    loop = get_event_loop()
    ready: int
    s: Wait

    def wakeup(state: Ready) -> None:
        nonlocal ready
        ready |= state
        ev.set()

    try:
        s = next(gen)
        while True:
            reader = s & WAIT_R
            writer = s & WAIT_W
            if not (reader or writer):
                raise e.InternalError(f"bad poll status: {s}")
            ev.clear()
            ready = 0
            if reader:
                loop.add_reader(fileno, wakeup, READY_R)
            if writer:
                loop.add_writer(fileno, wakeup, READY_W)
            try:
                t = interval if deadline is None else _wait_time(interval, deadline)
                try:
                    await wait_for(ev.wait(), t)
                except TimeoutError:
                    pass
            finally:
                if reader:
                    loop.remove_reader(fileno)
                if writer:
                    loop.remove_writer(fileno)
            s = gen.send(ready)

            if deadline is not None and monotonic() >= deadline:
                raise e._WaitTimeout("wait timeout expired")

    except OSError as ex:
        # Assume the connection was closed
        raise e.OperationalError("connection socket closed") from ex
    except StopIteration as ex:
        rv: RV = ex.value
        return rv
