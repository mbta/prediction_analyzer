defmodule PredictionAnalyzer.Jobs.PredictionAccuracyPartitionWorker do
  @moduledoc """
  Creates and attaches a new child table (aka partition) to
  `prediction_accuracy_partitioned` table once a week.

  The new partition is for the week following the current one.

  For example: if today is Monday 2026-01-05, the job will create a partition
  for the week of Monday 2026-01-12 through Sunday 2026-01-18.
  """
  require Logger
  import Ecto.Query

  use Oban.Worker,
    max_attempts: 10,
    unique: [states: :incomplete]

  config =
    Application.compile_env!(:prediction_analyzer, :prediction_accuracy_migration)
    |> Map.new()

  @partitioned config.partitioned

  @impl Oban.Worker
  def timeout(_job), do: :timer.minutes(5)

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    Logger.info("partition_worker_start")

    {today, repo} = parse_args(args)

    current_lbound = Date.beginning_of_week(today)

    next_range = {Date.shift(current_lbound, week: 1), Date.shift(current_lbound, week: 2)}

    case create_attach_child_table(next_range, repo) do
      {:ok, table, result} ->
        Logger.info("partition_worker_success child_table_name=#{table} result=#{result}")
        :ok

      {:error, exception} ->
        Logger.warning("partition_worker_error reason=\"#{Exception.format(:error, exception)}\"")
        {:error, exception}

      {:cancel, reason} ->
        Logger.info("partition_worker_canceled reason=#{inspect(reason)}")
        {:cancel, reason}
    end
  end

  @spec create_attach_child_table({Date.t(), Date.t()}, Ecto.Repo.t()) ::
          {:ok, String.t(), :created | :already_exists}
          | {:error, Exception.t()}
          | {:cancel, String.t()}
  defp create_attach_child_table({lbound_inclusive, ubound_exclusive}, repo) do
    suffix = Calendar.strftime(lbound_inclusive, "week_of_%Y_%m_%d")
    table = "prediction_accuracy_partition_#{suffix}"

    repo.transact(fn repo ->
      if table_exists?(@partitioned) do
        repo.query("""
        CREATE TABLE IF NOT EXISTS #{table}
            PARTITION OF #{@partitioned}
            FOR VALUES FROM ('#{lbound_inclusive}') TO ('#{ubound_exclusive}')
        """)
      else
        {:cancel, "table #{@partitioned} does not exist"}
      end
    end)
    |> case do
      {:ok, %Postgrex.Result{messages: [%{code: "42P07"}]}} -> {:ok, table, :already_exists}
      {:ok, _} -> {:ok, table, :created}
      {:error, _} = error -> error
      {:cancel, _} = cancel -> cancel
    end
  end

  defp parse_args(args) do
    today =
      case Map.fetch(args, "today") do
        {:ok, datestamp} -> Date.from_iso8601!(datestamp)
        :error -> Date.utc_today()
      end

    repo =
      case Map.fetch(args, "repo") do
        {:ok, repo_mod_string} -> String.to_atom(repo_mod_string)
        :error -> PredictionAnalyzer.Repo
      end

    {today, repo}
  end

  defp table_exists?(name) do
    PredictionAnalyzer.Repo.exists?(
      from(t in "tables", where: t.table_schema == "public", where: t.table_name == ^name),
      prefix: "information_schema"
    )
  end
end
