defmodule PredictionAnalyzer.VehiclePositions.Vehicle do
  @moduledoc """
  Represents a vehicle that we track the position of.
  """

  @enforce_keys [
    :id,
    :environment,
    :label,
    :is_deleted,
    :trip_id,
    :route_id,
    :direction_id,
    :current_status,
    :stop_id,
    :timestamp
  ]

  defstruct @enforce_keys

  @type vehicle_id :: String.t()

  @type t :: %__MODULE__{
          id: vehicle_id,
          environment: String.t(),
          label: String.t(),
          is_deleted: boolean(),
          trip_id: String.t(),
          route_id: String.t(),
          direction_id: 0 | 1,
          current_status: :INCOMING_AT | :IN_TRANSIT_TO | :STOPPED_AT,
          timestamp: integer()
        }

  @spec from_json(map(), String.t()) :: {:ok, t()} | :error
  def from_json(
        %{
          "is_deleted" => is_deleted,
          "vehicle" => %{
            "current_status" => current_status,
            "stop_id" => stop_id,
            "timestamp" => timestamp,
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
        },
        environment
      )
      when is_boolean(is_deleted) and is_binary(stop_id) and is_binary(route_id) and
             is_binary(trip_id) and is_binary(id) and is_binary(label) and direction_id in [0, 1] and
             current_status in ["INCOMING_AT", "IN_TRANSIT_TO", "STOPPED_AT"] and
             is_integer(timestamp) do
    vehicle = %__MODULE__{
      id: id,
      environment: environment,
      label: label,
      is_deleted: is_deleted,
      trip_id: trip_id,
      route_id: route_id,
      direction_id: direction_id,
      current_status: status_atom(current_status),
      stop_id: PredictionAnalyzer.Utilities.generic_stop_id(stop_id),
      timestamp: timestamp
    }

    {:ok, vehicle}
  end

  def from_json(_, _) do
    :error
  end

  defp status_atom("INCOMING_AT"), do: :INCOMING_AT
  defp status_atom("IN_TRANSIT_TO"), do: :IN_TRANSIT_TO
  defp status_atom("STOPPED_AT"), do: :STOPPED_AT
end
