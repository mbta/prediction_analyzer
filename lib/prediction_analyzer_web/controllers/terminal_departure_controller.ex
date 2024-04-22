defmodule PredictionAnalyzerWeb.TerminalDepartureController do
  use PredictionAnalyzerWeb, :controller
  import Ecto.Query, only: [from: 2]
  alias PredictionAnalyzer.Predictions.Prediction
  alias PredictionAnalyzer.VehicleEvents.VehicleEvent
  alias PredictionAnalyzer.Filters.StopGroups
  alias PredictionAnalyzer.StopNameFetcher

  # TODO 3 stage drill -> route -> route, stop -> full data
  # TODO Remove exit only
  # TODO rollup Missed Departures by trip
  # TODO totals rows
  defp terminal_stops() do
    StopGroups.expand_groups(["_terminal"])
  end

  defp parse_date(nil), do: Date.utc_today()

  defp parse_date(date_str) do
    case Date.from_iso8601(date_str) do
      {:ok, date} -> date
      {:error, _} -> DateTime.now("America/New_York") |> DateTime.to_date()
    end
  end

  defp service_times(date) do
    start_time = Time.new!(4, 0, 0)
    {:ok, start_date_time} = DateTime.new(date, start_time, "America/New_York")

    end_time = Time.new!(2, 0, 0)
    tomorrow = Date.add(date, 1)
    {:ok, end_date_time} = DateTime.new(tomorrow, end_time, "America/New_York")

    {start_date_time |> DateTime.to_unix(), end_date_time |> DateTime.to_unix()}
  end

  defp base_params(params) do
    date = parse_date(params["date"])
    env = params["env"] || "prod"

    {min_time, max_time} = service_times(date)

    Map.merge(params, %{
      date: date,
      env: env,
      min_time: min_time,
      max_time: max_time,
      query_params: params
    })
  end

  defp add_stop_names(data, idx) do
    stop_dict = StopNameFetcher.get_stop_descriptions(:subway)

    Enum.map(data, fn row ->
      stop_id = elem(row, idx)
      stop_name = Map.get(stop_dict, stop_id, stop_id)
      Tuple.insert_at(row, idx + 1, stop_name)
    end)
  end

  defp load_data(%{"missing_route" => missing_route} = params) when not is_nil(missing_route) do
    %{env: env, min_time: min_time, max_time: max_time} = params

    unpredicted_departures_query =
      from(ve in VehicleEvent,
        as: :vehicle_event,
        where:
          not is_nil(ve.trip_id) and
            not is_nil(ve.departure_time) and
            not ve.is_deleted and
            ve.environment == ^env and
            ve.departure_time >= ^min_time and
            ve.departure_time <= ^max_time and
            ve.route_id == ^missing_route and
            ve.stop_id in ^terminal_stops() and
            not exists(
              from(p in Prediction,
                where:
                  p.vehicle_event_id == parent_as(:vehicle_event).id and
                    p.file_timestamp < parent_as(:vehicle_event).departure_time and
                    not is_nil(p.departure_time)
              )
            ),
        order_by: [asc: ve.departure_time],
        select: {ve.route_id, ve.vehicle_id, ve.trip_id, ve.stop_id, ve.departure_time}
      )

    unpredicted_departures =
      unpredicted_departures_query
      |> PredictionAnalyzer.Repo.all()
      |> add_stop_names(3)

    Map.merge(params, %{missing_departures_details: unpredicted_departures})
  end

  defp load_data(%{"missed_route" => missed_route} = params) when not is_nil(missed_route) do
    %{env: env, min_time: min_time, max_time: max_time} = params

    missed_departures_query =
      from(p in Prediction,
        where:
          p.environment == ^env and
            p.file_timestamp >= ^min_time and
            p.file_timestamp <= ^max_time and
            p.route_id == ^missed_route and
            not is_nil(p.departure_time) and
            is_nil(p.vehicle_event_id) and
            p.stop_id in ^terminal_stops(),
        group_by: [p.route_id, p.vehicle_id, p.stop_id, p.trip_id],
        order_by: [p.vehicle_id, p.stop_id, min(p.departure_time)],
        select:
          {p.route_id, p.vehicle_id, p.stop_id, p.trip_id, min(p.departure_time),
           max(p.departure_time), min(p.file_timestamp), max(p.file_timestamp), count(p.id)}
      )

    missed_departures =
      missed_departures_query
      |> PredictionAnalyzer.Repo.all()
      |> add_stop_names(2)

    Map.merge(params, %{missed_departures_details: missed_departures})
  end

  defp load_data(params) do
    %{env: env, min_time: min_time, max_time: max_time} = params

    unpredicted_departures_query =
      from(ve in VehicleEvent,
        as: :vehicle_event,
        where:
          not is_nil(ve.trip_id) and
            not is_nil(ve.departure_time) and
            not ve.is_deleted and
            ve.environment == ^env and
            ve.departure_time >= ^min_time and
            ve.departure_time <= ^max_time and
            ve.stop_id in ^terminal_stops(),
        group_by: ve.route_id,
        order_by: ve.route_id,
        select:
          {ve.route_id, count(ve.id),
           count(ve.id)
           |> filter(
             not exists(
               from(p in Prediction,
                 where:
                   p.vehicle_event_id == parent_as(:vehicle_event).id and
                     p.file_timestamp < parent_as(:vehicle_event).departure_time and
                     not is_nil(p.departure_time)
               )
             )
           ),
           (count(ve.id)
            |> filter(
              not exists(
                from(p in Prediction,
                  where:
                    p.vehicle_event_id == parent_as(:vehicle_event).id and
                      p.file_timestamp < parent_as(:vehicle_event).departure_time and
                      not is_nil(p.departure_time)
                )
              )
            )) * 100.0 / count(ve.id)}
      )

    unpredicted_departures = PredictionAnalyzer.Repo.all(unpredicted_departures_query)

    missed_departures_query =
      from(p in Prediction,
        where:
          p.environment == ^env and
            p.file_timestamp >= ^min_time and
            p.file_timestamp <= ^max_time and
            not is_nil(p.departure_time) and
            p.stop_id in ^terminal_stops(),
        group_by: p.route_id,
        order_by: [desc: count(p.trip_id, :distinct)],
        select:
          {p.route_id, count(p.trip_id, :distinct),
           count(p.trip_id, :distinct) |> filter(is_nil(p.vehicle_event_id)),
           (count(p.trip_id, :distinct) |> filter(is_nil(p.vehicle_event_id))) * 100.0 /
             count(p.trip_id, :distinct)}
      )

    missed_departures = PredictionAnalyzer.Repo.all(missed_departures_query)

    Map.merge(params, %{
      unpredicted_departures: unpredicted_departures,
      missed_departures: missed_departures
    })
  end

  def index(conn, params) do
    assigns =
      params
      |> base_params()
      |> load_data()

    render(conn, "index.html", assigns)
  end
end
