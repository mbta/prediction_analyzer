defmodule PredictionAnalyzer.PredictionAccuracy.Query do
  alias PredictionAnalyzer.Repo

  @doc """
  Calculate a given row of prediction_accuracy data. Looks back at files
  """
  @spec calculate_aggregate_accuracy(DateTime.t(), String.t(), String.t(),
    integer(), integer(), integer(), integer()) :: {:ok, term()}
  def calculate_aggregate_accuracy(
    current_time,
    arrival_departure,
    bin_name,
    bin_min,
    bin_max,
    bin_error_min,
    bin_error_max
  ) do
    {service_date, hour_of_day, min_unix, max_unix} =
      current_time
      |> Timex.shift(hours: -2)
      |> PredictionAnalyzer.Utilities.service_date_info()

    query = query_template(arrival_departure)

    Repo.query(
      query,
      [
        service_date,
        hour_of_day,
        arrival_departure,
        bin_name,
        bin_min,
        bin_max,
        bin_error_min,
        bin_error_max,
        min_unix,
        max_unix
      ]
    )
  end

  defp query_template(arrival_departure) do
    column_name = case arrival_departure do
      "arrival" -> "arrival_time"
      "departure" -> "departure_time"
    end

    "
      INSERT INTO prediction_accuracy (
        service_date,
        hour_of_day,
        route_id,
        stop_id,
        arrival_departure,
        bin,
        num_predictions,
        num_accurate_predictions
      ) (
      SELECT
        $1 AS service_date,
        $2 AS hour_of_day,
        p.route_id AS route_id,
        p.stop_id AS stop_id,
        $3 AS arrival_departure,
        $4 AS bin,
        COUNT(*) AS num_predictions,
        SUM(
          CASE
            WHEN
              ve.#{column_name} - p.#{column_name} > $7
              AND ve.#{column_name} - p.#{column_name} < $8 THEN 1
            ELSE 0
          END
      ) AS num_accurate_predictions
      FROM predictions AS p
      LEFT JOIN vehicle_events AS ve ON ve.id = p.vehicle_event_id
      WHERE p.file_timestamp > $9
        AND p.file_timestamp < $10
        AND p.#{column_name} IS NOT NULL
        AND p.#{column_name} > p.file_timestamp
        AND p.#{column_name} - p.file_timestamp >= $5
        AND p.#{column_name} - p.file_timestamp < $6
      GROUP BY p.route_id, p.stop_id
      )
    "
  end
end
