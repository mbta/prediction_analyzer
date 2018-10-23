defmodule PredictionAnalyzer.Repo.Migrations.CreatePredictions do
  use Ecto.Migration

  def change do
    create table("predictions", primary_key: true) do
      add(:trip_id, :string)
      add(:is_deleted, :boolean)
      add(:delay, :integer)
      add(:arrival_time, :integer)
      add(:boarding_status, :string)
      add(:departure_time, :integer)
      add(:schedule_relationship, :string)
      add(:stop_id, :string)
      add(:stop_sequence, :integer)
      add(:stops_away, :integer)
    end
  end
end
