defmodule PredictionAnalyzer.Repo.Migrations.AddNecessaryIndexes do
  use Ecto.Migration
  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create(index("vehicle_events", [:arrival_time], concurrently: true))
    create(index("vehicle_events", [:departure_time], concurrently: true))

    create(
      index("predictions", [:trip_id], where: "vehicle_event_id is null", concurrently: true)
    )
  end
end
