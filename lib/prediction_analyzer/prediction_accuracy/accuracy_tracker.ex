defmodule PredictionAnalyzer.PredictionAccuracy.AccuracyTracker do
  use GenServer

  alias PredictionAnalyzer.PredictionAccuracy.PredictionAccuracy
  alias PredictionAnalyzer.PredictionAccuracy
  alias PredictionAnalyzer.Filters
  require Logger

  # @drop_threshold 0.1

  @target_stop_id "place-south-station"
  @check_interval_minutes 30
  @hourly_drop_threshold 0.25
  @daily_drop_threshold 0.25
  @min_accuracy_threshold 0.50

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  def init([]) do
    schedule_next_check(self())
    {:ok, [yesterdays_accuracy: 0, previous_days_accuracy: 0]}
  end

  @spec schedule_next_check(pid()) :: :ok
  defp schedule_next_check(pid) do
    Logger.info("scheduling next check_accuracy: South Station")
    Process.send_after(pid, :check_accuracy, @check_interval_minutes * 60 * 1000)
    :ok
  end

  def handle_info(:check_accuracy, state) do
    Logger.info("Accuracy check is now running")

    check_accuracy()

    schedule_next_check(self())
    {:noreply, state}
  end


  defp check_accuracy() do
    now = DateTime.utc_now() |> DateTime.truncate(:minute)
    current_hour_start = DateTime.add(now, -3600, :second)
    current_hour_end = now
    previous_hour_start = DateTime.add(current_hour_start, -3600, :second)
    previous_hour_end = current_hour_start
    same_hour_yesterday_start = DateTime.add(current_hour_start, -86400, :second)
    same_hour_yesterday_end = DateTime.add(current_hour_end, -86400, :second)


    accuracy_now = fetch_accuracy(@target_stop_id, current_hour_start, current_hour_end)
    previous_hour_accuracy = fetch_accuracy(@target_stop_id, previous_hour_start, previous_hour_end)
    same_hour_yesterday_accuracy = fetch_accuracy(@target_stop_id, same_hour_yesterday_start, same_hour_yesterday_end)
    check_alert(accuracy_now, previous_hour_accuracy, same_hour_yesterday_accuracy)
end

  defp fetch_accuracy(stop_id, start_time, end_time) do
    PredictionAccuracy.get_accuracy(stop_id, start_time, end_time, ["at_terminal", "reverse_trip"])
  end


  #defp check_alert(accuracy_now, previous_hour_accuracy, same_hour_yesterday_accuracy) do
  #   if (previous_hour_accuracy - accuracy_now) > @hourly_drop_threshold do
  #     # send_alert("Hourly accuracy drop more than 25%: #{previous_hour_accuracy} - #{accuracy_now}")
  #     Logger.info("Rgiht now the accuracy is!!!! #{accuracy_now}")
  #   end

  #   if (same_hour_yesterday_accuracy - accuracy_now) > @daily_drop_threshold do
  #     send_alert("Daily accuracy drop more than 25%: #{same_hour_yesterday_accuracy} - #{accuracy_now}")
  #   end

  #   if accuracy_now < @min_accuracy_threshold do
  #     send_alert("General accuracy less than 50%: #{accuracy_now}")
  #   end
  end



defp check_alert(accuracy_now, previous_hour_accuracy, same_hour_yesterday_accuracy) do
  Logger.info("Right now accuracy!!!! #{accuracy_now}")
  Logger.info("Previous Accuracy!!!! #{previous_hour_accuracy}")
  Logger.info("Same hour but yesterday!!!!! #{same_hour_yesterday_accuracy}")

  if (previous_hour_accuracy - accuracy_now) > @hourly_drop_threshold do
    Logger.warn("Hourly drop more than 25% oh no")
  end

  if (same_hour_yesterday_accuracy - accuracy_now) > @daily_drop_threshold do
    Logger.warn("Daily drop more than 25% oh no")
  end

  if accuracy_now < @min_accuracy_threshold do
    Logger.warn("General accuracy less than 50% oh nooo!!")
  end


end






  # def check_accuracy() do
  #  ["Red", "Blue", "Orange", "Green-B", "Green-C", "Green-D", "Green-E", "Mattapan"]
  #  |> Enum.reduce(%{}, fn route_id, acc ->
  #    Map.put(acc, route_id, get_route_accuracy(route_id))
  #  end)
  # end - being commented out

# @spec get_route_accuracy(String.t()) :: [
#         yesterday_accuracy: float(),
#         previous_day_accuracy: float()
#         ]
#   defp get_route_accuracy(route_id) do
#     today = Date.utc_today()
#     yesterday = today |> Timex.shift(days: -1) |> Date.to_iso8601()
#     previous_day = today |> Timex.shift(days: -2) |> Date.to_iso8601()

#     {yesterday_query, _} =
#       PredictionAccuracy.filter(%{
#         "route_id" => route_id,
#         "chart_range" => "Hourly",
#         "service_date" => yesterday
#       })

#     yesterday_accs =
#       yesterday_query
#       |> Filters.stats_by_environment_and_chart_range("prod", %{
#         "chart_range" => "Hourly"
#       })
#       |> PredictionAnalyzer.Repo.all()

#     {previous_day_query, _} =
#       PredictionAccuracy.filter(%{
#         "route_id" => route_id,
#         "chart_range" => "Hourly",
#         "service_date" => previous_day
#       })

#     previous_day_accs =
#       previous_day_query
#       |> Filters.stats_by_environment_and_chart_range("prod", %{
#         "chart_range" => "Hourly"
#       })
#       |> PredictionAnalyzer.Repo.all()

#     yesterday_accuracy = get_accuracy(yesterday_accs)
#     previous_day_accuracy = get_accuracy(previous_day_accs)

#     if yesterday_accuracy < previous_day_accuracy - @drop_threshold do
#       Logger.warn(
#         "accuracy_drop on #{route_id} from #{previous_day_accuracy} to #{yesterday_accuracy} between #{previous_day} and #{yesterday}"
#       )
#     end

#     [yesterday_accuracy: yesterday_accuracy, previous_day_accuracy: previous_day_accuracy]
#   end

#   # @spec schedule_next_check(pid()) :: :ok
#   # defp schedule_next_check(pid) do
#   #   Logger.info("scheduling next check_accuracy")
#   #   Process.send_after(pid, :schedule_next_check, 24 * 60 * 60 * 1_000)
#   #  :ok
#   # end

#   @spec schedule_next_check(pid()) :: :ok
#   defp schedule_next_check(pid) do
#     Logger.info("scheduling next check_accuracy: South Station")
#     Process.send_after(pid, :check_accuracy, @check_interval_minutes * 60 * 1000)
#     :ok
#   end

#   defp get_accuracy(query) do
#     {total, accurate} =
#       Enum.reduce(query, {0, 0}, fn [_, prod_total, prod_accurate, _mean_err, _rmse],
#                                     {total, accurate} ->
#         {total + prod_total, accurate + prod_accurate}
#       end)

#     accuracy =
#       if total > 0 do
#         accurate / total
#       else
#         0
#       end

#     accuracy
