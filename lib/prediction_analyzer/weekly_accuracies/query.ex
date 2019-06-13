defmodule PredictionAnalyzer.WeeklyAccuracies.Query do
  import Ecto.Query
  require Logger

  @spec calculate_weekly_accuracies(
          module(),
          DateTime.t()
        ) :: {:ok, term()} | :error
  def calculate_weekly_accuracies(
        repo_module,
        current_time
      ) do
    do_calculate_weekly_accuracies(
      repo_module,
      current_time,
      true
    )
  end

  @spec do_calculate_weekly_accuracies(
          module(),
          DateTime.t(),
          boolean()
        ) :: {:ok, term()} | :error
  defp do_calculate_weekly_accuracies(
         repo_module,
         current_time,
         retry?
       ) do
    query = weekly_accuracy_template()

    {beginning_of_week, end_of_week} =
      current_time
      |> Timex.shift(days: -7)
      |> PredictionAnalyzer.Utilities.get_week_range()

    try do
      if aggregate_week?(repo_module, beginning_of_week) do
        repo_module.query(query, [beginning_of_week, end_of_week])
      end
    rescue
      e in DBConnection.ConnectionError ->
        log_msg = "#{__MODULE__} do_calculate_weekly_accuracies #{inspect(e)}"

        if retry? do
          Logger.warn(log_msg)

          Application.get_env(:prediction_analyzer, :retry_sleep_time)
          |> Process.sleep()

          do_calculate_weekly_accuracies(
            repo_module,
            current_time,
            false
          )
        else
          Logger.error(log_msg)
          :error
        end
    end
  end

  @spec aggregate_week?(module(), DateTime.t()) :: boolean()
  def aggregate_week?(repo_module, date) do
    query = "
      SELECT count(*)
      FROM weekly_accuracies
      WHERE week_start = $1
    "

    case repo_module.query(query, [date]) do
      {:ok, %{rows: [[0]]}} ->
        true

      _ ->
        false
    end
  end

  @spec weekly_accuracy_template() :: String.t()
  defp weekly_accuracy_template() do
    "
      INSERT INTO weekly_accuracies (
        environment,
        week_start,
        route_id,
        stop_id,
        direction_id,
        arrival_departure,
        bin,
        num_predictions,
        num_accurate_predictions
      ) (
      SELECT
        environment,
        $1 as week_start,
        route_id,
        stop_id,
        direction_id,
        arrival_departure,
        bin,
        sum(num_predictions) as num_predictions,
        sum(num_accurate_predictions) as num_accurate_predictions
      FROM prediction_accuracy
      WHERE service_date > $1
        AND service_date < $2
      GROUP BY route_id, stop_id, environment, direction_id, arrival_departure, bin
      )
    "
  end
end
