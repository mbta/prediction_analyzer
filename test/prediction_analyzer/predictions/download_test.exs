defmodule PredictionAnalyzer.Predictions.DownloadTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog

  import Ecto.Query, only: [from: 2]
  import Test.Support.Env
  alias PredictionAnalyzer.Predictions.Download
  alias PredictionAnalyzer.Predictions.Prediction
  alias PredictionAnalyzer.Predictions.DownloadTest.FailedHTTPFetcher

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(PredictionAnalyzer.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(PredictionAnalyzer.Repo, {:shared, self()})
  end

  defmodule FailedHTTPFetcher do
    def get(_, _, _) do
      {:error, "something"}
    end
  end

  describe "init/1" do
    test "schedules initial download" do
      Download.init(
        initial_prod_fetch_ms: 10,
        initial_dev_green_fetch_ms: 20,
        initial_commuter_rail_fetch_ms: 30
      )

      Process.sleep(50)

      assert_received :get_prod_predictions
      assert_received :get_dev_green_predictions
      assert_received :get_commuter_rail_predictions
    end
  end

  test "start_link/1" do
    {:ok, pid} =
      Download.start_link(
        initial_prod_fetch_ms: 100,
        initial_dev_green_fetch_ms: 100,
        initial_commuter_rail_fetch_ms: 100
      )

    :timer.sleep(500)
    assert Process.alive?(pid)
  end

  describe "get_subway_predictions/1" do
    test "downloads and stores predictions" do
      Download.get_subway_predictions(:prod)
      Download.get_subway_predictions(:dev_green)

      query =
        from(p in Prediction,
          select: [p.environment, p.trip_id, p.stop_id, p.direction_id, p.kind, p.nth_at_stop]
        )

      preds = PredictionAnalyzer.Repo.all(query)

      # See FakeHTTPoison
      assert preds == [
               ["prod", "TEST_TRIP_4", nil, 1, "mid_trip", nil],
               ["prod", "TEST_TRIP_2", "70061", 1, "mid_trip", 1],
               ["prod", "TEST_TRIP_1", "70061", 1, "mid_trip", 2],
               ["prod", "TEST_TRIP_1", "70063", 1, "mid_trip", 1],
               ["prod", "TEST_TRIP_2", "70063", 1, "mid_trip", 2],
               ["dev-green", "TEST_TRIP_4", nil, 1, "mid_trip", nil],
               ["dev-green", "TEST_TRIP_2", "70061", 1, "mid_trip", 1],
               ["dev-green", "TEST_TRIP_1", "70061", 1, "mid_trip", 2],
               ["dev-green", "TEST_TRIP_1", "70063", 1, "mid_trip", 1],
               ["dev-green", "TEST_TRIP_2", "70063", 1, "mid_trip", 2]
             ]
    end
  end

  describe "get_commuter_rail_predictions/0" do
    test "when theres an error, gets no predictions" do
      reassign_env(:http_fetcher, FailedHTTPFetcher)

      log =
        capture_log([level: :warn], fn ->
          Download.get_commuter_rail_predictions()
        end)

      query = from(p in Prediction, select: [p.stop_id, p.direction_id, p.vehicle_id])

      preds = PredictionAnalyzer.Repo.all(query)

      assert preds == []
      assert log =~ "Could not download commuter rail predictions"
    end

    test "downloads and stores prod predictions" do
      Download.get_commuter_rail_predictions()
      query = from(p in Prediction, select: [p.stop_id, p.direction_id, p.vehicle_id])

      preds = PredictionAnalyzer.Repo.all(query)

      assert preds == [
               ["North Station", 0, "vehicle_id"],
               ["North Station", 0, "vehicle_id"]
             ]
    end
  end

  describe "Handling messages" do
    test "ignores :ssl_closed" do
      {:ok, pid} =
        Download.start_link(
          initial_prod_fetch_ms: 10_000,
          initial_dev_green_fetch_ms: 10_000,
          initial_commuter_rail_fetch_ms: 10_000
        )

      log =
        capture_log(fn ->
          send(pid, {:ssl_closed, :socket})
        end)

      refute log =~ "unexpected_message"
    end

    test "handles but warns about unexpected message" do
      {:ok, pid} =
        Download.start_link(
          initial_prod_fetch_ms: 10_000,
          initial_dev_green_fetch_ms: 10_000,
          initial_commuter_rail_fetch_ms: 10_000
        )

      log =
        capture_log(fn ->
          send(pid, :something_unexpected)
        end)

      assert log =~ "unexpected_message"
    end
  end
end
