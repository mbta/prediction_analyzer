defmodule PredictionAnalyzer.Jobs.PredictionAccuracyPartitionWorker do
  @moduledoc """
  Periodically creates and attaches new child tables to the partitioned
  `prediction_accuracy` table.
  """
  require Logger

  use Oban.Worker,
    max_attempts: 10

  @partition_size_months Application.compile_env!(:prediction_analyzer, :partition_size_months)

  @impl Oban.Worker
  def timeout(_job), do: :timer.minutes(5)

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    Logger.info("partition_worker_start")

    {utc_today, repo, partition_size_months} = parse_args(args)

    current_lbound_month =
      div(utc_today.month - 1, partition_size_months) * partition_size_months + 1

    current_lbound = Date.new!(utc_today.year, current_lbound_month, 1)

    next_range =
      {Date.shift(current_lbound, month: partition_size_months),
       Date.shift(current_lbound, month: 2 * partition_size_months)}

    case create_attach_child_table(next_range, repo) do
      {:ok, table, result} ->
        Logger.info("partition_worker_success child_table_name=#{table} result=#{result}")
        :ok

      {:error, exception} ->
        Logger.warning("partition_worker_error reason=\"#{Exception.format(:error, exception)}\"")
        {:error, exception}
    end
  end

  @spec create_attach_child_table({Date.t(), Date.t()}, Ecto.Repo.t()) ::
          {:ok, String.t(), :created | :already_exists} | {:error, Exception.t()}
  defp create_attach_child_table({lbound_inclusive, ubound_exclusive}, repo) do
    table = "prediction_accuracy_#{Calendar.strftime(lbound_inclusive, "y%Y_m%m")}"

    repo.transact(fn repo ->
      repo.query("""
      CREATE TABLE IF NOT EXISTS #{table}
          PARTITION OF prediction_accuracy
          FOR VALUES FROM ('#{lbound_inclusive}') TO ('#{ubound_exclusive}')
      """)
    end)
    |> case do
      {:ok, %Postgrex.Result{messages: [%{code: "42P07"}]}} -> {:ok, table, :already_exists}
      {:ok, _} -> {:ok, table, :created}
      {:error, _} = error -> error
    end
  end

  defp parse_args(args) do
    utc_today =
      case Map.fetch(args, "today") do
        {:ok, datestamp} -> Date.from_iso8601!(datestamp)
        :error -> Date.utc_today()
      end

    repo =
      case Map.fetch(args, "repo") do
        {:ok, repo_mod_string} -> String.to_atom(repo_mod_string)
        :error -> PredictionAnalyzer.Repo
      end

    partition_size_months = args["partition_size_months"] || @partition_size_months

    {utc_today, repo, partition_size_months}
  end
end
