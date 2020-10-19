defmodule PredictionAnalyzer.Repo.Migrations.DropWeeklyAccuracies do
  use Ecto.Migration

  def up do
    drop(table(:weekly_accuracies))
  end

  def down do
    create table(:weekly_accuracies) do
      add(:week_start, :date, null: false)
      add(:stop_id, :string, null: false)
      add(:route_id, :string, null: false)
      add(:arrival_departure, :arrival_departure, null: false)
      add(:bin, :prediction_bin, null: false)
      add(:num_predictions, :integer, null: false)
      add(:num_accurate_predictions, :integer, null: false)
      add(:environment, :environment)
      add(:direction_id, :integer)
      add(:mean_error, :real)
      add(:root_mean_squared_error, :real)
    end

    create(index(:weekly_accuracies, [:week_start]))
  end
end
