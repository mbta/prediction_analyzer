defmodule PredictionAnalyzer.PredictionAccuracy.Aggregator do
  use GenServer
  require Logger
  alias PredictionAnalyzer.PredictionAccuracy.Query
  alias PredictionAnalyzer.PredictionAccuracy.PredictionAccuracy

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  def init([]) do
    schedule_next_run(self())
    {:ok, []}
  end

  def handle_info(:aggregate, state) do
    Logger.info("Calculating prediction accuracies")

    {time, _result} =
      :timer.tc(fn ->
        current_time = Timex.now("America/New_York")

        Enum.each(PredictionAccuracy.bins(), fn {bin_name,
                                                 {bin_min, bin_max, bin_error_min, bin_error_max}} ->
          {:ok, r} =
            Query.calculate_aggregate_accuracy(
              current_time,
              "arrival",
              bin_name,
              bin_min,
              bin_max,
              bin_error_min,
              bin_error_max,
              "prod"
            )

          Logger.info("prediction_accuracy_aggregator arrival prod result=#{inspect(r)}")

          {:ok, r} =
            Query.calculate_aggregate_accuracy(
              current_time,
              "departure",
              bin_name,
              bin_min,
              bin_max,
              bin_error_min,
              bin_error_max,
              "prod"
            )

          Logger.info("prediction_accuracy_aggregator departure prod result=#{inspect(r)}")

          {:ok, r} =
            Query.calculate_aggregate_accuracy(
              current_time,
              "arrival",
              bin_name,
              bin_min,
              bin_max,
              bin_error_min,
              bin_error_max,
              "dev-green"
            )

          Logger.info("prediction_accuracy_aggregator arrival dev_green result=#{inspect(r)}")

          {:ok, r} =
            Query.calculate_aggregate_accuracy(
              current_time,
              "departure",
              bin_name,
              bin_min,
              bin_max,
              bin_error_min,
              bin_error_max,
              "dev-green"
            )

          Logger.info("prediction_accuracy_aggregator departure dev_green result=#{inspect(r)}")
        end)
      end)

    Logger.info("Finished prediction aggregations in #{time / 1000} ms")
    schedule_next_run(self())
    {:noreply, state}
  end

  defp schedule_next_run(pid) do
    Process.send_after(pid, :aggregate, PredictionAnalyzer.Utilities.ms_to_next_hour())
  end
end
