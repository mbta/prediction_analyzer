defmodule PredictionAnalyzer.Repo.Migrations.AddDirectionIdToPredictionsAndPredictionAccuracy do
  use Ecto.Migration

  def change do
    alter table("predictions") do
      add(:direction_id, :integer)
    end

    alter table("prediction_accuracy") do
      add(:direction_id, :integer)
    end
  end
end
