defmodule PredictionAnalyzer.PredictionAccuracy.AggregatorTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog

  alias PredictionAnalyzer.PredictionAccuracy.Aggregator

  defmodule FakeRepo do
    def query(_query, _params) do
      raise DBConnection.ConnectionError
    end

    def transaction(fun, _opts \\ []) do
      fun.()
    end
  end

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
    old_level = Logger.level()
    Logger.configure(level: :info)
    on_exit(fn -> Logger.configure(level: old_level) end)

    logs =
      capture_log(fn ->
        {:noreply, _state} =
          Aggregator.handle_info(:aggregate, %{
            repo: PredictionAnalyzer.Repo,
            retry_time_fetcher: fn _ -> 0 end
          })
      end)

    assert logs =~ "Finished prediction aggregations"
  end

  test "the :aggregate handle_info runs when aggregation fails" do
    old_level = Logger.level()
    Logger.configure(level: :info)
    on_exit(fn -> Logger.configure(level: old_level) end)

    log =
      capture_log([level: :info], fn ->
        {:noreply, _state} =
          Aggregator.handle_info(:aggregate, %{
            repo: FakeRepo,
            retry_time_fetcher: fn n -> n * 10 end
          })
      end)

    assert log =~ "retrying in 0.01 seconds"
    assert log =~ "retrying in 0.02 seconds"
    assert log =~ "retrying in 0.03 seconds"
    assert log =~ "retrying in 0.04 seconds"

    assert log =~ "Prediction aggregation failed, not retrying"
  end

  describe "retry_sleep_ms_per_attempt/1" do
    test "returns the correct amount of time to sleep" do
      assert Aggregator.retry_sleep_ms_per_attempt(4) == 10_000
      assert Aggregator.retry_sleep_ms_per_attempt(3) == 60_000
      assert Aggregator.retry_sleep_ms_per_attempt(2) == 600_000
      assert Aggregator.retry_sleep_ms_per_attempt(1) == 1_800_000
    end
  end
end
