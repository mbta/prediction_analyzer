#!/usr/bin/env bash
set -e
set -x

MIX_ENV=test mix coveralls.json
bash <(curl -s https://codecov.io/bash) -t $PREDICTION_ANALYZER_CODECOV_TOKEN -r mbta/prediction_analyzer

mix format --check-formatted
