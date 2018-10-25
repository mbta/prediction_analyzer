defmodule PredictionAnalyzerWeb.VehicleEventsTest do
  use PredictionAnalyzerWeb.ConnCase

  test "GET /", %{conn: conn} do
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

    conn = get(conn, "/vehicle_events")
    response = html_response(conn, 200)
    assert response =~ "abc123"
    assert response =~ "1234"
    assert response =~ "false"
    assert response =~ "Red"
    assert response =~ "0"
    assert response =~ "R12345"
    assert response =~ "71234"
    assert response =~ "1234567"
    assert response =~ "2345678"
  end
end
