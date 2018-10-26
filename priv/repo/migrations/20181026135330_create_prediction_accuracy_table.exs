defmodule PredictionAnalyzer.Repo.Migrations.CreatePredictionAccuracyTable do
  use Ecto.Migration

  def up do
    execute("create type arrival_departure as enum ('arrival', 'departure')")
    execute("create type prediction_bin as enum ('0-3 min', '3-6 min', '6-12 min', '12-30 min')")

    create table("prediction_accuracy") do
      add :service_date, :date, null: false
      add :hour_of_day, :integer, null: false
      add :stop_id, :string, null: false
      add :route_id, :string, null: false
      add :arrival_departure, :arrival_departure, null: false
      add :bin, :prediction_bin, null: false
      add :num_predictions, :integer, null: false
      add :num_accurate_predictions, :integer, null: false
    end

    create index("prediction_accuracy", [:service_date])
  end

  def down do
    drop table("prediction_accuracy")
    execute("drop type prediction_bin")
    execute("drop type arrival_departure")
  end
end
