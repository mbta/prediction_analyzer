defmodule PredictionAnalyzerWeb.PredictionsController do
  use PredictionAnalyzerWeb, :controller

  import Ecto.Query, only: [from: 2]
  alias PredictionAnalyzer.Predictions.Prediction

  def index(conn, _params) do
    query =
      from(p in Prediction, order_by: [:arrival_time, :departure_time], limit: 100)

    predictions = PredictionAnalyzer.Repo.all(query)
    render(conn, "index.html", predictions: predictions)
  end
end
