defmodule PredictionAnalyzer.Repo.Migrations.AddVehicleEventIdToPredictions do
  use Ecto.Migration

  def change do
    alter table("predictions") do
      add(:vehicle_event_id, :id)
    end
  end
end
