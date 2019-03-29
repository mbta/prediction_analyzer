defmodule PredictionAnalyzer.FakeStopNameFetcher do
  def get_stop_descriptions(:subway) do
    %{"12345" => "John Doe Square", "67890" => "Jane Roe St"}
  end

  def get_stop_descriptions(:commuter_rail) do
    %{"No Description Stop" => nil}
  end

  def get_stop_name(:subway, "70238"), do: "Cleveland Circle (Park Street & North)"
end
