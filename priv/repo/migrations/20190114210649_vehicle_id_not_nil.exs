defmodule PredictionAnalyzer.Repo.Migrations.VehicleIdNotNil do
  use Ecto.Migration

  def change do
    alter table("predictions") do
      modify(:vehicle_id, :string, null: false)
    end
  end

  def down do
    alter table("predictions") do
      modify(:vehicle_id, :string, null: true)
    end
  end
end
