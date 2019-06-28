defmodule PredictionAnalyzer.QueryUtilitiesTest do
  use ExUnit.Case, async: false

  import Ecto.Query, only: [from: 2]
  import PredictionAnalyzer.QueryUtilities

  alias PredictionAnalyzer.PredictionAccuracy.PredictionAccuracy
  alias PredictionAnalyzer.WeeklyAccuracies.WeeklyAccuracies
  alias PredictionAnalyzer.Repo

  @prediction_accuracy %PredictionAccuracy{
    environment: "prod",
    service_date: ~D[2019-07-01],
    hour_of_day: 10,
    stop_id: "stop1",
    route_id: "route1",
    direction_id: 0,
    arrival_departure: "arrival",
    bin: "0-3 min",
    num_predictions: 1,
    num_accurate_predictions: 1,
    mean_error: 10.0,
    root_mean_squared_error: 10.0
  }

  @weekly_accuracy %WeeklyAccuracies{
    environment: "prod",
    week_start: ~D[2019-07-01],
    stop_id: "stop1",
    route_id: "route1",
    direction_id: 0,
    arrival_departure: "arrival",
    bin: "0-3 min",
    num_predictions: 1,
    num_accurate_predictions: 1,
    mean_error: 10.0,
    root_mean_squared_error: 10.0
  }

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(PredictionAnalyzer.Repo)
  end

  describe "aggregate_mean_error/2" do
    test "aggregates multiple mean errors into a correct overall mean error for prediction_accuracy" do
      pa1 = %{@prediction_accuracy | mean_error: 5.0, num_predictions: 5}
      pa2 = %{@prediction_accuracy | mean_error: -10.0, num_predictions: 10}

      Repo.insert!(pa1)
      Repo.insert!(pa2)

      [mean_error] =
        Repo.all(
          from(
            pa in PredictionAccuracy,
            select: aggregate_mean_error(pa.mean_error, pa.num_predictions)
          )
        )

      assert_in_delta(mean_error, (5.0 * 5 + -10.0 * 10) / (5 + 10), 0.001)
    end

    test "aggregates multiple mean errors into a correct overall mean error for weekly_accuracies" do
      wa1 = %{@weekly_accuracy | mean_error: 5.0, num_predictions: 5}
      wa2 = %{@weekly_accuracy | mean_error: -10.0, num_predictions: 10}

      Repo.insert!(wa1)
      Repo.insert!(wa2)

      [mean_error] =
        Repo.all(
          from(
            wa in WeeklyAccuracies,
            select: aggregate_mean_error(wa.mean_error, wa.num_predictions)
          )
        )

      assert_in_delta(mean_error, (5.0 * 5 + -10.0 * 10) / (5 + 10), 0.001)
    end

    test "aggregates multiple mean errors when grouped by a field" do
      pa1 = %{@prediction_accuracy | mean_error: 5.0, num_predictions: 5, stop_id: "stop1"}
      pa2 = %{@prediction_accuracy | mean_error: -10.0, num_predictions: 10, stop_id: "stop1"}
      pa3 = %{@prediction_accuracy | mean_error: -10.0, num_predictions: 10, stop_id: "stop2"}

      Repo.insert!(pa1)
      Repo.insert!(pa2)
      Repo.insert!(pa3)

      [["stop1", stop1_mean_error], ["stop2", stop2_mean_error]] =
        Repo.all(
          from(
            pa in PredictionAccuracy,
            select: [pa.stop_id, aggregate_mean_error(pa.mean_error, pa.num_predictions)],
            group_by: pa.stop_id,
            order_by: pa.stop_id
          )
        )

      assert_in_delta(stop1_mean_error, (5.0 * 5 + -10.0 * 10) / (5 + 10), 0.001)
      assert_in_delta(stop2_mean_error, -10.0, 0.001)
    end
  end

  describe "aggregate_rmse/2" do
    test "aggregates multiple mean errors into a correct overall mean error for prediction_accuracy" do
      pa1 = %{@prediction_accuracy | root_mean_squared_error: 5.0, num_predictions: 5}
      pa2 = %{@prediction_accuracy | root_mean_squared_error: 10.0, num_predictions: 10}

      Repo.insert!(pa1)
      Repo.insert!(pa2)

      [rmse] =
        Repo.all(
          from(
            pa in PredictionAccuracy,
            select: aggregate_rmse(pa.root_mean_squared_error, pa.num_predictions)
          )
        )

      assert_in_delta(rmse, :math.sqrt((5.0 * 5.0 * 5 + 10.0 * 10.0 * 10) / (5 + 10)), 0.001)
    end

    test "aggregates multiple mean errors into a correct overall mean error for weekly_accuracies" do
      wa1 = %{@weekly_accuracy | root_mean_squared_error: 5.0, num_predictions: 5}
      wa2 = %{@weekly_accuracy | root_mean_squared_error: 10.0, num_predictions: 10}

      Repo.insert!(wa1)
      Repo.insert!(wa2)

      [rmse] =
        Repo.all(
          from(
            wa in WeeklyAccuracies,
            select: aggregate_rmse(wa.root_mean_squared_error, wa.num_predictions)
          )
        )

      assert_in_delta(rmse, :math.sqrt((5.0 * 5.0 * 5 + 10.0 * 10.0 * 10) / (5 + 10)), 0.001)
    end

    test "aggregates multiple mean errors when grouped by a field" do
      pa1 = %{
        @prediction_accuracy
        | root_mean_squared_error: 5.0,
          num_predictions: 5,
          stop_id: "stop1"
      }

      pa2 = %{
        @prediction_accuracy
        | root_mean_squared_error: 10.0,
          num_predictions: 10,
          stop_id: "stop1"
      }

      pa3 = %{
        @prediction_accuracy
        | root_mean_squared_error: 10.0,
          num_predictions: 10,
          stop_id: "stop2"
      }

      Repo.insert!(pa1)
      Repo.insert!(pa2)
      Repo.insert!(pa3)

      [["stop1", stop1_rmse], ["stop2", stop2_rmse]] =
        Repo.all(
          from(
            pa in PredictionAccuracy,
            select: [
              pa.stop_id,
              aggregate_rmse(pa.root_mean_squared_error, pa.num_predictions)
            ],
            group_by: pa.stop_id,
            order_by: pa.stop_id
          )
        )

      assert_in_delta(
        stop1_rmse,
        :math.sqrt((5.0 * 5.0 * 5 + -10.0 * -10.0 * 10) / (5 + 10)),
        0.001
      )

      assert_in_delta(stop2_rmse, 10.0, 0.001)
    end
  end
end
