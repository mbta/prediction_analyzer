defmodule PredictionAnalyzerWeb.AccuracyController do
  use PredictionAnalyzerWeb, :controller
  alias PredictionAnalyzer.PredictionAccuracy.PredictionAccuracy

  import Ecto.Query, only: [from: 2]

  def index(conn, params) do
    relevant_accuracies = PredictionAccuracy.filter(params["filters"] || %{})

    [num_accurate, num_predictions] =
      from(
        acc in relevant_accuracies,
        select: [sum(acc.num_accurate_predictions), sum(acc.num_predictions)]
      )
      |> PredictionAnalyzer.Repo.one!()

    accuracies =
      relevant_accuracies
      |> PredictionAccuracy.stats_by_environment_and_hour()
      |> PredictionAnalyzer.Repo.all()

    render(
      conn,
      "index.html",
      accuracies: accuracies,
      num_predictions: num_predictions,
      num_accurate: num_accurate
    )
  end
end
