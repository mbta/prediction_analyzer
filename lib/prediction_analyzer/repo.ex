defmodule PredictionAnalyzer.Repo do
  use Ecto.Repo, otp_app: :prediction_analyzer, adapter: Ecto.Adapters.Postgres

  def init(_, opts) do
    {:ok, Keyword.put_new(opts, :url, System.get_env("DATABASE_URL"))}
  end
end
