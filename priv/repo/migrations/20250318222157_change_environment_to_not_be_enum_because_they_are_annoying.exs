defmodule PredictionAnalyzer.Repo.Migrations.ChangeEnvironmentToNotBeEnumBecauseTheyAreAnnoying do
  use Ecto.Migration

  def change do
    execute("alter table prediction_accuracy alter column environment TYPE varchar")
    execute("alter table vehicle_events alter column environment TYPE varchar")
    execute("alter table predictions alter column environment TYPE varchar")
  end
end
