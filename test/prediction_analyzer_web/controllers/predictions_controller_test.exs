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
      file_timestamp: 1_542_558_122,
      trip_id: "TEST_TRIP",
      is_deleted: false,
      delay: 0,
      arrival_time: 1_539_896_675,
      boarding_status: "Stopped at station",
      departure_time: nil,
      schedule_relationship: "SCHEDULED",
      route_id: "r1",
      stop_id: "70107",
      stop_sequence: 310,
      stops_away: 0,
      vehicle_event_id: vehicle_event_id
    }

    PredictionAnalyzer.Repo.insert!(prediction)

    response =
      conn
      |> get("/predictions?stop_id=70107&service_date=2018-11-18&hour=11")
      |> html_response(200)

    assert response =~ "TEST_TRIP"
    assert response =~ "false"
    assert response =~ "0"
    assert response =~ "1539896675"
    assert response =~ "Stopped at station"
    assert response =~ "SCHEDULED"
    assert response =~ "r1"
    assert response =~ "70107"
    assert response =~ "310"
    assert response =~ "0"
    assert response =~ "TEST_TRIP"
    assert response =~ "1000001"
    assert response =~ "1000002"
  end

  test "GET /predictions with format=csv downloads file", %{conn: conn} do
    response =
      conn
      |> get("/predictions?format=csv")
      |> response(200)

    assert response =~ "env,file_timestamp,is_deleted"
  end
end
