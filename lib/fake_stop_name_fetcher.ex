defmodule PredictionAnalyzer.FakeStopNameFetcher do
  def get_stop_descriptions() do
    %{"12345" => "John Doe Square", "67890" => "Jane Roe St"}
  end

  def get_stop_name("70238"), do: "Cleveland Circle (Park Street & North)"
end
