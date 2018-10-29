defmodule PredictionAnalyzer.Repo.Migrations.RequireRouteId do
  use Ecto.Migration

  def up do
    PredictionAnalyzer.Repo.query("TRUNCATE predictions", [])

    alter table("predictions") do
      modify(:route_id, :string, null: false)
    end
  end

  def down do
    alter table("predictions") do
      modify(:route_id, :string, null: true)
    end
  end
end
