defmodule PredictionAnalyzer.VehicleEvents.VehicleEvent do
  use Ecto.Schema

  import Ecto.Changeset

  schema "vehicle_events" do
    field(:vehicle_id, :string)
    field(:environment, :string)
    field(:vehicle_label, :string)
    field(:is_deleted, :boolean)
    field(:route_id, :string)
    field(:direction_id, :integer)
    field(:trip_id, :string)
    field(:stop_id, :string)
    field(:arrival_time, :integer)
    field(:departure_time, :integer)
  end

  def changeset(vehicle_event, params \\ %{}) do
    fields = [
      :vehicle_id,
      :environment,
      :vehicle_label,
      :is_deleted,
      :route_id,
      :direction_id,
      :trip_id,
      :stop_id,
      :arrival_time
    ]

    vehicle_event
    |> cast(params, fields)
    |> validate_required(fields)
  end
end
