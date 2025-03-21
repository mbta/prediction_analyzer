defmodule PredictionAnalyzer.Repo.Migrations.AddTripIdIndex do
  use Ecto.Migration
  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create(
      index("predictions", [:trip_id, :direction_id],
        where: "vehicle_event_id is null",
        concurrently: true
      )
    )
  end
end
