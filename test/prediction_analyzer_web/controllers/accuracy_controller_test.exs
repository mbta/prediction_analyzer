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
    bin: "0-3 min",
    num_predictions: 40,
    num_accurate_predictions: 21
  }

  @last_of_month ~D[2020-01-31]
  @last_of_month_str Date.to_string(@last_of_month)
  @first_of_month ~D[2020-02-01]
  @first_of_month_str Date.to_string(@first_of_month)

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

    insert_hourly_accuracy("dev-blue", 10, 200, 100)
    insert_hourly_accuracy("dev-blue", 10, 100, 100)
    insert_hourly_accuracy("dev-blue", 11, 420, 200)
    insert_hourly_accuracy("dev-blue", 11, 420, 123)

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

    # 420 + 420
    assert response =~ "840"

    # (123 + 200) + (420 + 420)
    assert response =~ "38.45%"
  end

  test "GET /accuracy aggregates the results by hour, even when one environment is missing hours",
       %{conn: conn} do
    insert_hourly_accuracy("prod", 10, 101, 99)
    insert_hourly_accuracy("prod", 10, 108, 102)
    insert_hourly_accuracy("prod", 11, 225, 211)
    insert_hourly_accuracy("prod", 11, 270, 261)
    insert_hourly_accuracy("dev-green", 10, 401, 399)
    insert_hourly_accuracy("dev-green", 10, 408, 302)
    insert_hourly_accuracy("dev-green", 11, 525, 411)
    insert_hourly_accuracy("dev-green", 11, 570, 461)
    insert_hourly_accuracy("dev-green", 12, 216, 135)

    conn = get(conn, "/accuracy")
    conn = get(conn, redirected_to(conn))
    response = html_response(conn, 200)

    assert response =~ "216"
    # 135 / 216
    assert response =~ "62.5%"
  end

  test "GET /accuracy defaults to hourly", %{conn: conn} do
    conn = get(conn, "/accuracy")

    assert redirected_to(conn) =~ "/accuracy"

    assert %{
             "filters[chart_range]" => "Hourly",
             "filters[timeframe_resolution]" => "60",
             "filters[service_date]" => @today_str,
             "filters[route_ids]" => "",
             "filters[direction_id]" => "any",
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

  test "GET /accuracy for a daily range sorts table correctly across month boundaries", %{
    conn: conn
  } do
    insert_hourly_accuracy("prod", 10, 101, 99, @last_of_month)
    insert_hourly_accuracy("prod", 10, 201, 199, @first_of_month)

    conn =
      get(conn, "/accuracy", %{
        "filters" => %{
          "chart_range" => "Daily",
          "date_start" => @last_of_month_str,
          "date_end" => @first_of_month_str
        }
      })

    conn = get(conn, redirected_to(conn))
    response = html_response(conn, 200)

    assert String.match?(
             response,
             Regex.compile!(@last_of_month_str <> ".*" <> @first_of_month_str)
           )
  end

  test "GET /accuracy with partial daily range redirects to full range", %{conn: conn} do
    conn =
      get(conn, "/accuracy", %{
        "filters" => %{
          "chart_range" => "Daily",
          "date_start" => "2019-01-01",
          "route_ids" => "",
          "direction_id" => "any",
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
          "direction_id" => "any",
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
          "direction_id" => "any",
          "bin" => "All"
        }
      })

    response = html_response(conn, 200)
    assert response =~ "Can&#39;t parse start or end date."
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

  test "GET /accuracy includes a summary of the bins", %{conn: conn} do
    conn = get(conn, "/accuracy")
    conn = get(conn, redirected_to(conn))

    response = html_response(conn, 200)

    assert response =~ "<td>\n0-3 min\n              </td>\n              <td>\n-60 sec to 60 sec"
  end

  test "GET /accuracy/csv provides a valid csv", %{conn: conn} do
    insert_hourly_accuracy("prod", 10, 101, 99)
    insert_hourly_accuracy("prod", 10, 108, 102)
    insert_hourly_accuracy("prod", 11, 225, 211)
    insert_hourly_accuracy("prod", 11, 270, 261)
    conn = get(conn, "/accuracy/csv")
    conn = get(conn, redirected_to(conn))
    headers = Enum.into(conn.resp_headers, %{})
    assert headers["content-type"] == "application/csv"

    assert conn.resp_body =~
             "Hourly,Prod Accuracy,Err,RMSE,Count"
  end

  def insert_hourly_accuracy(env, hour, total, accurate, service_date \\ nil) do
    accuracy = %PredictionAccuracy{
      @prediction_accuracy
      | environment: env,
        hour_of_day: hour,
        num_predictions: total,
        num_accurate_predictions: accurate
    }

    accuracy =
      if service_date do
        %{accuracy | service_date: service_date}
      else
        accuracy
      end

    PredictionAnalyzer.Repo.insert!(accuracy)
  end
end
