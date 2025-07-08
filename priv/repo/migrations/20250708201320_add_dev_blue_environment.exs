defmodule PredictionAnalyzer.Repo.Migrations.AddDevBlueEnvironment do
  use Ecto.Migration

  def up do
    execute("ALTER TYPE environment ADD VALUE 'dev-blue'")
  end

  def down do
    raise "Cannot remove values from enums"
  end
end
