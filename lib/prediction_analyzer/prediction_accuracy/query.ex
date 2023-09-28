defmodule PredictionAnalyzer.PredictionAccuracy.Query do
  require Logger

  @doc """
  Calculate a given row of prediction_accuracy data. Looks back at files
  """
  @spec calculate_aggregate_accuracy(
          module(),
          DateTime.t(),
          String.t(),
          boolean(),
          String.t(),
          integer(),
          integer(),
          integer(),
          integer(),
          String.t()
        ) :: {:ok, term()} | :error
  def calculate_aggregate_accuracy(
        repo_module,
        current_time,
        kind,
        in_next_two?,
        bin_name,
        bin_min,
        bin_max,
        bin_error_min,
        bin_error_max,
        environment
      ) do
    {service_date, hour_of_day, minute_of_hour, min_unix, max_unix} =
      current_time
      |> Timex.shift(minutes: -Application.get_env(:prediction_analyzer, :analysis_lookback_min))
      |> PredictionAnalyzer.Utilities.service_date_info()

    repo_module.query(insert_accuracy_query(kind), [
      service_date,
      hour_of_day,
      bin_name,
      bin_min,
      bin_max,
      bin_error_min,
      bin_error_max,
      min_unix,
      max_unix,
      environment,
      kind,
      in_next_two?,
      minute_of_hour
    ])
  end

  @spec insert_accuracy_query(String.t()) :: String.t()
  defp insert_accuracy_query(kind) do
    """
    INSERT INTO prediction_accuracy (
      environment,
      service_date,
      hour_of_day,
      route_id,
      stop_id,
      direction_id,
      bin,
      kind,
      in_next_two,
      minute_of_hour,
      num_predictions,
      num_accurate_predictions,
      mean_error,
      root_mean_squared_error
    ) (
      SELECT
        $10 AS environment,
        $1 AS service_date,
        $2 AS hour_of_day,
        p.route_id AS route_id,
        p.stop_id AS stop_id,
        p.direction_id AS direction_id,
        $3 AS bin,
        $11 AS kind,
        $12 AS in_next_two,
        $13 AS minute_of_hour,
        COUNT(*) AS num_predictions,
        SUM(
          CASE
            WHEN p.arrival_time IS NOT NULL
              AND ve.arrival_time - p.arrival_time > $6
              AND ve.arrival_time - p.arrival_time < $7
              THEN 1
            WHEN p.arrival_time IS NULL
              AND ve.departure_time - p.departure_time > $6
              AND ve.departure_time - p.departure_time < $7
              THEN 1
            ELSE 0
          END
        ) AS num_accurate_predictions,
        AVG(
          CASE
            WHEN p.arrival_time IS NOT NULL
              THEN ve.arrival_time - p.arrival_time
            ELSE ve.departure_time - p.departure_time
          END
        ) AS mean_error,
        SQRT(
          AVG(
            CASE
              WHEN p.arrival_time IS NOT NULL
                THEN (ve.arrival_time - p.arrival_time)^2
              ELSE (ve.departure_time - p.departure_time)^2
            END
          )
        ) AS root_mean_squared_error
      FROM (
        SELECT *,
          COALESCE(arrival_time, departure_time) AS arrival_or_departure_time FROM predictions
      ) AS p
      LEFT JOIN vehicle_events AS ve ON ve.id = p.vehicle_event_id
      WHERE p.file_timestamp > $8
        AND p.file_timestamp < $9
        AND p.environment = $10
        AND #{kind_clause(kind)}
        AND p.arrival_or_departure_time IS NOT NULL
        AND p.arrival_or_departure_time > p.file_timestamp
        AND p.arrival_or_departure_time - p.file_timestamp >= $4
        AND p.arrival_or_departure_time - p.file_timestamp < $5
        AND (
          ($12 AND (p.nth_at_stop IN (1, 2)))
          OR
          ((NOT $12) AND (p.nth_at_stop NOT IN (1, 2) OR p.nth_at_stop IS NULL))
        )
      GROUP BY p.route_id, p.stop_id, p.direction_id
    )
    """
  end

  defp kind_clause(nil), do: "p.kind IS NULL"
  defp kind_clause(_), do: "p.kind = $11"
end
