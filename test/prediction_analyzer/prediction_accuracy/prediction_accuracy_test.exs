defmodule PredictionAnalyzer.PredictionAccuracy.PredictionAccuracyTest do
  use ExUnit.Case, async: true
  alias PredictionAnalyzer.PredictionAccuracy.PredictionAccuracy
  alias PredictionAnalyzer.Repo

  import Ecto.Query, only: [from: 2]

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  @prediction_accuracy %PredictionAccuracy{
    service_date: Timex.local() |> DateTime.to_date(),
    hour_of_day: 10,
    stop_id: "stop1",
    route_id: "route1",
    arrival_departure: "arrival",
    bin: "0-3 min",
    num_predictions: 10,
    num_accurate_predictions: 5
  }

  describe "new_insert_changeset/1" do
    test "valid when fields are correct" do
      changeset =
        PredictionAccuracy.new_insert_changeset(%{
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

  describe "filter/1" do
    test "filters work" do
      acc1 = %{@prediction_accuracy | service_date: ~D[2018-01-01]}
      acc2 = %{@prediction_accuracy | stop_id: "some_stop"}
      acc3 = %{@prediction_accuracy | route_id: "some_route"}
      acc4 = %{@prediction_accuracy | arrival_departure: "departure"}
      acc5 = %{@prediction_accuracy | bin: "6-12 min"}

      [acc1_id, acc2_id, acc3_id, acc4_id, acc5_id] =
        Enum.map([acc1, acc2, acc3, acc4, acc5], fn acc ->
          %{id: id} = Repo.insert!(acc)
          id
        end)

      q = from(acc in PredictionAccuracy.filter(%{}), [])

      assert [%{id: ^acc2_id}, %{id: ^acc3_id}, %{id: ^acc4_id}, %{id: ^acc5_id}] =
               execute_query(q)

      q = from(acc in PredictionAccuracy.filter(%{"service_date" => "2018-01-01"}), [])
      assert [%{id: ^acc1_id}] = execute_query(q)

      q = from(acc in PredictionAccuracy.filter(%{"stop_id" => "some_stop"}), [])
      assert [%{id: ^acc2_id}] = execute_query(q)

      q = from(acc in PredictionAccuracy.filter(%{"route_id" => "some_route"}), [])
      assert [%{id: ^acc3_id}] = execute_query(q)

      q = from(acc in PredictionAccuracy.filter(%{"arrival_departure" => "departure"}), [])
      assert [%{id: ^acc4_id}] = execute_query(q)

      q = from(acc in PredictionAccuracy.filter(%{"bin" => "6-12 min"}), [])
      assert [%{id: ^acc5_id}] = execute_query(q)
    end
  end

  describe "stats_by_environment_and_hour/1" do
    test "groups by environment and hour and sums" do
      insert_accuracy("prod", 10, 101, 99)
      insert_accuracy("prod", 10, 108, 102)
      insert_accuracy("prod", 11, 225, 211)
      insert_accuracy("prod", 11, 270, 261)
      insert_accuracy("dev-green", 10, 401, 399)
      insert_accuracy("dev-green", 10, 408, 302)
      insert_accuracy("dev-green", 11, 525, 411)
      insert_accuracy("dev-green", 11, 570, 461)

      stats =
        from(acc in PredictionAccuracy, [])
        |> PredictionAccuracy.stats_by_environment_and_hour()
        |> Repo.all()

      assert stats == [
               [10, 209, 201, 809, 701],
               [11, 495, 472, 1095, 872]
             ]
    end
  end

  defp execute_query(q) do
    Repo.all(from(acc in q, order_by: :id))
  end

  defp insert_accuracy(env, hour, total, accurate) do
    PredictionAnalyzer.Repo.insert!(%{
      @prediction_accuracy
      | environment: env,
        hour_of_day: hour,
        num_predictions: total,
        num_accurate_predictions: accurate
    })
  end
end
