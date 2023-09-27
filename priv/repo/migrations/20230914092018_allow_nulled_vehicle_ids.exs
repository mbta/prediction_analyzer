defmodule PredictionAnalyzer.Repo.Migrations.AllowNulledVehicleIds do
  use Ecto.Migration

  def up do
    alter table(:predictions) do
      modify(:vehicle_id, :string, null: true)
    end
  end

  def down do
    alter table(:predictions) do
      modify(:vehicle_id, :string, null: false)
    end
  end
end
