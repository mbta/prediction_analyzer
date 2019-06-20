defmodule PredictionAnalyzer.WeeklyAccuracies.WeeklyAccuraciesTest do
  use ExUnit.Case, async: true
  alias PredictionAnalyzer.WeeklyAccuracies.WeeklyAccuracies
  alias PredictionAnalyzer.Repo

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  @today DateTime.to_date(Timex.local())

  @weekly_accuracies %WeeklyAccuracies{
    week_start: @today,
    environment: "prod",
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
        WeeklyAccuracies.new_insert_changeset(%{
          week_start: @today,
          environment: "prod",
          stop_id: "stop1",
          route_id: "route1",
          direction_id: 0,
          arrival_departure: "arrival",
          bin: "0-3 min",
          num_predictions: 10,
          num_accurate_predictions: 5
        })

      assert changeset.valid?
    end

    test "invalid when fields are not correct" do
      changeset = WeeklyAccuracies.new_insert_changeset(%{})
      refute changeset.valid?
    end
  end

  describe "filter/1" do
    test "when there is a problem, gets no results and an error message" do
      filters = %{
        "route_ids" => BadData,
        "stop_id" => BadData,
        "direction_id" => BadData,
        "arrival_departure" => BadData,
        "bin" => BadData,
        "mode" => BadData,
        "chart_range" => "Weekly",
        "week_start" => BadData
      }

      assert {_, "No start or end date given."} = WeeklyAccuracies.filter(filters)
    end
  end

  def insert_weekly_accuracy(env, total, accurate) do
    PredictionAnalyzer.Repo.insert!(%{
      @weekly_accuracies
      | environment: env,
        num_predictions: total,
        num_accurate_predictions: accurate
    })
  end
end
