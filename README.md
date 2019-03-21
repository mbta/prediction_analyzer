# PredictionAnalyzer

An app for aggregating and analyzing the accuracy of gtfs predictions using TripUpdates and VehiclePositions over time.

## Environment / Configuration

In order to run this app locally you will need to set several ENV variables.
For downloading the prod trip updates and vehicle positions, you will need an `AWS_PREDICTIONS_URL` and `AWS_VEHICLE_POSITIONS_URL`.
Similarly, for dev-green, you will need `DEV_GREEN_AWS_PREDICTIONS_URL` and `DEV_GREEN_AWS_VEHICLE_POSITIONS_URL`.

In order to store them you will need a local postgres database, run the migrations, and set a `DATABASE_URL` in the form:
`postgresql://<usernam>:<password>@<hostname>:<port>/<database_name>`. Usually `postgres` and a blank password works. If that
doesn't, try using your local system username instead.

Example run command:
`DATABASE_URL="postgres://postgres@localhost:5432/prediction_analyzer_repo" AWS_PREDICTIONS_URL="https://s3.amazonaws.com/mbta-gtfs-s3/rtr/TripUpdates_enhanced.json" AWS_VEHICLE_POSITIONS_URL="https://s3.amazonaws.com/mbta-gtfs-s3/rtr/VehiclePositions_enhanced.json" DEV_GREEN_AWS_PREDICTIONS_URL="https://s3.amazonaws.com/mbta-gtfs-s3-dev-green/rtr/TripUpdates_enhanced.json" DEV_GREEN_AWS_VEHICLE_POSITIONS_URL="https://s3.amazonaws.com/mbta-gtfs-s3-dev-green/rtr/VehiclePositions_enhanced.json"  iex -S mix`

## Quick Start

To start your Phoenix server:

  * Install dependencies with `mix deps.get`
  * You'll need a copy of Postgres running locally. There's an easy-to-use [Mac OS app](https://postgresapp.com/) you can use.
	Install the app and make sure it's running.
  * Create and migrate your database with `mix ecto.create && mix ecto.migrate`
  * Optionally, you can insert some randomized sample data for a few Red and Orange Line stations by running `mix ecto.reset`,
	supplying the environment variables given above, as in the example command.
  * Install Node.js dependencies with `cd assets && npm install`
  * Start Phoenix endpoint with `mix phx.server`, supplying the environment variables.

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Learn more

  * Official website: http://www.phoenixframework.org/
  * Guides: http://phoenixframework.org/docs/overview
  * Docs: https://hexdocs.pm/phoenix
  * Mailing list: http://groups.google.com/group/phoenix-talk
  * Source: https://github.com/phoenixframework/phoenix
