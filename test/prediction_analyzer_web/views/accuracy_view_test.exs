defmodule PredictionAnalyzerWeb.AccuracyViewTest do
  use PredictionAnalyzerWeb.ConnCase, async: true

  alias PredictionAnalyzerWeb.AccuracyView

  describe "route_options/1" do
    test "subway returns subway values" do
      route_options = AccuracyView.route_options(:subway)
      assert {"All", ""} in route_options
      assert {"Blue", "Blue"} in route_options
      assert {"Heavy Rail", "Red,Orange,Blue"} in route_options
    end

    test "commuter rail returns commuter rail values" do
      route_options = AccuracyView.route_options(:commuter_rail)
      assert {"All", ""} in route_options
      assert {"CR-Fitchburg", "CR-Fitchburg"} in route_options
      refute {"Heavy Rail", "Red,Orange,Blue"} in route_options
    end
  end

  test "bin_options/0 returns bin names in the proper order" do
    assert AccuracyView.bin_options() == [
             "0-3 min",
             "3-6 min",
             "6-8 min",
             "8-10 min",
             "10-12 min",
             "12-30 min",
             {"6-12 min", "6-8 min,8-10 min,10-12 min,6-12 min"}
           ]
  end

  test "chart_range_scope_header/1 returns the proper value" do
    assert AccuracyView.chart_range_scope_header("Hourly") == "Hour"
    assert AccuracyView.chart_range_scope_header("Daily") == "Date"
    assert AccuracyView.chart_range_scope_header("By Station") == "Station"
  end

  describe "formatted_row_scope/2" do
    test "returns a station name if chart range is By Station" do
      assert AccuracyView.formatted_row_scope(%{"chart_range" => "By Station"}, "70238") ==
               "Cleveland Circle (Park Street & North)"
    end

    test "returns the row scope unchanged otherwise" do
      assert AccuracyView.formatted_row_scope(%{"chart_range" => "Hourly"}, "some_hour") ==
               "some_hour"

      assert AccuracyView.formatted_row_scope(%{"chart_range" => "Daily"}, "some_day") ==
               "some_day"
    end
  end

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

  describe "stop_descriptions/1" do
    test "returns subway stops" do
      assert AccuracyView.stop_descriptions(:subway) == [
               {"", ""},
               {"Jane Roe St (67890)", "67890"},
               {"John Doe Square (12345)", "12345"}
             ]
    end

    test "returns commuter rail stops" do
      assert AccuracyView.stop_descriptions(:commuter_rail) == [
               {"", ""},
               {"No Description Stop", "No Description Stop"}
             ]
    end
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

  test "button_class/2" do
    assert AccuracyView.button_class(%{params: %{"filters" => %{"route_id" => "Blue"}}}, "Blue") =~
             "mode-button"

    assert AccuracyView.button_class(%{params: %{"filters" => %{"route_id" => "Blue"}}}, "Red") =~
             "mode-button"

    assert AccuracyView.button_class(%{}, "Red") =~ "mode-button"

    assert AccuracyView.button_class(%{}, "") =~ "mode-button"
  end
end
