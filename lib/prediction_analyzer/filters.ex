defmodule PredictionAnalyzer.Filters do
  import Ecto.Query, only: [from: 2]
  import PredictionAnalyzer.QueryUtilities, only: [aggregate_mean_error: 2, aggregate_rmse: 2]
  alias PredictionAnalyzer.Filters.StopGroups

  @doc """
  Defines the bins we consider for aggregate accuracy. Each bin has the
  window of predictions that it applies to (e.g. arriving within 3-6 minutes)
  and the tolerance in seconds for which a prediction is considered accurate.
  """
  @spec bins() :: map()
  def bins do
    %{
      "0-3 min" => {-30, 180, -60, 60},
      "3-6 min" => {180, 360, -90, 120},
      "6-8 min" => {360, 720, -150, 210},
      "8-10 min" => {360, 720, -150, 210},
      "10-12 min" => {360, 720, -150, 210},
      "12-30 min" => {720, 1800, -240, 360}
    }
  end

  @spec filter_by_route(Ecto.Query.t(), any()) :: {:ok, Ecto.Query.t()} | {:error, String.t()}
  def filter_by_route(q, route_ids) when is_binary(route_ids) and route_ids != "" do
    route_id_list = String.split(route_ids, ",")
    {:ok, from(acc in q, where: acc.route_id in ^route_id_list)}
  end

  def filter_by_route(q, _), do: {:ok, q}

  @spec filter_by_mode(Ecto.Query.t(), any()) :: {:ok, Ecto.Query.t()} | {:error, String.t()}
  def filter_by_mode(q, mode) when is_binary(mode) and mode != "" do
    routes =
      mode
      |> PredictionAnalyzer.Utilities.string_to_mode()
      |> PredictionAnalyzer.Utilities.routes_for_mode()

    {:ok,
     from(
       acc in q,
       where: acc.route_id in ^routes
     )}
  end

  def filter_by_mode(q, _), do: {:ok, q}

  @spec filter_by_stop(Ecto.Query.t(), [String.t()]) ::
          {:ok, Ecto.Query.t()} | {:error, String.t()}
  def filter_by_stop(q, [_ | _] = stop_ids) do
    expanded_stop_ids = StopGroups.expand_groups(stop_ids)
    {:ok, from(acc in q, where: acc.stop_id in ^expanded_stop_ids)}
  end

  def filter_by_stop(q, []), do: {:ok, q}
  def filter_by_stop(q, nil), do: {:ok, q}

  @spec filter_by_arrival_departure(Ecto.Query.t(), any()) ::
          {:ok, Ecto.Query.t()} | {:error, String.t()}
  def filter_by_arrival_departure(q, arr_dep) when arr_dep in ["arrival", "departure"] do
    {:ok, from(acc in q, where: acc.arrival_departure == ^arr_dep)}
  end

  def filter_by_arrival_departure(q, _), do: {:ok, q}

  @spec filter_by_direction(Ecto.Query.t(), any()) :: {:ok, Ecto.Query.t()} | {:error, String.t()}
  def filter_by_direction(q, direction_id) when direction_id in ["0", "1"] do
    {direction_id_int, _} = Integer.parse(direction_id)
    {:ok, from(acc in q, where: acc.direction_id == ^direction_id_int)}
  end

  def filter_by_direction(q, _), do: {:ok, q}

  @spec filter_by_bin(Ecto.Query.t(), String.t()) :: {:ok, Ecto.Query.t()} | {:error, String.t()}
  def filter_by_bin(q, "All") do
    {:ok, q}
  end

  def filter_by_bin(q, bins) when byte_size(bins) > 0 do
    bins = String.split(bins, ",")
    {:ok, from(acc in q, where: acc.bin in ^bins)}
  end

  def filter_by_bin(q, _bins) do
    {:ok, q}
  end

  @spec filter_by_timeframe(Ecto.Query.t(), any(), any(), any(), any()) ::
          {:ok, Ecto.Query.t()} | {:error, String.t()}
  def filter_by_timeframe(q, chart_range, _date, start_date, end_date)
      when (chart_range == "Daily" or chart_range == "By Station") and is_binary(start_date) and
             is_binary(end_date) do
    case {Date.from_iso8601(start_date), Date.from_iso8601(end_date)} do
      {{:ok, d1}, {:ok, d2}} ->
        case Timex.diff(d2, d1, :days) do
          n when n < 0 ->
            {:error, "Start date is after end date"}

          n when n > 35 ->
            {:error, "Dates can't be more than 5 weeks apart"}

          _ ->
            {:ok, from(acc in q, where: acc.service_date >= ^d1 and acc.service_date <= ^d2)}
        end

      _ ->
        {:error, "Can't parse start or end date."}
    end
  end

  def filter_by_timeframe(q, "Hourly", date, _daily_start, _daily_end) when is_binary(date) do
    case Date.from_iso8601(date) do
      {:ok, d} ->
        {:ok, from(acc in q, where: acc.service_date == ^d)}

      _ ->
        {:error, "Can't parse service date."}
    end
  end

  def filter_by_timeframe(_q, "Hourly", _, _, _), do: {:error, "No service date given."}
  def filter_by_timeframe(_q, "Daily", _, _, _), do: {:error, "No start or end date given."}
  def filter_by_timeframe(_q, "By Station", _, _, _), do: {:error, "No start or end date given."}

  @doc """
  Takes a Queryable and groups and sums the results into
  a table like:

  hour | prod total | prod accurate | dev-green total | dev-green accurate
  """
  @spec stats_by_environment_and_chart_range(Ecto.Query.t(), String.t(), map()) :: Ecto.Query.t()
  def stats_by_environment_and_chart_range(q, environment, filters) do
    scope =
      case filters["chart_range"] do
        "Daily" -> :service_date
        "By Station" -> :stop_id
        "Hourly" -> :hour_of_day
      end

    from(
      acc in q,
      group_by: ^scope,
      order_by: ^scope,
      where: acc.environment == ^environment,
      select: [
        field(acc, ^scope),
        sum(acc.num_predictions),
        sum(acc.num_accurate_predictions),
        aggregate_mean_error(acc.mean_error, acc.num_predictions),
        aggregate_rmse(acc.root_mean_squared_error, acc.num_predictions)
      ]
    )
  end
end
