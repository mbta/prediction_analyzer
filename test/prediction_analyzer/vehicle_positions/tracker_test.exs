defmodule PredictionAnalyzer.VehiclePositions.TrackerTest do
  use ExUnit.Case, async: false

  alias PredictionAnalyzer.VehiclePositions.Tracker
  alias PredictionAnalyzer.VehiclePositions.TrackerTest.NotifyGet
  alias PredictionAnalyzer.VehiclePositions.TrackerTest.OneVehicle
  alias PredictionAnalyzer.VehiclePositions.Vehicle

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(PredictionAnalyzer.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(PredictionAnalyzer.Repo, {:shared, self()})
  end

  test "Loops every second and downloads the vehicles" do
    Process.register(self(), :tracker_test_listener)
    opts = [environment: "dev-green", http_fetcher: NotifyGet, aws_vehicle_positions_url: "foo"]

    {:ok, _pid} = Tracker.start_link(opts)
    refute_received({:get, "foo"})

    :timer.sleep(1_200)
    assert_received({:get, "foo"})

    :timer.sleep(700)
    refute_received({:get, "foo"})

    :timer.sleep(200)
    assert_received({:get, "foo"})
  end

  describe "handle_info :track_vehicles" do
    test "updates the state with new vehicles" do
      state = %{
        http_fetcher: OneVehicle,
        aws_vehicle_positions_url: "vehiclepositions",
        environment: "dev-green",
        subway_vehicles: %{},
        commuter_rail_vehicles: %{}
      }

      assert {
               :noreply,
               %{subway_vehicles: %{"R-5458F5AF" => %Vehicle{}}}
             } = Tracker.handle_info(:track_subway_vehicles, state)
    end
  end

  defmodule NotifyGet do
    def get!(url) do
      send(:tracker_test_listener, {:get, url})
      %{body: Jason.encode!(%{"entity" => []})}
    end
  end

  defmodule OneVehicle do
    def get!(_url) do
      data = %{
        "entity" => [
          %{
            "alert" => nil,
            "id" => "1540242318_R-5458F5AF",
            "is_deleted" => false,
            "trip_update" => nil,
            "vehicle" => %{
              "congestion_level" => nil,
              "current_status" => "IN_TRANSIT_TO",
              "current_stop_sequence" => 180,
              "occupancy_status" => nil,
              "position" => %{
                "bearing" => 170,
                "latitude" => 42.3185,
                "longitude" => -71.05212,
                "odometer" => nil,
                "speed" => nil
              },
              "stop_id" => "70097",
              "timestamp" => 1_540_242_318,
              "trip" => %{
                "direction_id" => 0,
                "route_id" => "Red",
                "schedule_relationship" => "SCHEDULED",
                "start_date" => "20181022",
                "start_time" => nil,
                "trip_id" => "38066323-21 =>00-KL"
              },
              "vehicle" => %{
                "id" => "R-5458F5AF",
                "label" => "1800",
                "license_plate" => nil
              }
            }
          }
        ]
      }

      %{body: Jason.encode!(data)}
    end
  end
end
