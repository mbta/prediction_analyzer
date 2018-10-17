defmodule Predictions.Repo do
  use Ecto.Repo, otp_app: :prediction_analyzer

  def init(_, opts) do
    opts =
      opts
      |> Keyword.put(
        :username,
        System.get_env("DB_USERNAME")
      )
      |> Keyword.put(
        :password,
        System.get_env("DB_PASSWORD")
      )
      |> Keyword.put(
        :hostname,
        System.get_env("DB_HOSTNAME")
      )

    {:ok, opts}
  end
end
