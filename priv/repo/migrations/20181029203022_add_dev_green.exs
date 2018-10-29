defmodule PredictionAnalyzer.Repo.Migrations.AddDevGreen do
  use Ecto.Migration

  def up do
    execute("create type environment as enum ('prod', 'dev-green')")

    alter table("prediction_accuracy") do
      add(:environment, :environment, null: false, default: "prod")
    end

    alter table("vehicle_events") do
      add(:environment, :environment, null: false, default: "prod")
    end

    alter table("predictions") do
      add(:environment, :environment, null: false, default: "prod")
    end
  end

  def down do
    alter table("prediction_accuracy") do
      remove(:environment)
    end

    alter table("vehicle_events") do
      remove(:environment)
    end

    alter table("predictions") do
      remove(:environment)
    end

    execute("drop type environment")
  end
end
