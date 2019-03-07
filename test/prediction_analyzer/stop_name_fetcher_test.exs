defmodule PredictionAnalyzer.StopNameFetcherTest do
  alias PredictionAnalyzer.StopNameFetcher
  import Test.Support.Env

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

  test "get_stop_map/1 returns parsed results in alphabetical order" do
    {:ok, pid} = StopNameFetcher.start_link()
    assert StopNameFetcher.get_stop_map(pid) == @expected_stops
  end

  test "if API fetch fails, proceeds with an empty list of stops" do
    reassign_env(:stop_fetch_url, "https://api-v3.mbta.com/bad_stops")
    {:ok, pid} = StopNameFetcher.start_link()
    assert StopNameFetcher.get_stop_map(pid) == []
  end
end
