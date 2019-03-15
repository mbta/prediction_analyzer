defmodule PredictionAnalyzer.PredictionAccuracy.PredictionAccuracy do
  use Ecto.Schema
  import Ecto.Changeset

  import Ecto.Query, only: [from: 2]

  schema "prediction_accuracy" do
    field(:environment, :string)
    field(:service_date, :date)
    field(:hour_of_day, :integer)
    field(:stop_id, :string)
    field(:route_id, :string)
    field(:direction_id, :integer)
    field(:arrival_departure, :string)
    field(:bin, :string)
    field(:num_predictions, :integer)
    field(:num_accurate_predictions, :integer)
  end

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
      "6-12 min" => {360, 720, -150, 210},
      "12-30 min" => {720, 1800, -240, 360}
    }
  end

  def new_insert_changeset(params \\ %{}) do
    all_fields = [
      :service_date,
      :hour_of_day,
      :stop_id,
      :route_id,
      :direction_id,
      :arrival_departure,
      :bin,
      :num_predictions,
      :num_accurate_predictions
    ]

    %__MODULE__{}
    |> cast(params, all_fields)
    |> validate_required(all_fields)
    |> validate_inclusion(:arrival_departure, ["arrival", "departure"])
    |> validate_inclusion(:bin, Map.keys(bins()))
  end

  @spec filter(map()) :: {Ecto.Query.t(), nil | String.t()}
  def filter(params) do
    q = from(acc in __MODULE__, [])

    with {:ok, q} <- filter_by_route(q, params["route_id"]),
         {:ok, q} <- filter_by_stop(q, params["stop_id"]),
         {:ok, q} <- filter_by_direction(q, params["direction_id"]),
         {:ok, q} <- filter_by_arrival_departure(q, params["arrival_departure"]),
         {:ok, q} <- filter_by_bin(q, params["bin"]),
         {:ok, q} <-
           filter_by_timeframe(
             q,
             params["chart_range"],
             params["service_date"],
             params["daily_date_start"],
             params["daily_date_end"]
           ) do
      {q, nil}
    else
      {:error, msg} -> {from(acc in q, where: false), msg}
    end
  end

  @spec filter_by_route(Ecto.Query.t(), any()) :: {:ok, Ecto.Query.t()} | {:error, String.t()}
  defp filter_by_route(q, route_id) when is_binary(route_id) and route_id != "" do
    {:ok, from(acc in q, where: acc.route_id == ^route_id)}
  end

  defp filter_by_route(q, _), do: {:ok, q}

  @spec filter_by_stop(Ecto.Query.t(), any()) :: {:ok, Ecto.Query.t()} | {:error, String.t()}
  defp filter_by_stop(q, stop_id) when is_binary(stop_id) and stop_id != "" do
    {:ok, from(acc in q, where: acc.stop_id == ^stop_id)}
  end

  defp filter_by_stop(q, _), do: {:ok, q}

  @spec filter_by_arrival_departure(Ecto.Query.t(), any()) ::
          {:ok, Ecto.Query.t()} | {:error, String.t()}
  defp filter_by_arrival_departure(q, arr_dep) when arr_dep in ["arrival", "departure"] do
    {:ok, from(acc in q, where: acc.arrival_departure == ^arr_dep)}
  end

  defp filter_by_arrival_departure(q, _), do: {:ok, q}

  @spec filter_by_direction(Ecto.Query.t(), any()) :: {:ok, Ecto.Query.t()} | {:error, String.t()}
  defp filter_by_direction(q, direction_id) when direction_id in [0, 1] do
    {:ok, from(acc in q, where: acc.direction_id == ^direction_id)}
  end

  defp filter_by_direction(q, _), do: {:ok, q}

  @spec filter_by_bin(Ecto.Query.t(), any()) :: {:ok, Ecto.Query.t()} | {:error, String.t()}
  defp filter_by_bin(q, bin) do
    if Map.has_key?(bins(), bin) do
      {:ok, from(acc in q, where: acc.bin == ^bin)}
    else
      {:ok, q}
    end
  end

  @spec filter_by_timeframe(Ecto.Query.t(), any(), any(), any(), any()) ::
          {:ok, Ecto.Query.t()} | {:error, String.t()}
  defp filter_by_timeframe(q, chart_range, _date, start_date, end_date)
       when (chart_range == "Daily" or chart_range == "By Station") and is_binary(start_date) and
              is_binary(end_date) do
    case {Date.from_iso8601(start_date), Date.from_iso8601(end_date)} do
      {{:ok, d1}, {:ok, d2}} ->
        case Timex.diff(d2, d1, :days) do
          n when n < 0 ->
            {:error, "Start date is after end date"}

          n when n > 28 ->
            {:error, "Dates can't be more than 4 weeks apart"}

          _ ->
            {:ok, from(acc in q, where: acc.service_date >= ^d1 and acc.service_date <= ^d2)}
        end

      _ ->
        {:error, "Can't parse start or end date."}
    end
  end

  defp filter_by_timeframe(q, "Hourly", date, _daily_start, _daily_end) when is_binary(date) do
    case Date.from_iso8601(date) do
      {:ok, d} ->
        {:ok, from(acc in q, where: acc.service_date == ^d)}

      _ ->
        {:error, "Can't parse service date."}
    end
  end

  defp filter_by_timeframe(_q, "Hourly", _, _, _), do: {:error, "No service date given."}
  defp filter_by_timeframe(_q, "Daily", _, _, _), do: {:error, "No start or end date given."}
  defp filter_by_timeframe(_q, "By Station", _, _, _), do: {:error, "No start or end date given."}

  @doc """
  Takes a Queryable and groups and sums the results into
  a table like:

  hour | prod total | prod accurate | dev-green total | dev-green accurate
  """
  @spec stats_by_environment_and_chart_range(Ecto.Query.t(), %{}) :: Ecto.Query.t()
  def stats_by_environment_and_chart_range(q, filters) do
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
      select: [
        field(acc, ^scope),
        sum(
          fragment(
            "case when ? = ? then ? else 0 end",
            acc.environment,
            "prod",
            acc.num_predictions
          )
        ),
        sum(
          fragment(
            "case when ? = ? then ? else 0 end",
            acc.environment,
            "prod",
            acc.num_accurate_predictions
          )
        ),
        sum(
          fragment(
            "case when ? = ? then ? else 0 end",
            acc.environment,
            "dev-green",
            acc.num_predictions
          )
        ),
        sum(
          fragment(
            "case when ? = ? then ? else 0 end",
            acc.environment,
            "dev-green",
            acc.num_accurate_predictions
          )
        )
      ]
    )
  end
end
