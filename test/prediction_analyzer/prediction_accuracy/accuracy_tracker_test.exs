defmodule PredictionAnalyzer.PredictionAccuracy.AccuracyTrackerTest do
  use ExUnit.Case, async: false
  alias PredictionAnalyzer.PredictionAccuracy.AccuracyTracker
  alias PredictionAnalyzer.PredictionAccuracy.PredictionAccuracy
  alias PredictionAnalyzer.Repo
  import ExUnit.CaptureLog

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(PredictionAnalyzer.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(PredictionAnalyzer.Repo, {:shared, self()})
  end

  describe "start_link/1" do
    test "starts an instance of the accuracy tracker" do
      {:ok, pid} = AccuracyTracker.start_link()
      assert Process.alive?(pid)
    end
  end

  describe "handle_info/2 :check_accuracy" do
    test "logs a warning when accuracy drops by more than 10% from previous day to yesterday" do
      setup_db(69, 80)

      log =
        capture_log([level: :warn], fn ->
          AccuracyTracker.check_accuracy()
        end)

      assert log =~ "accuracy_drop"
    end

    test "does not log a warning when accuracy drops 10% from previous day to yesterday" do
      setup_db(80, 90)

      log =
        capture_log([level: :warn], fn ->
          AccuracyTracker.check_accuracy()
        end)

      refute log =~ "accuracy_drop"
    end

    test "does not log a warning when accuracy rises the same from previous day to yesterday" do
      setup_db(90, 80)

      log =
        capture_log([level: :warn], fn ->
          AccuracyTracker.check_accuracy()
        end)

      refute log =~ "accuracy_drop"
    end
  end

  describe "handle_info/2 :schedule_next_check" do
    test "checks the accuracy of all lines we care about" do
      Logger.configure(level: :info)

      log =
        capture_log([level: :info], fn ->
          {:ok, pid} = AccuracyTracker.start_link()
          Ecto.Adapters.SQL.Sandbox.mode(PredictionAnalyzer.Repo, {:shared, pid})

          Process.send_after(pid, :schedule_next_check, 10)

          :timer.sleep(50)
        end)

      Logger.configure(level: :warn)

      assert log =~ "check_accuracy"
    end
  end

  def setup_db(yesterday_accurate, previous_day_accurate) do
    today = Date.utc_today()
    yesterday = today |> Timex.shift(days: -1) |> Date.to_iso8601()
    previous_day = today |> Timex.shift(days: -2) |> Date.to_iso8601()

    changeset =
      PredictionAccuracy.new_insert_changeset(%{
        service_date: yesterday,
        hour_of_day: 5,
        stop_id: "stop1",
        route_id: "Red",
        direction_id: 1,
        bin: "0-3 min",
        num_predictions: 100,
        num_accurate_predictions: yesterday_accurate
      })

    Repo.insert!(changeset)

    changeset =
      PredictionAccuracy.new_insert_changeset(%{
        service_date: previous_day,
        hour_of_day: 5,
        stop_id: "stop1",
        route_id: "Red",
        direction_id: 1,
        bin: "0-3 min",
        num_predictions: 100,
        num_accurate_predictions: previous_day_accurate
      })

    Repo.insert!(changeset)
  end
end
