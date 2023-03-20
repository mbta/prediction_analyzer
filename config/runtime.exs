import Config

if config_env() == :prod do
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

  config :arrow, PredictionAnalyzer.Repo,
    username: System.get_env("DATABASE_USER"),
    database: System.get_env("DATABASE_NAME"),
    hostname: System.get_env("DATABASE_HOST"),
    port: port,
    pool_size: pool_size,
    # password set by `configure` callback below
    configure: {PredictionAnalyzer.Repo, :before_connect, []}
end
