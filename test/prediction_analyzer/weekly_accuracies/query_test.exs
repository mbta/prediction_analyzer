defmodule PredictionAnalyzer.WeeklyAccuracies.QueryTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog
  import Ecto.Query, only: [from: 2]
  alias PredictionAnalyzer.Repo
  alias PredictionAnalyzer.PredictionAccuracy.PredictionAccuracy
  alias PredictionAnalyzer.WeeklyAccuracies.WeeklyAccuracies
  alias PredictionAnalyzer.Predictions.Prediction
  alias PredictionAnalyzer.WeeklyAccuracies.Query

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(PredictionAnalyzer.Repo)
  end

  @prediction_accuracy %PredictionAccuracy{
    environment: "prod",
    service_date: DateTime.to_date(Timex.local()),
    hour_of_day: 11,
    stop_id: "70120",
    route_id: "Green-B",
    arrival_departure: "departure",
    bin: "0-3 min",
    num_predictions: 40,
    num_accurate_predictions: 21
  }

  defmodule FakeRepo do
    def query(_query, _params) do
      raise DBConnection.ConnectionError
    end
  end

  describe "calculate_weekly_accuracies/2" do
    test "selects the right predictions based on bin and grades them accurately" do
      PredictionAnalyzer.Repo.insert!(@prediction_accuracy)

      {:ok, x} =
        Query.calculate_weekly_accuracies(
          PredictionAnalyzer.Repo,
          Timex.shift(Timex.local(), days: 2)
        )

      [pa] = Repo.all(from(pa in WeeklyAccuracies, select: pa))

      assert pa.stop_id == "70120"
      assert pa.route_id == "Green-B"
      assert pa.arrival_departure == "departure"
      assert pa.bin == "0-3 min"
      assert pa.num_predictions == 40
      assert pa.num_accurate_predictions == 21
    end

    test "handles database failure properly" do
      log =
        capture_log([level: :warn], fn ->
          :error =
            Query.calculate_weekly_accuracies(
              FakeRepo,
              Timex.local()
            )
        end)

      base_log_msg =
        "Elixir.PredictionAnalyzer.WeeklyAccuracies.Query do_calculate_weekly_accuracies"

      assert log =~ "[warn] " <> base_log_msg
      assert log =~ "[error] " <> base_log_msg
    end
  end
end
