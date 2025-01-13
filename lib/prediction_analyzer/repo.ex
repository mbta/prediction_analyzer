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

    Keyword.merge(config,
      password: token,
      ssl_opts: [
        cacertfile: Path.join(:code.priv_dir(:prediction_analyzer), "aws-cert-bundle.pem"),
        verify: :verify_peer,
        server_name_indication: String.to_charlist(hostname),
        verify_fun:
          {&:ssl_verify_hostname.verify_fun/3, [check_hostname: String.to_charlist(hostname)]}
      ]
    )
  end
end
