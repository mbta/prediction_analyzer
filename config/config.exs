# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# Configures the endpoint
config :prediction_analyzer, PredictionAnalyzerWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "local_secret_key_base",
  render_errors: [view: PredictionAnalyzerWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: PredictionAnalyzer.PubSub, adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
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
config :prediction_analyzer, :migration_task, Predictions.ReleaseTasks.NoOp

config :prediction_analyzer, PredictionAnalyzer.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: "prediction_analyzer_repo"

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
