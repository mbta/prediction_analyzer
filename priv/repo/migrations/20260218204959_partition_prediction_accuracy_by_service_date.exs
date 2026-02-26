defmodule PredictionAnalyzer.Repo.Migrations.PartitionPredictionAccuracyByServiceDate do
  use Ecto.Migration
  import Ecto.Query

  alias PredictionAnalyzer.PredictionAccuracy.PredictionAccuracy

  @partition_size_months Application.compile_env!(:prediction_analyzer, :partition_size_months)

  @copy_data_timeout :timer.minutes(5)

  def up, do: do_migration(pk_cols: "id, service_date", partitioned?: true)
  def down, do: do_migration(pk_cols: "id", partitioned?: false)

  defp do_migration(opts) do
    ###########
    # Prepare #
    ###########

    # Rename existing table and its dependent objects to make room for new ones.
    rename_old_table_and_objects()

    ####################
    # Set up new table #
    ####################

    [
      # Create new table, copying column names, types, nullability, and defaults from original.
      """
      CREATE TABLE prediction_accuracy (
                LIKE prediction_accuracy_old INCLUDING DEFAULTS,
                CONSTRAINT prediction_accuracy_pkey PRIMARY KEY (#{opts[:pk_cols]})
            )
            #{if opts[:partitioned?], do: "PARTITION BY RANGE (service_date)"}
      """,
      # Re-add indexes.
      "CREATE INDEX prediction_accuracy_service_date_index ON prediction_accuracy USING btree (service_date)",
      "CREATE INDEX prediction_accuracy_stop_id_index ON prediction_accuracy USING btree (stop_id)",
      # Replace the auto-incrementing id sequence with a new one, to fully decouple the old and new tables.
      """
      CREATE SEQUENCE prediction_accuracy_id_seq
          START WITH 1
          INCREMENT BY 1
          NO MINVALUE
          NO MAXVALUE
          CACHE 1
      """,
      "ALTER SEQUENCE prediction_accuracy_id_seq OWNED BY prediction_accuracy.id",
      "ALTER TABLE ONLY prediction_accuracy ALTER COLUMN id SET DEFAULT nextval('prediction_accuracy_id_seq'::regclass)"
    ]
    |> Enum.each(&execute/1)

    # Create the initial child tables of the partitioned table.
    # They inherit columns, defaults, constraints etc from the parent.
    if opts[:partitioned?], do: create_child_tables()

    ##################
    # Copy data over #
    ##################

    # If copying to the partitioned table, it will automatically route each record to the appropriate child table.
    execute(fn ->
      repo().query!(
        "INSERT INTO prediction_accuracy SELECT * FROM prediction_accuracy_old",
        [],
        timeout: @copy_data_timeout
      )
    end)

    # Update the id sequence after copying so that it doesn't cause PK conflicts on future inserts.
    execute(
      "SELECT setval('prediction_accuracy_id_seq', (SELECT max(id) FROM prediction_accuracy))"
    )

    ############
    # Clean up #
    ############

    execute("""
    DROP TABLE prediction_accuracy_old
    """)
  end

  defp rename_old_table_and_objects do
    [
      "ALTER SEQUENCE prediction_accuracy_id_seq RENAME TO prediction_accuracy_id_seq_old",
      "ALTER TABLE ONLY prediction_accuracy RENAME CONSTRAINT prediction_accuracy_pkey TO prediction_accuracy_pkey_old",
      "ALTER INDEX prediction_accuracy_service_date_index RENAME TO prediction_accuracy_service_date_index_old",
      "ALTER INDEX prediction_accuracy_stop_id_index RENAME TO prediction_accuracy_stop_id_index_old",
      "ALTER TABLE prediction_accuracy RENAME TO prediction_accuracy_old"
    ]
    |> Enum.each(&execute/1)
  end

  # Creates children of the partitioned table for date ranges:
  # range0(includes earliest service_date), range1, ..., rangeN-1(includes utc_today), rangeN
  defp create_child_tables do
    # We get today in UTC, which will always be >= the current service date.
    #
    # This is fine because the goal is to create partitions up to 1 past the
    # partition that includes the current service date.
    # In the worst case (service date is at the very end of a partition range, and UTC today is on the following date),
    # we would just create 1 more partition than needed right now.
    utc_today = Date.utc_today()

    earliest_service_date_q = from(p in PredictionAccuracy, select: min(p.service_date))
    service_date0 = repo().one(earliest_service_date_q)

    lbound_month =
      div(service_date0.month - 1, @partition_size_months) * @partition_size_months + 1

    lbound_inclusive0 = Date.new!(service_date0.year, lbound_month, 1)
    ubound_exclusive0 = Date.shift(lbound_inclusive0, month: @partition_size_months)

    {lbound_inclusive0, ubound_exclusive0}
    |> Stream.iterate(fn {_, ubound_exclusive} ->
      {ubound_exclusive, Date.shift(ubound_exclusive, month: @partition_size_months)}
    end)
    |> take_until_and_including(fn {lbound_inclusive, _} ->
      Date.after?(lbound_inclusive, utc_today)
    end)
    |> Enum.each(&create_attach_child_table/1)

    create_attach_default_child_table()
  end

  defp create_attach_child_table({lbound_inclusive, ubound_exclusive}) do
    execute("""
    CREATE TABLE prediction_accuracy_#{Calendar.strftime(lbound_inclusive, "y%Y_m%m")}
        PARTITION OF prediction_accuracy
        FOR VALUES FROM ('#{lbound_inclusive}') TO ('#{ubound_exclusive}')
    """)
  end

  defp create_attach_default_child_table do
    # Default partition will not be used, except:
    # - by test cases, or
    # - if we for some reason insert rows with service dates earlier than the
    #   current oldest service date in the table.
    execute("""
    CREATE TABLE prediction_accuracy_default
        PARTITION OF prediction_accuracy DEFAULT
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
end
