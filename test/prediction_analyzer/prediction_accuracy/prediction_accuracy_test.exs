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
    direction_id: 0,
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
          direction_id: 1,
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
      acc6 = %{@prediction_accuracy | direction_id: 1}

      base_params = %{
        "chart_range" => "Hourly",
        "service_date" => Timex.local() |> Date.to_string()
      }

      [acc1_id, acc2_id, acc3_id, acc4_id, acc5_id, acc6_id] =
        Enum.map([acc1, acc2, acc3, acc4, acc5, acc6], fn acc ->
          %{id: id} = Repo.insert!(acc)
          id
        end)

      {accs, nil} = PredictionAccuracy.filter(base_params)
      q = from(acc in accs, [])

      assert [%{id: ^acc2_id}, %{id: ^acc3_id}, %{id: ^acc4_id}, %{id: ^acc5_id}, %{id: ^acc6_id}] =
               execute_query(q)

      {accs, nil} =
        PredictionAccuracy.filter(Map.merge(base_params, %{"service_date" => "2018-01-01"}))

      q = from(acc in accs, [])
      assert [%{id: ^acc1_id}] = execute_query(q)

      {accs, nil} = PredictionAccuracy.filter(Map.merge(base_params, %{"stop_id" => "some_stop"}))
      q = from(acc in accs, [])
      assert [%{id: ^acc2_id}] = execute_query(q)

      {accs, nil} =
        PredictionAccuracy.filter(
          Map.merge(base_params, %{"route_ids" => "some_route,some_other_route"})
        )

      q = from(acc in accs, [])
      assert [%{id: ^acc3_id}] = execute_query(q)

      {accs, nil} =
        PredictionAccuracy.filter(Map.merge(base_params, %{"arrival_departure" => "departure"}))

      q = from(acc in accs, [])
      assert [%{id: ^acc4_id}] = execute_query(q)

      {accs, nil} = PredictionAccuracy.filter(Map.merge(base_params, %{"bin" => "6-12 min"}))
      q = from(acc in accs, [])
      assert [%{id: ^acc5_id}] = execute_query(q)

      {accs, nil} = PredictionAccuracy.filter(Map.merge(base_params, %{"direction_id" => "1"}))
      q = from(acc in accs, [])
      assert [%{id: ^acc6_id}] = execute_query(q)
    end

    test "can filter by single date or more" do
      yesterday = Timex.local() |> Timex.shift(days: -1) |> DateTime.to_date()
      day_before = Timex.local() |> Timex.shift(days: -2) |> DateTime.to_date()

      acc1 = %{@prediction_accuracy | service_date: yesterday}
      acc2 = %{@prediction_accuracy | service_date: day_before}

      [acc1_id, acc2_id] =
        Enum.map([acc1, acc2], fn acc ->
          %{id: id} = Repo.insert!(acc)
          id
        end)

      {accs, nil} =
        PredictionAccuracy.filter(%{
          "chart_range" => "Hourly",
          "service_date" => Date.to_string(yesterday)
        })

      q = from(acc in accs, [])

      assert [%{id: ^acc1_id}] = execute_query(q)

      {accs, nil} =
        PredictionAccuracy.filter(%{
          "chart_range" => "Hourly",
          "service_date" => Date.to_string(day_before)
        })

      q = from(acc in accs, [])

      assert [%{id: ^acc2_id}] = execute_query(q)

      assert {_, "No start or end date given."} =
               PredictionAccuracy.filter(%{"chart_range" => "Daily"})
    end

    test "can customize range of date filter, with max of 4 weeks" do
      acc1 = %{@prediction_accuracy | service_date: ~D[2018-01-01]}
      acc2 = %{@prediction_accuracy | service_date: ~D[2018-01-21]}

      [acc1_id, acc2_id] =
        Enum.map([acc1, acc2], fn acc ->
          %{id: id} = Repo.insert!(acc)
          id
        end)

      {accs, nil} =
        PredictionAccuracy.filter(%{
          "chart_range" => "Daily",
          "daily_date_start" => "2018-01-01",
          "daily_date_end" => "2018-01-14"
        })

      q = from(acc in accs, [])
      assert [%{id: ^acc1_id}] = execute_query(q)

      {accs, nil} =
        PredictionAccuracy.filter(%{
          "chart_range" => "Daily",
          "daily_date_start" => "2018-01-01",
          "daily_date_end" => "2018-01-21"
        })

      q = from(acc in accs, [])
      assert [%{id: ^acc1_id}, %{id: ^acc2_id}] = execute_query(q)

      assert {_accs, "Dates can't be more than 5 weeks apart"} =
               PredictionAccuracy.filter(%{
                 "chart_range" => "Daily",
                 "daily_date_start" => "2018-01-01",
                 "daily_date_end" => "2018-02-28"
               })
    end
  end

  describe "stats_by_environment_and_chart_range/2" do
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
        |> PredictionAccuracy.stats_by_environment_and_chart_range(%{"chart_range" => "Hourly"})
        |> Repo.all()

      assert stats == [
               [10, 209, 201, 809, 701],
               [11, 495, 472, 1095, 872]
             ]
    end

    test "groups by environment and service date and sums" do
      today = Timex.local() |> DateTime.to_date()
      yesterday = Timex.local() |> Timex.shift(days: -1) |> DateTime.to_date()

      insert_accuracy("prod", 10, 101, 99, yesterday)
      insert_accuracy("prod", 11, 108, 102, yesterday)
      insert_accuracy("prod", 10, 225, 211, today)
      insert_accuracy("prod", 11, 270, 261, today)
      insert_accuracy("dev-green", 10, 401, 399, yesterday)
      insert_accuracy("dev-green", 11, 408, 302, yesterday)
      insert_accuracy("dev-green", 10, 525, 411, today)
      insert_accuracy("dev-green", 11, 570, 461, today)

      stats =
        from(acc in PredictionAccuracy, [])
        |> PredictionAccuracy.stats_by_environment_and_chart_range(%{"chart_range" => "Daily"})
        |> Repo.all()

      assert stats == [
               [yesterday, 209, 201, 809, 701],
               [today, 495, 472, 1095, 872]
             ]
    end
  end

  defp execute_query(q) do
    Repo.all(from(acc in q, order_by: :id))
  end

  defp insert_accuracy(env, hour, total, accurate, service_date \\ nil) do
    accuracy = %{
      @prediction_accuracy
      | environment: env,
        hour_of_day: hour,
        num_predictions: total,
        num_accurate_predictions: accurate
    }

    accuracy =
      if service_date do
        %{accuracy | service_date: service_date}
      else
        accuracy
      end

    PredictionAnalyzer.Repo.insert!(accuracy)
  end
end
