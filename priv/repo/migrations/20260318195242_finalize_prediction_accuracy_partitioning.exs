defmodule PredictionAnalyzer.Repo.Migrations.FinalizePredictionAccuracyPartitioning do
  @moduledoc """
  Completes the partitioning of `prediction_accuracy`.

  ## Instructions for local development

  This migration will fail if some data still needs to be copied to the partitioned table.

  To complete the migration quickly, do the following:
  1. Rename this file to 20260318195242_finalize_prediction_accuracy_partitioning.exs.disabled
     to prevent the migrator from running it automatically.
  2. In config.exs, change `:prediction_accuracy_migration` ->`:copy_duration` to something big,
     like `[year: 5]`.
  3. Configure the migration job to run every minute: In config.exs, add or modify the Oban crontab entry:
     ```
     config :prediction_analyzer, Oban,
       plugins: [
         {Oban.Plugins.Cron,
          crontab: [
            {"* * * * *", PredictionAnalyzer.Jobs.PredictionAccuracyDataMigrationWorker}
          ]}
       ]
     ```
  4. Call `iex -S mix` and wait until you see "prediction_accuracy_migration_job_skipped_copy" printed.
  5. Remove `.disabled` from this filename and run `mix ecto.migrate`. The migration should complete.
  6. Undo config changes made in steps 2 and 3. You're all set.

  Note that running this migration in the "down" direction (i.e. `ecto.rollback`)
  will start the incremental data migration in the reverse direction, and cannot be
  undone until the data is migrated and the migration preceding this one is run in the "down"
  direction.
  """
  use Ecto.Migration
  import Ecto.Query

  alias PredictionAnalyzer.PredictionAccuracy.PredictionAccuracy

  config =
    Application.compile_env!(:prediction_analyzer, :prediction_accuracy_migration)
    |> Map.new()

  @monolithic config.monolithic
  @partitioned config.partitioned
  @migration_state config.migration_state
  @copy_data_timeout config.copy_data_timeout
  @copy_duration config.copy_duration
  @min_days_in_past_for_finalize config.min_days_in_past_for_finalize

  def up do
    cur_service_date = check_up_migration_state!()

    # Copy data over for the remaining service dates up to the present.
    execute(fn ->
      repo().query!(
        "INSERT INTO #{@partitioned} SELECT * FROM #{@monolithic} WHERE service_date >= '#{cur_service_date}'::date",
        [],
        timeout: @copy_data_timeout
      )
    end)

    execute(&assert_equal_row_counts!/0)

    # Update the id sequence after copying so that it doesn't cause PK conflicts on future inserts.
    execute("SELECT setval('#{@partitioned}_id_seq', (SELECT max(id) FROM #{@partitioned}))")

    # Re-point the view from the monolithic to the partitioned table.
    execute("CREATE OR REPLACE VIEW prediction_accuracy AS SELECT * FROM #{@partitioned}")

    drop table(@monolithic)
    drop table(@migration_state)
  end

  defp check_up_migration_state! do
    today = Date.utc_today()
    q = from(@migration_state, select: [:cur_service_date, :direction])

    case PredictionAnalyzer.Repo.one(q) do
      nil ->
        raise "table #{@migration_state} does not exist or is empty, did you run preceding migrations in the up direction?"

      %{direction: "down"} ->
        raise "incremental data migration is still in progress in the 'down' direction, cannot continue with up migration"

      %{
        cur_service_date: cur_service_date,
        direction: "up"
      } ->
        copy_window_end = Date.shift(cur_service_date, @copy_duration)

        if Date.diff(today, copy_window_end) < @min_days_in_past_for_finalize do
          cur_service_date
        else
          raise "data has not finished copying to the partitioned table, " <>
                  "cannot continue with up migration. cur_service_date=#{cur_service_date}"
        end
    end
  end

  ##################################################

  def down do
    :ok = check_down_migration_state!()

    [
      # Create new table, copying column names, types, nullability, and defaults from original.
      """
      CREATE TABLE #{@monolithic} (
                LIKE #{@partitioned} INCLUDING DEFAULTS,
                CONSTRAINT #{@monolithic}_pkey PRIMARY KEY (id)
            )
      """,
      # Re-add indexes.
      "CREATE INDEX #{@monolithic}_service_date_index ON #{@monolithic} USING btree (service_date)",
      "CREATE INDEX #{@monolithic}_stop_id_index ON #{@monolithic} USING btree (stop_id)",
      # Replace the auto-incrementing id sequence with a new one, to fully decouple the old and new tables.
      """
      CREATE SEQUENCE #{@monolithic}_id_seq
          START WITH 1
          INCREMENT BY 1
          NO MINVALUE
          NO MAXVALUE
          CACHE 1
      """,
      "ALTER SEQUENCE #{@monolithic}_id_seq OWNED BY #{@monolithic}.id",
      "ALTER TABLE ONLY #{@monolithic} ALTER COLUMN id SET DEFAULT nextval('#{@monolithic}_id_seq'::regclass)"
    ]
    |> Enum.each(&execute/1)

    create table(@migration_state) do
      add :cur_service_date, :date, null: false
      add :direction, :string, null: false
    end

    execute(fn ->
      utc_today = Date.utc_today()

      earliest_service_date_q = from(p in PredictionAccuracy, select: min(p.service_date))
      service_date0 = repo().one(earliest_service_date_q) || utc_today

      PredictionAnalyzer.Repo.insert_all(
        @migration_state,
        List.wrap(%{cur_service_date: service_date0, direction: "down"})
      )
    end)
  end

  defp check_down_migration_state! do
    if table_exists?(@migration_state) do
      map =
        PredictionAnalyzer.Repo.one(
          from(@migration_state, select: [:cur_service_date, :direction])
        )

      raise "table #{@migration_state} must not exist for down migration to run, but exists with values: #{inspect(map)}"
    else
      :ok
    end
  end

  defp table_exists?(name) do
    PredictionAnalyzer.Repo.exists?(
      from(t in "tables", where: t.table_schema == "public", where: t.table_name == ^name),
      prefix: "information_schema"
    )
  end

  defp assert_equal_row_counts! do
    monolithic_count = PredictionAnalyzer.Repo.one!(from(@monolithic, select: count()))
    partitioned_count = PredictionAnalyzer.Repo.one!(from(@partitioned, select: count()))

    if monolithic_count != partitioned_count do
      # (This stops further execution of the transaction.)
      PredictionAnalyzer.Repo.rollback(
        "mismatched_row_counts_after_finishing_copy monolithic_count=#{monolithic_count} partitioned_count=#{partitioned_count}"
      )
    end
  end
end
