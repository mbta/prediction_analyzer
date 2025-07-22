defmodule PredictionAnalyzer.PredictionAccuracy.AccuracyTracker do
  use GenServer
  require Logger

  alias PredictionAnalyzer.PredictionAccuracy


  @drop_threshold 0.1

  @target_stop_id "place-south-station"
  @check_interval_minutes 30
  #@hourly_drop_threshold 0.25
  #@daily_drop_threshold 0.25
  #@min_accuracy_threshold 0.50

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  def init([]) do
    schedule_next_check(self())
    {:ok, %{}}
  end

  def handle_info(:check_accuracy, state) do
    Logger.info("Accuracy check is now running")

    check_accuracy()

    schedule_next_check(self())
    {:noreply, state}
  end

defp schedule_next_check(pid) do
    Process.send_after(pid, :check_accuracy, @check_interval_minutes * 60 * 1000)
  end
  defp check_accuracy() do
    now = DateTime.utc_now() |> DateTime.truncate(:minute)
    current_hour_start = DateTime.add(now, -3600, :second)
    previous_hour_start = DateTime.add(now, -7200, :second)
    current_accuracy = fetch_accuracy(@target_stop_id, current_hour_start, now)
    previous_accuracy = fetch_accuracy(@target_stop_id, previous_hour_start, current_hour_start)

    trigger_maybe(previous_accuracy, current_accuracy, previous_hour_start, current_hour_start, now)
  end

  defp fetch_accuracy(stop_id, start_time, end_time) do
    PredictionAccuracy.get_accuracy(stop_id, start_time, end_time, ["at_terminal", "reverse_trip"])
  end

  defp trigger_maybe(nil, _, _, _, _), do: Logger.warn(" No data for previous hour")
  defp trigger_maybe(_, nil, _, _, _), do: Logger.warn("No data for current hour")

  defp trigger_maybe(prev, curr, _prev_start, prev_end, curr_end) do
    drop = prev - curr

    if drop > @drop_threshold do
      IO.puts("""

      Alert!!! There has been a prediction accuracy drop !!!
      Time: #{inspect(prev_end)} to #{inspect(curr_end)}
      Previous Hour Accuracy: #{prev}
      Current Hour Accuracy: #{curr}

      Drop: #{drop * 100}%
      """)

    end
  end
end
