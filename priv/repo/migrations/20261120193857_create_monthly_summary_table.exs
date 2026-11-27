defmodule PredictionAnalyzer.Repo.Migrations.CreateMonthlySummaryTable do
  use Ecto.Migration

  def change do
    create table("prediction_accuracy_monthly_summary") do
      add(:month, :date, null: false)
      add(:query, :string, null: false)
      add(:num_predictions, :integer, null: false)
      add(:num_accurate, :integer, null: false)
      add(:mean_error, :real, null: false)
      add(:rmse, :real, null: false)
    end
  end
end
