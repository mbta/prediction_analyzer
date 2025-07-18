defmodule PredictionAnalyzer.VehiclePositions.Comparator do
  @moduledoc """
  Compare the new set of vehicles to the old ones, to determine
  which ones have arrived at or departed from a station.
  """

  require Logger
  alias PredictionAnalyzer.VehiclePositions.Tracker
  alias PredictionAnalyzer.VehiclePositions.Vehicle
  alias PredictionAnalyzer.VehicleEvents.VehicleEvent
  alias PredictionAnalyzer.Predictions.Prediction
  alias PredictionAnalyzer.Utilities
  alias PredictionAnalyzer.Repo
  import Ecto.Query, only: [from: 2]

  @spec compare(Tracker.vehicle_map(), Tracker.vehicle_map()) :: Tracker.vehicle_map()
  def compare(new_vehicles, old_vehicles) do
    Enum.each(new_vehicles, fn {_id, new_vehicle} ->
      compare_vehicle(new_vehicle, old_vehicles[new_vehicle.id])
    end)

    new_vehicle_ids = new_vehicles |> Map.keys() |> MapSet.new()
    old_vehicle_ids = old_vehicles |> Map.keys() |> MapSet.new()

    lost_vehicle_ids = MapSet.difference(old_vehicle_ids, new_vehicle_ids)

    if MapSet.size(lost_vehicle_ids) > 0 do
      lost_vehicle_labels =
        Enum.map(lost_vehicle_ids, fn vehicle_id ->
          {old_vehicles[vehicle_id].environment, old_vehicles[vehicle_id].label}
        end)

      Logger.info("vehicles_dropped_from_feed vehicles=#{inspect(lost_vehicle_labels)}")
    end

    new_vehicles
  end

  @spec compare_vehicle(Vehicle.t(), Vehicle.t()) :: nil
  defp compare_vehicle(
         %Vehicle{stop_id: new_stop, current_status: new_status} = vehicle,
         %Vehicle{stop_id: old_stop, current_status: old_status}
       )
       when new_stop == old_stop and new_status == :STOPPED_AT and old_status != :STOPPED_AT do
    record_arrival(vehicle)
  end

  defp compare_vehicle(
         %Vehicle{stop_id: new_stop, current_status: new_status, timestamp: new_timestamp},
         %Vehicle{stop_id: old_stop, current_status: old_status} = old_vehicle
       )
       when new_stop != old_stop and old_status == :STOPPED_AT and new_status != :STOPPED_AT do
    record_departure(%{old_vehicle | timestamp: new_timestamp})
  end

  defp compare_vehicle(
         %Vehicle{stop_id: new_stop, current_status: new_status} = new_vehicle,
         %Vehicle{stop_id: old_stop, current_status: old_status} = old_vehicle
       )
       when new_stop != old_stop and old_status == :STOPPED_AT and new_status == :STOPPED_AT do
    record_departure(%{old_vehicle | timestamp: new_vehicle.timestamp})
    record_arrival(new_vehicle)
  end

  defp compare_vehicle(%Vehicle{label: label, current_status: status} = vehicle, nil) do
    if status == :STOPPED_AT do
      record_arrival(vehicle)
    end

    Logger.info(
      "Tracking new vehicle vehicle=#{label} stop_id=#{vehicle.stop_id} environment=#{vehicle.environment}"
    )
  end

  defp compare_vehicle(_new, _old) do
    nil
  end

  @spec record_arrival(Vehicle.t()) :: nil
  defp record_arrival(vehicle) do
    params =
      vehicle
      |> vehicle_params()
      |> Map.put(:arrival_time, vehicle.timestamp)

    %VehicleEvent{}
    |> VehicleEvent.changeset(params)
    |> Repo.insert()
    |> case do
      {:ok, vehicle_event} ->
        Logger.info(
          "Inserted vehicle arrival event: vehicle=#{vehicle.label} stop_id=#{vehicle.stop_id} environment=#{vehicle.environment}"
        )

        associate_vehicle_event_with_predictions(vehicle_event)

      {:error, changeset} ->
        Logger.warn("Could not insert vehicle event: #{inspect(changeset)}")
    end

    nil
  end

  @spec record_departure(Vehicle.t()) :: nil
  defp record_departure(vehicle) do
    max_dwell_time_sec = Application.get_env(:prediction_analyzer, :max_dwell_time_sec)

    from(
      ve in VehicleEvent,
      where:
        ve.environment == ^vehicle.environment and ve.vehicle_id == ^vehicle.id and
          ve.stop_id == ^vehicle.stop_id and is_nil(ve.departure_time) and
          ve.arrival_time > ^(System.system_time(:second) - max_dwell_time_sec),
      update: [set: [departure_time: ^vehicle.timestamp]],
      select: ve
    )
    |> Repo.update_all([])
    |> case do
      {0, _} ->
        Logger.warn("Tried to update departure time, but no arrival for #{vehicle.label}")

      {1, [ve]} ->
        Logger.info(
          "Added departure to vehicle event for vehicle=#{vehicle.label} stop_id=#{vehicle.stop_id} environment=#{vehicle.environment}"
        )

        associate_vehicle_event_with_predictions(ve)

      {_, _} ->
        log_string =
          "One departure, multiple updates for vehicle=#{vehicle.label} route=#{vehicle.route_id} trip_id=#{vehicle.trip_id} stop_id=#{vehicle.stop_id} environment=#{vehicle.environment}"

        cond do
          vehicle.route_id in Utilities.routes_for_mode(:subway) ->
            Logger.error(log_string)

          vehicle.route_id in Utilities.routes_for_mode(:commuter_rail) ->
            Logger.info(log_string)
        end
    end

    nil
  end

  @spec vehicle_params(Vehicle.t()) :: map()
  defp vehicle_params(vehicle) do
    %{
      environment: vehicle.environment,
      vehicle_id: vehicle.id,
      vehicle_label: vehicle.label,
      is_deleted: vehicle.is_deleted,
      route_id: vehicle.route_id,
      direction_id: vehicle.direction_id,
      trip_id: vehicle.trip_id,
      stop_id: vehicle.stop_id
    }
  end

  @spec associate_vehicle_event_with_predictions(VehicleEvent.t()) :: nil
  def associate_vehicle_event_with_predictions(vehicle_event) do
    # Handle Glides terminal predictions:
    from(
      p in Prediction,
      # Use trip_id in case where vehicle_id is nil:
      # Rest is the same:
      # More flexible for backfilling vehicle_event_ids:
      where:
        p.trip_id == ^vehicle_event.trip_id and
          p.direction_id == ^vehicle_event.direction_id and
          is_nil(p.vehicle_id) and
          p.stop_id == ^vehicle_event.stop_id and
          p.environment == ^vehicle_event.environment and
          is_nil(p.vehicle_event_id) and
          p.file_timestamp >= ^(System.system_time(:second) - 60 * 40),
      update: [set: [vehicle_event_id: ^vehicle_event.id, vehicle_id: ^vehicle_event.vehicle_id]]
    )
    |> Repo.update_all([])
    |> case do
      {n, _} ->
        if n > 0,
          do:
            Logger.info(
              "vehicle_event_type=glides Associated vehicle_event with #{n} prediction(s)"
            )
    end

    # Handle normal events:
    from(
      p in Prediction,
      where:
        p.vehicle_id == ^vehicle_event.vehicle_id and
          not is_nil(p.vehicle_id) and
          p.stop_id == ^vehicle_event.stop_id and
          p.environment == ^vehicle_event.environment and is_nil(p.vehicle_event_id) and
          p.file_timestamp > ^(System.system_time(:second) - 60 * 30),
      update: [set: [vehicle_event_id: ^vehicle_event.id]]
    )
    |> Repo.update_all([])
    |> case do
      {0, _} ->
        unless vehicle_event.departure_time do
          Logger.warn(
            "vehicle_event_type=standard Created vehicle_event with no associated prediction: #{vehicle_event.id}"
          )
        end

      {n, _} ->
        Logger.info(
          "vehicle_event_type=standard Associated vehicle_event with #{n} prediction(s)"
        )
    end

    nil
  end
end
