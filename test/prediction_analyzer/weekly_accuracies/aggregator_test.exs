defmodule PredictionAnalyzer.WeeklyAccuracies.AggregatorTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog

  alias PredictionAnalyzer.WeeklyAccuracies.Aggregator

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(PredictionAnalyzer.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(PredictionAnalyzer.Repo, {:shared, self()})

    log_level = Logger.level()

    on_exit(fn ->
      Logger.configure(level: log_level)
    end)
  end

  test "Can be started up without incident" do
    {:ok, pid} = Aggregator.start_link()
    :timer.sleep(500)
    assert Process.alive?(pid)
  end

  test "the :aggregate handle_info runs and logs its results" do
    Logger.configure(level: :info)

    logs =
      capture_log(fn ->
        {:noreply, _backfill_time} =
          Aggregator.handle_info(:aggregate_weekly, %{backfill_time: Timex.now()})
      end)

    assert logs =~ "Finished weekly prediction aggregations"
  end
end
