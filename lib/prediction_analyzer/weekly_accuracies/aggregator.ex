defmodule PredictionAnalyzer.WeeklyAccuracies.Aggregator do
  use GenServer
  require Logger
  alias PredictionAnalyzer.WeeklyAccuracies.Query

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  def init([]) do
    schedule_next_week(self())
    schedule_backfill(self())

    timezone = Application.get_env(:timezone)
    local_now = Timex.now(timezone)

    days_to_end_of_week =
      local_now
      |> Timex.days_to_end_of_week()

    backfill_start =
      local_now
      |> Timex.shift(days: days_to_end_of_week)
      |> Timex.shift(days: -7)
      |> Timex.set(hour: 1, minute: 0, second: 0)

    {:ok, %{backfill_time: backfill_start}}
  end

  def handle_info(:backfill_weekly, state) do
    Logger.info("Backfilling weekly data")

    Query.calculate_weekly_accuracies(
      PredictionAnalyzer.Repo,
      state[:backfill_time]
    )

    next_backfill =
      state[:backfill_time]
      |> Timex.shift(days: -7)

    schedule_backfill(self())
    {:noreply, %{backfill_time: next_backfill}}
  end

  def handle_info(:aggregate_weekly, state) do
    Logger.info("Calculating weekly prediction accuracies")

    {time, _result} =
      :timer.tc(fn ->
        timezone = Application.get_env(:timezone)
        current_time = Timex.now(timezone)

        Query.calculate_weekly_accuracies(
          PredictionAnalyzer.Repo,
          current_time
        )
      end)

    Logger.info("Finished weekly prediction aggregations in #{time / 1000} ms")
    schedule_next_week(self())
    {:noreply, state}
  end

  defp schedule_backfill(pid) do
    Process.send_after(pid, :backfill_weekly, 60_000)
  end

  defp schedule_next_week(pid) do
    Process.send_after(pid, :aggregate_weekly, PredictionAnalyzer.Utilities.ms_to_next_week())
  end
end
