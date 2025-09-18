defmodule PredictionAnalyzer.Pruner do
  use GenServer

  alias PredictionAnalyzer.Repo
  alias PredictionAnalyzer.VehicleEvents.VehicleEvent
  alias PredictionAnalyzer.Predictions.Prediction

  import Ecto.Query, only: [from: 2]

  require Logger

  @prune_interval_ms 6 * 60 * 60 * 1_000

  def start_link(_args) do
    GenServer.start_link(__MODULE__, [])
  end

  def init([]) do
    schedule_next_run(self())
    {:ok, []}
  end

  def handle_info(:prune, state) do
    Logger.info("Beginning prune of DB")

    prune_lookback_sec = Application.get_env(:prediction_analyzer, :prune_lookback_sec)

    predictions_cutoff = System.system_time(:second) - prune_lookback_sec
    vehicle_events_cutoff = predictions_cutoff - max_dwell_time_sec()

    {time, _} =
      :timer.tc(fn ->
        Logger.info("deleting old predictions")

        Repo.delete_all(
          from(
            p in Prediction,
            where: p.file_timestamp < ^predictions_cutoff
          ),
          timeout: 600_000
        )

        Logger.info("deleting old vehicle events")

        Repo.delete_all(
          from(
            ve in VehicleEvent,
            where: ve.arrival_time < ^vehicle_events_cutoff
          ),
          timeout: 600_000
        )
      end)

    Logger.info("Pruning complete. db=#{time / 1000}")

    schedule_next_run(self())
    {:noreply, state}
  end

  # The `max_dwell_time_sec` configuration used to be a single value for
  # all usages but now contains bespoke values for certain circumstances,
  # such as the Mattapan line. Despite this, that information is not in the
  # `VehicleEvent`'s table. To keep the Pruner running as is, it uses the largest
  # value of the configuration list, to avoid pruning any `VehicleEvent`'s
  # too soon.
  defp max_dwell_time_sec,
    do:
      Application.get_env(:prediction_analyzer, :max_dwell_time_sec)
      |> Keyword.values()
      |> Enum.max()

  @spec schedule_next_run(pid()) :: reference()
  defp schedule_next_run(pid) do
    Process.send_after(pid, :prune, @prune_interval_ms)
  end
end
