defmodule PredictionAnalyzerWeb.AccuracyControllerTest do
  use PredictionAnalyzerWeb.ConnCase
  alias PredictionAnalyzer.PredictionAccuracy.PredictionAccuracy
  alias PredictionAnalyzer.WeeklyAccuracies.WeeklyAccuracies

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

  @weekly_accuracy %WeeklyAccuracies{
    week_start: @today,
    arrival_departure: "departure",
    bin: "0-3 min",
    direction_id: 1,
    environment: "prod",
    num_accurate_predictions: 327,
    num_predictions: 617,
    route_id: "Blue",
    stop_id: "70038"
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
    insert_hourly_accuracy("prod", 10, 101, 99)
    insert_hourly_accuracy("prod", 10, 108, 102)
    insert_hourly_accuracy("prod", 11, 225, 211)
    insert_hourly_accuracy("prod", 11, 270, 261)
    insert_hourly_accuracy("dev-green", 10, 401, 399)
    insert_hourly_accuracy("dev-green", 10, 408, 302)
    insert_hourly_accuracy("dev-green", 11, 525, 411)
    insert_hourly_accuracy("dev-green", 11, 570, 461)

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
             "filters[route_ids]" => "",
             "filters[stop_id]" => "",
             "filters[direction_id]" => "any",
             "filters[arrival_departure]" => "all",
             "filters[bin]" => "All",
             "filters[mode]" => "subway"
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
        "filters" => %{
          "chart_range" => "Daily",
          "date_start" => "2019-01-01",
          "route_ids" => "",
          "stop_id" => "",
          "direction_id" => "any",
          "arrival_departure" => "all",
          "bin" => "All"
        }
      })

    today = Timex.local() |> Date.to_string()

    assert response(conn, 302)
    assert redirected_to(conn) =~ "Daily"
    assert redirected_to(conn) =~ "filters[date_start]=2019-01-01"
    assert redirected_to(conn) =~ "filters[date_end]=#{today}"
  end

  test "GET /accuracy maintains service date when redirecting", %{conn: conn} do
    conn =
      get(conn, "/accuracy", %{
        "filters" => %{
          "chart_range" => "Hourly",
          "service_date" => "2019-01-01"
        }
      })

    assert response(conn, 302)
    assert redirected_to(conn) =~ "Hourly"
    assert redirected_to(conn) =~ "2019-01-01"
  end

  test "GET /accuracy when the filters dont have time filters, redirects such that it does", %{
    conn: conn
  } do
    conn =
      get(conn, "/accuracy", %{
        "filters" => %{
          "route_ids" => "",
          "stop_id" => "",
          "direction_id" => "any",
          "arrival_departure" => "all",
          "bin" => "All",
          "mode" => "subway"
        }
      })

    assert response(conn, 302)
    assert redirected_to(conn) =~ "Hourly"
  end

  test "GET /accuracy maintains daily date range when redirecting", %{conn: conn} do
    conn =
      get(conn, "/accuracy", %{
        "filters" => %{
          "chart_range" => "Daily",
          "date_start" => "2019-01-01",
          "date_end" => "2019-01-05"
        }
      })

    assert response(conn, 302)
    assert redirected_to(conn) =~ "Daily"
    assert redirected_to(conn) =~ "2019-01-01"
    assert redirected_to(conn) =~ "2019-01-05"
  end

  test "GET /accuracy with invalid date renders error", %{conn: conn} do
    conn =
      get(conn, "/accuracy", %{
        "filters" => %{
          "chart_range" => "Daily",
          "date_start" => "2019-01-01",
          "date_end" => "invalid",
          "route_ids" => "",
          "mode" => "subway",
          "stop_id" => "",
          "direction_id" => "any",
          "arrival_departure" => "all",
          "bin" => "All"
        }
      })

    response = html_response(conn, 200)
    assert response =~ "Can&#39;t parse start or end date."
  end

  test "GET /accuracy can be changed to weekly", %{conn: conn} do
    insert_weekly_accuracy("prod", @today, 10, 9)
    insert_weekly_accuracy("dev-green", @today, 10, 8)

    conn =
      get(conn, "/accuracy", %{
        "filters" => %{
          "arrival_departure" => "all",
          "bin" => "All",
          "chart_range" => "Weekly",
          "direction_id" => "any",
          "mode" => "subway",
          "route_ids" => "",
          "date_start" => @today_str,
          "date_end" => @today_str,
          "stop_id" => ""
        }
      })

    response = html_response(conn, 200)

    assert response =~ "<th>Week Start</th>"
    refute response =~ "<th>Hour</th>"
    refute response =~ "<th>Date</th>"
  end

  test "GET /accuracy redirects such that it has a date if it wasnt given dates on the weekly view",
       %{conn: conn} do
    insert_weekly_accuracy("prod", @today, 10, 9)
    insert_weekly_accuracy("dev-green", @today, 10, 8)

    conn =
      get(conn, "/accuracy", %{
        "filters" => %{
          "arrival_departure" => "all",
          "bin" => "All",
          "chart_range" => "Weekly",
          "direction_id" => "any",
          "mode" => "subway",
          "route_ids" => "",
          "stop_id" => ""
        }
      })

    response = html_response(conn, 302)

    assert response =~ "redirected"
  end

  test "GET /accuracy/subway gets the index for subway mode", %{conn: conn} do
    conn = get(conn, "/accuracy/subway", %{})

    assert response(conn, 302)
    assert conn.assigns[:mode] == :subway
  end

  test "GET /accuracy/commuter_rail gets the index for commuter rail mode", %{conn: conn} do
    conn = get(conn, "/accuracy/commuter_rail", %{})

    assert response(conn, 302)
    assert conn.assigns[:mode] == :commuter_rail
  end

  def insert_hourly_accuracy(env, hour, total, accurate) do
    PredictionAnalyzer.Repo.insert!(%{
      @prediction_accuracy
      | environment: env,
        hour_of_day: hour,
        num_predictions: total,
        num_accurate_predictions: accurate
    })
  end

  def insert_weekly_accuracy(env, week_start, total, accurate) do
    PredictionAnalyzer.Repo.insert!(%{
      @weekly_accuracy
      | environment: env,
        week_start: week_start,
        num_predictions: total,
        num_accurate_predictions: accurate
    })
  end
end
