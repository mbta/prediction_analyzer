defmodule PredictionAnalyzer.StopNameFetcherTest do
  alias PredictionAnalyzer.StopNameFetcher
  import Test.Support.Env

  use ExUnit.Case, async: false

  @expected_descriptions %{
    "70238" => "Cleveland Circle - Green Line - Park Street & North",
    "70007" => "Jackson Square - Orange Line - Oak Grove",
    "70197" => "Park Street - Green Line - (C) Cleveland Circle",
    "70150" => "Kenmore - Green Line - Park Street & North",
    "71150" => "Kenmore - Green Line - Park Street & North",
    "dummystop1" => "Dummy Stop Description",
    "dummystop2" => "Dummy Stop Description"
  }

  setup do
    {:ok, pid} = StopNameFetcher.start_link()
    # We don't need to explicitly stop the GenServer after test ends because it's
    # killed when the linked test process exits.
    # https://hexdocs.pm/ex_unit/ExUnit.Case.html#module-process-architecture

    %{pid: pid}
  end

  test "starts up with no issue", %{pid: pid} do
    assert Process.alive?(pid)
  end

  describe "get_stop_descriptions/1" do
    test "returns parsed results in alphabetical order", %{pid: pid} do
      assert StopNameFetcher.get_stop_descriptions(pid, :subway) == @expected_descriptions
    end

    test "if API fetch fails, proceeds with an empty list of stops" do
      reassign_env(:api_base_url, "https://bad-api-v3.mbta.com/")
      {:ok, pid} = StopNameFetcher.start_link()
      IO.inspect(Application.get_env(:prediction_analyzer, :api_base_url), label: "api_base_url")
      assert StopNameFetcher.get_stop_descriptions(pid, :subway) == %{}
      assert StopNameFetcher.get_stop_descriptions(pid, :commuter_rail) == %{}
    end
  end

  describe "get_stop_name/1" do
    test "returns the name (and platform code) of the stop in question", %{pid: pid} do
      assert StopNameFetcher.get_stop_name(pid, :subway, "70238") ==
               "Cleveland Circle (Park Street & North)"
    end

    test "returns the name with no platform code if the stop doesn't have a platform code", %{
      pid: pid
    } do
      assert StopNameFetcher.get_stop_name(pid, :commuter_rail, "Andover") == "Andover"
    end

    test "returns the id if the stop isn't found", %{pid: pid} do
      assert StopNameFetcher.get_stop_name(pid, :commuter_rail, "99999999") == "99999999"
    end

    test "returns the id if the mode isn't found", %{pid: pid} do
      assert StopNameFetcher.get_stop_name(pid, :not_a_mode, "99999999") == "99999999"
    end

    test "include the stop ID if the description and platform name are ambiguous", %{pid: pid} do
      assert StopNameFetcher.get_stop_name(pid, :subway, "70150") ==
               "Kenmore (Park Street & North) - 70150"
    end

    test "include the stop ID if the description is ambiguous (no platform name case)", %{
      pid: pid
    } do
      assert StopNameFetcher.get_stop_name(pid, :subway, "dummystop1") ==
               "Dummy Stop Name - dummystop1"
    end
  end
end
