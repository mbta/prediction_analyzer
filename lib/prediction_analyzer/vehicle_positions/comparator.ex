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
  alias PredictionAnalyzer.Repo
  import Ecto.Query, only: [from: 2]

  @spec compare(Tracker.vehicle_map(), Tracker.vehicle_map()) :: Tracker.vehicle_map()
  def compare(new_vehicles, old_vehicles) do
    Enum.each(new_vehicles, fn {_id, new_vehicle} ->
      compare_vehicle(new_vehicle, old_vehicles[new_vehicle.id])
    end)

    new_vehicles
  end

  defp compare_vehicle(
         %Vehicle{stop_id: new_stop, current_status: new_status} = vehicle,
         %Vehicle{stop_id: old_stop, current_status: old_status}
       )
       when new_stop == old_stop and new_status == :STOPPED_AT and old_status != :STOPPED_AT do
    record_arrival(vehicle)
  end

  defp compare_vehicle(
         %Vehicle{stop_id: new_stop, current_status: new_status},
         %Vehicle{stop_id: old_stop, current_status: old_status} = old_vehicle
       )
       when new_stop != old_stop and old_status == :STOPPED_AT and new_status != :STOPPED_AT do
    record_departure(old_vehicle)
  end

  defp compare_vehicle(%Vehicle{label: label}, nil) do
    Logger.info("Tracking new vehicle #{label}")
  end

  defp compare_vehicle(_new, _old) do
    nil
  end

  defp record_arrival(vehicle) do
    params =
      vehicle
      |> vehicle_params()
      |> Map.put(:arrival_time, vehicle.timestamp)

    %VehicleEvent{}
    |> VehicleEvent.changeset(params)
    |> Repo.insert
    |> case do
      {:ok, vehicle_event} ->
        Logger.info("Inserted vehicle event: #{vehicle.label} arrived at #{vehicle.stop_id}")
        associate_vehicle_event_with_predictions(vehicle_event)

      {:error, changeset} ->
        Logger.warn("Could not insert vehicle event: #{inspect(changeset)}")
    end
  end

  defp record_departure(vehicle) do
    from(
      ve in VehicleEvent,
      where: ve.vehicle_id == ^(vehicle.id)
        and ve.stop_id == ^(vehicle.stop_id)
        and is_nil(ve.departure_time)
        and ve.arrival_time > ^(:os.system_time(:second) - 60*30),
      update: [set: [departure_time: ^(vehicle.timestamp)]]
    )
    |> Repo.update_all([])
    |> case do
      {0, _} ->
        Logger.warn("Tried to update departure time, but no arrival for #{vehicle.label}")

      {1, _} ->
        Logger.info("Added departure to vehicle event for #{vehicle.label}")

      {_, _} ->
        Logger.error("One departure, multiple updates for #{vehicle.label}")
    end
  end

  @spec vehicle_params(Vehicle.t()) :: map()
  defp vehicle_params(vehicle) do
    %{
      vehicle_id: vehicle.id,
      vehicle_label: vehicle.label,
      is_deleted: vehicle.is_deleted,
      route_id: vehicle.route_id,
      direction_id: vehicle.direction_id,
      trip_id: vehicle.trip_id,
      stop_id: vehicle.stop_id
    }
  end

  defp associate_vehicle_event_with_predictions(vehicle_event) do
    from(
      p in Prediction,
      where: p.trip_id == ^(vehicle_event.trip_id)
        and p.stop_id == ^(vehicle_event.stop_id)
        and (
          p.arrival_time > ^(:os.system_time(:second) - 60*60*2)
          or p.departure_time > ^(:os.system_time(:second) - 60*60*2)
        ),
      update: [set: [vehicle_event_id: ^(vehicle_event.id)]]
    )
    |> Repo.update_all([])
    |> case do
      {0, _} ->
        Logger.warn("Created vehicle_event with no associated prediction: #{vehicle_event.id}")

      {n, _} ->
        Logger.info("Associated vehicle_event with #{n} prediction(s)")
    end
  end
end
