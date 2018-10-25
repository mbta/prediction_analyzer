defmodule PredictionAnalyzerWeb.PredictionsController do
  use PredictionAnalyzerWeb, :controller

  import Ecto.Query, only: [from: 2]
  alias PredictionAnalyzer.Predictions.Prediction

  def index(conn, _params) do
    query =
      from(
        p in Prediction,
        join: ve in assoc(p, :vehicle_event),
        order_by: [desc: :arrival_time, desc: :departure_time],
        limit: 100,
        preload: [vehicle_event: ve],
        select: p
      )

    predictions = PredictionAnalyzer.Repo.all(query)
    render(conn, "index.html", predictions: predictions)
  end
end
