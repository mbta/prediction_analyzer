defmodule PredictionAnalyzer.VehiclePositions.Vehicle do
  @moduledoc """
  Represents a vehicle that we track the position of.
  """

  @enforce_keys [
    :id,
    :label,
    :is_deleted,
    :trip_id,
    :route_id,
    :direction_id,
    :current_status,
    :stop_id
  ]

  defstruct @enforce_keys

  @type vehicle_id :: String.t()

  @type t :: %__MODULE__{
          id: vehicle_id,
          label: String.t(),
          is_deleted: boolean(),
          trip_id: String.t(),
          route_id: String.t(),
          direction_id: 0 | 1,
          current_status: :INCOMING_AT | :IN_TRANSIT_TO | :STOPPED_AT
        }

  @spec from_json(map()) :: {:ok, t()} | :error
  def from_json(%{
        "is_deleted" => is_deleted,
        "vehicle" => %{
          "current_status" => current_status,
          "stop_id" => stop_id,
          "trip" => %{
            "direction_id" => direction_id,
            "route_id" => route_id,
            "trip_id" => trip_id
          },
          "vehicle" => %{
            "id" => id,
            "label" => label
          }
        }
      })
      when is_boolean(is_deleted) and is_binary(stop_id) and is_binary(route_id) and
             is_binary(trip_id) and is_binary(id) and is_binary(label) and direction_id in [0, 1] and
             current_status in ["INCOMING_AT", "IN_TRANSIT_TO", "STOPPED_AT"] do

    vehicle = %__MODULE__{
      id: id,
      label: label,
      is_deleted: is_deleted,
      trip_id: trip_id,
      route_id: route_id,
      direction_id: direction_id,
      current_status: status_atom(current_status),
      stop_id: stop_id
    }

    {:ok, vehicle}
  end

  def from_json(_) do
    :error
  end

  defp status_atom("INCOMING_AT"), do: :INCOMING_AT
  defp status_atom("IN_TRANSIT_TO"), do: :IN_TRANSIT_TO
  defp status_atom("STOPPED_AT"), do: :STOPPED_AT
end
