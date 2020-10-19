defmodule PredictionAnalyzer.PredictionAccuracy.PredictionAccuracyTest do
  use ExUnit.Case, async: true
  alias PredictionAnalyzer.PredictionAccuracy.PredictionAccuracy
  alias PredictionAnalyzer.Filters
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
    num_accurate_predictions: 5,
    mean_error: 0.0,
    root_mean_squared_error: 0.0
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
    defp base_params do
      %{
        "bin" => "All",
        "chart_range" => "Hourly",
        "service_date" => Timex.local() |> Date.to_string()
      }
    end

    test "filters work" do
      acc1 = %{@prediction_accuracy | service_date: ~D[2018-01-01]}
      acc2 = %{@prediction_accuracy | stop_id: "some_stop"}
      acc3 = %{@prediction_accuracy | route_id: "some_route"}
      acc4 = %{@prediction_accuracy | arrival_departure: "departure"}
      acc5 = %{@prediction_accuracy | bin: "6-8 min"}
      acc6 = %{@prediction_accuracy | direction_id: 1}

      [acc1_id, acc2_id, acc3_id, acc4_id, acc5_id, acc6_id] =
        Enum.map([acc1, acc2, acc3, acc4, acc5, acc6], fn acc ->
          %{id: id} = Repo.insert!(acc)
          id
        end)

      {accs, nil} = PredictionAccuracy.filter(base_params())
      q = from(acc in accs, [])

      assert [%{id: ^acc2_id}, %{id: ^acc3_id}, %{id: ^acc4_id}, %{id: ^acc5_id}, %{id: ^acc6_id}] =
               execute_query(q)

      {accs, nil} =
        PredictionAccuracy.filter(Map.merge(base_params(), %{"service_date" => "2018-01-01"}))

      q = from(acc in accs, [])
      assert [%{id: ^acc1_id}] = execute_query(q)

      {accs, nil} =
        PredictionAccuracy.filter(Map.merge(base_params(), %{"stop_ids" => ["some_stop"]}))

      q = from(acc in accs, [])
      assert [%{id: ^acc2_id}] = execute_query(q)

      {accs, nil} =
        PredictionAccuracy.filter(Map.merge(base_params(), %{"route_ids" => "some_route"}))

      q = from(acc in accs, [])
      assert [%{id: ^acc3_id}] = execute_query(q)

      {accs, nil} =
        PredictionAccuracy.filter(Map.merge(base_params(), %{"arrival_departure" => "departure"}))

      q = from(acc in accs, [])
      assert [%{id: ^acc4_id}] = execute_query(q)

      {accs, nil} = PredictionAccuracy.filter(Map.merge(base_params(), %{"bin" => "6-8 min"}))
      q = from(acc in accs, [])
      assert [%{id: ^acc5_id}] = execute_query(q)

      {accs, nil} = PredictionAccuracy.filter(Map.merge(base_params(), %{"direction_id" => "1"}))
      q = from(acc in accs, [])
      assert [%{id: ^acc6_id}] = execute_query(q)
    end

    test "can filter by multiple routes" do
      Repo.insert!(%{@prediction_accuracy | route_id: "route1"})
      Repo.insert!(%{@prediction_accuracy | route_id: "route2"})
      Repo.insert!(%{@prediction_accuracy | route_id: "route3"})

      {accs, nil} =
        PredictionAccuracy.filter(Map.merge(base_params(), %{"route_ids" => "route1,route3"}))

      query = from(acc in accs, [])
      assert [%{route_id: "route1"}, %{route_id: "route3"}] = execute_query(query)
    end

    test "can filter by multiple stops" do
      Repo.insert!(%{@prediction_accuracy | stop_id: "stop1"})
      Repo.insert!(%{@prediction_accuracy | stop_id: "stop2"})
      Repo.insert!(%{@prediction_accuracy | stop_id: "stop3"})

      {accs, nil} =
        PredictionAccuracy.filter(Map.merge(base_params(), %{"stop_ids" => ~w(stop1 stop3)}))

      query = from(acc in accs, [])
      assert [%{stop_id: "stop1"}, %{stop_id: "stop3"}] = execute_query(query)
    end

    test "can filter using stop groups" do
      Repo.insert!(%{@prediction_accuracy | stop_id: "70061"})
      Repo.insert!(%{@prediction_accuracy | stop_id: "70085"})
      Repo.insert!(%{@prediction_accuracy | stop_id: "70001"})

      {accs, nil} =
        PredictionAccuracy.filter(
          Map.merge(base_params(), %{"stop_ids" => ~w(70001 _ashmont_branch)})
        )

      query = from(acc in accs, [])
      assert [%{stop_id: "70085"}, %{stop_id: "70001"}] = execute_query(query)
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
          "bin" => "All",
          "chart_range" => "Hourly",
          "service_date" => Date.to_string(yesterday)
        })

      q = from(acc in accs, [])

      assert [%{id: ^acc1_id}] = execute_query(q)

      {accs, nil} =
        PredictionAccuracy.filter(%{
          "bin" => "All",
          "chart_range" => "Hourly",
          "service_date" => Date.to_string(day_before)
        })

      q = from(acc in accs, [])

      assert [%{id: ^acc2_id}] = execute_query(q)

      assert {_, "No start or end date given."} =
               PredictionAccuracy.filter(%{"bin" => "All", "chart_range" => "Daily"})
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
          "bin" => "All",
          "chart_range" => "Daily",
          "date_start" => "2018-01-01",
          "date_end" => "2018-01-14"
        })

      q = from(acc in accs, [])
      assert [%{id: ^acc1_id}] = execute_query(q)

      {accs, nil} =
        PredictionAccuracy.filter(%{
          "bin" => "All",
          "chart_range" => "Daily",
          "date_start" => "2018-01-01",
          "date_end" => "2018-01-21"
        })

      q = from(acc in accs, [])
      assert [%{id: ^acc1_id}, %{id: ^acc2_id}] = execute_query(q)

      assert {_accs, "Dates can't be more than 5 weeks apart"} =
               PredictionAccuracy.filter(%{
                 "bin" => "All",
                 "chart_range" => "Daily",
                 "date_start" => "2018-01-01",
                 "date_end" => "2018-02-28"
               })
    end
  end

  describe "stats_by_environment_and_chart_range/3" do
    test "groups by environment and hour and sums" do
      insert_accuracy("prod", 10, 101, 99)
      insert_accuracy("prod", 10, 108, 102)
      insert_accuracy("prod", 11, 225, 211)
      insert_accuracy("prod", 11, 270, 261)
      insert_accuracy("dev-green", 10, 401, 399)
      insert_accuracy("dev-green", 10, 408, 302)
      insert_accuracy("dev-green", 11, 525, 411)
      insert_accuracy("dev-green", 11, 570, 461)

      prod_stats =
        from(acc in PredictionAccuracy, [])
        |> Filters.stats_by_environment_and_chart_range("prod", %{
          "chart_range" => "Hourly"
        })
        |> Repo.all()

      dev_green_stats =
        from(acc in PredictionAccuracy, [])
        |> Filters.stats_by_environment_and_chart_range("dev-green", %{
          "chart_range" => "Hourly"
        })
        |> Repo.all()

      assert prod_stats == [
               [10, 209, 201, 0.0, 0.0],
               [11, 495, 472, 0.0, 0.0]
             ]

      assert dev_green_stats == [
               [10, 809, 701, 0.0, 0.0],
               [11, 1095, 872, 0.0, 0.0]
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

      prod_stats =
        from(acc in PredictionAccuracy, [])
        |> Filters.stats_by_environment_and_chart_range("prod", %{
          "chart_range" => "Daily"
        })
        |> Repo.all()

      dev_green_stats =
        from(acc in PredictionAccuracy, [])
        |> Filters.stats_by_environment_and_chart_range("dev-green", %{
          "chart_range" => "Daily"
        })
        |> Repo.all()

      assert prod_stats == [
               [yesterday, 209, 201, 0.0, 0.0],
               [today, 495, 472, 0.0, 0.0]
             ]

      assert dev_green_stats == [
               [yesterday, 809, 701, 0.0, 0.0],
               [today, 1095, 872, 0.0, 0.0]
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
