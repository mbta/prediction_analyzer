import Config
require Logger

Logger.info("Begin runtime.exs")
Logger.info(config_env())

if config_env() == :prod do
  Logger.info("Begin prod config init")

  pool_size =
    case System.get_env("DATABASE_POOL_SIZE") do
      nil -> 10
      val -> String.to_integer(val)
    end

  port =
    case System.get_env("DATABASE_PORT") do
      nil -> nil
      val -> String.to_integer(val)
    end

  Logger.info(inspect(pool_size))
  Logger.info(inspect(port))

  config :arrow, PredictionAnalyzer.Repo,
    username: System.get_env("DATABASE_USER"),
    database: System.get_env("DATABASE_NAME"),
    hostname: System.get_env("DATABASE_HOST"),
    port: port,
    pool_size: pool_size,
    # password set by `configure` callback below
    configure: {PredictionAnalyzer.Repo, :before_connect, []}
end
