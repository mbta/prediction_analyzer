defmodule PredictionAnalyzer.Predictions.DownloadTest do
  use ExUnit.Case, async: true

  import Ecto.Query, only: [from: 2]
  alias PredictionAnalyzer.Predictions.Download
  alias PredictionAnalyzer.Predictions.Prediction

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(PredictionAnalyzer.Repo)
  end

  describe "get_predictions/1" do
    test "downloads and stores prod predictions" do
      Download.get_predictions(:prod)
      Download.get_predictions(:dev_green)
      query = from(p in Prediction, select: [p.environment, p.stop_id])

      preds = PredictionAnalyzer.Repo.all(query)

      assert preds == [
               ["prod", "70061"],
               ["prod", "70063"],
               ["dev-green", "70061"],
               ["dev-green", "70063"]
             ]
    end
  end
end
