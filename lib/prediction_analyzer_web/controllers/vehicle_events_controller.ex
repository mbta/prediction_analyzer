defmodule PredictionAnalyzerWeb.VehicleEventsController do
  use PredictionAnalyzerWeb, :controller
  import Ecto.Query, only: [from: 2]
  alias PredictionAnalyzer.VehicleEvents.VehicleEvent

  def index(conn, _params) do
    query = from(vp in VehicleEvent, order_by: [:arrival_time, :departure_time], limit: 100)

    vehicle_events = PredictionAnalyzer.Repo.all(query)
    render(conn, "index.html", vehicle_events: vehicle_events)
  end
end
