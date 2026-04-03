defmodule PredictionAnalyzer.Repo.Migrations.PartitionPredictionAccuracyByServiceDate do
  @moduledoc """
  This migration sets up the schema for a new partitioned version of `prediction_accuracy`,
  but does not move data over yet. The table is too large to make the change all at once.

  Each partition holds data for 1 week (MON - SUN) of service dates.

  See `PredictionAnalyzer.Jobs.PredictionAccuracyDataMigrationWorker` for the cron job
  that copies data over to the new table one service date at a time.

  See `PredictionAnalyzer.Repo.Migrations.FinalizePredictionAccuracyPartitioning` for the migration that completes the switch
  to the new partitioned table.

  Note that running this migration in the "up" direction (i.e. `ecto.migrate`)
  will start the incremental data migration, and cannot be undone until the data is
  migrated and the migration following this one is run in the "up" direction.
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

  def up do
    :ok = check_up_migration_state!()

    ####################
    # Set up new table #
    ####################

    [
      # Create new table, copying column names, types, nullability, and defaults from original.
      """
      CREATE TABLE #{@partitioned} (
                LIKE #{@monolithic} INCLUDING DEFAULTS,
                CONSTRAINT #{@partitioned}_pkey PRIMARY KEY (id, service_date)
            )
            PARTITION BY RANGE (service_date)
      """,
      # Re-add indexes.
      "CREATE INDEX #{@partitioned}_service_date_index ON #{@partitioned} USING btree (service_date)",
      "CREATE INDEX #{@partitioned}_stop_id_index ON #{@partitioned} USING btree (stop_id)",
      # Replace the auto-incrementing id sequence with a new one, to fully decouple the old and new tables.
      """
      CREATE SEQUENCE #{@partitioned}_id_seq
          START WITH 1
          INCREMENT BY 1
          NO MINVALUE
          NO MAXVALUE
          CACHE 1
      """,
      "ALTER SEQUENCE #{@partitioned}_id_seq OWNED BY #{@partitioned}.id",
      "ALTER TABLE ONLY #{@partitioned} ALTER COLUMN id SET DEFAULT nextval('#{@partitioned}_id_seq'::regclass)"
    ]
    |> Enum.each(&execute/1)

    ###############################################################
    # Create a table to track state of incremental data migration #
    ###############################################################

    create table(@migration_state) do
      add :cur_service_date, :date, null: false
      add :direction, :string, null: false
    end

    #######################
    # Set up child tables #
    #######################

    # We get today in UTC, which will always be >= the current service date.
    #
    # This is fine because the goal is to create partitions up to 1 past the
    # partition that includes the current service date.
    # In the worst case (service date is at the very end of a partition range, and UTC today is on the following date),
    # we would just create 1 more partition than needed right now.
    utc_today = Date.utc_today()

    earliest_service_date_q = from(p in PredictionAccuracy, select: min(p.service_date))
    service_date0 = repo().one(earliest_service_date_q) || utc_today

    lbound_inclusive0 = Date.beginning_of_week(service_date0)
    ubound_exclusive0 = Date.shift(lbound_inclusive0, week: 1)

    execute_create_child_tables(lbound_inclusive0, ubound_exclusive0, utc_today)

    ###############################################
    # Initialize incremental data migration state #
    ###############################################

    execute(fn ->
      PredictionAnalyzer.Repo.insert_all(
        @migration_state,
        List.wrap(%{cur_service_date: service_date0, direction: "up"})
      )
    end)
  end

  # Creates children of the partitioned table for date ranges:
  # range0(includes earliest service_date), range1, ..., rangeN-1(includes utc_today), rangeN
  defp execute_create_child_tables(lbound_inclusive0, ubound_exclusive0, utc_today) do
    {lbound_inclusive0, ubound_exclusive0}
    |> Stream.iterate(fn {_, ubound_exclusive} ->
      {ubound_exclusive, Date.shift(ubound_exclusive, week: 1)}
    end)
    |> take_until_and_including(fn {lbound_inclusive, _} ->
      Date.after?(lbound_inclusive, utc_today)
    end)
    |> Enum.each(&execute_create_attach_child_table/1)

    execute_create_attach_default_child_table()
  end

  defp execute_create_attach_child_table({lbound_inclusive, ubound_exclusive}) do
    suffix = Calendar.strftime(lbound_inclusive, "week_of_%Y_%m_%d")

    execute("""
    CREATE TABLE prediction_accuracy_partition_#{suffix}
        PARTITION OF #{@partitioned}
        FOR VALUES FROM ('#{lbound_inclusive}') TO ('#{ubound_exclusive}')
    """)
  end

  defp execute_create_attach_default_child_table do
    # Default partition will not be used, except:
    # - by test cases, or
    # - if we for some reason insert rows with service dates earlier than the
    #   current oldest service date in the table.
    execute("""
    CREATE TABLE prediction_accuracy_partition_default
        PARTITION OF #{@partitioned} DEFAULT
    """)
  end

  # Behaves like:
  #     Enum.take_while(enumerable, &not(end_condition?.(&1)))
  # but also takes the first value for which `end_condition?` returns true.
  defp take_until_and_including(enumerable, end_condition?) do
    Enum.reduce_while(enumerable, [], fn el, acc ->
      if end_condition?.(el),
        do: {:halt, Enum.reverse([el | acc])},
        else: {:cont, [el | acc]}
    end)
  end

  defp check_up_migration_state! do
    if table_exists?(@migration_state) do
      map =
        PredictionAnalyzer.Repo.one(
          from(@migration_state, select: [:cur_service_date, :direction])
        )

      raise "table #{@migration_state} must not exist for up migration to run, but exists with values: #{inspect(map)}"
    else
      :ok
    end
  end

  ##################################################

  @copy_data_timeout config.copy_data_timeout
  @copy_duration config.copy_duration
  @min_days_in_past_for_finalize config.min_days_in_past_for_finalize

  def down do
    cur_service_date = check_down_migration_state!()

    # Copy data over for the remaining service dates up to the present.
    execute(fn ->
      repo().query!(
        "INSERT INTO #{@monolithic} SELECT * FROM #{@partitioned} WHERE service_date >= '#{cur_service_date}'::date",
        [],
        timeout: @copy_data_timeout
      )
    end)

    execute(&assert_equal_row_counts!/0)

    # Update the id sequence after copying so that it doesn't cause PK conflicts on future inserts.
    execute("SELECT setval('#{@monolithic}_id_seq', (SELECT max(id) FROM #{@monolithic}))")

    execute(fn -> repo().query!("ANALYZE #{@monolithic}", [], timeout: :timer.minutes(30)) end)

    # Re-point the view from the partitioned to the monolithic table.
    execute("CREATE OR REPLACE VIEW prediction_accuracy AS SELECT * FROM #{@monolithic}")

    drop table(@partitioned)
    drop table(@migration_state)
  end

  defp check_down_migration_state! do
    today = Date.utc_today()
    q = from(@migration_state, select: [:cur_service_date, :direction])

    case PredictionAnalyzer.Repo.one(q) do
      nil ->
        raise "table #{@migration_state} does not exist, did you run subsequent migrations in the down direction?"

      %{direction: "up"} ->
        raise "incremental data migration is still in progress in the 'up' direction, cannot continue with down migration"

      %{
        cur_service_date: cur_service_date,
        direction: "down"
      } ->
        copy_window_end = Date.shift(cur_service_date, @copy_duration)

        if Date.diff(today, copy_window_end) < @min_days_in_past_for_finalize do
          cur_service_date
        else
          raise "data has not finished copying back to the monolithic table, " <>
                  "cannot continue with down migration. cur_service_date=#{cur_service_date}"
        end
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
