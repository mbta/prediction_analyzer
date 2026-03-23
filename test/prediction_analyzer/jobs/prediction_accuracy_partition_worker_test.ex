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
    args = %{repo: FakeRepoGood, today: ~D[2026-02-01]}

    expected_command = """
    CREATE TABLE IF NOT EXISTS prediction_accuracy_partition_week_of_2026_02_02
        PARTITION OF prediction_accuracy_partitioned
        FOR VALUES FROM ('2026-02-02') TO ('2026-02-09')
    """

    assert {:ok, logs} = with_log(fn -> perform_job(PredictionAccuracyPartitionWorker, args) end)

    assert logs =~
             "partition_worker_success child_table_name=prediction_accuracy_partition_week_of_2026_02_02 result=created"

    assert_received {:fake_repo_command, ^expected_command}
  end

  test "Handles case where partition already exists" do
    args = %{repo: FakeRepoTableExists, today: ~D[2026-01-01]}

    expected_command = """
    CREATE TABLE IF NOT EXISTS prediction_accuracy_partition_week_of_2026_01_05
        PARTITION OF prediction_accuracy_partitioned
        FOR VALUES FROM ('2026-01-05') TO ('2026-01-12')
    """

    assert {:ok, logs} = with_log(fn -> perform_job(PredictionAccuracyPartitionWorker, args) end)

    assert logs =~
             "partition_worker_success child_table_name=prediction_accuracy_partition_week_of_2026_01_05 result=already_exists"

    assert_received {:fake_repo_command, ^expected_command}
  end

  test "Logs failures" do
    args = %{repo: FakeRepoBad, today: ~D[2026-08-01]}

    expected_command = """
    CREATE TABLE IF NOT EXISTS prediction_accuracy_partition_week_of_2026_08_03
        PARTITION OF prediction_accuracy_partitioned
        FOR VALUES FROM ('2026-08-03') TO ('2026-08-10')
    """

    assert {{:error, %Postgrex.QueryError{message: "query failed!"}}, logs} =
             with_log(fn -> perform_job(PredictionAccuracyPartitionWorker, args) end)

    assert logs =~
             "partition_worker_error reason=\"** (Postgrex.QueryError) query failed!\""

    assert_received {:fake_repo_command, ^expected_command}
  end

  test "Logs an error if the job exhausts all its retries" do
    args = %{repo: FakeRepoBad, today: ~D[2026-08-01]}

    opts = [attempt: 10]

    expected_command = """
    CREATE TABLE IF NOT EXISTS prediction_accuracy_partition_week_of_2026_08_03
        PARTITION OF prediction_accuracy_partitioned
        FOR VALUES FROM ('2026-08-03') TO ('2026-08-10')
    """

    assert {{:error, %Postgrex.QueryError{message: "query failed!"}}, logs} =
             with_log(fn -> perform_job(PredictionAccuracyPartitionWorker, args, opts) end)

    assert logs =~
             "partition_worker_error reason=\"** (Postgrex.QueryError) query failed!\""

    assert logs =~ "oban_job_retries_exhausted"

    assert_received {:fake_repo_command, ^expected_command}
  end
end
