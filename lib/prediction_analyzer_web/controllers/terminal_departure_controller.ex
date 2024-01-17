defmodule PredictionAnalyzerWeb.TerminalDepartureController do
  use PredictionAnalyzerWeb, :controller
  import Ecto.Query, only: [from: 2]
  alias PredictionAnalyzer.Predictions.Prediction
  alias PredictionAnalyzer.VehicleEvents.VehicleEvent

  defp parse_date(nil), do: Date.utc_today()

  defp parse_date(date_str) do
    case Date.from_iso8601(date_str) do
      {:ok, date} -> date
      {:error, _} -> Date.utc_today()
    end
  end

  def index(conn, params) do
    date = parse_date(params["date"])
    env = params["env"] || "prod"

    min_time = date |> Timex.to_datetime() |> Timex.beginning_of_day() |> DateTime.to_unix()
    max_time = date |> Timex.to_datetime() |> Timex.end_of_day() |> DateTime.to_unix()

    query =
      from(ve in VehicleEvent,
        as: :vehicle_event,
        where:
          not is_nil(ve.trip_id) and
            not is_nil(ve.departure_time) and
            not ve.is_deleted and
            ve.environment == ^env and
            ve.departure_time >= ^min_time and
            ve.departure_time <= ^max_time and
            not exists(
              from(p in Prediction,
                where:
                  p.vehicle_event_id == parent_as(:vehicle_event).id and
                    p.file_timestamp < parent_as(:vehicle_event).departure_time
              )
            ),
        group_by: ve.route_id,
        order_by: [desc: count(ve.id)],
        select: {ve.route_id, count(ve.id)}
      )

    results = PredictionAnalyzer.Repo.all(query)

    render(conn, "index.html", results: results, date: date, env: env)
  end
end
