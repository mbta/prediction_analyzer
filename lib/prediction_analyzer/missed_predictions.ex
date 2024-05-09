defmodule PredictionAnalyzer.MissedPredictions do
  import Ecto.Query, only: [from: 2]
  alias PredictionAnalyzer.VehicleEvents.VehicleEvent
  alias PredictionAnalyzer.Predictions.Prediction
  alias PredictionAnalyzer.Filters.StopGroups
  alias PredictionAnalyzer.StopNameFetcher

  def unpredicted_departures_summary(date, env) do
    {min_time, max_time} = service_times(date)

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

    unpredicted_departures_query
    |> PredictionAnalyzer.Repo.all()
    |> Enum.sort_by(&Map.get(sort_map(), elem(&1, 0), 0))
  end

  def unpredicted_departures_for_route(date, env, route_id) do
    {min_time, max_time} = service_times(date)

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
            ve.stop_id in ^terminal_stops() and
            ve.route_id == ^route_id,
        group_by: ve.stop_id,
        order_by: ve.stop_id,
        select:
          {ve.stop_id, count(ve.id),
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

    unpredicted_departures_query
    |> PredictionAnalyzer.Repo.all()
    |> add_stop_names(0)
  end

  def unpredicted_departures_for_route_stop(date, env, route_id, stop_id) do
    {min_time, max_time} = service_times(date)

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
            ve.route_id == ^route_id and
            ve.stop_id == ^stop_id and
            not exists(
              from(p in Prediction,
                where:
                  p.vehicle_event_id == parent_as(:vehicle_event).id and
                    p.file_timestamp < parent_as(:vehicle_event).departure_time and
                    not is_nil(p.departure_time)
              )
            ),
        order_by: [asc: ve.departure_time],
        select: {ve.vehicle_id, ve.trip_id, ve.departure_time}
      )

    PredictionAnalyzer.Repo.all(unpredicted_departures_query)
  end

  def missed_departures_summary(date, env) do
    {min_time, max_time} = service_times(date)

    missed_departures_query =
      from(p in Prediction,
        where:
          p.environment == ^env and
            p.file_timestamp >= ^min_time and
            p.file_timestamp <= ^max_time and
            not is_nil(p.departure_time) and
            p.stop_id in ^terminal_stops(),
        group_by: p.route_id,
        select:
          {p.route_id, count(p.trip_id, :distinct),
           count(p.trip_id, :distinct) |> filter(is_nil(p.vehicle_event_id)),
           (count(p.trip_id, :distinct) |> filter(is_nil(p.vehicle_event_id))) * 100.0 /
             count(p.trip_id, :distinct)}
      )

    missed_departures_query
    |> PredictionAnalyzer.Repo.all()
    |> Enum.sort_by(&Map.get(sort_map(), elem(&1, 0), 0))
  end

  def missed_departues_for_route(date, env, route_id) do
    {min_time, max_time} = service_times(date)

    missed_departures_query =
      from(p in Prediction,
        where:
          p.environment == ^env and
            p.file_timestamp >= ^min_time and
            p.file_timestamp <= ^max_time and
            not is_nil(p.departure_time) and
            p.route_id == ^route_id and
            p.stop_id in ^terminal_stops(),
        group_by: p.stop_id,
        order_by: [desc: count(p.trip_id, :distinct)],
        select:
          {p.stop_id, count(p.trip_id, :distinct),
           count(p.trip_id, :distinct) |> filter(is_nil(p.vehicle_event_id)),
           (count(p.trip_id, :distinct) |> filter(is_nil(p.vehicle_event_id))) * 100.0 /
             count(p.trip_id, :distinct)}
      )

    PredictionAnalyzer.Repo.all(missed_departures_query) |> add_stop_names(0)
  end

  def missed_departures_for_route_stop(date, env, route_id, stop_id) do
    {min_time, max_time} = service_times(date)

    missed_departures_query =
      from(p in Prediction,
        where:
          p.environment == ^env and
            p.file_timestamp >= ^min_time and
            p.file_timestamp <= ^max_time and
            p.route_id == ^route_id and
            not is_nil(p.departure_time) and
            is_nil(p.vehicle_event_id) and
            p.stop_id == ^stop_id,
        group_by: [p.vehicle_id, p.trip_id],
        order_by: [p.vehicle_id, min(p.departure_time)],
        select:
          {p.vehicle_id, p.trip_id, min(p.departure_time), max(p.departure_time),
           min(p.file_timestamp), max(p.file_timestamp), count(p.id)}
      )

    PredictionAnalyzer.Repo.all(missed_departures_query)
  end

  defp service_times(date) do
    start_time = Time.new!(4, 0, 0)
    {:ok, start_date_time} = DateTime.new(date, start_time, "America/New_York")

    end_time = Time.new!(2, 0, 0)
    tomorrow = Date.add(date, 1)
    {:ok, end_date_time} = DateTime.new(tomorrow, end_time, "America/New_York")

    {start_date_time |> DateTime.to_unix(), end_date_time |> DateTime.to_unix()}
  end

  defp sort_map() do
    PredictionAnalyzer.Utilities.routes_for_mode(:subway) |> Enum.with_index() |> Enum.into(%{})
  end

  defp terminal_stops() do
    StopGroups.expand_groups(["_terminal"])
  end

  defp add_stop_names(data, idx) do
    stop_dict = StopNameFetcher.get_stop_descriptions(:subway)

    Enum.map(data, fn row ->
      stop_id = elem(row, idx)
      stop_name = Map.get(stop_dict, stop_id, stop_id)
      Tuple.insert_at(row, idx + 1, stop_name)
    end)
  end
end
