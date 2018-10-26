defmodule PredictionAnalyzer.Repo.Migrations.NonNullPredictionFileTimestamp do
  use Ecto.Migration

  def up do
    PredictionAnalyzer.Repo.query("TRUNCATE predictions", [])

    alter table("predictions") do
      modify(:file_timestamp, :integer, null: false)
    end
  end

  def down do
    alter table("predictions") do
      modify(:file_timestamp, :integer, null: true)
    end
  end
end
