defmodule PredictionAnalyzer.Repo.Migrations.AddMseRmseColumns do
  use Ecto.Migration

  def change do
    alter table("prediction_accuracy") do
      add(:mean_error, :real, null: false, default: 0.0)
      add(:root_mean_squared_error, :real, null: false, default: 0.0)
    end

    alter table("weekly_accuracies") do
      add(:mean_error, :real, null: false, default: 0.0)
      add(:root_mean_squared_error, :real, null: false, default: 0.0)
    end
  end
end
