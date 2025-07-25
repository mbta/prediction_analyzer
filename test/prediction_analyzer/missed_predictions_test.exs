defmodule PredictionAnalyzer.MissedPredictionsTest do
  use PredictionAnalyzer.DataCase

  alias PredictionAnalyzer.Repo
  alias PredictionAnalyzer.VehicleEvents.VehicleEvent
  alias PredictionAnalyzer.Predictions.Prediction
  alias PredictionAnalyzer.MissedPredictions
  alias PredictionAnalyzer.Utilities

  defp unix(date, time) do
    DateTime.new!(date, time, "America/New_York") |> DateTime.to_unix()
  end

  defp insert_vehicle_events(events) do
    cnt = Enum.count(events)
    {^cnt, _} = Repo.insert_all(VehicleEvent, events)
  end

  defp insert_predictions(predictions) do
    cnt = Enum.count(predictions)
    {^cnt, _} = Repo.insert_all(Prediction, predictions)
  end

  setup_all do
    {:ok, _pid} =
      start_supervised(
        {PredictionAnalyzer.StopNameFetcher, name: PredictionAnalyzer.StopNameFetcher}
      )

    :ok
  end

  describe "unpredicted_departures_summary/2" do
    test "date filter's by service dates rather than calendar dates" do
      insert_vehicle_events([
        # Just after start of service 7/1
        %{
          id: 1,
          environment: "prod",
          departure_time: unix(~D[2019-07-01], ~T[04:01:00]),
          stop_id: "70036",
          route_id: "route1",
          trip_id: "trip1",
          is_deleted: false
        },
        # Just before end of 7/1 service
        %{
          id: 2,
          environment: "prod",
          departure_time: unix(~D[2019-07-02], ~T[01:59:00]),
          stop_id: "70036",
          route_id: "route1",
          trip_id: "trip1",
          is_deleted: false
        },
        # Just before start of service 7/5
        %{
          id: 3,
          environment: "prod",
          departure_time: unix(~D[2019-07-05], ~T[03:59:00]),
          stop_id: "70036",
          route_id: "route1",
          trip_id: "trip1",
          is_deleted: false
        },
        # Just after end of 7/5 service
        %{
          id: 4,
          environment: "prod",
          departure_time: unix(~D[2019-07-06], ~T[02:01:00]),
          stop_id: "70036",
          route_id: "route1",
          trip_id: "trip1",
          is_deleted: false
        }
      ])

      assert [{"route1", 2, 2, 100.0}] =
               MissedPredictions.unpredicted_departures_summary(~D[2019-07-01], "prod")

      assert [] = MissedPredictions.unpredicted_departures_summary(~D[2019-07-05], "prod")
    end

    test "vehicle events without prediction are unpredicted" do
      insert_vehicle_events([
        %{
          id: 1,
          environment: "prod",
          departure_time: unix(~D[2019-07-01], ~T[10:00:00]),
          stop_id: "70036",
          route_id: "route1",
          trip_id: "trip1",
          is_deleted: false
        }
      ])

      assert [{"route1", 1, 1, 100.0}] =
               MissedPredictions.unpredicted_departures_summary(~D[2019-07-01], "prod")
    end

    test "vehicle events with predictions after departure are unpredicted" do
      insert_vehicle_events([
        %{
          id: 1,
          environment: "prod",
          departure_time: unix(~D[2019-07-01], ~T[10:00:00]),
          stop_id: "70036",
          route_id: "route1",
          trip_id: "trip1",
          is_deleted: false
        }
      ])

      insert_predictions([
        %{
          id: 1,
          vehicle_event_id: 1,
          route_id: "route1",
          trip_id: "trip1",
          stop_id: "70036",
          file_timestamp: unix(~D[2019-07-01], ~T[10:01:00]),
          departure_time: unix(~D[2019-07-01], ~T[10:00:00])
        }
      ])

      assert [{"route1", 1, 1, 100.0}] =
               MissedPredictions.unpredicted_departures_summary(~D[2019-07-01], "prod")
    end

    test "deleted vehicle events are not unpredicted" do
      insert_vehicle_events([
        %{
          id: 1,
          environment: "prod",
          departure_time: unix(~D[2019-07-01], ~T[10:00:00]),
          stop_id: "70036",
          route_id: "route1",
          trip_id: "trip1",
          is_deleted: true
        }
      ])

      assert [] = MissedPredictions.unpredicted_departures_summary(~D[2019-07-01], "prod")
    end

    test "vehicle events without departure_time are not unpredicted" do
      insert_vehicle_events([
        %{
          id: 1,
          environment: "prod",
          departure_time: nil,
          stop_id: "70036",
          route_id: "route1",
          trip_id: "trip1",
          is_deleted: false
        }
      ])

      assert [] = MissedPredictions.unpredicted_departures_summary(~D[2019-07-01], "prod")
    end

    test "vehicle events without a trip are not unpredicted" do
      insert_vehicle_events([
        %{
          id: 1,
          environment: "prod",
          departure_time: unix(~D[2019-07-01], ~T[10:00:00]),
          stop_id: "70036",
          route_id: "route1",
          trip_id: nil,
          is_deleted: false
        }
      ])

      assert [] = MissedPredictions.unpredicted_departures_summary(~D[2019-07-01], "prod")
    end

    test "vehicle events at non-terminals are not unpredicted" do
      insert_vehicle_events([
        %{
          id: 1,
          environment: "prod",
          departure_time: unix(~D[2019-07-01], ~T[10:00:00]),
          stop_id: "non-terminal",
          route_id: "route1",
          trip_id: "trip1",
          is_deleted: false
        }
      ])

      assert [] = MissedPredictions.unpredicted_departures_summary(~D[2019-07-01], "prod")
    end

    test "vehicle events with predictions are not unpredicted" do
      insert_vehicle_events([
        %{
          id: 1,
          environment: "prod",
          departure_time: unix(~D[2019-07-01], ~T[10:00:00]),
          stop_id: "70036",
          route_id: "route1",
          trip_id: "trip1",
          is_deleted: false
        }
      ])

      insert_predictions([
        %{
          id: 1,
          vehicle_event_id: 1,
          route_id: "route1",
          trip_id: "trip1",
          stop_id: "70036",
          file_timestamp: unix(~D[2019-07-01], ~T[09:59:00]),
          departure_time: unix(~D[2019-07-01], ~T[10:00:00])
        }
      ])

      assert [{"route1", 1, 0, +0.0}] =
               MissedPredictions.unpredicted_departures_summary(~D[2019-07-01], "prod")
    end

    test "routes are returned in drop-down order" do
      insert_vehicle_events([
        %{
          id: 1,
          environment: "prod",
          departure_time: unix(~D[2019-07-01], ~T[10:00:00]),
          stop_id: "70036",
          route_id: "Red",
          trip_id: "trip1",
          is_deleted: false
        },
        %{
          id: 2,
          environment: "prod",
          departure_time: unix(~D[2019-07-01], ~T[10:00:00]),
          stop_id: "70036",
          route_id: "Green-E",
          trip_id: "trip2",
          is_deleted: false
        },
        %{
          id: 3,
          environment: "prod",
          departure_time: unix(~D[2019-07-01], ~T[10:00:00]),
          stop_id: "70036",
          route_id: "Blue",
          trip_id: "trip3",
          is_deleted: false
        },
        %{
          id: 4,
          environment: "prod",
          departure_time: unix(~D[2019-07-01], ~T[10:00:00]),
          stop_id: "70036",
          route_id: "Green-D",
          trip_id: "trip4",
          is_deleted: false
        },
        %{
          id: 5,
          environment: "prod",
          departure_time: unix(~D[2019-07-01], ~T[10:00:00]),
          stop_id: "70036",
          route_id: "Green-C",
          trip_id: "trip5",
          is_deleted: false
        },
        %{
          id: 6,
          environment: "prod",
          departure_time: unix(~D[2019-07-01], ~T[10:00:00]),
          stop_id: "70036",
          route_id: "Green-B",
          trip_id: "trip6",
          is_deleted: false
        },
        %{
          id: 7,
          environment: "prod",
          departure_time: unix(~D[2019-07-01], ~T[10:00:00]),
          stop_id: "70036",
          route_id: "Orange",
          trip_id: "trip7",
          is_deleted: false
        },
        %{
          id: 8,
          environment: "prod",
          departure_time: unix(~D[2019-07-01], ~T[10:00:00]),
          stop_id: "70036",
          route_id: "Mattapan",
          trip_id: "trip8",
          is_deleted: false
        }
      ])

      routes =
        MissedPredictions.unpredicted_departures_summary(~D[2019-07-01], "prod")
        |> Enum.map(&elem(&1, 0))

      assert Utilities.routes_for_mode(:subway) == routes
    end
  end

  describe "unpredicted_departures_for_route/3" do
    test "includes stop names as well as IDs" do
      insert_vehicle_events([
        %{
          id: 1,
          environment: "prod",
          departure_time: unix(~D[2019-07-01], ~T[10:00:00]),
          stop_id: "70197",
          route_id: "route1",
          trip_id: "trip1",
          is_deleted: false
        }
      ])

      assert [{"70197", "Park Street - Green Line - (C) Cleveland Circle", 1, 1, 100.0}] =
               MissedPredictions.unpredicted_departures_for_route(
                 ~D[2019-07-01],
                 "prod",
                 "route1"
               )
    end

    test "it does not include stop_ids not in terminal stops" do
      insert_vehicle_events([
        %{
          id: 1,
          environment: "prod",
          departure_time: unix(~D[2019-07-01], ~T[10:00:00]),
          stop_id: "non-terminal",
          route_id: "route1",
          trip_id: "trip1",
          is_deleted: false
        },
        %{
          id: 2,
          environment: "prod",
          departure_time: unix(~D[2019-07-01], ~T[10:00:00]),
          stop_id: "70036",
          route_id: "route1",
          trip_id: "trip2",
          is_deleted: false
        }
      ])

      included_stops =
        MissedPredictions.unpredicted_departures_for_route(~D[2019-07-01], "prod", "route1")
        |> Enum.map(&elem(&1, 0))

      assert ["70036"] = included_stops
    end

    test "vehicle events with predictions after departure are unpredicted" do
      insert_vehicle_events([
        %{
          id: 1,
          environment: "prod",
          departure_time: unix(~D[2019-07-01], ~T[10:00:00]),
          stop_id: "70197",
          route_id: "route1",
          trip_id: "trip1",
          is_deleted: false
        }
      ])

      insert_predictions([
        %{
          id: 1,
          vehicle_event_id: 1,
          route_id: "route1",
          trip_id: "trip1",
          stop_id: "70197",
          file_timestamp: unix(~D[2019-07-01], ~T[10:01:00]),
          departure_time: unix(~D[2019-07-01], ~T[10:00:00])
        }
      ])

      assert [{"70197", "Park Street - Green Line - (C) Cleveland Circle", 1, 1, 100.0}] =
               MissedPredictions.unpredicted_departures_for_route(
                 ~D[2019-07-01],
                 "prod",
                 "route1"
               )
    end

    test "vehicle events with and without predictions are summarized correctly" do
      insert_vehicle_events([
        %{
          id: 1,
          environment: "prod",
          departure_time: unix(~D[2019-07-01], ~T[10:00:00]),
          stop_id: "70197",
          route_id: "route1",
          trip_id: "trip1",
          is_deleted: false
        },
        %{
          id: 2,
          environment: "prod",
          departure_time: unix(~D[2019-07-01], ~T[10:05:00]),
          stop_id: "70197",
          route_id: "route1",
          trip_id: "trip1",
          is_deleted: false
        },
        %{
          id: 3,
          environment: "prod",
          departure_time: unix(~D[2019-07-01], ~T[10:01:00]),
          stop_id: "70197",
          route_id: "route1",
          trip_id: "trip1",
          is_deleted: false
        },
        %{
          id: 4,
          environment: "prod",
          departure_time: unix(~D[2019-07-01], ~T[11:02:00]),
          stop_id: "70197",
          route_id: "route1",
          trip_id: "trip2",
          is_deleted: false
        }
      ])

      insert_predictions([
        %{
          id: 1,
          vehicle_event_id: 1,
          route_id: "route1",
          trip_id: "trip1",
          stop_id: "70197",
          file_timestamp: unix(~D[2019-07-01], ~T[09:55:00]),
          departure_time: unix(~D[2019-07-01], ~T[10:00:00])
        }
      ])

      assert [
               {"70197", "Park Street - Green Line - (C) Cleveland Circle", 4, 3, 75.0}
             ] =
               MissedPredictions.unpredicted_departures_for_route(
                 ~D[2019-07-01],
                 "prod",
                 "route1"
               )
    end
  end

  describe "upredicted_departues_for_route_stop" do
    test "returns unpredicted departures" do
      insert_vehicle_events([
        %{
          id: 1,
          environment: "prod",
          departure_time: unix(~D[2019-07-01], ~T[10:00:00]),
          stop_id: "70197",
          route_id: "route1",
          trip_id: "trip1",
          vehicle_id: "vehicle1",
          is_deleted: false
        },
        %{
          id: 2,
          environment: "prod",
          departure_time: unix(~D[2019-07-01], ~T[10:02:00]),
          stop_id: "70197",
          route_id: "route1",
          trip_id: "trip1",
          vehicle_id: "vehicle1",
          is_deleted: false
        },
        %{
          id: 3,
          environment: "prod",
          departure_time: unix(~D[2019-07-01], ~T[10:04:00]),
          stop_id: "70197",
          route_id: "route1",
          trip_id: "trip2",
          vehicle_id: "vehicle2",
          is_deleted: false
        }
      ])

      assert [
               {"vehicle1", "trip1", "2019-07-01 10:00:00 EDT"},
               {"vehicle1", "trip1", "2019-07-01 10:02:00 EDT"},
               {"vehicle2", "trip2", "2019-07-01 10:04:00 EDT"}
             ] =
               MissedPredictions.unpredicted_departures_for_route_stop(
                 ~D[2019-07-01],
                 "prod",
                 "route1",
                 "70197"
               )
    end

    test "does not include predicted departures" do
      insert_vehicle_events([
        %{
          id: 1,
          environment: "prod",
          departure_time: unix(~D[2019-07-01], ~T[10:00:00]),
          stop_id: "70197",
          route_id: "route1",
          trip_id: "trip1",
          vehicle_id: "vehicle1",
          is_deleted: false
        },
        %{
          id: 2,
          environment: "prod",
          departure_time: unix(~D[2019-07-01], ~T[10:02:00]),
          stop_id: "70197",
          route_id: "route1",
          trip_id: "trip1",
          vehicle_id: "vehicle1",
          is_deleted: false
        }
      ])

      insert_predictions([
        %{
          id: 1,
          vehicle_event_id: 1,
          route_id: "route1",
          trip_id: "trip1",
          stop_id: "70197",
          file_timestamp: unix(~D[2019-07-01], ~T[09:55:00]),
          departure_time: unix(~D[2019-07-01], ~T[10:00:00])
        },
        %{
          id: 2,
          vehicle_event_id: 2,
          route_id: "route1",
          trip_id: "trip1",
          stop_id: "70197",
          file_timestamp: unix(~D[2019-07-01], ~T[09:57:00]),
          departure_time: unix(~D[2019-07-01], ~T[10:02:00])
        }
      ])

      assert [] =
               MissedPredictions.unpredicted_departures_for_route_stop(
                 ~D[2019-07-01],
                 "prod",
                 "route1",
                 "70197"
               )
    end
  end

  describe "missed_departures_summary/2" do
    test "date filters by service date rather than calendar date" do
      insert_predictions([
        # Just after start of service 7/1
        %{
          id: 1,
          environment: "prod",
          departure_time: unix(~D[2019-07-01], ~T[04:01:00]),
          file_timestamp: unix(~D[2019-07-01], ~T[04:01:00]),
          stop_id: "70036",
          route_id: "route1",
          trip_id: "trip1"
        },
        # Just before end of 7/1 service
        %{
          id: 2,
          environment: "prod",
          departure_time: unix(~D[2019-07-02], ~T[01:59:00]),
          file_timestamp: unix(~D[2019-07-02], ~T[01:59:00]),
          stop_id: "70036",
          route_id: "route1",
          trip_id: "trip2"
        },
        # Just before start of service 7/5
        %{
          id: 3,
          environment: "prod",
          departure_time: unix(~D[2019-07-05], ~T[03:59:00]),
          file_timestamp: unix(~D[2019-07-05], ~T[03:59:00]),
          stop_id: "70036",
          route_id: "route1",
          trip_id: "trip3"
        },
        # Just after end of 7/5 service
        %{
          id: 4,
          environment: "prod",
          departure_time: unix(~D[2019-07-06], ~T[02:01:00]),
          file_timestamp: unix(~D[2019-07-06], ~T[02:01:00]),
          stop_id: "70036",
          route_id: "route1",
          trip_id: "trip4"
        }
      ])

      assert [{"route1", 2, 2, 100.0}] =
               MissedPredictions.missed_departures_summary(~D[2019-07-01], "prod")

      assert [] = MissedPredictions.missed_departures_summary(~D[2019-07-05], "prod")
    end

    test "aggregates multiple predictions for the same trip into a single record" do
      insert_predictions([
        %{
          id: 1,
          environment: "prod",
          departure_time: unix(~D[2019-07-01], ~T[10:00:00]),
          file_timestamp: unix(~D[2019-07-01], ~T[10:00:00]),
          stop_id: "70036",
          route_id: "route1",
          trip_id: "trip1"
        },
        %{
          id: 2,
          environment: "prod",
          departure_time: unix(~D[2019-07-01], ~T[10:01:00]),
          file_timestamp: unix(~D[2019-07-01], ~T[10:01:00]),
          stop_id: "70036",
          route_id: "route1",
          trip_id: "trip1"
        }
      ])

      assert [{"route1", 1, 1, 100.0}] =
               MissedPredictions.missed_departures_summary(~D[2019-07-01], "prod")
    end

    test "predictions without a departure time are not considered" do
      insert_predictions([
        %{
          id: 1,
          environment: "prod",
          departure_time: nil,
          file_timestamp: unix(~D[2019-07-01], ~T[10:00:00]),
          stop_id: "70036",
          route_id: "route1",
          trip_id: "trip1"
        }
      ])

      assert [] = MissedPredictions.missed_departures_summary(~D[2019-07-01], "prod")
    end

    test "predictions for non-terminals are not considered" do
      insert_predictions([
        %{
          id: 1,
          environment: "prod",
          departure_time: unix(~D[2019-07-01], ~T[10:00:00]),
          file_timestamp: unix(~D[2019-07-01], ~T[10:00:00]),
          stop_id: "non-terminal",
          route_id: "route1",
          trip_id: "trip1"
        }
      ])

      assert [] = MissedPredictions.missed_departures_summary(~D[2019-07-01], "prod")
    end

    test "predictions with a vehicle event are not unrealized" do
      insert_vehicle_events([
        %{
          id: 1,
          environment: "prod",
          departure_time: unix(~D[2019-07-01], ~T[10:00:00]),
          stop_id: "70036",
          route_id: "route1",
          trip_id: "trip1",
          is_deleted: false
        }
      ])

      insert_predictions([
        %{
          id: 1,
          environment: "prod",
          departure_time: unix(~D[2019-07-01], ~T[10:00:00]),
          file_timestamp: unix(~D[2019-07-01], ~T[10:00:00]),
          stop_id: "70036",
          route_id: "route1",
          trip_id: "trip1",
          vehicle_event_id: 1
        }
      ])

      assert [{"route1", 1, 0, +0.0}] =
               MissedPredictions.missed_departures_summary(~D[2019-07-01], "prod")
    end

    test "results are sorted in dropdown order" do
      insert_predictions([
        %{
          id: 1,
          environment: "prod",
          departure_time: unix(~D[2019-07-01], ~T[10:00:00]),
          file_timestamp: unix(~D[2019-07-01], ~T[10:00:00]),
          stop_id: "70036",
          route_id: "Red",
          trip_id: "trip1"
        },
        %{
          id: 2,
          environment: "prod",
          departure_time: unix(~D[2019-07-01], ~T[10:00:00]),
          file_timestamp: unix(~D[2019-07-01], ~T[10:00:00]),
          stop_id: "70036",
          route_id: "Green-E",
          trip_id: "trip2"
        },
        %{
          id: 3,
          environment: "prod",
          departure_time: unix(~D[2019-07-01], ~T[10:00:00]),
          file_timestamp: unix(~D[2019-07-01], ~T[10:00:00]),
          stop_id: "70036",
          route_id: "Blue",
          trip_id: "trip3"
        },
        %{
          id: 4,
          environment: "prod",
          departure_time: unix(~D[2019-07-01], ~T[10:00:00]),
          file_timestamp: unix(~D[2019-07-01], ~T[10:00:00]),
          stop_id: "70036",
          route_id: "Green-D",
          trip_id: "trip4"
        },
        %{
          id: 5,
          environment: "prod",
          departure_time: unix(~D[2019-07-01], ~T[10:00:00]),
          file_timestamp: unix(~D[2019-07-01], ~T[10:00:00]),
          stop_id: "70036",
          route_id: "Green-C",
          trip_id: "trip5"
        },
        %{
          id: 6,
          environment: "prod",
          departure_time: unix(~D[2019-07-01], ~T[10:00:00]),
          file_timestamp: unix(~D[2019-07-01], ~T[10:00:00]),
          stop_id: "70036",
          route_id: "Green-B",
          trip_id: "trip6"
        },
        %{
          id: 7,
          environment: "prod",
          departure_time: unix(~D[2019-07-01], ~T[10:00:00]),
          file_timestamp: unix(~D[2019-07-01], ~T[10:00:00]),
          stop_id: "70036",
          route_id: "Orange",
          trip_id: "trip7"
        },
        %{
          id: 8,
          environment: "prod",
          departure_time: unix(~D[2019-07-01], ~T[10:00:00]),
          file_timestamp: unix(~D[2019-07-01], ~T[10:00:00]),
          stop_id: "70036",
          route_id: "Mattapan",
          trip_id: "trip8"
        }
      ])

      routes =
        MissedPredictions.missed_departures_summary(~D[2019-07-01], "prod")
        |> Enum.map(&elem(&1, 0))

      assert Utilities.routes_for_mode(:subway) == routes
    end
  end

  describe "missed_departures_for_route/3" do
    test "includes stop names as well as IDs" do
      insert_predictions([
        %{
          id: 1,
          environment: "prod",
          departure_time: unix(~D[2019-07-01], ~T[10:00:00]),
          file_timestamp: unix(~D[2019-07-01], ~T[10:00:00]),
          stop_id: "70197",
          route_id: "route1",
          trip_id: "trip1"
        }
      ])

      assert [{"70197", "Park Street - Green Line - (C) Cleveland Circle", 1, 1, 100.0}] =
               MissedPredictions.missed_departures_for_route(~D[2019-07-01], "prod", "route1")
    end

    test "it does not include stop_ids not in terminal stops" do
      insert_predictions([
        %{
          id: 1,
          environment: "prod",
          departure_time: unix(~D[2019-07-01], ~T[10:00:00]),
          file_timestamp: unix(~D[2019-07-01], ~T[10:00:00]),
          stop_id: "non-terminal",
          route_id: "route1",
          trip_id: "trip1"
        },
        %{
          id: 2,
          environment: "prod",
          departure_time: unix(~D[2019-07-01], ~T[10:00:00]),
          file_timestamp: unix(~D[2019-07-01], ~T[10:00:00]),
          stop_id: "70036",
          route_id: "route1",
          trip_id: "trip2"
        }
      ])

      included_stops =
        MissedPredictions.missed_departures_for_route(~D[2019-07-01], "prod", "route1")
        |> Enum.map(&elem(&1, 0))

      assert ["70036"] = included_stops
    end

    test "predicted and unpredicted departures are summarized correctly" do
      insert_vehicle_events([
        %{
          id: 1,
          environment: "prod",
          departure_time: unix(~D[2019-07-01], ~T[10:00:00]),
          stop_id: "70036",
          route_id: "route1",
          trip_id: "trip1",
          is_deleted: false
        }
      ])

      insert_predictions([
        %{
          id: 1,
          vehicle_event_id: 1,
          route_id: "route1",
          trip_id: "trip1",
          stop_id: "70036",
          file_timestamp: unix(~D[2019-07-01], ~T[10:01:00]),
          departure_time: unix(~D[2019-07-01], ~T[10:00:00])
        },
        %{
          id: 2,
          environment: "prod",
          departure_time: unix(~D[2019-07-01], ~T[10:02:00]),
          file_timestamp: unix(~D[2019-07-01], ~T[10:02:00]),
          stop_id: "70036",
          route_id: "route1",
          trip_id: "trip2"
        }
      ])

      assert [{"70036", "70036", 2, 1, 50.0}] =
               MissedPredictions.missed_departures_for_route(~D[2019-07-01], "prod", "route1")
    end
  end

  describe "missed_departures_for_route_stop/4" do
    test "returns missed departures" do
      insert_predictions([
        %{
          id: 1,
          environment: "prod",
          departure_time: unix(~D[2019-07-01], ~T[10:00:00]),
          file_timestamp: unix(~D[2019-07-01], ~T[10:00:00]),
          stop_id: "70197",
          route_id: "route1",
          trip_id: "trip1",
          vehicle_id: "vehicle1"
        }
      ])

      assert [
               {"vehicle1", "trip1", "2019-07-01 10:00:00 EDT", "2019-07-01 10:00:00 EDT",
                "2019-07-01 10:00:00 EDT", "2019-07-01 10:00:00 EDT", 1}
             ] =
               MissedPredictions.missed_departures_for_route_stop(
                 ~D[2019-07-01],
                 "prod",
                 "route1",
                 "70197"
               )
    end

    test "missed departures are summarized by vehicle, trip" do
      insert_predictions([
        %{
          id: 1,
          environment: "prod",
          departure_time: unix(~D[2019-07-01], ~T[10:00:00]),
          file_timestamp: unix(~D[2019-07-01], ~T[10:00:00]),
          stop_id: "70197",
          route_id: "route1",
          trip_id: "trip1",
          vehicle_id: "vehicle1"
        },
        %{
          id: 2,
          environment: "prod",
          departure_time: unix(~D[2019-07-01], ~T[10:05:00]),
          file_timestamp: unix(~D[2019-07-01], ~T[10:02:00]),
          stop_id: "70197",
          route_id: "route1",
          trip_id: "trip1",
          vehicle_id: "vehicle1"
        },
        %{
          id: 3,
          environment: "prod",
          departure_time: unix(~D[2019-07-01], ~T[10:01:00]),
          file_timestamp: unix(~D[2019-07-01], ~T[10:01:00]),
          stop_id: "70197",
          route_id: "route1",
          trip_id: "trip1",
          vehicle_id: "vehicle2"
        },
        %{
          id: 4,
          environment: "prod",
          departure_time: unix(~D[2019-07-01], ~T[11:02:00]),
          file_timestamp: unix(~D[2019-07-01], ~T[11:02:00]),
          stop_id: "70197",
          route_id: "route1",
          trip_id: "trip2",
          vehicle_id: "vehicle1"
        }
      ])

      assert [
               # vehicle1 was predicted for trip1 whith file times of 10:00 and 10:02 and departure times of 10:00 and 10:05
               {"vehicle1", "trip1", "2019-07-01 10:00:00 EDT", "2019-07-01 10:05:00 EDT",
                "2019-07-01 10:00:00 EDT", "2019-07-01 10:02:00 EDT", 2},
               # trip2 is it's own entry
               {"vehicle1", "trip2", "2019-07-01 11:02:00 EDT", "2019-07-01 11:02:00 EDT",
                "2019-07-01 11:02:00 EDT", "2019-07-01 11:02:00 EDT", 1},
               # vehicle2 is it's own entry even though it's the same trip as vehicle1
               {"vehicle2", "trip1", "2019-07-01 10:01:00 EDT", "2019-07-01 10:01:00 EDT",
                "2019-07-01 10:01:00 EDT", "2019-07-01 10:01:00 EDT", 1}
             ] =
               MissedPredictions.missed_departures_for_route_stop(
                 ~D[2019-07-01],
                 "prod",
                 "route1",
                 "70197"
               )
    end
  end
end
