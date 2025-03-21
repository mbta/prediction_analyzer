alias PredictionAnalyzer.Repo
alias PredictionAnalyzer.PredictionAccuracy.PredictionAccuracy
alias PredictionAnalyzer.Filters
alias PredictionAnalyzer.Predictions.Prediction
require Logger

stops = [
  {"Red", "70061", 0, "at_terminal"},
  {"Red", "70063", 0, "reverse"},
  {"Red", "70064", 1, "mid_trip"},
  {"Red", "70065", 0, "reverse"},
  {"Red", "70066", 1, "mid_trip"},
  {"Red", "70067", 0, "reverse"},
  {"Red", "70068", 1, "mid_trip"},
  {"Orange", "70036", 0, "at_terminal"},
  {"Orange", "70034", 0, "reverse"},
  {"Orange", "70035", 1, "mid_trip"},
  {"Orange", "70032", 0, "reverse"},
  {"Orange", "70033", 1, "mid_trip"},
  {"Orange", "70278", 0, "reverse"},
  {"Orange", "70279", 1, "mid_trip"},
  {"Orange", "70030", 0, "reverse"},
  {"Orange", "70031", 1, "mid_trip"},
  {"CR-Fitchburg", "Waltham", 0, nil},
  {"CR-Fitchburg", "Waltham", 1, nil},
  {"CR-Fitchburg", "Belmont", 1, nil},
  {"CR-Fitchburg", "Belmont", 0, nil},
  {"CR-Fitchburg", "Fitchburg", 1, nil},
  {"CR-Fitchburg", "Fitchburg", 0, nil},
  {"CR-Fitchburg", "Concord", 1, nil},
  {"CR-Fitchburg", "Concord", 0, nil},
  {"CR-Fitchburg", "Lincoln", 1, nil}
]

Logger.info("Generating sample prediction_accuracy data")

service_dates =
  Enum.map(0..-14, fn day_offset ->
    Timex.local()
    |> Timex.shift(days: day_offset)
    |> DateTime.to_date()
  end)

for env <- ["prod", "dev-green", "dev-blue"],
    service_date <- service_dates,
    hour_of_day <- 4..25,
    {route_id, stop_id, direction_id, kind} <- stops,
    bin <- Map.keys(Filters.bins()) do
  num_predictions = :rand.uniform(100)
  num_accurate_predictions = num_predictions - :rand.uniform(num_predictions)

  %{
    environment: env,
    service_date: service_date,
    hour_of_day: hour_of_day,
    stop_id: stop_id,
    route_id: route_id,
    direction_id: direction_id,
    bin: bin,
    kind: kind,
    num_predictions: num_predictions,
    num_accurate_predictions: num_accurate_predictions
  }
end
|> Enum.chunk_every(1_000)
|> Enum.each(fn chunk ->
  Logger.info("Inserting chunk of sample data")
  Repo.insert_all(PredictionAccuracy, chunk)
end)

for env <- ["prod", "dev-green", "dev-blue"],
    service_date <- service_dates,
    hour_of_day <- 4..25,
    {route_id, stop_id, direction_id, kind} <- stops do
  for i <- 1..:rand.uniform(25) do
    timestamp =
      service_date
      |> Timex.to_datetime()
      |> Timex.shift(hours: hour_of_day, seconds: :rand.uniform(3_600))
      |> DateTime.to_unix()

    %{
      file_timestamp: timestamp,
      environment: env,
      trip_id: "Seed-1",
      vehicle_id: "1234",
      is_deleted: false,
      delay: 0,
      arrival_time: 1_000,
      boarding_status: "Stopped at station",
      departure_time: nil,
      schedule_relationship: "SCHEDULED",
      stop_id: stop_id,
      route_id: route_id,
      direction_id: direction_id,
      kind: kind,
      stop_sequence: 310,
      stops_away: 0,
      vehicle_event_id: nil
    }
  end
end
|> List.flatten()
|> Enum.chunk_every(1_000)
|> Enum.each(fn chunk ->
  Logger.info("Inserting chunk of sample data")
  Repo.insert_all(Prediction, chunk)
end)
