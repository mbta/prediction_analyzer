defmodule PredictionAnalyzer.Repo do
  use Ecto.Repo, otp_app: :prediction_analyzer

  def init(_, opts) do
    opts =
      Keyword.put(
        opts,
        :url,
        System.get_env("DATABASE_URL")
      )

    {:ok, opts}
  end
end
