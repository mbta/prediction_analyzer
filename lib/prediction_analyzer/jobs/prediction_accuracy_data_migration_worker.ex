defmodule PredictionAnalyzer.Jobs.PredictionAccuracyDataMigrationWorker do
  @moduledoc """
  Copies 1 or more service dates of data between `prediction_accuracy_monolithic` and `prediction_accuracy_partitioned`.

  Works in both directions for up/down migrations.

  If the service dates to be copied include one less than @min_days_in_past_for_finalize
  before the current date, the job does not copy anything.
  """
  use Oban.Worker,
    max_attempts: 3,
    unique: [states: :incomplete]

  require Logger
  import Ecto.Query
  alias PredictionAnalyzer.Repo

  config =
    Application.compile_env!(:prediction_analyzer, :prediction_accuracy_migration)
    |> Map.new()

  @monolithic config.monolithic
  @partitioned config.partitioned
  @migration_state config.migration_state
  @copy_duration config.copy_duration
  @min_days_in_past_for_finalize config.min_days_in_past_for_finalize
  @copy_data_timeout config.copy_data_timeout

  # Some napkin math:
  #     iex> total_row_count = 803_000_000
  #     iex> service_dates_covered = Date.diff(Date.utc_today(), ~D[2018-10-01])
  #     2_730
  # Estimating number of rows copied per job run (i.e., number of rows per week of service dates)
  #     iex> round(total_row_count / service_dates_covered * 7)
  #     2_058_974
  # Estimating time to reach present day:
  #     iex> total_minutes = ceil(service_dates_covered / 7) * 2
  #     780
  #     iex> total_hours = ceil(total_minutes / 60)
  #     13

  @impl Oban.Worker
  def timeout(_job), do: @copy_data_timeout

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    Logger.info("prediction_accuracy_migration_job_start")

    with :ok <- check_migration_state(args) do
      {time_us, result} =
        :timer.tc(fn ->
          Repo.transact(fn -> do_perform(args) end, timeout: @copy_data_timeout)
        end)

      log_result(result, System.convert_time_unit(time_us, :microsecond, :millisecond))

      result
    end
  end

  defp do_perform(args) do
    with {:ok, today} <- get_today(args),
         {:ok, first_date, last_date} <- get_copy_date_range(args),
         {:ok, :safe} <- check_last_date(last_date, today),
         {:ok, direction, from_table, to_table} <- get_migration_direction(args),
         {:ok, next_start} <- copy_data(first_date, last_date, direction, from_table, to_table) do
      update_service_date(next_start)
    end
  end

  defp log_result({:ok, _}, time_ms) do
    Logger.info("prediction_accuracy_migration_job_success elapsed_ms=#{time_ms}")
  end

  defp log_result({:error, exception}, _) when is_exception(exception) do
    msg = Exception.format(:error, exception)
    Logger.info("prediction_accuracy_migration_job_error #{msg}")
  end

  defp log_result({:error, term}, _) do
    Logger.info("prediction_accuracy_migration_job_error #{inspect(term)}")
  end

  defp copy_data(first_date, last_date, dir, from_table, to_table) do
    Repo.query(
      "INSERT INTO #{to_table} SELECT * FROM #{from_table} origin WHERE origin.service_date BETWEEN '#{first_date}' AND '#{last_date}'",
      [],
      timeout: @copy_data_timeout
    )
    |> case do
      {:ok, %{num_rows: num_rows}} ->
        Logger.info(
          "prediction_accuracy_migration_worker_copied_service_date from=#{first_date} to=#{last_date} num_rows_copied=#{num_rows} migration_direction=#{dir} "
        )

        {:ok, Date.add(last_date, 1)}

      err ->
        err
    end
  end

  @spec check_last_date(Date.t(), Date.t()) :: {:ok, :safe} | {:ok, :skip}
  defp check_last_date(last_date, today) do
    if Date.diff(today, last_date) >= @min_days_in_past_for_finalize do
      {:ok, :safe}
    else
      Logger.info(
        "prediction_accuracy_migration_job_skipped_copy reason=too_close_to_today service_date=#{last_date}"
      )

      {:ok, :skip}
    end
  end

  defp update_service_date(next_service_date) do
    case Repo.update_all(@migration_state, set: [cur_service_date: next_service_date]) do
      {1, nil} ->
        {:ok, :success}

      _ ->
        {:error, "Unexpected result when updating service date in #{@migration_state}"}
    end
  end

  @spec get_today(map) :: {:ok, Date.t()} | {:error, String.t()}
  defp get_today(%{"today" => datestamp}), do: parse_date(datestamp, "bad_today_date")
  defp get_today(%{}), do: {:ok, Date.utc_today()}

  @spec get_copy_date_range(map) :: {:ok, Date.t(), Date.t()} | {:error, String.t()}
  defp get_copy_date_range(%{"service_date" => datestamp}) do
    with {:ok, first_date} <- parse_date(datestamp, "bad_service_date") do
      last_date = Date.shift(first_date, @copy_duration)
      {:ok, first_date, last_date}
    end
  end

  defp get_copy_date_range(%{}) do
    case Repo.one(from(state in @migration_state, select: state.cur_service_date)) do
      nil ->
        {:error, "prediction_accuracy_migration_state_table_empty"}

      first_date ->
        last_date = Date.shift(first_date, @copy_duration)
        {:ok, first_date, last_date}
    end
  end

  defp get_migration_direction(%{"direction" => "up"}) do
    {:ok, :up, @monolithic, @partitioned}
  end

  defp get_migration_direction(%{"direction" => "down"}) do
    {:ok, :down, @partitioned, @monolithic}
  end

  defp get_migration_direction(%{}) do
    case Repo.one(from(state in @migration_state, select: state.direction)) do
      nil -> {:error, "prediction_accuracy_migration_state_table_empty"}
      direction -> get_migration_direction(%{"direction" => direction})
    end
  end

  defp parse_date(datestamp, error_label) do
    case Date.from_iso8601(datestamp) do
      {:error, reason} -> {:error, ~s(#{error_label} arg="#{datestamp}" reason=#{reason})}
      {:ok, _date} = ok -> ok
    end
  end

  defp check_migration_state(args) do
    if match?(%{"service_date" => _, "direction" => _}, args) or table_exists?(@migration_state) do
      :ok
    else
      Logger.info(
        "prediction_accuracy_migration_job_canceled reason=\"table #{@migration_state} does not exist\""
      )

      {:cancel, "table #{@migration_state} does not exist"}
    end
  end

  defp table_exists?(name) do
    PredictionAnalyzer.Repo.exists?(
      from(t in "tables", where: t.table_schema == "public", where: t.table_name == ^name),
      prefix: "information_schema"
    )
  end
end
