defmodule PredictionAnalyzerWeb.AccuracyControllerTest do
  use PredictionAnalyzerWeb.ConnCase
  alias PredictionAnalyzer.PredictionAccuracy.PredictionAccuracy

  @today DateTime.to_date(Timex.local())

  @prediction_accuracy %PredictionAccuracy{
    service_date: @today,
    hour_of_day: 11,
    stop_id: "70120",
    route_id: "Green-B",
    arrival_departure: "departure",
    bin: "0-3 min",
    num_predictions: 40,
    num_accurate_predictions: 21
  }

  test "GET /", %{conn: conn} do
    PredictionAnalyzer.Repo.insert!(@prediction_accuracy)

    conn = get(conn, "/accuracy")
    response = html_response(conn, 200)

    assert response =~ "70120"
    assert response =~ "Green-B"
    assert response =~ "departure"
    assert response =~ "0-3 min"
    assert response =~ "40"
    assert response =~ "21"
  end

  test "GET /accuracy returns a top-level summary of accuracy", %{conn: conn} do
    a1 = %{@prediction_accuracy | num_accurate_predictions: 100, num_predictions: 100}

    a2 = %{@prediction_accuracy | num_accurate_predictions: 50, num_predictions: 100}

    PredictionAnalyzer.Repo.insert!(a1)
    PredictionAnalyzer.Repo.insert!(a2)

    conn = get(conn, "/accuracy")
    response = html_response(conn, 200)

    assert response =~ "From 150 accurate out of 200 total predictions"
    assert response =~ "75.0"
  end

  test "GET /accuracy with query params filter prediction accuracy statistics", %{conn: conn} do
    a1 = %{@prediction_accuracy | num_accurate_predictions: 10, num_predictions: 20}

    a2 = %{
      @prediction_accuracy
      | num_accurate_predictions: 20,
        num_predictions: 20,
        stop_id: "70121"
    }

    PredictionAnalyzer.Repo.insert!(a1)
    PredictionAnalyzer.Repo.insert!(a2)

    conn = get(conn, "/accuracy")
    assert html_response(conn, 200) =~ "From 30 accurate out of 40 total predictions"

    conn = get(conn, "/accuracy", %{"filters" => %{"stop_id" => "70120"}})
    assert html_response(conn, 200) =~ "From 10 accurate out of 20 total predictions"
  end
end
