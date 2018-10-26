defmodule PredictionAnalyzer.PredictionAccuracy.PredictionAccuracyTest do
  use ExUnit.Case, async: true
  alias PredictionAnalyzer.PredictionAccuracy.PredictionAccuracy


  describe "new_insert_changeset/1" do
    test "valid when fields are correct" do
      changeset = PredictionAccuracy.new_insert_changeset(%{
        service_date: "2015-01-01",
        hour_of_day: 5,
        stop_id: "stop1",
        route_id: "route1",
        arrival_departure: "arrival",
        bin: "0-3 min",
        num_predictions: 100,
        num_accurate_predictions: 80
      })

      assert changeset.valid?
    end

    test "invalid when fields are not correct" do
      changeset = PredictionAccuracy.new_insert_changeset(%{})
      refute changeset.valid?
    end
  end
end
