defmodule PredictionAnalyzer.Repo.Migrations.AddDevBlue do
  use Ecto.Migration

  def change do
    execute("alter type environment add value 'dev-blue'")
  end
end
