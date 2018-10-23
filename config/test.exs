use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :prediction_analyzer, PredictionAnalyzerWeb.Endpoint,
  http: [port: 4001],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn

# Configure your database
config :prediction_analyzer, PredictionAnalyzer.Repo,
  username: System.get_env("DATABASE_POSTGRESQL_USERNAME") || "postgres",
  password: System.get_env("DATABASE_POSTGRESQL_PASSWORD") || "postgres",
  database: "prediction_analyzer_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox
