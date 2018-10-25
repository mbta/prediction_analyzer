defmodule PredictionAnalyzer.Repo.Migrations.AddVehicleEventIdToPredictions do
  use Ecto.Migration

  def change do
    alter table("predictions") do
      add(:vehicle_event_id, references("vehicle_events"), on_delete: :delete_all)
    end
  end
end
