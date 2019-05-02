defmodule PredictionAnalyzer.PredictionAccuracy.AccuracyTracker do
  alias PredictionAnalyzer.PredictionAccuracy.PredictionAccuracy
  require Logger

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  def init([]) do
    schedule_next_check(self())
    {:ok, [yesterdays_accuracy: 0, previous_days_accuracy: 0]}
  end

  @spec check_accuracy() :: [yesterday_accuracy: float(), previous_day_accuracy: float()]
  def check_accuracy() do
    today = Date.utc_today()
    yesterday = today |> Timex.shift(days: -1) |> Date.to_iso8601()
    previous_day = today |> Timex.shift(days: -2) |> Date.to_iso8601()

    {yesterday_query, _} =
      PredictionAccuracy.filter(%{"chart_range" => "Hourly", "service_date" => yesterday})

    yesterday_accs =
      yesterday_query
      |> PredictionAccuracy.stats_by_environment_and_chart_range(%{
        "chart_range" => "Hourly"
      })
      |> PredictionAnalyzer.Repo.all()

    {yesterday_total, yesterday_accurate} =
      Enum.reduce(yesterday_accs, {0, 0}, fn [_h, p_t, p_a, _, _], {t, a} ->
        {t + p_t, a + p_a}
      end)

    {previous_day_query, _} =
      PredictionAccuracy.filter(%{"chart_range" => "Hourly", "service_date" => previous_day})

    previous_day_accs =
      previous_day_query
      |> PredictionAccuracy.stats_by_environment_and_chart_range(%{
        "chart_range" => "Hourly"
      })
      |> PredictionAnalyzer.Repo.all()

    {previous_day_total, previous_day_accurate} =
      Enum.reduce(previous_day_accs, {0, 0}, fn [_h, p_t, p_a, _, _], {t, a} ->
        {t + p_t, a + p_a}
      end)

    schedule_next_check(self())

    yesterday_accuracy =
      if yesterday_total > 0 do
        yesterday_accurate / yesterday_total
      else
        0
      end

    previous_day_accuracy =
      if previous_day_total > 0 do
        previous_day_accurate / previous_day_total
      else
        0
      end

    if yesterday_accuracy < previous_day_accuracy do
      Logger.warn(
        "accuracy_drop from #{previous_day_accuracy} to #{yesterday_accuracy} between #{
          previous_day
        } and #{yesterday}"
      )
    end

    [yesterday_accuracy: yesterday_accuracy, previous_day_accuracy: previous_day_accuracy]
  end

  @spec handle_info(:schedule_next_check, any) ::
          {:noreply, [yesterdays_accuracy: float(), previous_days_accuracy: float()]}
  def handle_info(:schedule_next_check, _state) do
    state = check_accuracy()
    schedule_next_check(self())
    {:noreply, state}
  end

  @spec schedule_next_check(pid()) :: :ok
  defp schedule_next_check(pid) do
    Process.send_after(pid, :schedule_next_check, 10 * 1_000)
    :ok
  end
end
