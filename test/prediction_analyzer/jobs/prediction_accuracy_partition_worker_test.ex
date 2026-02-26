defmodule PredictionAnalyzer.Jobs.PredictionAccuracyPartitionWorkerTest do
  alias PredictionAnalyzer.Jobs.PredictionAccuracyPartitionWorker
  import ExUnit.CaptureLog

  use PredictionAnalyzer.DataCase

  defmodule FakeRepoGood do
    def transact(fun), do: fun.(__MODULE__)

    def query(command) do
      send(self(), {:fake_repo_command, command})
      {:ok, %Postgrex.Result{messages: []}}
    end
  end

  defmodule FakeRepoTableExists do
    def transact(fun), do: fun.(__MODULE__)

    def query(command) do
      send(self(), {:fake_repo_command, command})
      {:ok, %Postgrex.Result{messages: [%{code: "42P07"}]}}
    end
  end

  defmodule FakeRepoBad do
    def transact(fun), do: fun.(__MODULE__)

    def query(command) do
      send(self(), {:fake_repo_command, command})
      {:error, Postgrex.QueryError.exception("query failed!")}
    end
  end

  setup do
    prev_level = Logger.level()
    Logger.configure(level: :info)
    on_exit(fn -> Logger.configure(level: prev_level) end)
  end

  test "Generates correct CREATE TABLE command for the given date" do
    args = %{
      repo: FakeRepoGood,
      partition_size_months: 2,
      today: ~D[2026-02-01]
    }

    expected_command = """
    CREATE TABLE IF NOT EXISTS prediction_accuracy_y2026_m03
        PARTITION OF prediction_accuracy
        FOR VALUES FROM ('2026-03-01') TO ('2026-05-01')
    """

    assert {:ok, logs} = with_log(fn -> perform_job(PredictionAccuracyPartitionWorker, args) end)

    assert logs =~
             "partition_worker_success child_table_name=prediction_accuracy_y2026_m03 result=created"

    assert_received {:fake_repo_command, ^expected_command}
  end

  test "Handles case where partition already exists" do
    args = %{
      repo: FakeRepoTableExists,
      partition_size_months: 2,
      today: ~D[2026-01-01]
    }

    expected_command = """
    CREATE TABLE IF NOT EXISTS prediction_accuracy_y2026_m03
        PARTITION OF prediction_accuracy
        FOR VALUES FROM ('2026-03-01') TO ('2026-05-01')
    """

    assert {:ok, logs} = with_log(fn -> perform_job(PredictionAccuracyPartitionWorker, args) end)

    assert logs =~
             "partition_worker_success child_table_name=prediction_accuracy_y2026_m03 result=already_exists"

    assert_received {:fake_repo_command, ^expected_command}
  end

  test "Logs failures" do
    args = %{
      repo: FakeRepoBad,
      partition_size_months: 3,
      today: ~D[2026-08-01]
    }

    expected_command = """
    CREATE TABLE IF NOT EXISTS prediction_accuracy_y2026_m10
        PARTITION OF prediction_accuracy
        FOR VALUES FROM ('2026-10-01') TO ('2027-01-01')
    """

    assert {{:error, %Postgrex.QueryError{message: "query failed!"}}, logs} =
             with_log(fn -> perform_job(PredictionAccuracyPartitionWorker, args) end)

    assert logs =~
             "partition_worker_error reason=\"** (Postgrex.QueryError) query failed!\""

    assert_received {:fake_repo_command, ^expected_command}
  end
end
