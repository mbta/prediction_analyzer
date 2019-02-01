defmodule PredictionAnalyzerWeb.AccuracyControllerTest do
  use PredictionAnalyzerWeb.ConnCase
  alias PredictionAnalyzer.PredictionAccuracy.PredictionAccuracy

  @today DateTime.to_date(Timex.local())
  @today_str Date.to_string(@today)

  @prediction_accuracy %PredictionAccuracy{
    environment: "prod",
    service_date: @today,
    hour_of_day: 11,
    stop_id: "70120",
    route_id: "Green-B",
    arrival_departure: "departure",
    bin: "0-3 min",
    num_predictions: 40,
    num_accurate_predictions: 21
  }

  test "GET /accuracy returns a top-level summary of accuracy", %{conn: conn} do
    a1 = %{@prediction_accuracy | num_accurate_predictions: 100, num_predictions: 100}

    a2 = %{@prediction_accuracy | num_accurate_predictions: 50, num_predictions: 100}

    PredictionAnalyzer.Repo.insert!(a1)
    PredictionAnalyzer.Repo.insert!(a2)

    conn = get(conn, "/accuracy")
    conn = get(conn, redirected_to(conn))
    response = html_response(conn, 200)

    assert response =~ "From 150 accurate out of 200 total predictions"
    assert response =~ "75.0"
  end

  test "GET /accuracy aggregates the results by hour", %{conn: conn} do
    insert_accuracy("prod", 10, 101, 99)
    insert_accuracy("prod", 10, 108, 102)
    insert_accuracy("prod", 11, 225, 211)
    insert_accuracy("prod", 11, 270, 261)
    insert_accuracy("dev-green", 10, 401, 399)
    insert_accuracy("dev-green", 10, 408, 302)
    insert_accuracy("dev-green", 11, 525, 411)
    insert_accuracy("dev-green", 11, 570, 461)

    conn = get(conn, "/accuracy")
    conn = get(conn, redirected_to(conn))
    response = html_response(conn, 200)

    # 101 + 108
    assert response =~ "209"
    # (99 + 102) / (101 + 108)
    assert response =~ "96.17%"

    # 525 + 570
    assert response =~ "1095"
    # (411 + 461) / (525 + 570)
    assert response =~ "79.63%"
  end

  test "GET /accuracy defaults to hourly", %{conn: conn} do
    conn = get(conn, "/accuracy")

    assert redirected_to(conn) =~ "/accuracy"

    assert %{
             "filters[chart_range]" => "Hourly",
             "filters[service_date]" => @today_str,
             "filters[route_id]" => "",
             "filters[stop_id]" => "",
             "filters[arrival_departure]" => "all",
             "filters[bin]" => "All"
           } ==
             URI.parse(redirected_to(conn))
             |> Map.get(:query)
             |> URI.decode_query()

    conn = get(conn, redirected_to(conn))
    response = html_response(conn, 200)

    assert response =~ "<th>Hour</th>"
    refute response =~ "<th>Date</th>"
  end

  test "GET /accuracy can be changed to daily", %{conn: conn} do
    conn = get(conn, "/accuracy", %{"filters" => %{"chart_range" => "Daily"}})
    conn = get(conn, redirected_to(conn))
    response = html_response(conn, 200)

    assert response =~ "<th>Date</th>"
    refute response =~ "<th>Hour</th>"
  end

  test "GET /accuracy with partial daily range redirects to full range", %{conn: conn} do
    conn =
      get(conn, "/accuracy", %{
        "filters" => %{"chart_range" => "Daily", "daily_date_start" => "2019-01-01"}
      })

    assert response(conn, 301)
    assert redirected_to(conn) =~ "Daily"
    assert redirected_to(conn) =~ "daily_date_start"
    assert redirected_to(conn) =~ "daily_date_end"
  end

  test "GET /accuracy with invalid date renders error", %{conn: conn} do
    conn =
      get(conn, "/accuracy", %{
        "filters" => %{
          "chart_range" => "Daily",
          "daily_date_start" => "2019-01-01",
          "daily_date_end" => "invalid"
        }
      })

    response = html_response(conn, 200)
    assert response =~ "Can't parse start or end date."
  end

  def insert_accuracy(env, hour, total, accurate) do
    PredictionAnalyzer.Repo.insert!(%{
      @prediction_accuracy
      | environment: env,
        hour_of_day: hour,
        num_predictions: total,
        num_accurate_predictions: accurate
    })
  end
end
