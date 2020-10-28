defmodule PredictionAnalyzer.Predictions.Prediction do
  use Ecto.Schema
  alias PredictionAnalyzer.VehicleEvents.VehicleEvent

  schema "predictions" do
    field(:file_timestamp, :integer)
    field(:environment, :string)
    field(:trip_id, :string)
    field(:vehicle_id, :string)
    field(:is_deleted, :boolean)
    field(:delay, :integer)
    field(:arrival_time, :integer)
    field(:boarding_status, :string)
    field(:departure_time, :integer)
    field(:schedule_relationship, :string)
    field(:stop_id, :string)
    field(:route_id, :string)
    field(:stop_sequence, :integer)
    field(:stops_away, :integer)
    field(:direction_id, :integer)
    belongs_to(:vehicle_event, VehicleEvent)
  end
end
