defmodule PredictionAnalyzer.Repo do
  use Ecto.Repo, otp_app: :prediction_analyzer, adapter: Ecto.Adapters.Postgres
  require Logger

  @doc """
  Set via the `:configure` option in the PredictionAnalyzer.Repo configuration, a function
  invoked prior to each DB connection. `config` is the configured connection values
  and it returns a new set of config values to be used when connecting.
  """
  def before_connect(config) do
    :ok = Logger.info("generating_aws_rds_iam_auth_token")
    username = Keyword.fetch!(config, :username)
    hostname = Keyword.fetch!(config, :hostname)
    port = Keyword.fetch!(config, :port)

    mod = Application.get_env(:prediction_analyzer, :aws_rds_mod)
    token = mod.generate_db_auth_token(hostname, username, port, %{})
    :ok = Logger.info("generated_aws_rds_iam_auth_token")

    certfile_path = Path.join(:code.priv_dir(:prediction_analyzer), "aws-cert-bundle.pem")

    Keyword.merge(config,
      password: token,
      ssl: true,
      ssl_opts: [
        cacertfile: certfile_path,
        verify: :verify_peer,
        server_name_indication: String.to_charlist(hostname),
        verify_fun:
          {&:ssl_verify_hostname.verify_fun/3, [check_hostname: String.to_charlist(hostname)]}
      ]
    )
    |> tap(fn conf ->
      IO.inspect(conf, label: "Repo config")
      IO.inspect(Keyword.get(conf, :ssl), label: "ssl key")
      IO.inspect(Keyword.get(conf, :ssl_opts), label: "ssl_opts key")
      IO.inspect(certfile_path, label: "certfile path")
      IO.inspect(File.exists?(certfile_path), label: "certfile exists at that path?")
      IO.inspect(File.regular?(certfile_path), label: "certfile is a file and not dir?")
    end)
  end
end
