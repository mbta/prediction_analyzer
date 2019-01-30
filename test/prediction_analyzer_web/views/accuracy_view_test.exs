defmodule PredictionAnalyzerWeb.AccuracyViewTest do
  use PredictionAnalyzerWeb.ConnCase, async: true

  alias PredictionAnalyzerWeb.AccuracyView

  test "service_dates/1" do
    time = Timex.local() |> Timex.set(year: 2018, month: 10, day: 31)

    assert AccuracyView.service_dates(time) ==
             [
               "2018-10-31",
               "2018-10-30",
               "2018-10-29",
               "2018-10-28",
               "2018-10-27",
               "2018-10-26",
               "2018-10-25",
               "2018-10-24"
             ]
  end

  test "show_download?/1" do
    assert AccuracyView.show_download?(%{
             "filters" => %{
               "stop_id" => "123",
               "service_date" => "2018-10-10",
               "chart_range" => "Hourly"
             }
           })

    refute AccuracyView.show_download?(%{
             "filters" => %{"stop_id" => "", "service_date" => "", "chart_range" => "Daily"}
           })
  end

  test "predictions_path_with_filters/2" do
    conn =
      build_conn(:get, "/accuracy", %{
        "filters" => %{"stop_id" => "123", "service_date" => "2018-10-10"}
      })

    path =
      AccuracyView.predictions_path_with_filters(
        conn,
        10
      )

    assert path =~ "hour=10"
    assert path =~ "service_date=2018-10-10"

    assert AccuracyView.predictions_path_with_filters(%{}, 5) == "#"
  end

  test "chart_range_class/2" do
    matching_conn =
      build_conn(:get, "/accuracy", %{
        "filters" => %{"chart_range" => "some_range"}
      })

    unmatching_conn =
      build_conn(:get, "/accuracy", %{
        "filters" => %{"chart_range" => "other_range"}
      })

    assert AccuracyView.chart_range_class(matching_conn, "some_range") ==
             "chart-range-link chart-range-link-active"

    assert AccuracyView.chart_range_class(unmatching_conn, "some_range") == "chart-range-link"
  end

  test "chart_range_id/1" do
    assert AccuracyView.chart_range_id("SomeRange") == "link-somerange"
  end
end
