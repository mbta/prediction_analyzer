defmodule PredictionAnalyzer.PredictionAccuracy.AggregatorTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog

  alias PredictionAnalyzer.PredictionAccuracy.Aggregator

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(PredictionAnalyzer.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(PredictionAnalyzer.Repo, {:shared, self()})

    log_level = Logger.level()
    on_exit fn ->
      Logger.configure(level: log_level)
    end
  end

  test "Can be started up without incident" do
    {:ok, pid} = Aggregator.start_link()
    :timer.sleep(500)
    assert Process.alive?(pid)
  end

  test "the :aggregate handle_info runs and logs its results" do
    Logger.configure(level: :info)

    logs = capture_log(fn ->
      {:noreply, []} = Aggregator.handle_info(:aggregate, [])
    end)

    assert logs =~ "Finished prediction aggregations"
  end
end
