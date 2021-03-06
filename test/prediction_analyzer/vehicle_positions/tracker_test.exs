defmodule PredictionAnalyzer.VehiclePositions.TrackerTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog
  import Test.Support.Env

  alias PredictionAnalyzer.VehiclePositions.Tracker
  alias PredictionAnalyzer.VehiclePositions.TrackerTest.NotifyGet
  alias PredictionAnalyzer.VehiclePositions.TrackerTest.SubwayVehicle
  alias PredictionAnalyzer.VehiclePositions.Vehicle
  alias PredictionAnalyzer.VehiclePositions.TrackerTest.FailedHTTPFetcher
  alias PredictionAnalyzer.VehiclePositions.TrackerTest.NotModifiedHTTPFetcher
  alias PredictionAnalyzer.VehiclePositions.TrackerTest.ServerErrorHTTPFetcher
  alias PredictionAnalyzer.VehiclePositions.TrackerTest.MalformedSubwayVehicleHTTPFetcher
  alias PredictionAnalyzer.VehiclePositions.TrackerTest.SubwayVehicleNoStopIDHTTPFetcher

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

  test "Handles :ssl_closed without a warning" do
    {:ok, pid} = Tracker.start_link(environment: "dev-green", http_fetcher: NotifyGet)

    log =
      capture_log(fn ->
        send(pid, {:ssl_closed, :socket})
      end)

    refute log =~ "unknown_message"
  end

  describe "handle_info :track_subway_vehicles" do
    test "updates the state with new vehicles" do
      state = %{
        http_fetcher: SubwayVehicle,
        aws_vehicle_positions_url: "vehiclepositions",
        environment: "dev-green",
        subway_vehicles: %{},
        subway_last_modified: "Thu, 01 Jan 1970 00:00:00 GMT"
      }

      assert {
               :noreply,
               %{subway_vehicles: %{"R-5458F5AF" => %Vehicle{}}}
             } = Tracker.handle_info(:track_subway_vehicles, state)
    end

    test "handles 304s (Not Modified) gracefully" do
      old_level = Logger.level()
      Logger.configure(level: :info)
      on_exit(fn -> Logger.configure(level: old_level) end)

      state = %{
        http_fetcher: NotModifiedHTTPFetcher,
        aws_vehicle_positions_url: "vehiclepositions",
        environment: "prod",
        commuter_rail_vehicles: %{},
        subway_vehicles: %{something: "another"},
        subway_last_modified: "Mon, 22 Apr 2019 16:30:00 GMT"
      }

      log =
        capture_log([level: :info], fn ->
          assert Tracker.handle_info(:track_subway_vehicles, state) ==
                   {:noreply,
                    %{
                      http_fetcher: NotModifiedHTTPFetcher,
                      aws_vehicle_positions_url: "vehiclepositions",
                      environment: "prod",
                      subway_vehicles: %{something: "another"},
                      commuter_rail_vehicles: %{},
                      subway_last_modified: "Mon, 22 Apr 2019 16:30:00 GMT"
                    }}
        end)

      assert log =~
               "vehicle positions not modified since last request at Mon, 22 Apr 2019 16:30:00 GMT"
    end

    test "handles failures gracefully" do
      state = %{
        http_fetcher: FailedHTTPFetcher,
        aws_vehicle_positions_url: "vehiclepositions",
        environment: "prod",
        subway_vehicles: %{},
        commuter_rail_vehicles: %{},
        commuter_rail_last_modified: "Thu, 01 Jan 1970 00:00:00 GMT",
        subway_last_modified: "Thu, 01 Jan 1970 00:00:00 GMT"
      }

      log =
        capture_log([level: :warn], fn ->
          assert Tracker.handle_info(:track_subway_vehicles, state) ==
                   {:noreply,
                    %{
                      http_fetcher: FailedHTTPFetcher,
                      aws_vehicle_positions_url: "vehiclepositions",
                      environment: "prod",
                      subway_vehicles: %{},
                      commuter_rail_vehicles: %{},
                      commuter_rail_last_modified: "Thu, 01 Jan 1970 00:00:00 GMT",
                      subway_last_modified: "Thu, 01 Jan 1970 00:00:00 GMT"
                    }}
        end)

      assert log =~ "Could not download subway vehicles"
    end

    test "handles AWS S3 500 responses gracefully" do
      state = %{
        http_fetcher: ServerErrorHTTPFetcher,
        aws_vehicle_positions_url: "vehiclepositions",
        environment: "prod",
        subway_vehicles: %{},
        commuter_rail_vehicles: %{},
        commuter_rail_last_modified: "Thu, 01 Jan 1970 00:00:00 GMT",
        subway_last_modified: "Thu, 01 Jan 1970 00:00:00 GMT"
      }

      log =
        capture_log([level: :warn], fn ->
          assert Tracker.handle_info(:track_subway_vehicles, state) ==
                   {:noreply, state}
        end)

      assert log =~ "Could not download subway vehicles"
      assert log =~ "status_code=500"
    end

    test "logs failures to parse a given vehicle entity" do
      state = %{
        http_fetcher: MalformedSubwayVehicleHTTPFetcher,
        aws_vehicle_positions_url: "vehiclepositions",
        environment: "prod",
        subway_vehicles: %{},
        commuter_rail_vehicles: %{},
        commuter_rail_last_modified: "Thu, 01 Jan 1970 00:00:00 GMT",
        subway_last_modified: "Thu, 01 Jan 1970 00:00:00 GMT"
      }

      log =
        capture_log([level: :warn], fn ->
          assert Tracker.handle_info(:track_subway_vehicles, state) ==
                   {:noreply,
                    %{
                      http_fetcher: MalformedSubwayVehicleHTTPFetcher,
                      aws_vehicle_positions_url: "vehiclepositions",
                      environment: "prod",
                      subway_vehicles: %{},
                      commuter_rail_vehicles: %{},
                      commuter_rail_last_modified: "Thu, 01 Jan 1970 00:00:00 GMT",
                      subway_last_modified: "Thu, 01 Jan 1970 00:00:00 GMT"
                    }}
        end)

      assert log =~ "failed_to_parse_vehicle_entity"
    end

    test "ignores a vehicle without a stop_id and doesn't log warning" do
      state = %{
        http_fetcher: SubwayVehicleNoStopIDHTTPFetcher,
        aws_vehicle_positions_url: "vehiclepositions",
        environment: "prod",
        subway_vehicles: %{},
        commuter_rail_vehicles: %{},
        commuter_rail_last_modified: "Thu, 01 Jan 1970 00:00:00 GMT",
        subway_last_modified: "Thu, 01 Jan 1970 00:00:00 GMT"
      }

      log =
        capture_log([level: :warn], fn ->
          assert Tracker.handle_info(:track_subway_vehicles, state) ==
                   {:noreply,
                    %{
                      http_fetcher: SubwayVehicleNoStopIDHTTPFetcher,
                      aws_vehicle_positions_url: "vehiclepositions",
                      environment: "prod",
                      subway_vehicles: %{},
                      commuter_rail_vehicles: %{},
                      commuter_rail_last_modified: "Thu, 01 Jan 1970 00:00:00 GMT",
                      subway_last_modified: "Thu, 01 Jan 1970 00:00:00 GMT"
                    }}
        end)

      refute log =~ "failed_to_parse_vehicle_entity"
    end
  end

  describe "handle_info :track_commuter_rail_vehicles" do
    test "updates the state with new vehicles and a new last-modified time" do
      state = %{
        aws_vehicle_positions_url: "vehiclepositions",
        environment: "prod",
        subway_vehicles: %{},
        commuter_rail_vehicles: %{},
        commuter_rail_last_modified: "Thu, 01 Jan 1970 00:00:00 GMT"
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
                 },
                 commuter_rail_last_modified: "Sat, 10 Sep 1977 08:25:00 GMT"
               }
             } = Tracker.handle_info(:track_commuter_rail_vehicles, state)
    end

    test "handles 304s (Not Modified) gracefully" do
      old_level = Logger.level()
      Logger.configure(level: :info)
      on_exit(fn -> Logger.configure(level: old_level) end)
      reassign_env(:http_fetcher, NotModifiedHTTPFetcher)

      state = %{
        aws_vehicle_positions_url: "vehiclepositions",
        environment: "prod",
        subway_vehicles: %{},
        commuter_rail_vehicles: %{something: "another"},
        commuter_rail_last_modified: "Mon, 22 Apr 2019 16:30:00 GMT"
      }

      log =
        capture_log([level: :info], fn ->
          assert Tracker.handle_info(:track_commuter_rail_vehicles, state) ==
                   {:noreply,
                    %{
                      aws_vehicle_positions_url: "vehiclepositions",
                      environment: "prod",
                      subway_vehicles: %{},
                      commuter_rail_vehicles: %{something: "another"},
                      commuter_rail_last_modified: "Mon, 22 Apr 2019 16:30:00 GMT"
                    }}
        end)

      assert log =~
               "vehicle positions not modified since last request at Mon, 22 Apr 2019 16:30:00 GMT"
    end

    test "fails gracefully when API returns error" do
      reassign_env(:http_fetcher, FailedHTTPFetcher)

      state = %{
        aws_vehicle_positions_url: "vehiclepositions",
        environment: "prod",
        subway_vehicles: %{},
        commuter_rail_vehicles: %{},
        commuter_rail_last_modified: "Thu, 01 Jan 1970 00:00:00 GMT"
      }

      log =
        capture_log([level: :warn], fn ->
          assert Tracker.handle_info(:track_commuter_rail_vehicles, state) ==
                   {:noreply,
                    %{
                      aws_vehicle_positions_url: "vehiclepositions",
                      environment: "prod",
                      subway_vehicles: %{},
                      commuter_rail_vehicles: %{},
                      commuter_rail_last_modified: "Thu, 01 Jan 1970 00:00:00 GMT"
                    }}
        end)

      assert log =~ "Could not download commuter rail vehicles"
    end

    test "does nothing on dev-green" do
      state = %{
        aws_vehicle_positions_url: "vehiclepositions",
        environment: "dev-green",
        subway_vehicles: %{},
        commuter_rail_vehicles: %{}
      }

      assert Tracker.handle_info(:track_commuter_rail_vehicles, state) == {:noreply, state}
    end
  end

  defmodule NotifyGet do
    def get(url, _headers) do
      send(:tracker_test_listener, {:get, url})
      {:ok, %{status_code: 200, body: Jason.encode!(%{"entity" => []}), headers: []}}
    end

    def get(url, _, _) do
      send(:tracker_test_listener, {:get, url})
      {:ok, %{status_code: 200, body: Jason.encode!(%{"entity" => []}), headers: []}}
    end
  end

  defmodule SubwayVehicle do
    def get(_url, _headers) do
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

      {:ok, %{status_code: 200, body: Jason.encode!(data), headers: []}}
    end
  end

  defmodule FailedHTTPFetcher do
    def get(_, _) do
      {:error, "something"}
    end

    def get(_, _, _) do
      {:error, "something"}
    end
  end

  defmodule NotModifiedHTTPFetcher do
    def get(_, _) do
      {:ok, %{status_code: 304}}
    end

    def get(_, _, _) do
      %{status_code: 304}
    end
  end

  defmodule ServerErrorHTTPFetcher do
    def get(_, _) do
      {:ok, %{status_code: 500}}
    end

    def get(_, _, _) do
      %{status_code: 500}
    end
  end

  defmodule MalformedSubwayVehicleHTTPFetcher do
    def get(_url, _headers) do
      data = %{
        "entity" => [
          %{
            "foo" => "bar"
          }
        ]
      }

      {:ok, %{status_code: 200, body: Jason.encode!(data), headers: []}}
    end
  end

  defmodule SubwayVehicleNoStopIDHTTPFetcher do
    def get(url, headers) do
      {:ok, %{body: body} = response} = SubwayVehicle.get(url, headers)

      new_body =
        body
        |> Jason.decode!()
        |> put_in(["entity", Access.all(), "vehicle", "stop_id"], nil)

      {:ok, %{response | body: Jason.encode!(new_body)}}
    end
  end
end
