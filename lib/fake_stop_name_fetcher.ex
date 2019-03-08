defmodule PredictionAnalyzer.FakeStopNameFetcher do
  def get_stop_map() do
    %{"12345" => "John Doe Square", "67890" => "Jane Roe St"}
  end
end
