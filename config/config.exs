# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
import Config

# Configures the endpoint
config :prediction_analyzer, PredictionAnalyzerWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [view: PredictionAnalyzerWeb.ErrorView, accepts: ~w(html json)],
  pubsub_server: PredictionAnalyzerWeb.PubSub

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

config :prediction_analyzer, aws_rds_mod: ExAws.RDS
config :prediction_analyzer, ecto_repos: [PredictionAnalyzer.Repo]
config :prediction_analyzer, http_fetcher: HTTPoison
config :prediction_analyzer, :api_base_url, "https://api-v3.mbta.com/"
config :prediction_analyzer, :migration_task, Predictions.ReleaseTasks.NoOp
config :prediction_analyzer, :stop_name_fetcher, PredictionAnalyzer.StopNameFetcher
config :prediction_analyzer, :timezone, "America/New_York"

config :prediction_analyzer, :max_dwell_time_sec,
  default: 30 * 60,
  mattapan: 20 * 60

config :prediction_analyzer, :prune_lookback_sec, 7 * 24 * 60 * 60
config :prediction_analyzer, :analysis_lookback_min, 40

config :prediction_analyzer, start_workers: true

config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase

config :phoenix, :json_library, Jason

config :prediction_analyzer, Oban,
  engine: Oban.Engines.Basic,
  queues: [default: 10],
  repo: PredictionAnalyzer.Repo,
  plugins: [
    {Oban.Plugins.Cron,
     timezone: "America/New_York",
     crontab: [
       # At 04:00 Eastern every Monday.
       {"0 4 * * MON", PredictionAnalyzer.Jobs.PredictionAccuracyPartitionWorker}
     ]}
  ]

# Config for incremental migration of the `prediction_accuracy` table.
config :prediction_analyzer, :prediction_accuracy_migration,
  monolithic: "prediction_accuracy_monolithic",
  partitioned: "prediction_accuracy_partitioned",
  migration_state: "prediction_accuracy_migration_state",
  copy_data_timeout: :timer.minutes(1) + :timer.seconds(55),
  # Number of service dates to copy per run of the incremental data migration job, as a `Duration.duration()`.
  # (1 day subtracted because the copy range is inclusive on both ends.)
  copy_duration: [week: 1, day: -1],
  # The migration can be finalized once data has been copied up to, but not including,
  # the window that ends after (today - min_days_in_past_for_finalize).
  min_days_in_past_for_finalize: 3

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
