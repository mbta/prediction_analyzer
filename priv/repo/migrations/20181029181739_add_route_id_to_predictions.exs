defmodule PredictionAnalyzer.Repo.Migrations.AddRouteIdToPredictions do
  use Ecto.Migration

  def change do
    alter table("predictions") do
      add :route_id, :string
    end
  end
end
