defmodule PredictionAnalyzer.Pruner do
  use GenServer

  alias PredictionAnalyzer.Utilities
  alias PredictionAnalyzer.Repo
  alias PredictionAnalyzer.VehicleEvents.VehicleEvent
  alias PredictionAnalyzer.Predictions.Prediction

  import Ecto.Query, only: [from: 2]

  require Logger

  def start_link do
    GenServer.start_link(__MODULE__, [])
  end

  def init([]) do
    schedule_next_run(self())
    {:ok, []}
  end

  def handle_info(:prune, state) do
    Logger.info("Beginning prune of DB")

    unix_cutoff =
      Timex.local()
      |> Timex.shift(days: -7)
      |> Timex.set(hour: 3, minute: 0, second: 0)
      |> DateTime.to_unix()

    {time, _} =
      :timer.tc(fn ->
        Logger.info("deleting old predictions")

        Repo.delete_all(
          from(
            p in Prediction,
            where: p.file_timestamp < ^unix_cutoff
          ),
          timeout: 600_000
        )

        Logger.info("deleting old vehicle events based on arrival")

        Repo.delete_all(
          from(
            ve in VehicleEvent,
            where: ve.arrival_time < ^unix_cutoff
          ),
          timeout: 600_000
        )

        Logger.info("deleting old vehicle events based on departure")

        Repo.delete_all(
          from(
            ve in VehicleEvent,
            where: ve.departure_time < ^unix_cutoff
          ),
          timeout: 600_000
        )
      end)

    Logger.info("Pruning complete. db=#{time / 1000}")

    schedule_next_run(self())
    {:noreply, state}
  end

  defp schedule_next_run(pid) do
    Process.send_after(pid, :prune, Utilities.ms_to_3am(Timex.local()) + 10 * 60 * 1_000)
  end
end
