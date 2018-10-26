#!/usr/bin/env bash
set -e
set -x

# run pronto in background
MIX_ENV=test pronto run -f github github_status -c origin/master &
pronto_pid=$!


export ERL_CRASH_DUMP=/dev/null

mix format mix.exs "lib/**/*.{ex,exs}" "test/**/*.{ex,exs}" --check-formatted

wait $pronto_pid
