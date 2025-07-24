import Config

if config_env() == :prod do
  sentry_env = System.fetch_env!("SENTRY_ENV")

  config :sentry,
    dsn: System.fetch_env!("SENTRY_DSN"),
    environment_name: sentry_env,
    tags: %{
      env: sentry_env
    }

  pool_size =
    case System.get_env("DATABASE_POOL_SIZE") do
      nil -> 15
      val -> String.to_integer(val)
    end

  port =
    case System.get_env("DATABASE_PORT") do
      nil -> nil
      val -> String.to_integer(val)
    end

  config :prediction_analyzer, PredictionAnalyzer.Repo,
    username: System.get_env("DATABASE_USER"),
    database: System.get_env("DATABASE_NAME"),
    hostname: System.get_env("DATABASE_HOST"),
    port: port,
    pool_size: pool_size,
    timeout: 60_000,
    pool_timeout: 60_000,
    # password set by `configure` callback below
    configure: {PredictionAnalyzer.Repo, :before_connect, []}
end
