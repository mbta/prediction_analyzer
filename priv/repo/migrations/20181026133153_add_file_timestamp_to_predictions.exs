defmodule PredictionAnalyzer.Repo.Migrations.AddFileTimestampToPredictions do
  use Ecto.Migration

  def change do
    alter table("predictions") do
      add :file_timestamp, :integer
    end

    create index("predictions", [:file_timestamp])
  end
end
