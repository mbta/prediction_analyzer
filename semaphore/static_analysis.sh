#!/usr/bin/env bash
set -e
set -x

mix format mix.exs "lib/**/*.{ex,exs}" "test/**/*.{ex,exs}" --check-formatted
