defmodule PredictionAnalyzerWeb.PredictionsControllerTest do
  use PredictionAnalyzerWeb.ConnCase

  test "GET /", %{conn: conn} do
    vehicle_event = %PredictionAnalyzer.VehicleEvents.VehicleEvent{
      vehicle_id: "v1",
      vehicle_label: "l1",
      is_deleted: false,
      route_id: "r1",
      direction_id: 0,
      trip_id: "TEST_TRIP",
      stop_id: "70107",
      arrival_time: 1_000_001,
      departure_time: 1_000_002
    }

    {:ok, %{id: vehicle_event_id}} = PredictionAnalyzer.Repo.insert(vehicle_event)

    prediction = %PredictionAnalyzer.Predictions.Prediction{
      trip_id: "TEST_TRIP",
      is_deleted: false,
      delay: 0,
      arrival_time: 1_539_896_675,
      boarding_status: "Stopped at station",
      departure_time: nil,
      schedule_relationship: "SCHEDULED",
      stop_id: "70107",
      stop_sequence: 310,
      stops_away: 0,
      vehicle_event_id: vehicle_event_id
    }

    PredictionAnalyzer.Repo.insert!(prediction)

    response =
      conn
      |> get("/predictions")
      |> html_response(200)

    assert response =~ "trip_id"
    assert response =~ "is_deleted"
    assert response =~ "delay"
    assert response =~ "arrival_time"
    assert response =~ "boarding_status"
    assert response =~ "departure_time"
    assert response =~ "schedule_relationship"
    assert response =~ "stop_id"
    assert response =~ "stop_sequence"
    assert response =~ "stops_away"
    assert response =~ "TEST_TRIP"
    assert response =~ "1000001"
    assert response =~ "1000002"
  end
end
