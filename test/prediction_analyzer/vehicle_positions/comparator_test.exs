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
    log_level = Logger.level()

    on_exit(fn ->
      Logger.configure(level: log_level)
    end)

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
      Logger.configure(level: :info)

      assert Repo.one(from(ve in VehicleEvent, select: count(ve.id))) == 0

      old_vehicles = %{
        "1" => %{@vehicle | current_status: :INCOMING_AT}
      }

      new_vehicles = %{
        "1" => %{@vehicle | current_status: :STOPPED_AT}
      }

      log =
        capture_log([level: :info], fn ->
          Comparator.compare(new_vehicles, old_vehicles)
        end)

      assert log =~
               "Inserted vehicle arrival event: vehicle=1000 stop_id=stop1 environment=dev-green"

      arrival_time = @vehicle.timestamp

      vehicle_events = Repo.all(from(ve in VehicleEvent, select: ve))

      assert [
               %VehicleEvent{
                 vehicle_id: "1",
                 arrival_time: ^arrival_time,
                 departure_time: nil
               }
             ] = vehicle_events

      ve_id = List.first(vehicle_events).id

      departure_time = arrival_time + 30

      old_vehicles = new_vehicles

      new_vehicles = %{
        "1" => %{
          @vehicle
          | current_status: :IN_TRANSIT_TO,
            stop_id: "stop2",
            timestamp: departure_time
        }
      }

      log =
        capture_log([level: :info], fn ->
          Comparator.compare(new_vehicles, old_vehicles)
        end)

      assert log =~
               "Added departure to vehicle event for vehicle=1000 stop_id=stop1 environment=dev-green"

      assert [
               %VehicleEvent{
                 id: ^ve_id,
                 vehicle_id: "1",
                 arrival_time: ^arrival_time,
                 departure_time: ^departure_time
               }
             ] = Repo.all(from(ve in VehicleEvent, select: ve))
    end

    test "logs when a vehicle drops out of the feed" do
      Logger.configure(level: :info)

      old_vehicles = %{
        "1" => %{@vehicle | current_status: :INCOMING_AT},
        "2" => %Vehicle{
          id: "2",
          environment: "dev-green",
          label: "1001",
          is_deleted: false,
          trip_id: "trip2",
          route_id: "route1",
          direction_id: 0,
          current_status: :INCOMING_AT,
          stop_id: "stop1",
          timestamp: :os.system_time(:second)
        }
      }

      new_vehicles = %{}

      log =
        capture_log([level: :info], fn ->
          Comparator.compare(new_vehicles, old_vehicles)
        end)

      assert log =~
               "vehicles_dropped_from_feed environment=dev-green vehicle=1000 vehicle=1001"
    end

    test "logs a message for each environment when a vehicle drops out of the feed" do
      Logger.configure(level: :info)

      old_vehicles = %{
        "1" => %{@vehicle | current_status: :INCOMING_AT},
        "2" => %Vehicle{
          id: "2",
          environment: "prod",
          label: "1001",
          is_deleted: false,
          trip_id: "trip2",
          route_id: "route1",
          direction_id: 0,
          current_status: :INCOMING_AT,
          stop_id: "stop1",
          timestamp: :os.system_time(:second)
        }
      }

      new_vehicles = %{}

      log =
        capture_log([level: :info], fn ->
          Comparator.compare(new_vehicles, old_vehicles)
        end)

      assert log =~
               "vehicles_dropped_from_feed environment=dev-green vehicle=1000"

      assert log =~
               "vehicles_dropped_from_feed environment=prod vehicle=1001"
    end

    test "logs an error when there are multiple updates for a subway vehicle" do
      vehicle = %{@vehicle | route_id: "Red"}

      event1 = %PredictionAnalyzer.VehicleEvents.VehicleEvent{
        vehicle_id: "1",
        environment: "dev-green",
        vehicle_label: "1000",
        is_deleted: false,
        route_id: "Red",
        direction_id: 0,
        trip_id: "trip1",
        stop_id: "stop1",
        arrival_time: vehicle.timestamp,
        departure_time: nil
      }

      event2 = %PredictionAnalyzer.VehicleEvents.VehicleEvent{
        vehicle_id: "1",
        environment: "dev-green",
        vehicle_label: "1000",
        is_deleted: false,
        route_id: "Red",
        direction_id: 0,
        trip_id: "trip1",
        stop_id: "stop1",
        arrival_time: vehicle.timestamp,
        departure_time: nil
      }

      PredictionAnalyzer.Repo.insert(event1)
      PredictionAnalyzer.Repo.insert(event2)

      prediction = %{
        @prediction
        | trip_id: "trip1",
          route_id: "route1",
          vehicle_id: "1",
          arrival_time: :os.system_time(:second),
          stop_id: "stop1"
      }

      Repo.insert!(prediction)

      old_vehicles = %{
        "1" => %{vehicle | stop_id: "stop1", current_status: :STOPPED_AT}
      }

      new_vehicles = %{
        "1" => %{vehicle | stop_id: "stop2", current_status: :IN_TRANSIT_TO}
      }

      log =
        capture_log([level: :warn], fn ->
          Comparator.compare(new_vehicles, old_vehicles)
        end)

      assert log =~
               "One departure, multiple updates for vehicle=1000 route=Red trip_id=trip1 stop_id=stop1 environment=dev-green"
    end

    test "does not log an error when there are multiple updates for a commuter rail vehicle" do
      vehicle = %{@vehicle | route_id: "CR-Fitchburg"}

      event1 = %PredictionAnalyzer.VehicleEvents.VehicleEvent{
        vehicle_id: "1",
        environment: "dev-green",
        vehicle_label: "1000",
        is_deleted: false,
        route_id: "CR-Fitchburg",
        direction_id: 0,
        trip_id: "trip1",
        stop_id: "stop1",
        arrival_time: vehicle.timestamp,
        departure_time: nil
      }

      event2 = %PredictionAnalyzer.VehicleEvents.VehicleEvent{
        vehicle_id: "1",
        environment: "dev-green",
        vehicle_label: "1000",
        is_deleted: false,
        route_id: "CR-Fitchburg",
        direction_id: 0,
        trip_id: "trip1",
        stop_id: "stop1",
        arrival_time: vehicle.timestamp,
        departure_time: nil
      }

      PredictionAnalyzer.Repo.insert(event1)
      PredictionAnalyzer.Repo.insert(event2)

      prediction = %{
        @prediction
        | trip_id: "trip1",
          route_id: "route1",
          vehicle_id: "1",
          arrival_time: :os.system_time(:second),
          stop_id: "stop1"
      }

      Repo.insert!(prediction)

      old_vehicles = %{
        "1" => %{vehicle | stop_id: "stop1", current_status: :STOPPED_AT}
      }

      new_vehicles = %{
        "1" => %{vehicle | stop_id: "stop2", current_status: :IN_TRANSIT_TO}
      }

      log =
        capture_log([level: :warn], fn ->
          Comparator.compare(new_vehicles, old_vehicles)
        end)

      refute log =~ "One departure, multiple updates"
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

    test "records arrival of vehicle created in STOPPED_AT state" do
      Logger.configure(level: :info)

      old_vehicles = %{}

      new_vehicles = %{
        "1" => %{@vehicle | stop_id: "stop1", current_status: :STOPPED_AT}
      }

      newer_vehicles = %{
        "1" => %{@vehicle | stop_id: "stop2", current_status: :IN_TRANSIT}
      }

      log =
        capture_log([level: :info], fn ->
          Comparator.compare(new_vehicles, old_vehicles)
        end)

      assert log =~ "Tracking new vehicle vehicle=1000 stop_id=stop1 environment=dev-green"

      timestamp = @vehicle.timestamp

      assert [
               %VehicleEvent{
                 id: event_id,
                 vehicle_id: "1",
                 arrival_time: ^timestamp,
                 departure_time: nil
               }
             ] = Repo.all(from(ve in VehicleEvent, select: ve))

      Comparator.compare(newer_vehicles, new_vehicles)

      assert [
               %VehicleEvent{
                 id: ^event_id,
                 vehicle_id: "1",
                 arrival_time: ^timestamp,
                 departure_time: departure_time
               }
             ] = Repo.all(from(ve in VehicleEvent, select: ve))

      assert is_number(departure_time)
    end

    test "logs warning if fails to record creation of vehicle created in STOPPED_AT state" do
      old_vehicles = %{}

      new_vehicles = %{
        "1" => %{@vehicle | stop_id: nil, current_status: :STOPPED_AT}
      }

      log =
        capture_log([level: :warn], fn ->
          Comparator.compare(new_vehicles, old_vehicles)
        end)

      assert log =~ "Could not insert vehicle event"
      assert [] = Repo.all(from(ve in VehicleEvent, select: ve))
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
