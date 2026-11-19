defmodule PredictionAnalyzer.PredictionAccuracy.AccuracyTracker do
  use GenServer

  alias PredictionAnalyzer.PredictionAccuracy.PredictionAccuracy
  alias PredictionAnalyzer.Filters
  import Ecto.Query, only: [where: 2]
  require Logger

  @drop_threshold 0.1

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  def init([]) do
    schedule_next_check(self())
    {:ok, [yesterdays_accuracy: 0, previous_days_accuracy: 0]}
  end

  def check_accuracy() do
    ["Red", "Blue", "Orange", "Green-B", "Green-C", "Green-D", "Green-E", "Mattapan"]
    |> Enum.reduce(%{}, fn route_id, acc ->
      Map.put(acc, route_id, get_route_accuracy(route_id))
    end)
  end

  @spec get_route_accuracy(String.t()) :: [
          yesterday_accuracy: float(),
          previous_day_accuracy: float()
        ]
  defp get_route_accuracy(route_id) do
    today = Date.utc_today()
    yesterday = today |> Timex.shift(days: -1) |> Date.to_iso8601()
    previous_day = today |> Timex.shift(days: -2) |> Date.to_iso8601()

    {yesterday_query, _} =
      PredictionAccuracy.filter(%{
        "route_ids" => route_id,
        "chart_range" => "Hourly",
        "service_date" => yesterday
      })

    yesterday_accs =
      yesterday_query
      |> Filters.select_stats()
      |> where(environment: "prod")
      |> PredictionAnalyzer.Repo.one()

    {previous_day_query, _} =
      PredictionAccuracy.filter(%{
        "route_ids" => route_id,
        "chart_range" => "Hourly",
        "service_date" => previous_day
      })

    previous_day_accs =
      previous_day_query
      |> Filters.select_stats()
      |> where(environment: "prod")
      |> PredictionAnalyzer.Repo.one()

    yesterday_accuracy = get_accuracy(yesterday_accs)
    previous_day_accuracy = get_accuracy(previous_day_accs)

    if yesterday_accuracy < previous_day_accuracy - @drop_threshold do
      Logger.warning(
        "accuracy_drop on #{route_id} from #{previous_day_accuracy} to #{yesterday_accuracy} between #{previous_day} and #{yesterday}"
      )
    end

    [yesterday_accuracy: yesterday_accuracy, previous_day_accuracy: previous_day_accuracy]
  end

  def handle_info(:schedule_next_check, _state) do
    state = check_accuracy()
    schedule_next_check(self())
    {:noreply, state}
  end

  @spec schedule_next_check(pid()) :: :ok
  defp schedule_next_check(pid) do
    Logger.info("scheduling next check_accuracy")
    Process.send_after(pid, :schedule_next_check, 24 * 60 * 60 * 1_000)
    :ok
  end

  defp get_accuracy(%{num_predictions: total, num_accurate: accurate})
       when not is_nil(total) and not is_nil(accurate) and total > 0, do: accurate / total

  defp get_accuracy(_), do: 0
end
