defmodule PredictionAnalyzer.VehiclePositions.ComparatorTest do
  use ExUnit.Case
  import Ecto.Query, only: [from: 2]
  alias PredictionAnalyzer.VehicleEvents.VehicleEvent
  alias PredictionAnalyzer.Predictions.Prediction
  alias PredictionAnalyzer.Repo
  alias PredictionAnalyzer.VehiclePositions.Comparator
  alias PredictionAnalyzer.VehiclePositions.Vehicle

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(PredictionAnalyzer.Repo)
  end

  @vehicle %Vehicle{
    id: "1",
    label: "1000",
    is_deleted: false,
    trip_id: "trip1",
    route_id: "route1",
    direction_id: 0,
    current_status: :IN_TRANSIT_TO,
    stop_id: "stop1",
    timestamp: :os.system_time(:second)
  }

  describe "compare_vehicles" do
    test "records arrival and departure of vehicle" do
      assert Repo.one(from(ve in VehicleEvent, select: count(ve.id))) == 0

      old_vehicles = %{
        "1" => %{@vehicle | current_status: :INCOMING_AT}
      }

      new_vehicles = %{
        "1" => %{@vehicle | current_status: :STOPPED_AT}
      }

      Comparator.compare(new_vehicles, old_vehicles)

      timestamp = @vehicle.timestamp

      vehicle_events = Repo.all(from(ve in VehicleEvent, select: ve))

      assert [
               %VehicleEvent{vehicle_id: "1", arrival_time: ^timestamp, departure_time: nil}
             ] = vehicle_events

      ve_id = List.first(vehicle_events).id

      old_vehicles = new_vehicles

      new_vehicles = %{
        "1" => %{@vehicle | current_status: :IN_TRANSIT_TO, stop_id: "stop2"}
      }

      Comparator.compare(new_vehicles, old_vehicles)

      assert [
               %VehicleEvent{
                 id: ^ve_id,
                 vehicle_id: "1",
                 arrival_time: ^timestamp,
                 departure_time: ^timestamp
               }
             ] = Repo.all(from(ve in VehicleEvent, select: ve))
    end

    test "updates relevant predictions" do
      prediction1 = %Prediction{
        trip_id: "trip1",
        arrival_time: :os.system_time(:second),
        stop_id: "stop1"
      }

      prediction2 = %Prediction{
        trip_id: "trip1",
        arrival_time: :os.system_time(:second),
        stop_id: "stop0"
      }

      prediction3 = %Prediction{
        trip_id: "trip1",
        arrival_time: :os.system_time(:second) - 24 * 60 * 60,
        stop_id: "stop1"
      }

      [p1_id, p2_id, p3_id] =
        Enum.map([prediction1, prediction2, prediction3], fn prediction ->
          Repo.insert!(prediction) |> Map.get(:id)
        end)

      vehicle = %{@vehicle | trip_id: "trip1", stop_id: "stop1"}

      old_vehicles = %{
        "1" => %{vehicle | current_status: :INCOMING_AT}
      }

      new_vehicles = %{
        "1" => %{vehicle | current_status: :STOPPED_AT}
      }

      Comparator.compare(new_vehicles, old_vehicles)

      [ve_id] = Repo.all(from(ve in VehicleEvent, select: ve.id))

      assert Repo.one(from(p in Prediction, where: p.id == ^p1_id, select: p.vehicle_event_id)) ==
               ve_id

      assert Repo.one(from(p in Prediction, where: p.id == ^p2_id, select: p.vehicle_event_id)) ==
               nil

      assert Repo.one(from(p in Prediction, where: p.id == ^p3_id, select: p.vehicle_event_id)) ==
               nil
    end
  end
end
