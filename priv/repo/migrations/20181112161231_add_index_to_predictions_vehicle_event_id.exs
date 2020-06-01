defmodule PredictionAnalyzer.Repo.Migrations.AddIndexToPredictionsVehicleEventId do
  use Ecto.Migration
  @disable_ddl_transaction true

  def change do
    create(index("predictions", [:vehicle_event_id], concurrently: true))
  end
end
