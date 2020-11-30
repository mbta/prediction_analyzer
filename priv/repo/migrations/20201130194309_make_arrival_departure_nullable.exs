defmodule PredictionAnalyzer.Repo.Migrations.MakeArrivalDepartureNullable do
  use Ecto.Migration

  def up do
    alter table(:prediction_accuracy) do
      modify(:arrival_departure, :arrival_departure, null: true)
    end
  end

  def down do
    alter table(:prediction_accuracy) do
      modify(:arrival_departure, :arrival_departure, null: false)
    end
  end
end
