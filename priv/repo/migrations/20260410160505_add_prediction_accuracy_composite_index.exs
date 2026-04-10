defmodule PredictionAnalyzer.Repo.Migrations.AddPredictionAccuracyCompositeIndex do
  use Ecto.Migration
  import Ecto.Query

  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    # The `CONCURRENTLY` option is not supported for partitioned tables,
    # so we need to take a more manual approach:
    # 1. Create the index on the parent table only, non-concurrently.
    #    This makes a metadata-only index that starts out in an "invalid" state. (A fast operation.)
    # 2. Create an index concurrently on each partition table.
    # 3. Attach each concurrently-building partition index to the index on the parent table.
    #
    # The parent table index automatically becomes valid once all partition tables
    # have attached their own indexes to it.
    parent_idx_name = "prediction_accuracy_partitioned_composite_idx"

    partitions =
      from("pg_inherits",
        where: [inhparent: fragment("'prediction_accuracy_partitioned'::regclass")],
        select: fragment("inhrelid::regclass::text")
      )
      |> PredictionAnalyzer.Repo.all(prefix: "pg_catalog")

    create index("prediction_accuracy_partitioned", [:route_id, :environment, :service_date],
             name: parent_idx_name,
             only: true
           )

    for partition <- partitions do
      partition_idx_name = "#{partition}_composite_idx"

      create index(partition, [:route_id, :environment, :service_date],
               name: partition_idx_name,
               concurrently: true
             )

      execute(fn ->
        repo().query!("ALTER INDEX #{parent_idx_name} ATTACH PARTITION #{partition_idx_name}")
      end)
    end
  end

  def down do
    drop index(:prediction_accuracy_partitioned, [:route_id, :environment, :service_date])
  end
end
