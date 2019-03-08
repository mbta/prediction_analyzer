defmodule PredictionAnalyzer.StopNameFetcherTest do
  alias PredictionAnalyzer.StopNameFetcher
  import Test.Support.Env

  use ExUnit.Case, async: false

  @expected_stops %{
    "70238" => "Cleveland Circle - Green Line - Park Street & North",
    "70007" => "Jackson Square - Orange Line - Oak Grove",
    "70197" => "Park Street - Green Line - (C) Cleveland Circle"
  }

  test "starts up with no issue" do
    {:ok, pid} = StopNameFetcher.start_link(name: PredictionAnalyzer.StopNameFetcher)
    :timer.sleep(500)
    assert Process.alive?(pid)
  end

  describe "get_stop_map/1" do
    test "doesn't crash if fetcher hasn't been started" do
      assert StopNameFetcher.get_stop_map() == %{}
    end

    test "returns parsed results in alphabetical order" do
      StopNameFetcher.start_link(name: PredictionAnalyzer.StopNameFetcher)
      assert StopNameFetcher.get_stop_map() == @expected_stops
    end

    test "if API fetch fails, proceeds with an empty list of stops" do
      reassign_env(:stop_fetch_url, "https://api-v3.mbta.com/bad_stops")
      StopNameFetcher.start_link(name: PredictionAnalyzer.StopNameFetcher)
      assert StopNameFetcher.get_stop_map() == %{}
    end
  end
end
