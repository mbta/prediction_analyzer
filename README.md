# PredictionAnalyzer

To start your Phoenix server:

  * Install dependencies with `mix deps.get`
  * Create and migrate your database with `mix ecto.create && mix ecto.migrate`
  * Install Node.js dependencies with `cd assets && npm install`
  * Start Phoenix endpoint with `mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](http://www.phoenixframework.org/docs/deployment).
An app for aggregating and analyzing the accuracy of gtfs predictions using TripUpdates and VehiclePositions over time.

## Running the app

In order to run this app locally you will need to set several ENV variables.
For downloading the trip updates and vehicle positions, you will need an `AWS_PREDICTIONS_URL` and `AWS_VEHICLE_POSITIONS_URL`.

In order to store them you will need a local postgres database, run the migrations, and set a `DATABASE_URL` in the form:
`postgresql://<usernam>:<password>@<hostname>:<port>/<database_name>`

Example run command:
`AWS_PREDICTIONS_URL="https://s3.amazonaws.com/mbta-gtfs-s3/rtr/TripUpdates_enhanced.json" AWS_VEHICLE_POSITIONS_URL="https://s3.amazonaws.com/mbta-gtfs-s3/rtr/VehiclePositions_enhanced.json" DATABASE_URL="postgres://user:pass@localhost:5432/prediction_analyzer_repo" iex -S mix`

## Learn more

  * Official website: http://www.phoenixframework.org/
  * Guides: http://phoenixframework.org/docs/overview
  * Docs: https://hexdocs.pm/phoenix
  * Mailing list: http://groups.google.com/group/phoenix-talk
  * Source: https://github.com/phoenixframework/phoenix
