defmodule PredictionAnalyzerWeb.PredictionsController do
  use PredictionAnalyzerWeb, :controller
  import Ecto.Query
  alias PredictionAnalyzer.Predictions.Prediction
  alias PredictionAnalyzer.VehicleEvents.VehicleEvent

  def csv(conn, %{"date" => service_date, "hour" => hour, "stop_id" => stop_id}) do
    {:ok, date} = Date.from_iso8601(service_date)

    timezone = Application.get_env(:prediction_analyzer, :timezone)

    hour = String.to_integer(hour)

    start_hour = Time.new!(hour, 0, 0)

    unix_start =
      date
      |> NaiveDateTime.new!(start_hour)
      |> DateTime.from_naive!(timezone)
      |> DateTime.to_unix()

    unix_end = unix_start + 60 * 60

    query =
      from(p in Prediction,
        join: ve in VehicleEvent,
        on: p.vehicle_event_id == ve.id,
        where:
          p.stop_id == ^stop_id and p.file_timestamp >= ^unix_start and
            p.file_timestamp < ^unix_end,
        select: %{
          environment: p.environment,
          departure_time: ve.departure_time,
          trip_id: p.trip_id,
          route: p.route_id,
          direction: p.direction_id,
          generated_time: p.file_timestamp,
          predicted_departure: p.departure_time,
          vehicle_label: ve.vehicle_label,
          kind: p.kind
        }
      )

    result = PredictionAnalyzer.Repo.all(query)

    filename = "raw_predictions_#{stop_id}_#{Date.to_iso8601(date)}_#{hour}.csv"

    send_download(
      conn,
      {:binary,
       result
       |> CSV.encode(
         headers: [
           environment: "environment",
           departure_time: "departure_time",
           trip_id: "trip_id",
           route: "route",
           direction: "direction",
           generated_time: "generated_time",
           predicted_departure: "predicted_departure",
           vehicle_label: "vehicle_label",
           kind: "kind"
         ]
       )
       |> Enum.to_list()
       |> Enum.join()},
      content_type: "application/csv",
      filename: filename
    )
  end
end
