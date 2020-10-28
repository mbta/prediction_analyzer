defmodule PredictionAnalyzer.Repo.Migrations.AddKindToPredictions do
  use Ecto.Migration

  def change do
    execute(
      "CREATE TYPE prediction_kind AS enum('at_terminal', 'mid_trip', 'reverse')",
      "DROP TYPE prediction_kind"
    )

    alter(table("predictions"), do: add(:kind, :prediction_kind))
    alter(table("prediction_accuracy"), do: add(:kind, :prediction_kind))
  end
end
