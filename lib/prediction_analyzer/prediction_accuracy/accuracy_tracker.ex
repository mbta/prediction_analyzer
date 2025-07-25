defmodule PredictionAnalyzer.PredictionAccuracy.AccuracyTracker do
  use GenServer
  alias PredictionAnalyzer.PredictionAccuracy
  require Logger

  @target_stop_id "place-south-station"
  @check_interval_minutes 30
  @drop_threshold 0.25

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  def init([]) do
    schedule_next_check(self())
    {:ok, []}
  end

  def handle_info(:check_accuracy, state) do
    Logger.info("Checking accuracy")
    check_accuracy()
    schedule_next_check(self())
    {:noreply, state}
  end

  defp schedule_next_check(pid) do
    Process.send_after(pid, :check_accuracy, @check_interval_minutes * 60 * 1000)
    :ok
  end

  defp check_accuracy do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    current_hour_start = DateTime.add(now, -3600, :second)
    current_hour_finish = now
    previous_hour_start = DateTime.add(current_hour_start, -3600, :second)
    previous_hour_end = current_hour_start
    current_accuracy = fetch_accuracy(@target_stop_id, current_hour_start, current_hour_finish)
    previous_accuracy = fetch_accuracy(@target_stop_id, previous_hour_start, previous_hour_end)
    trigger_maybe(previous_accuracy, current_accuracy, previous_hour_end, current_hour_finish)
  end

  defp fetch_accuracy(stop_id, start_time, end_time) do
    get_accuracy(stop_id, start_time, end_time, ["at_terminal", "reverse_trip"])
  end

  defp trigger_maybe(nil, _curr, _previous_hour_end, _current_hour_finish), do: :skip
  defp trigger_maybe(_prev, nil, _previous_hour_end, _current_hour_finish), do: :skip
  defp trigger_maybe(prev, curr, previous_hour_end, current_hour_finish) do
    drop = prev - curr
    if drop > @drop_threshold do
      IO.puts("""

      Alert!!! Prediction Accuracy drop!!!

      Time: #{inspect(previous_hour_end)} to #{inspect(current_hour_finish)}
      Previous Hour: #{prev}
      Current Hour: #{curr}
      Drop: #{drop * 100}%
      """)
    end
  end
end
