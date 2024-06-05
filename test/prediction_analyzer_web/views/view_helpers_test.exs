defmodule PredictionAnalyzerWeb.ViewHelpersTest do
  use PredictionAnalyzerWeb.ConnCase, async: true

  alias PredictionAnalyzerWeb.ViewHelpers

  test "button_class/2" do
    assert ViewHelpers.button_class(%{params: %{"filters" => %{"route_id" => "Blue"}}}, "Blue") =~
             "mode-button"

    assert ViewHelpers.button_class(%{params: %{"filters" => %{"route_id" => "Blue"}}}, "Red") =~
             "mode-button"

    assert ViewHelpers.button_class(%{}, "Red") =~ "mode-button"

    assert ViewHelpers.button_class(%{}, "") =~ "mode-button"
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

    assert ViewHelpers.chart_range_class(matching_conn, "some_range") ==
             "chart-range-link chart-range-link-active"

    assert ViewHelpers.chart_range_class(unmatching_conn, "some_range") == "chart-range-link"
  end

  test "chart_range_id/1" do
    assert ViewHelpers.chart_range_id("SomeRange") == "link-somerange"
  end
end
