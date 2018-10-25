defmodule PredictionAnalyzerWeb.VehicleEventsTest do
  use PredictionAnalyzerWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, "/vehicle_events")

    event = %PredictionAnalyzer.VehicleEvents.VehicleEvent{
      vehicle_id: "abc123",
      vehicle_label: "1234",
      is_deleted: false,
      route_id: "Red",
      direction_id: 0,
      trip_id: "R12345",
      stop_id: "71234",
      arrival_time: 1_234_567,
      departure_time: 2_345_678
    }

    PredictionAnalyzer.Repo.insert(event)

    response = html_response(conn, 200)
    assert response =~ "vehicle_id"
    assert response =~ "vehicle_label"
    assert response =~ "is_deleted"
    assert response =~ "route_id"
    assert response =~ "direction_id"
    assert response =~ "trip_id"
    assert response =~ "stop_id"
    assert response =~ "arrival_time"
    assert response =~ "departure_time"
  end
end
