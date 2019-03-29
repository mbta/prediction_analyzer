defmodule PredictionAnalyzer.StopNameFetcherTest do
  alias PredictionAnalyzer.StopNameFetcher
  import Test.Support.Env

  use ExUnit.Case, async: false

  @expected_descriptions %{
    "70238" => "Cleveland Circle - Green Line - Park Street & North",
    "70007" => "Jackson Square - Orange Line - Oak Grove",
    "70197" => "Park Street - Green Line - (C) Cleveland Circle"
  }

  test "starts up with no issue" do
    {:ok, pid} = StopNameFetcher.start_link(name: PredictionAnalyzer.StopNameFetcher)
    :timer.sleep(500)
    assert Process.alive?(pid)
  end

  describe "get_stop_descriptions/1" do
    test "returns parsed results in alphabetical order" do
      StopNameFetcher.start_link(name: PredictionAnalyzer.StopNameFetcher)
      assert StopNameFetcher.get_stop_descriptions(:subway) == @expected_descriptions
    end

    test "if API fetch fails, proceeds with an empty list of stops" do
      reassign_env(:api_base_url, "https://bad-api-v3.mbta.com/")
      StopNameFetcher.start_link(name: PredictionAnalyzer.StopNameFetcher)
      assert StopNameFetcher.get_stop_descriptions(:subway) == %{}
      assert StopNameFetcher.get_stop_descriptions(:commuter_rail) == %{}
    end
  end

  describe "get_stop_name/1" do
    test "returns the name (and platform code) of the stop in question" do
      StopNameFetcher.start_link(name: PredictionAnalyzer.StopNameFetcher)

      assert StopNameFetcher.get_stop_name(:subway, "70238") ==
               "Cleveland Circle (Park Street & North)"
    end
  end
end
