defmodule PredictionAnalyzer.VehiclePositions.VehicleTest do
  use ExUnit.Case, async: true

  alias PredictionAnalyzer.VehiclePositions.Vehicle

  @data %{
    "alert" => nil,
    "id" => "1540391481_B-5458FB84",
    "is_deleted" => false,
    "trip_update" => nil,
    "vehicle" => %{
      "congestion_level" => nil,
      "current_status" => "INCOMING_AT",
      "current_stop_sequence" => 50,
      "occupancy_status" => nil,
      "position" => %{
        "bearing" => 230.0,
        "latitude" => 42.38497,
        "longitude" => -71.01054,
        "odometer" => nil,
        "speed" => nil
      },
      "stop_id" => "70049",
      "timestamp" => 1_540_391_481,
      "trip" => %{
        "direction_id" => 0,
        "route_id" => "Blue",
        "schedule_relationship" => "SCHEDULED",
        "start_date" => "20181024",
        "start_time" => nil,
        "trip_id" => "38078941"
      },
      "vehicle" => %{
        "id" => "B-5458FB84",
        "label" => "0758",
        "license_plate" => nil
      }
    }
  }

  describe "from_json/1" do
    test "parses a correctly formed bit of JSON data" do
      assert {
               :ok,
               %Vehicle{
                 id: "B-5458FB84",
                 environment: "dev-green",
                 label: "0758",
                 is_deleted: false,
                 trip_id: "38078941",
                 route_id: "Blue",
                 direction_id: 0,
                 current_status: :INCOMING_AT,
                 stop_id: "70049"
               }
             } = Vehicle.from_json(@data, "dev-green")
    end

    test "translates to generic terminal stop IDs" do
      assert {
               :ok,
               %Vehicle{
                 id: "B-5458FB84",
                 environment: "dev-green",
                 label: "0758",
                 is_deleted: false,
                 trip_id: "38078941",
                 route_id: "Red",
                 direction_id: 0,
                 current_status: :INCOMING_AT,
                 stop_id: "70061"
               }
             } =
               Vehicle.from_json(
                 %{
                   @data
                   | "vehicle" => %{
                       @data["vehicle"]
                       | "stop_id" => "Alewife-01",
                         "trip" => %{@data["vehicle"]["trip"] | "route_id" => "Red"}
                     }
                 },
                 "dev-green"
               )
    end

    test "returns :error if JSON can't be made into vehicle" do
      bad_data = Map.put(@data, "vehicle", nil)
      assert :error = Vehicle.from_json(bad_data, "dev-green")
    end
  end
end
