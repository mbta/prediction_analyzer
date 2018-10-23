defmodule PredictionAnalyzer.Repo.Migrations.AddVehicleEventsTable do
  use Ecto.Migration

  def change do
    create table("vehicle_events", primary_key: true) do
      add(:vehicle_id, :string)
      add(:vehicle_label, :string)
      add(:is_deleted, :boolean)
      add(:route_id, :string)
      add(:direction_id, :integer)
      add(:trip_id, :string)
      add(:stop_id, :string)
      add(:arrival_time, :integer)
      add(:departure_time, :integer)
    end
  end
end
