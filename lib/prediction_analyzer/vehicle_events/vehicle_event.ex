defmodule PredictionAnalyzer.VehicleEvents.VehicleEvent do
  use Ecto.Schema

  import Ecto.Changeset

  require Logger

  @type t :: %__MODULE__{
          vehicle_id: String.t(),
          environment: String.t(),
          vehicle_label: String.t(),
          is_deleted: boolean(),
          route_id: String.t(),
          direction_id: integer(),
          trip_id: String.t(),
          stop_id: String.t(),
          arrival_time: integer(),
          departure_time: integer()
        }

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

  @spec changeset(Ecto.Schema.t(), %{atom => any}) :: Ecto.Changeset.t()
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

    required_fields = fields |> Enum.reject(&(&1 == :arrival_time))

    vehicle_event
    |> cast(params, fields)
    |> validate_required(required_fields)
  end
end
