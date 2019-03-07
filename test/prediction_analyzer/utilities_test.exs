defmodule PredictionAnalyzer.UtilitiesTest do
  use ExUnit.Case, async: true
  alias PredictionAnalyzer.Utilities

  describe "service_date_info" do
    test "returns current date if after 3am" do
      time = Timex.to_datetime(~D[2018-10-30], "America/New_York") |> Timex.set(hour: 10)

      assert {
               ~D[2018-10-30],
               10,
               1_540_908_000,
               1_540_911_600
             } = Utilities.service_date_info(time)
    end

    test "returns previous date if before 3am" do
      time = Timex.to_datetime(~D[2018-10-30], "America/New_York") |> Timex.set(hour: 1)

      assert {
               ~D[2018-10-29],
               25,
               1_540_875_600,
               1_540_879_200
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

  describe "ms_to_3am" do
    test "returns the milliseconds to 3am when 3am is tomorrow" do
      time =
        "America/New_York"
        |> Timex.now()
        |> Timex.set(hour: 23, minute: 59, second: 0, microsecond: {0, 6})

      assert Utilities.ms_to_3am(time) == 10_860_000
    end

    test "returns the milliseconds to 3am when 3am is later today" do
      time =
        "America/New_York"
        |> Timex.now()
        |> Timex.set(hour: 2, minute: 59, second: 0, microsecond: {0, 6})

      assert Utilities.ms_to_3am(time) == 60_000
    end
  end

  describe "generic_stop_id/1" do
    test "maps terminal child stop ID to generic terminal stop ID" do
      assert Utilities.generic_stop_id("Alewife-01") == "70061"
    end

    test "maps generic terminal stop ID to itself" do
      assert Utilities.generic_stop_id("70061") == "70061"
    end

    test "maps non-terminal stop ID to itself" do
      assert Utilities.generic_stop_id("70063") == "70063"
    end
  end
end
