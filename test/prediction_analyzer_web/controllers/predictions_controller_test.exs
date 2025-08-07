defmodule PredictionAnalyzerWeb.PredictionsControllerTest do
  use PredictionAnalyzerWeb.ConnCase

  @prediction %PredictionAnalyzer.Predictions.Prediction{
    file_timestamp: 1_754_573_400,
    vehicle_id: "vehicle",
    environment: "dev-green",
    trip_id: "trip",
    is_deleted: false,
    delay: 0,
    arrival_time: nil,
    boarding_status: nil,
    departure_time: nil,
    schedule_relationship: "SCHEDULED",
    stop_id: "70106",
    route_id: "route",
    direction_id: 0,
    stop_sequence: 10,
    stops_away: 2,
    vehicle_event_id: nil,
    kind: "mid_trip",
    nth_at_stop: 5
  }

  @vehicle_event %PredictionAnalyzer.VehicleEvents.VehicleEvent{
    vehicle_id: "vehicle",
    environment: "dev-green",
    vehicle_label: "label",
    is_deleted: false,
    route_id: "route",
    direction_id: 0,
    trip_id: "trip",
    stop_id: "stop",
    arrival_time: nil,
    departure_time: nil
  }

  describe "csv/2" do
    test "renders a valid CSV", %{conn: conn} do
      %{id: ve_id} = PredictionAnalyzer.Repo.insert!(@vehicle_event)

      PredictionAnalyzer.Repo.insert!(%{@prediction | vehicle_event_id: ve_id})

      conn = get(conn, "/predictions?date=2025-08-07&hour=9&stop_id=70106")

      headers = Enum.into(conn.resp_headers, %{})
      assert headers["content-type"] == "application/csv"

      assert conn.resp_body =~ "departure_time"
      assert conn.resp_body =~ "trip_id"
      assert conn.resp_body =~ "route"
    end
  end
end
