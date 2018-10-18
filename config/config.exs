# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# General application configuration
config :prediction_analyzer,
  ecto_repos: [PredictionAnalyzer.Repo]

# Configures the endpoint
config :prediction_analyzer, PredictionAnalyzerWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "WwAbiSXUXI/0bYooMLdKT+9xyqLZvqcT0SfY1OPfwdoskZ4UelRc/08JhEy74zGU",
  render_errors: [view: PredictionAnalyzerWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: PredictionAnalyzer.PubSub,
           adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:user_id]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
