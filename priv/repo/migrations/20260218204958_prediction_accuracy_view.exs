defmodule PredictionAnalyzer.Repo.Migrations.PredictionAccuracyView do
  @moduledoc """
  Adds a layer of indirection to the `prediction_accuracy` table,
  to simplify subsequent migrations that partition the underlying table.
  """
  use Ecto.Migration

  def change do
    rename table("prediction_accuracy"), to: table("prediction_accuracy_monolithic")

    execute(
      "CREATE VIEW prediction_accuracy AS SELECT * FROM prediction_accuracy_monolithic",
      "DROP VIEW prediction_accuracy"
    )
  end
end
