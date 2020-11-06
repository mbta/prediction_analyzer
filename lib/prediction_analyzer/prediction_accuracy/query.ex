defmodule PredictionAnalyzer.PredictionAccuracy.Query do
  require Logger

  @doc """
  Calculate a given row of prediction_accuracy data. Looks back at files
  """
  @spec calculate_aggregate_accuracy(
          module(),
          DateTime.t(),
          String.t(),
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
        arrival_departure,
        kind,
        in_next_two?,
        bin_name,
        bin_min,
        bin_max,
        bin_error_min,
        bin_error_max,
        environment
      ) do
    {service_date, hour_of_day, min_unix, max_unix} =
      current_time
      |> Timex.shift(hours: -2)
      |> PredictionAnalyzer.Utilities.service_date_info()

    query = query_template(arrival_departure)

    repo_module.query(query, [
      service_date,
      hour_of_day,
      arrival_departure,
      bin_name,
      bin_min,
      bin_max,
      bin_error_min,
      bin_error_max,
      min_unix,
      max_unix,
      environment,
      kind,
      in_next_two?
    ])
  end

  @spec query_template(String.t()) :: String.t()
  defp query_template(arrival_departure) do
    arrival_or_departure_time_column =
      case arrival_departure do
        "arrival" -> "arrival_time"
        "departure" -> "departure_time"
      end

    "
      INSERT INTO prediction_accuracy (
        environment,
        service_date,
        hour_of_day,
        route_id,
        stop_id,
        direction_id,
        arrival_departure,
        bin,
        kind,
        in_next_two,
        num_predictions,
        num_accurate_predictions,
        mean_error,
        root_mean_squared_error
      ) (
      SELECT
        $11 AS environment,
        $1 AS service_date,
        $2 AS hour_of_day,
        p.route_id AS route_id,
        p.stop_id AS stop_id,
        p.direction_id AS direction_id,
        $3 AS arrival_departure,
        $4 AS bin,
        $12 AS kind,
        $13 AS in_next_two,
        COUNT(*) AS num_predictions,
        SUM(
          CASE
            WHEN
              ve.#{arrival_or_departure_time_column} - p.#{arrival_or_departure_time_column} > $7
              AND ve.#{arrival_or_departure_time_column} - p.#{arrival_or_departure_time_column} < $8 THEN 1
            ELSE 0
          END
        ) AS num_accurate_predictions,
        AVG(ve.#{arrival_or_departure_time_column} - p.#{arrival_or_departure_time_column}) AS mean_error,
        SQRT(
          AVG(
            (ve.#{arrival_or_departure_time_column} - p.#{arrival_or_departure_time_column})^2
          )
        ) AS root_mean_squared_error
      FROM predictions AS p
      LEFT JOIN vehicle_events AS ve ON ve.id = p.vehicle_event_id
      WHERE p.file_timestamp > $9
        AND p.file_timestamp < $10
        AND p.environment = $11
        AND p.kind = $12
        AND p.#{arrival_or_departure_time_column} IS NOT NULL
        AND p.#{arrival_or_departure_time_column} > p.file_timestamp
        AND p.#{arrival_or_departure_time_column} - p.file_timestamp >= $5
        AND p.#{arrival_or_departure_time_column} - p.file_timestamp < $6
        AND (
          ($13 AND (p.nth_at_stop IN (1, 2)))
          OR
          ((NOT $13) AND (p.nth_at_stop NOT IN (1, 2) OR p.nth_at_stop IS NULL))
        )
      GROUP BY p.route_id, p.stop_id, p.direction_id
    )
    "
  end
end
