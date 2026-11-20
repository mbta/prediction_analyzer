defmodule PredictionAnalyzer.Repo.Migrations.CreateMonthlySummaryTable do
  use Ecto.Migration

  def change do
    create table("prediction_accuracy_monthly_summary") do
      add(:date_start, :date, null: false)
      add(:date_end, :date, null: false)
      add(:query, :string, null: false)
      add(:num_predictions, :integer, null: false)
      add(:num_accurate, :integer, null: false)
      add(:mean_error, :real, null: false)
      add(:root_mean_squared_error, :real, null: false)
    end
  end
end
