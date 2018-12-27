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

  def filter(params) do
    from(acc in __MODULE__, [])
    |> filter_by_route(params["route_id"])
    |> filter_by_stop(params["stop_id"])
    |> filter_by_arrival_departure(params["arrival_departure"])
    |> filter_by_bin(params["bin"])
    |> filter_by_timeframe(params["chart_range"], params["service_date"])
  end

  defp filter_by_route(q, route_id) when is_binary(route_id) and route_id != "" do
    from(acc in q, where: acc.route_id == ^route_id)
  end

  defp filter_by_route(q, _), do: q

  defp filter_by_stop(q, stop_id) when is_binary(stop_id) and stop_id != "" do
    from(acc in q, where: acc.stop_id == ^stop_id)
  end

  defp filter_by_stop(q, _), do: q

  defp filter_by_arrival_departure(q, arr_dep) when arr_dep in ["arrival", "departure"] do
    from(acc in q, where: acc.arrival_departure == ^arr_dep)
  end

  defp filter_by_arrival_departure(q, _), do: q

  defp filter_by_bin(q, bin) do
    if Map.has_key?(bins(), bin) do
      from(acc in q, where: acc.bin == ^bin)
    else
      q
    end
  end

  defp filter_by_timeframe(q, "Daily", _date) do
    date = Timex.local() |> Timex.shift(days: -14) |> DateTime.to_date()
    from(acc in q, where: acc.service_date >= ^date)
  end

  defp filter_by_timeframe(q, _chart_range, date) do
    case Date.from_iso8601(date || "") do
      {:ok, d} ->
        from(acc in q, where: acc.service_date == ^d)

      _ ->
        from(acc in q, where: acc.service_date == ^(Timex.local() |> DateTime.to_date()))
    end
  end

  @doc """
  Takes a Queryable and groups and sums the results into
  a table like:

  hour | prod total | prod accurate | dev-green total | dev-green accurate
  """
  def stats_by_environment_and_hour(q, filters) do
    scope = if filters["chart_range"] == "Daily", do: :service_date, else: :hour_of_day

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
