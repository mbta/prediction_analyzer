#!/usr/bin/env bash
set -e
set -x

MIX_ENV=test mix coveralls.json
bash <(curl -s https://codecov.io/bash) -t $PREDICTION_ANALYZER_CODECOV_TOKEN -r mbta/prediction_analyzer

mix format --check-formatted
npm --prefix assets run check

# copy any pre-built PLTs to the right directory
find $SEMAPHORE_CACHE_DIR -name "dialyxir_*_deps-test.plt*" | xargs -I{} cp '{}' _build/test

MIX_ENV=test mix dialyzer --plt
# copy build PLTs back
cp _build/test/*_deps-test.plt* $SEMAPHORE_CACHE_DIR

MIX_ENV=test mix dialyzer --halt-exit-status
