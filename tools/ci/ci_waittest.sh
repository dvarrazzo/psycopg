#!/bin/bash

# Run the async wait functions benchmarks in Github Action.
#
# TEMPORARY: this script is run by the "Wait benchmark" workflow
# (.github/workflows/waittest.yml) in order to compare the performance of
# wait_async() across the platforms we support. Together with that workflow and
# with tests/scripts/wait_async_ebf8d9d4.py, it is scaffolding to review #1331
# and it is not meant to reach master.
#
# The output is written to the directory in WAITTEST_OUT (default: waittest-out)
# to be uploaded as a workflow artifact, because the numbers are hard to read
# from the CI logs, and printed too.
#
# The name of the file is passed as first argument and should identify the
# matrix entry, e.g. "linux-py3.12-c".

set -euo pipefail

name="${1:?usage: $0 NAME}"
outdir="${WAITTEST_OUT:-waittest-out}"
out="${outdir}/${name}.txt"

# The measures are repeated this many times and the median is reported. Keep an
# eye on the total run time: macOS and Windows runners are much slower than the
# Linux ones.
rounds="${WAITTEST_ROUNDS:-9}"
nqueries="${WAITTEST_NQUERIES:-1000}"
nrows="${WAITTEST_NROWS:-50000}"

# The implementation to compare the current one with. It lives in the same
# directory as the script, which Python puts on the path.
old="wait_async_ebf8d9d4:wait_async_ebf8d9d4"

script="tests/scripts/waittest.py"

mkdir -p "${outdir}"

{
    echo "# ${name}"
    echo "#"
    echo "# date: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    echo "# uname: $(uname -a)"
    echo "# python: $(python -VV | tr '\n' ' ')"
    echo "# psycopg: $(python -c '
import psycopg
print(psycopg.__version__, "impl:", psycopg.pq.__impl__, "libpq:", psycopg.pq.version())
')"
    echo "# rounds: ${rounds} nqueries: ${nqueries} nrows: ${nrows}"
    echo "#"
    echo "# BEWARE: CI runners are noisy and macOS and Windows ones are slow:"
    echo "# the wall clock differences are indicative at best. The idle CPU"
    echo "# measure is the robust one, as a spinning wait function would burn a"
    echo "# whole core instead of a fraction of a percent."
    echo
} | tee "${out}"

# Time the workloads, comparing the current implementation with the old one.
python "${script}" bench \
    --dsn "${PSYCOPG_TEST_DSN}" \
    --wait-async "${old}" \
    --rounds "${rounds}" \
    --nqueries "${nqueries}" \
    --nrows "${nrows}" \
    2>&1 | tee -a "${out}"

echo | tee -a "${out}"

# Check that neither implementation polls the socket instead of sleeping on it.
python "${script}" idle \
    --dsn "${PSYCOPG_TEST_DSN}" \
    --wait-async "${old}" \
    2>&1 | tee -a "${out}"

echo | tee -a "${out}"

# Report how often the wait function is entered by each workload, which tells
# whether the platform's numbers above are meaningful at all.
python "${script}" calls \
    --dsn "${PSYCOPG_TEST_DSN}" \
    --nqueries "${nqueries}" \
    --nrows "${nrows}" \
    2>&1 | tee -a "${out}"
