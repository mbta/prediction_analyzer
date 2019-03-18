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

  def to_csv(predictions) do
    [
      [
        "env,",
        "file_timestamp,",
        "is_deleted,",
        "delay,",
        "boarding_status,",
        "schedule_relationship,",
        "stop_sequence,",
        "stops_away,",
        "trip_id,",
        "trip_vehicle_id,",
        "route_id,",
        "stop_id,",
        "direction_id,",
        "predicted_arrival,",
        "predicted_departure,",
        "vehicle_id,",
        "vehicle_label,",
        "vehicle_direction_id,",
        "actual_arrival,",
        "actual_departure",
        "\n"
      ],
      Enum.map(predictions, fn p ->
        vehicle_event =
          if Ecto.assoc_loaded?(p.vehicle_event) do
            p.vehicle_event
          end

        [
          p.environment,
          p.file_timestamp,
          p.is_deleted,
          p.delay,
          p.boarding_status,
          p.schedule_relationship,
          p.stop_sequence,
          p.stops_away,
          p.trip_id,
          p.vehicle_id,
          p.route_id,
          p.stop_id,
          p.direction_id,
          p.arrival_time,
          p.departure_time,
          vehicle_event && vehicle_event.vehicle_id,
          vehicle_event && vehicle_event.vehicle_label,
          vehicle_event && vehicle_event.direction_id,
          vehicle_event && vehicle_event.arrival_time,
          vehicle_event && vehicle_event.departure_time
        ]
        |> Enum.map(&to_string/1)
        |> Enum.intersperse(",")
        |> List.insert_at(-1, "\n")
      end)
    ]
    |> IO.iodata_to_binary()
  end
end
