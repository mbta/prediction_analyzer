defmodule PredictionAnalyzer.Repo do
  use Ecto.Repo, otp_app: :prediction_analyzer

  def init(_, opts) do
    {:ok, Keyword.put_new(opts, :url, System.get_env("DATABASE_URL"))}
  end
end
