defmodule PredictionAnalyzer.Repo.Migrations.AddIndexOnVehicleIdPredictions do
  use Ecto.Migration
  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create(index("predictions", [:vehicle_id], concurrently: true))
  end
end
