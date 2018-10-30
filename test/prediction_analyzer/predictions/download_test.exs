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
      prod_query = from(p in Prediction, where: p.environment == "prod")
      dev_green_query = from(p in Prediction, where: p.environment == "dev-green")

      prod = PredictionAnalyzer.Repo.aggregate(prod_query, :count, :environment)
      dev_green = PredictionAnalyzer.Repo.aggregate(dev_green_query, :count, :environment)
      assert prod == 6
      assert dev_green == 2
    end
  end
end
