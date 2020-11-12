defmodule PredictionAnalyzer.Repo.Migrations.ConsolidateBins do
  use Ecto.Migration

  def up do
    execute("DELETE FROM prediction_accuracy WHERE bin IN ('8-10 min', '10-12 min')")
    execute("UPDATE prediction_accuracy SET bin = '6-12 min' WHERE bin = '6-8 min'")
  end

  def down do
    # operation isn't reversable
  end
end
