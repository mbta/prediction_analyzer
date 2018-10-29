defmodule PredictionAnalyzer.UtilitiesTest do
  use ExUnit.Case, async: true
  alias PredictionAnalyzer.Utilities

  describe "service_date_info" do
    test "returns current date if after 3am" do
      time = Timex.set(Timex.now("America/New_York"), year: 2018, month: 10, day: 30, hour: 10)
      assert {
        ~D[2018-10-30],
        10,
        1540908000,
        1540911600
      } = Utilities.service_date_info(time)
    end

    test "returns previous date if before 3am" do
      time = Timex.set(Timex.now("America/New_York"), year: 2018, month: 10, day: 30, hour: 1)
      assert {
        ~D[2018-10-29],
        25,
        1540875600,
        1540879200
      } = Utilities.service_date_info(time)
    end
  end

  describe "ms_to_next_hour" do
    test "returns the number of milliseconds to the top of the next hour" do
      soon = Timex.now() |> Timex.set(minute: 58, second: 0, microsecond: {0, 6})
      late = Timex.now() |> Timex.set(minute: 2, second: 0, microsecond: {0, 6})

      assert Utilities.ms_to_next_hour(soon) == 150_000
      assert Utilities.ms_to_next_hour(late) == 3_510_000
    end
  end
end
