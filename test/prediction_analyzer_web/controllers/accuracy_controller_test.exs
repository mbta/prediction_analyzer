defmodule PredictionAnalyzerWeb.AccuracyControllerTest do
  use PredictionAnalyzerWeb.ConnCase

  test "GET /", %{conn: conn} do
    event = %PredictionAnalyzer.PredictionAccuracy.PredictionAccuracy{
      service_date: ~D[2018-10-31],
      hour_of_day: 11,
      stop_id: "70120",
      route_id: "Green-B",
      arrival_departure: "departure",
      bin: "0-3 min",
      num_predictions: 40,
      num_accurate_predictions: 21
    }

    PredictionAnalyzer.Repo.insert(event)

    conn = get(conn, "/accuracy")
    response = html_response(conn, 200)
    assert response =~ "2018-10-31"
    assert response =~ "10"
    assert response =~ "70120"
    assert response =~ "Green-B"
    assert response =~ "departure"
    assert response =~ "0-3 min"
    assert response =~ "40"
    assert response =~ "21"
  end
end
