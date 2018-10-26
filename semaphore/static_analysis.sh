#!/usr/bin/env bash
set -e
set -x

# run pronto in background
MIX_ENV=test pronto run -f github github_status -c origin/master &
pronto_pid=$!

MIX_ENV=test mix coveralls.json
bash <(curl -s https://codecov.io/bash) -t $PREDICTION_ANALYZER_CODECOV_TOKEN
MIX_ENV=test mix test --only integration

# copy any pre-built PLTs to the right directory
find $SEMAPHORE_CACHE_DIR -name "dialyxir_*_deps-test.plt*" | xargs -I{} cp '{}' _build/test

export ERL_CRASH_DUMP=/dev/null
MIX_ENV=test mix dialyzer --plt

# copy build PLTs back
cp _build/test/*_deps-test.plt* $SEMAPHORE_CACHE_DIR

MIX_ENV=test mix dialyzer --halt-exit-status

mix format mix.exs "lib/**/*.{ex,exs}" "test/**/*.{ex,exs}" --check-formatted

wait $pronto_pid
