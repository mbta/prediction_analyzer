defmodule PredictionAnalyzer.Predictions.DownloadTest do
  use ExUnit.Case, async: true

  import Ecto.Query, only: [from: 2]
  alias PredictionAnalyzer.Predictions.Download
  alias PredictionAnalyzer.Predictions.Prediction

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(PredictionAnalyzer.Repo)
  end

  describe "init/1" do
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

  test "start_link/1" do
    {:ok, pid} = Download.start_link()
    :timer.sleep(500)
    assert Process.alive?(pid)
  end

  describe "get_subway_predictions/1" do
    test "downloads and stores prod predictions" do
      Download.get_subway_predictions(:prod)
      Download.get_subway_predictions(:dev_green)
      query = from(p in Prediction, select: [p.environment, p.stop_id, p.direction_id])

      preds = PredictionAnalyzer.Repo.all(query)

      assert preds == [
               ["prod", "70061", 1],
               ["prod", "70063", 1],
               ["dev-green", "70061", 1],
               ["dev-green", "70063", 1]
             ]
    end
  end

  describe "get_commuter_rail_predictions/1" do
    test "downloads and stores prod predictions" do
      Download.get_commuter_rail_predictions(:prod)
      query = from(p in Prediction, select: [p.stop_id, p.direction_id, p.vehicle_id])

      preds = PredictionAnalyzer.Repo.all(query)

      assert preds == [["North Station", 0, "vehicle_id"], ["North Station", 0, "CR-na"]]
    end
  end
end
