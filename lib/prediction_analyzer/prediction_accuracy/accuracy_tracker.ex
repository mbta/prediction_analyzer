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
    Logger.info("Running accuracy check...")
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
    curr_start = DateTime.add(now, -3600, :second)
    curr_end = now
    prev_start = DateTime.add(curr_start, -3600, :second)
    prev_end = curr_start
    acc_now = fetch_accuracy(@target_stop_id, curr_start, curr_end)
    acc_prev = fetch_accuracy(@target_stop_id, prev_start, prev_end)
    trigger_maybe(acc_prev, acc_now, prev_end, curr_end)
  end

  defp fetch_accuracy(stop_id, start_time, end_time) do
    PredictionAccuracy.get_accuracy(stop_id, start_time, end_time, ["at_terminal", "reverse_trip"])
  end

  defp trigger_maybe(nil, _curr, _prev_end, _curr_end), do: :skip
  defp trigger_maybe(_prev, nil, _prev_end, _curr_end), do: :skip
  defp trigger_maybe(prev, curr, prev_end, curr_end) do
    drop = prev - curr
    if drop > @drop_threshold do
      IO.puts("""

      Alert!!! Prediction Accuracy drop!!!

      Time: #{inspect(prev_end)} to #{inspect(curr_end)}
      Previous Hour Accuracy: #{prev}
      Current Hour Accuracy: #{curr}
      Drop: #{drop * 100}%

      """)
    end
  end
end
