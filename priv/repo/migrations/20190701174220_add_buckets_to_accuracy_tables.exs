defmodule PredictionAnalyzer.Repo.Migrations.AddBucketsToAccuracyTables do
  use Ecto.Migration
  # adding value to enum type can't be done in a transaction
  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    execute("alter type prediction_bin add value '6-8 min'")
    execute("alter type prediction_bin add value '8-10 min'")
    execute("alter type prediction_bin add value '10-12 min'")
  end

  def down do
    # can't remove an enum type value without recreating type and
    # updating all rows.
    raise Ecto.MigrationError
  end
end
