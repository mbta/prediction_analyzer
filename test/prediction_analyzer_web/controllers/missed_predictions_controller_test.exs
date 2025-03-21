defmodule PredictionAnalyzerWeb.MissedPredictionsControllerTest do
  use PredictionAnalyzerWeb.ConnCase

  alias PredictionAnalyzerWeb.MissedPredictionsController
  alias PredictionAnalyzer.VehicleEvents.VehicleEvent
  alias PredictionAnalyzer.Predictions.Prediction
  alias PredictionAnalyzer.Repo

  defp insert_vehicle_events(events) do
    cnt = Enum.count(events)
    {^cnt, _} = Repo.insert_all(VehicleEvent, events)
  end

  defp insert_predictions(predictions) do
    cnt = Enum.count(predictions)
    {^cnt, _} = Repo.insert_all(Prediction, predictions)
  end

  setup do
    {:ok, _pid} =
      start_supervised(
        {PredictionAnalyzer.StopNameFetcher, name: PredictionAnalyzer.StopNameFetcher}
      )

    insert_vehicle_events([
      %{
        id: 1,
        departure_time: DateTime.to_unix(~U[2020-02-01 10:00:00Z]),
        route_id: "Green-B",
        stop_id: "70036",
        trip_id: "unpredicted-departure",
        environment: "prod",
        vehicle_id: "vehicle-1",
        is_deleted: false
      },
      %{
        id: 2,
        departure_time: DateTime.to_unix(~U[2020-02-01 10:20:00Z]),
        route_id: "Green-B",
        stop_id: "70036",
        trip_id: "trip-2",
        environment: "prod",
        vehicle_id: "vehicle-2",
        is_deleted: false
      },
      %{
        id: 3,
        departure_time: DateTime.to_unix(~U[2020-02-01 10:30:00Z]),
        route_id: "Green-B",
        stop_id: "70036",
        trip_id: "trip-3",
        environment: "prod",
        vehicle_id: "vehicle-3",
        is_deleted: false
      }
    ])

    insert_predictions([
      %{
        departure_time: DateTime.to_unix(~U[2020-02-01 10:10:00Z]),
        route_id: "Green-B",
        stop_id: "70036",
        trip_id: "trip-2",
        file_timestamp: DateTime.to_unix(~U[2020-02-01 09:00:00Z]),
        environment: "prod",
        vehicle_id: "vehicle-2",
        vehicle_event_id: 2
      },
      %{
        departure_time: DateTime.to_unix(~U[2020-02-01 10:20:00Z]),
        route_id: "Green-B",
        stop_id: "70036",
        trip_id: "trip-3",
        file_timestamp: DateTime.to_unix(~U[2020-02-01 09:00:00Z]),
        environment: "prod",
        vehicle_id: "vehicle-3",
        vehicle_event_id: 3
      },
      %{
        departure_time: DateTime.to_unix(~U[2020-02-01 10:30:00Z]),
        route_id: "Green-B",
        stop_id: "70036",
        trip_id: "unrealized-departure",
        file_timestamp: DateTime.to_unix(~U[2020-02-01 09:00:00Z]),
        environment: "prod",
        vehicle_id: "vehicle-4"
      }
    ])

    :ok
  end

  describe "index/2" do
    test "Defaults to today's date when no date parameter is provided", %{conn: conn} do
      conn = get(conn, "/missed_predictions")
      date_str = Date.to_string(Date.utc_today())
      assert html_response(conn, 200) =~ "value=\"#{date_str}\""
    end

    test "Generates summary tables for missed and unpredicted departures", %{conn: conn} do
      conn = get(conn, "/missed_predictions", date: "2020-02-01", env: "prod")
      response = html_response(conn, 200)

      assert response =~ "Unpredicted Departures"
      assert response =~ "Unrealized Departures"
    end

    test "Generates totals for missed and unpredicted departures", %{conn: conn} do
      conn = get(conn, "/missed_predictions", date: "2020-02-01", env: "prod")
      response = html_response(conn, 200)

      assert response =~ "<strong>Total</strong>"
      assert response =~ "<strong>3</strong>"
      assert response =~ "<strong>1</strong>"
      assert response =~ "<strong>33.33</strong>"
    end

    test "Generates tables for missed departures by route", %{conn: conn} do
      conn =
        get(conn, "/missed_predictions", date: "2020-02-01", env: "prod", missed_route: "Green-B")

      response = html_response(conn, 200)

      assert response =~ "Unrealized Departure Predictions"
      assert response =~ "Green-B"
      assert response =~ "All Stops"
      assert response =~ "70036"
      assert response =~ "3"
      assert response =~ "1"
      assert response =~ "33.33"
    end

    test "Generates tables for missed departures by route and stop", %{conn: conn} do
      conn =
        get(
          conn,
          "/missed_predictions",
          date: "2020-02-01",
          env: "prod",
          missed_route: "Green-B",
          stop_id: "70036"
        )

      response = html_response(conn, 200)

      assert response =~ "Unrealized Departure Predictions"
      assert response =~ "Green-B"
      assert response =~ "70036"
      assert response =~ "vehicle-4"
    end

    test "Generates tables for unpredicted departures by route", %{conn: conn} do
      conn =
        get(conn, "/missed_predictions",
          date: "2020-02-01",
          env: "prod",
          missing_route: "Green-B"
        )

      response = html_response(conn, 200)

      assert response =~ "Unpredicted Departures"
      assert response =~ "Green-B"
      assert response =~ "All Stops"
      assert response =~ "70036"
    end

    test "Generates tables for unpredicted departures by route and stop", %{conn: conn} do
      conn =
        get(
          conn,
          "/missed_predictions",
          date: "2020-02-01",
          env: "prod",
          missing_route: "Green-B",
          stop_id: "70036"
        )

      response = html_response(conn, 200)

      assert response =~ "Unpredicted Departures"
      assert response =~ "Green-B"
      assert response =~ "70036"
      assert response =~ "vehicle-1"
    end
  end
end
