defmodule PredictionAnalyzerWeb.AccuracyController do
  use PredictionAnalyzerWeb, :controller
  alias PredictionAnalyzer.PredictionAccuracy.PredictionAccuracy

  import Ecto.Query, only: [from: 2]

  def index(conn, params) do
    relevant_accuracies = PredictionAccuracy.filter(params["filters"] || %{})

    accuracies =
      relevant_accuracies
      |> PredictionAccuracy.stats_by_environment_and_hour()
      |> PredictionAnalyzer.Repo.all()

    render(
      conn,
      "index.html",
      accuracies: accuracies
    )
  end
end
