defmodule PredictionAnalyzerWeb.MissedPredictionsController do
  use PredictionAnalyzerWeb, :controller
  alias PredictionAnalyzer.StopNameFetcher
  alias PredictionAnalyzer.MissedPredictions

  # TODO: populate date filter when date is not provided

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
    Map.merge(params, %{
      missing_departures_for_route:
        MissedPredictions.unpredicted_departures_for_route(date, env, missing_route),
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
    Map.merge(params, %{
      unrealized_departures_for_route:
        MissedPredictions.missed_departures_for_route(date, env, missed_route),
      route: missed_route
    })
  end

  defp load_data(%{env: env, date: date} = params) do
    Map.merge(params, %{
      unpredicted_departures: MissedPredictions.unpredicted_departures_summary(date, env),
      missed_departures: MissedPredictions.missed_departures_summary(date, env)
    })
  end

  def index(conn, params) do
    assigns =
      params
      |> base_params()
      |> load_data()

    conn =
      put_in(
        conn,
        [Access.key(:params, %{}), Access.key("filters", %{}), Access.key("chart_range", %{})],
        "Missed/Missing Predictions"
      )

    render(conn, "index.html", assigns)
  end
end
