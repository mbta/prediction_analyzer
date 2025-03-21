defmodule PredictionAnalyzer.Repo.Migrations.AdjustIndexes do
  use Ecto.Migration
  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    drop(index(:predictions, :trip_id, where: "vehicle_event_id IS NULL", concurrently: true))
    drop(index(:predictions, :vehicle_id, concurrently: true))
    create(index(:vehicle_events, :stop_id, where: "departure_time IS NULL", concurrently: true))

    create(
      index(:vehicle_events, :vehicle_id, where: "departure_time IS NULL", concurrently: true)
    )

    create(index(:predictions, :stop_id, where: "vehicle_event_id IS NULL", concurrently: true))

    create(
      index(:predictions, :vehicle_id, where: "vehicle_event_id IS NULL", concurrently: true)
    )

    create(index(:prediction_accuracy, :stop_id, concurrently: true))
  end
end
