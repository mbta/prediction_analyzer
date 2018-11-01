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

    query =
      from(
        acc in relevant_accuracies,
        order_by: [desc: :service_date, desc: :hour_of_day],
        limit: 100
      )

    accuracies = PredictionAnalyzer.Repo.all(query)

    render(
      conn,
      "index.html",
      accuracies: accuracies,
      num_predictions: num_predictions,
      num_accurate: num_accurate
    )
  end
end
