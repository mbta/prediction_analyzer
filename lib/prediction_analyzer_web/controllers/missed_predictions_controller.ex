defmodule PredictionAnalyzerWeb.MissedPredictionsController do
  use PredictionAnalyzerWeb, :controller
  alias PredictionAnalyzer.StopNameFetcher
  alias PredictionAnalyzer.MissedPredictions

  defp parse_date(nil), do: Date.utc_today()

  defp parse_date(date_str) do
    case Date.from_iso8601(date_str) do
      {:ok, date} -> date
      {:error, _} -> DateTime.now!("America/New_York") |> DateTime.to_date()
    end
  end

  defp base_params(params) do
    date = parse_date(params["date"])
    env = params["env"] || "prod"

    Map.merge(params, %{
      date: date,
      env: env,
      query_params: params
    })
  end

  defp totals(data, base_idx, missed_idx) do
    total_missed = data |> Enum.map(&elem(&1, missed_idx)) |> Enum.sum()
    total_base = data |> Enum.map(&elem(&1, base_idx)) |> Enum.sum()
    total_pct = if total_base > 0, do: total_missed * 100.0 / total_base, else: 0.0
    {total_base, total_missed, total_pct}
  end

  defp load_data(
         %{"missing_route" => missing_route, "stop_id" => stop_id, env: env, date: date} = params
       )
       when not is_nil(missing_route) do
    stop_name = StopNameFetcher.get_stop_name(:subway, stop_id)

    Map.merge(params, %{
      missing_departures_for_route_stop:
        MissedPredictions.unpredicted_departures_for_route_stop(date, env, missing_route, stop_id),
      stop_name: stop_name,
      stop_id: stop_id,
      route: missing_route
    })
  end

  defp load_data(%{"missing_route" => missing_route, env: env, date: date} = params)
       when not is_nil(missing_route) do
    missing_departures_for_route =
      MissedPredictions.unpredicted_departures_for_route(date, env, missing_route)

    totals = totals(missing_departures_for_route, 2, 3)

    Map.merge(params, %{
      missing_departures_for_route:
        MissedPredictions.unpredicted_departures_for_route(date, env, missing_route),
      totals: totals,
      route: missing_route
    })
  end

  defp load_data(
         %{"missed_route" => missed_route, "stop_id" => stop_id, env: env, date: date} = params
       )
       when not is_nil(missed_route) do
    stop_name = StopNameFetcher.get_stop_name(:subway, stop_id)

    Map.merge(params, %{
      unrealized_departures_for_route_stop:
        MissedPredictions.missed_departures_for_route_stop(date, env, missed_route, stop_id),
      route: missed_route,
      stop_id: stop_id,
      stop_name: stop_name
    })
  end

  defp load_data(%{"missed_route" => missed_route, env: env, date: date} = params)
       when not is_nil(missed_route) do
    unrealized_departures_for_route =
      MissedPredictions.missed_departures_for_route(date, env, missed_route)

    totals = totals(unrealized_departures_for_route, 2, 3)

    Map.merge(params, %{
      unrealized_departures_for_route:
        MissedPredictions.missed_departures_for_route(date, env, missed_route),
      totals: totals,
      route: missed_route
    })
  end

  defp load_data(%{env: env, date: date} = params) do
    unpredicted_departures = MissedPredictions.unpredicted_departures_summary(date, env)
    missed_departures = MissedPredictions.missed_departures_summary(date, env)
    unpredicted_totals = totals(unpredicted_departures, 1, 2)
    missed_totals = totals(missed_departures, 1, 2)

    Map.merge(params, %{
      unpredicted_departures: unpredicted_departures,
      missed_departures: missed_departures,
      unpredicted_totals: unpredicted_totals,
      missed_totals: missed_totals
    })
  end

  def index(conn, params) do
    assigns =
      params
      |> base_params()
      |> load_data()

    conn =
      conn
      |> put_in(
        [Access.key(:params, %{}), Access.key("filters", %{}), Access.key("chart_range", %{})],
        "Missed/Missing Predictions"
      )
      |> put_in([Access.key(:params, %{}), "date"], Date.to_iso8601(assigns[:date]))

    render(conn, "index.html", assigns)
  end
end
