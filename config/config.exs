# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# Configures the endpoint
config :prediction_analyzer, PredictionAnalyzerWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [view: PredictionAnalyzerWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: PredictionAnalyzer.PubSub, adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  level: :debug,
  format: "$time $metadata[$level] $message\n",
  metadata: [:user_id]

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#

config :prediction_analyzer, ecto_repos: [PredictionAnalyzer.Repo]
config :prediction_analyzer, http_fetcher: HTTPoison
config :prediction_analyzer, :api_base_url, "https://api-v3.mbta.com/"
config :prediction_analyzer, :migration_task, Predictions.ReleaseTasks.NoOp
config :prediction_analyzer, :stop_name_fetcher, PredictionAnalyzer.StopNameFetcher
config :prediction_analyzer, :timezone, "America/New_York"
config :prediction_analyzer, :max_dwell_time_sec, 30 * 60
config :prediction_analyzer, :prune_lookback_sec, 12 * 60 * 60

config :prediction_analyzer, PredictionAnalyzer.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: "prediction_analyzer_repo"

config :prediction_analyzer, start_workers: true

config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase

config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
