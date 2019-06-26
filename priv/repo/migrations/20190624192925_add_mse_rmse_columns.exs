defmodule PredictionAnalyzer.Repo.Migrations.AddMseRmseColumns do
  use Ecto.Migration

  def change do
    alter table("prediction_accuracy") do
      add(:mean_error, :real)
      add(:root_mean_squared_error, :real)
    end

    alter table("weekly_accuracies") do
      add(:mean_error, :real)
      add(:root_mean_squared_error, :real)
    end
  end
end
