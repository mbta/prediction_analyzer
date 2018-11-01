defmodule PredictionAnalyzerWeb.AccuracyViewTest do
  use PredictionAnalyzerWeb.ConnCase, async: true

  test "service_dates/1" do
    time = Timex.local() |> Timex.set(year: 2018, month: 10, day: 31)

    assert PredictionAnalyzerWeb.AccuracyView.service_dates(time) ==
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
end
