defmodule PredictionAnalyzer.VehiclePositions.ComparatorTest do
  use ExUnit.Case
  import ExUnit.CaptureLog
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
    environment: "dev-green",
    label: "1000",
    is_deleted: false,
    trip_id: "trip1",
    route_id: "route1",
    direction_id: 0,
    current_status: :IN_TRANSIT_TO,
    stop_id: "stop1",
    timestamp: :os.system_time(:second)
  }

  @prediction %Prediction{
    file_timestamp: :os.system_time(:second),
    environment: "dev-green",
    trip_id: "trip",
    is_deleted: false,
    delay: 0,
    arrival_time: nil,
    boarding_status: nil,
    departure_time: nil,
    schedule_relationship: nil,
    route_id: "Blue",
    stop_id: "stop",
    stop_sequence: 10,
    stops_away: 2,
    vehicle_event_id: nil
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
      prediction1 = %{
        @prediction
        | trip_id: "trip1",
          vehicle_id: "1",
          arrival_time: :os.system_time(:second),
          stop_id: "stop1"
      }

      prediction2 = %{
        @prediction
        | trip_id: "trip1",
          vehicle_id: "1",
          arrival_time: :os.system_time(:second) - 60 * 15,
          stop_id: "stop1"
      }

      prediction3 = %{
        @prediction
        | trip_id: "trip1",
          vehicle_id: "1",
          arrival_time: :os.system_time(:second),
          stop_id: "stop0"
      }

      prediction4 = %{
        @prediction
        | trip_id: "trip1",
          vehicle_id: "1",
          arrival_time: :os.system_time(:second) - 60 * 60,
          file_timestamp: :os.system_time(:second) - 60 * 60,
          stop_id: "stop1"
      }

      [p1_id, p2_id, p3_id, p4_id] =
        Enum.map([prediction1, prediction2, prediction3, prediction4], fn prediction ->
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
               ve_id

      assert Repo.one(from(p in Prediction, where: p.id == ^p3_id, select: p.vehicle_event_id)) ==
               nil

      assert Repo.one(from(p in Prediction, where: p.id == ^p4_id, select: p.vehicle_event_id)) ==
               nil

      prediction5 = %{
        @prediction
        | trip_id: "trip1",
          vehicle_id: "1",
          departure_time: :os.system_time(:second) + 1,
          stop_id: "stop1"
      }

      p5_id = Repo.insert!(prediction5) |> Map.get(:id)

      vehicle = %{@vehicle | trip_id: "trip1"}

      old_vehicles = %{
        "1" => %{vehicle | stop_id: "stop1", current_status: :STOPPED_AT}
      }

      new_vehicles = %{
        "1" => %{vehicle | stop_id: "stop2", current_status: :IN_TRANSIT_TO}
      }

      Comparator.compare(new_vehicles, old_vehicles)

      assert Repo.one(from(p in Prediction, where: p.id == ^p5_id, select: p.vehicle_event_id)) ==
               ve_id
    end

    test "records arrival and departure of vehicle that doesn't track between stations" do
      base_time = :os.system_time(:second)
      stop1_arrival = base_time + 30
      stop2_arrival = base_time + 60

      old_vehicles = %{
        "1" => %{@vehicle | timestamp: base_time}
      }

      new_vehicles = %{
        "1" => %{@vehicle | timestamp: stop1_arrival, current_status: :STOPPED_AT}
      }

      Comparator.compare(new_vehicles, old_vehicles)

      old_vehicles = %{
        "1" => %{@vehicle | timestamp: stop1_arrival, current_status: :STOPPED_AT}
      }

      new_vehicles = %{
        "1" => %{
          @vehicle
          | timestamp: stop2_arrival,
            stop_id: "stop2",
            current_status: :STOPPED_AT
        }
      }

      Comparator.compare(new_vehicles, old_vehicles)

      assert [
               %VehicleEvent{
                 stop_id: "stop1",
                 arrival_time: ^stop1_arrival,
                 departure_time: ^stop2_arrival
               },
               %VehicleEvent{
                 stop_id: "stop2",
                 arrival_time: ^stop2_arrival,
                 departure_time: nil
               }
             ] = Repo.all(from(ve in VehicleEvent, select: ve, order_by: [asc: ve.id]))
    end

    test "Don't log vehicle_event warnings for departures" do
      old_vehicles = %{
        "1" => %{@vehicle | stop_id: "stop1", current_status: :IN_TRANSIT_TO}
      }

      new_vehicles = %{
        "1" => %{@vehicle | stop_id: "stop1", current_status: :STOPPED_AT}
      }

      Comparator.compare(new_vehicles, old_vehicles)

      old_vehicles = %{
        "1" => %{@vehicle | stop_id: "stop1", current_status: :STOPPED_AT}
      }

      new_vehicles = %{
        "1" => %{@vehicle | stop_id: "stop2", current_status: :IN_TRANSIT_TO}
      }

      log =
        capture_log([level: :warn], fn ->
          Comparator.compare(new_vehicles, old_vehicles)
        end)

      refute log =~ "Created vehicle_event with no associated prediction"
    end
  end
end
