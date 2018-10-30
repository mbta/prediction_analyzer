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
      query = from(p in Prediction, select: p.environment)

      preds = PredictionAnalyzer.Repo.all(query)
      assert preds == ["prod", "prod", "dev-green", "dev-green"]
    end
  end
end
