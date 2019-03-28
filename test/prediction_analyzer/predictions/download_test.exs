defmodule PredictionAnalyzer.Predictions.DownloadTest do
  use ExUnit.Case, async: true

  import Ecto.Query, only: [from: 2]
  alias PredictionAnalyzer.Predictions.Download
  alias PredictionAnalyzer.Predictions.Prediction

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(PredictionAnalyzer.Repo)
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
end
