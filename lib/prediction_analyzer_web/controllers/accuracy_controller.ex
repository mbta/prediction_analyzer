defmodule PredictionAnalyzerWeb.AccuracyController do
  use PredictionAnalyzerWeb, :controller
  alias PredictionAnalyzer.PredictionAccuracy.PredictionAccuracy

  import Ecto.Query, only: [from: 2]

  def index(conn, _params) do
    query =
      from(
        acc in PredictionAccuracy,
        order_by: [desc: :service_date, desc: :hour_of_day],
        limit: 100
      )

    accuracies = PredictionAnalyzer.Repo.all(query)
    render(conn, "index.html", accuracies: accuracies)
  end
end
