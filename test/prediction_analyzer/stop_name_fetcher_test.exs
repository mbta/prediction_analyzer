defmodule PredictionAnalyzer.StopNameFetcherTest do
  alias PredictionAnalyzer.StopNameFetcher

  use ExUnit.Case, async: false

  @expected_stops [
    {"Cleveland Circle - Green Line - Park Street & North (70238)", "70238"},
    {"Jackson Square - Orange Line - Oak Grove (70007)", "70007"},
    {"Park Street - Green Line - (C) Cleveland Circle (70197)", "70197"}
  ]

  test "starts up with no issue" do
    {:ok, pid} = StopNameFetcher.start_link()
    :timer.sleep(500)
    assert Process.alive?(pid)
  end

  describe "handle_call/3" do
    test "returns the list of description/stop ID pairs" do
      assert StopNameFetcher.handle_call(:get_stop_map, self(), @expected_stops) ==
               {:reply, @expected_stops, @expected_stops}
    end
  end

  describe "get_stop_names/0" do
    test "fetches, parses, and alphabetizes all stops" do
      result = StopNameFetcher.get_stop_names()

      assert result == @expected_stops
    end
  end
end
