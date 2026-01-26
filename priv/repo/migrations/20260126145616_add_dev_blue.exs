defmodule PredictionAnalyzer.Repo.Migrations.AddDevBlue do
  use Ecto.Migration

  def up do
    execute("alter type environment add value if not exists 'dev-blue'")
  end

  def down do
    # dev-blue was added to the enum out-of-band in some prediction_analyzer envs,
    # prior to this migration's creation.
    # This is a one-way migration to ensure that the enum is consistent across all envs.
  end
end
