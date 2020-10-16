# PredictionAnalyzer

An app for aggregating and analyzing the accuracy of GTFS predictions using
TripUpdates and VehiclePositions over time.

## Prerequisites

* PostgreSQL 10+
* [`asdf`](https://asdf-vm.com/#/core-manage-asdf)
* [`direnv`](https://github.com/direnv/direnv/blob/master/docs/installation.md)
   _(recommended)_

PostgreSQL and Direnv are available on macOS Homebrew.

## Setup

1. `asdf install`
2. `cp .envrc.template .envrc`
   * You may have to adjust `DATABASE_ROOT_URL` in this file to reflect your
     Postgres install, e.g. changing `postgres@` to `your_username@`
3. `direnv allow`
4. `mix deps.get`
5. `mix ecto.setup`
6. `npm install --prefix assets`

## Common Tasks

* Run the app: `mix phx.server` (then go to <http://localhost:4000>)
* Run the tests: `mix test`
