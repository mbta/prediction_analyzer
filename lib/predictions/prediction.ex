defmodule PredictionAnalyzer.Prediction do
  use Ecto.Schema

  schema "predictions" do
    field(:trip_id, :string)
    field(:is_deleted, :boolean)
    field(:delay, :integer)
    field(:arrival_time, :integer)
    field(:boarding_status, :string)
    field(:departure_time, :integer)
    field(:schedule_relationship, :string)
    field(:stop_id, :string)
    field(:stop_sequence, :integer)
    field(:stops_away, :integer)
  end
end
