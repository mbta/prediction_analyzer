defmodule PredictionAnalyzer.Repo.Migrations.AddMinuteOfHour do
  use Ecto.Migration

  def change do
    alter table(:prediction_accuracy) do
      add(:minute_of_hour, :integer, null: false, default: 0)
    end
  end
end
