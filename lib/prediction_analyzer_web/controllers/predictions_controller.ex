defmodule PredictionAnalyzerWeb.PredictionsController do
  use PredictionAnalyzerWeb, :controller

  import Ecto.Query, only: [from: 2]
  alias PredictionAnalyzer.Predictions.Prediction

  def index(conn, params) do
    # todo: hour greater than 24

    service_date =
      if not is_nil(params["service_date"]) and params["service_date"] != "" do
        params["service_date"]
        |> Date.from_iso8601!()
        |> Timex.to_datetime("America/New_York")
      end

    hour =
      if not is_nil(params["hour"]) and params["hour"] != "" do
        String.to_integer(params["hour"])
      end

    start_unix =
      if service_date && hour do
        {date, hour} =
          if hour >= 24 do
            {Timex.shift(service_date, days: 1), hour - 24}
          else
            {service_date, hour}
          end

        date
        |> Timex.set(hour: hour, minute: 0, second: 0, microsecond: {0, 6})
        |> DateTime.to_unix()
      else
        0
      end

    end_unix = start_unix + 60 * 60

    stop_id = params["stop_id"] || "no_stop"

    query =
      from(
        p in Prediction,
        left_join: ve in assoc(p, :vehicle_event),
        where:
          p.file_timestamp >= ^start_unix and p.file_timestamp < ^end_unix and
            p.stop_id == ^stop_id,
        order_by: [desc: :arrival_time, desc: :departure_time],
        limit: 5000,
        preload: [vehicle_event: ve],
        select: p
      )

    predictions = PredictionAnalyzer.Repo.all(query)

    if params["format"] == "csv" do
      send_download(
        conn,
        {:binary, Prediction.to_csv(predictions)},
        filename: "#{params["service_date"]}-hour#{params["hour"]}.csv"
      )
    else
      render(conn, "index.html", predictions: predictions)
    end
  end
end
