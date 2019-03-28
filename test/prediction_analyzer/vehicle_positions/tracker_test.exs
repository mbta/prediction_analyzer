defmodule PredictionAnalyzer.VehiclePositions.TrackerTest do
  use ExUnit.Case, async: false

  alias PredictionAnalyzer.VehiclePositions.Tracker
  alias PredictionAnalyzer.VehiclePositions.TrackerTest.NotifyGet
  alias PredictionAnalyzer.VehiclePositions.TrackerTest.SubwayVehicle
  alias PredictionAnalyzer.VehiclePositions.TrackerTest.CommuterRailVehicle
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

  describe "handle_info :track_subway_vehicles" do
    test "updates the state with new vehicles" do
      state = %{
        http_fetcher: SubwayVehicle,
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

  describe "handle_info :track_commuter_rail_vehicles" do
    test "updates the state with new vehicles" do
      state = %{
        http_fetcher: CommuterRailVehicle,
        aws_vehicle_positions_url: "vehiclepositions",
        environment: "prod",
        subway_vehicles: %{},
        commuter_rail_vehicles: %{}
      }

      assert {
               :noreply,
               %{
                 commuter_rail_vehicles: %{
                   "1629" => %PredictionAnalyzer.VehiclePositions.Vehicle{
                     current_status: :IN_TRANSIT_TO,
                     direction_id: 1,
                     environment: "prod",
                     id: "1629",
                     is_deleted: false,
                     label: "1629",
                     route_id: "CR-Lowell",
                     stop_id: "North Station",
                     timestamp: 1_553_795_877,
                     trip_id: "CR-Weekday-Fall-18-324"
                   }
                 }
               }
             } = Tracker.handle_info(:track_commuter_rail_vehicles, state)
    end
  end

  defmodule NotifyGet do
    def get!(url) do
      send(:tracker_test_listener, {:get, url})
      %{body: Jason.encode!(%{"entity" => []})}
    end
  end

  defmodule SubwayVehicle do
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

  defmodule CommuterRailVehicle do
    def get!(_url, _, _) do
      data = %{
        "data" => [
          %{
            "attributes" => %{
              "bearing" => 137,
              "current_status" => "IN_TRANSIT_TO",
              "current_stop_sequence" => 8,
              "direction_id" => 1,
              "label" => "1629",
              "latitude" => 42.376739501953125,
              "longitude" => -71.07559204101563,
              "speed" => 13,
              "updated_at" => "2019-03-28T13:57:57-04:00"
            },
            "id" => "1629",
            "links" => %{
              "self" => "/vehicles/1629"
            },
            "relationships" => %{
              "route" => %{
                "data" => %{
                  "id" => "CR-Lowell",
                  "type" => "route"
                }
              },
              "stop" => %{
                "data" => %{
                  "id" => "North Station",
                  "type" => "stop"
                }
              },
              "trip" => %{
                "data" => %{
                  "id" => "CR-Weekday-Fall-18-324",
                  "type" => "trip"
                }
              }
            },
            "type" => "vehicle"
          }
        ]
      }

      %{body: Jason.encode!(data)}
    end
  end
end
