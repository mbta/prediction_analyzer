defmodule PredictionAnalyzer.Repo.Migrations.PartitionPredictionAccuracyByServiceDate do
  use Ecto.Migration
  import Ecto.Query

  alias PredictionAnalyzer.PredictionAccuracy.PredictionAccuracy

  @partition_size_months 2

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

    [
      # If copying to the partitioned table, it will automatically route each record to the appropriate child table.
      "INSERT INTO prediction_accuracy SELECT * FROM prediction_accuracy_old",
      # Update the id sequence after copying so that it doesn't cause PK conflicts on future inserts.
      "SELECT setval('prediction_accuracy_id_seq', (SELECT max(id) FROM prediction_accuracy))"
    ]
    |> Enum.each(&execute/1)

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

  defp create_child_tables do
    # For unclear reasons, the time zone database is not available during migrations.
    # So, we can't determine the current service date--it requires a localized "now" datetime.
    #
    # As a workaround, we use UTC today, which will always be >= the current service date.
    #
    # We create partitions up to and including the first one that starts _after_ UTC today,
    # ensuring records will have a child table to be routed to for at least
    # the next @partition_size_months.
    utc_today = Date.utc_today()

    earliest_service_date_q = from(p in PredictionAccuracy, select: min(p.service_date))
    service_date0 = repo().one(earliest_service_date_q)

    month = div(service_date0.month - 1, @partition_size_months) * @partition_size_months + 1

    lbound_inclusive0 = Date.new!(service_date0.year, month, 1)
    ubound_exclusive0 = Date.shift(lbound_inclusive0, month: @partition_size_months)

    {lbound_inclusive0, ubound_exclusive0}
    |> Stream.iterate(fn {_, ubound_exclusive} ->
      {ubound_exclusive, Date.shift(ubound_exclusive, month: @partition_size_months)}
    end)
    # Behaves like:
    #     |> Enum.take_while(fn {lbound_inclusive, _} -> not Date.after?(lbound_inclusive, utc_today) end)
    # except it also takes the first value for which the predicate returns false.
    |> Enum.reduce_while([], fn {lbound_inclusive, _} = range, acc ->
      if Date.after?(lbound_inclusive, utc_today),
        do: {:halt, Enum.reverse([range | acc])},
        else: {:cont, [range | acc]}
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
end
