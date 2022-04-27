use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :prediction_analyzer, PredictionAnalyzerWeb.Endpoint,
  secret_key_base: "local_secret_key_base_at_least_64_bytes_________________________________",
  http: [port: 4001],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn

# Configure your database
config :prediction_analyzer, PredictionAnalyzer.Repo,
  url: "#{System.get_env("DATABASE_ROOT_URL")}/prediction_analyzer_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  # debug errors in test
  show_sensitive_data_on_connection_error: true

config :prediction_analyzer,
  http_fetcher: FakeHTTPoison,
  aws_predictions_url: "https://prod.example.com/mbta-gtfs-s3/rtr/TripUpdates_enhanced.json",
  dev_green_aws_predictions_url:
    "https://dev_green.example.com/mbta-gtfs-s3/rtr/TripUpdates_enhanced.json"

config :prediction_analyzer, start_workers: false
config :prediction_analyzer, :stop_name_fetcher, PredictionAnalyzer.FakeStopNameFetcher
config :prediction_analyzer, retry_sleep_time: 1
