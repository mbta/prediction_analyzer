defmodule PredictionAnalyzerWeb.PredictionsControllerTest do
  use PredictionAnalyzerWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, "/predictions")

    prediction = %Predictions.Prediction{
      trip_id: "TEST_TRIP",
      is_deleted: false,
      delay: 0,
      arrival_time: 1_539_896_675,
      boarding_status: "Stopped at station",
      departure_time: nil,
      schedule_relationship: "SCHEDULED",
      stop_id: "70107",
      stop_sequence: 310,
      stops_away: 0
    }

    PredictionAnalyzer.Repo.insert(prediction)

    response = html_response(conn, 200)
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
  end
end
