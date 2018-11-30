defmodule PredictionAnalyzer.Repo.Migrations.AddVehicleIdToPredictions do
  use Ecto.Migration

  def change do
    alter table("predictions") do
      add(:vehicle_id, :string)
    end

    create(index("predictions", [:vehicle_id]))
  end
end
