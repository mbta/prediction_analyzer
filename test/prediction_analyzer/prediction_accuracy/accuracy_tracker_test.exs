defmodule PredictionAnalyzer.PredictionAccuracy.AccuracyTrackerTest do
  use ExUnit.Case
  alias PredictionAnalyzer.PredictionAccuracy.AccuracyTracker
  alias PredictionAnalyzer.PredictionAccuracy.PredictionAccuracy
  alias PredictionAnalyzer.Repo
  import ExUnit.CaptureLog

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(PredictionAnalyzer.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(PredictionAnalyzer.Repo, {:shared, self()})
  end

  describe "handle_info/3 :check_accuracy" do
    test "logs a warning when accuracy drops from previous day to yesterday" do
      today = Date.utc_today()
      yesterday = today |> Timex.shift(days: -1) |> Date.to_iso8601()
      previous_day = today |> Timex.shift(days: -2) |> Date.to_iso8601()

      changeset =
        PredictionAccuracy.new_insert_changeset(%{
          service_date: yesterday,
          hour_of_day: 5,
          stop_id: "stop1",
          route_id: "route1",
          direction_id: 1,
          arrival_departure: "arrival",
          bin: "0-3 min",
          num_predictions: 100,
          num_accurate_predictions: 70
        })

      Repo.insert!(changeset)

      changeset =
        PredictionAccuracy.new_insert_changeset(%{
          service_date: previous_day,
          hour_of_day: 5,
          stop_id: "stop1",
          route_id: "route1",
          direction_id: 1,
          arrival_departure: "arrival",
          bin: "0-3 min",
          num_predictions: 100,
          num_accurate_predictions: 80
        })

      Repo.insert!(changeset)
      {:ok, pid} = AccuracyTracker.start_link([])

      log =
        capture_log([level: :warn], fn ->
          AccuracyTracker.check_accuracy(pid)
        end)

      assert log =~ "accuracy_drop"
    end

    test "does not log a warning when accuracy stays the same from previous day to yesterday" do
      today = Date.utc_today()
      yesterday = today |> Timex.shift(days: -1) |> Date.to_iso8601()
      previous_day = today |> Timex.shift(days: -2) |> Date.to_iso8601()

      changeset =
        PredictionAccuracy.new_insert_changeset(%{
          service_date: yesterday,
          hour_of_day: 5,
          stop_id: "stop1",
          route_id: "route1",
          direction_id: 1,
          arrival_departure: "arrival",
          bin: "0-3 min",
          num_predictions: 100,
          num_accurate_predictions: 80
        })

      Repo.insert!(changeset)

      changeset =
        PredictionAccuracy.new_insert_changeset(%{
          service_date: previous_day,
          hour_of_day: 5,
          stop_id: "stop1",
          route_id: "route1",
          direction_id: 1,
          arrival_departure: "arrival",
          bin: "0-3 min",
          num_predictions: 100,
          num_accurate_predictions: 80
        })

      Repo.insert!(changeset)
      {:ok, pid} = AccuracyTracker.start_link([])

      log =
        capture_log([level: :warn], fn ->
          AccuracyTracker.check_accuracy(pid)
        end)

      refute log =~ "accuracy_drop"
    end

    test "does not log a warning when accuracy rises the same from previous day to yesterday" do
      today = Date.utc_today()
      yesterday = today |> Timex.shift(days: -1) |> Date.to_iso8601()
      previous_day = today |> Timex.shift(days: -2) |> Date.to_iso8601()

      changeset =
        PredictionAccuracy.new_insert_changeset(%{
          service_date: yesterday,
          hour_of_day: 5,
          stop_id: "stop1",
          route_id: "route1",
          direction_id: 1,
          arrival_departure: "arrival",
          bin: "0-3 min",
          num_predictions: 100,
          num_accurate_predictions: 90
        })

      Repo.insert!(changeset)

      changeset =
        PredictionAccuracy.new_insert_changeset(%{
          service_date: previous_day,
          hour_of_day: 5,
          stop_id: "stop1",
          route_id: "route1",
          direction_id: 1,
          arrival_departure: "arrival",
          bin: "0-3 min",
          num_predictions: 100,
          num_accurate_predictions: 80
        })

      Repo.insert!(changeset)
      {:ok, pid} = AccuracyTracker.start_link([])

      log =
        capture_log([level: :warn], fn ->
          AccuracyTracker.check_accuracy(pid)
        end)

      refute log =~ "accuracy_drop"
    end
  end
end
