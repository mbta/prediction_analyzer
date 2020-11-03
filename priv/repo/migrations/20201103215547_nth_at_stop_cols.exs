defmodule PredictionAnalyzer.Repo.Migrations.NthAtStopCols do
  use Ecto.Migration

  def change do
    alter(table("predictions"), do: add(:nth_at_stop, :integer))
    alter(table("prediction_accuracy"), do: add(:in_next_two, :boolean))
  end
end
