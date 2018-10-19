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
For downloading the Trip updates, you will need an `AWS_ACCESS_KEY_ID` and a `AWS_SECRET_ACCESS_KEY`, as well as `AWS_PREDICTIONS_BUCKET`, and `AWS_PREDICTIONS_PATH`

In order to store them you will need a local postgres database, run the migrations, and set a `DB_URL` in the form:
`postgresql://<usernam>:<password>@<hostname>:<port>/<database_name>`

Example run command:
`AWS_PREDICTIONS_BUCKET=<bucket> AWS_PREDICTIONS_PATH=<path> AWS_ACCESS_KEY_ID=<access_id> AWS_SECRET_ACCESS_KEY=<secret_access_id> DB_URL=<url> DB_HOSTNAME=<hostname> iex -S mix`

## Learn more

  * Official website: http://www.phoenixframework.org/
  * Guides: http://phoenixframework.org/docs/overview
  * Docs: https://hexdocs.pm/phoenix
  * Mailing list: http://groups.google.com/group/phoenix-talk
  * Source: https://github.com/phoenixframework/phoenix
