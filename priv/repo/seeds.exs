alias PredictionAnalyzer.Repo
alias PredictionAnalyzer.PredictionAccuracy.PredictionAccuracy
require Logger

stops = [
  {"Red", "70061"},
  {"Red", "70063"},
  {"Red", "70064"},
  {"Red", "70065"},
  {"Red", "70066"},
  {"Red", "70067"},
  {"Red", "70068"},
  {"Orange", "70036"},
  {"Orange", "70036"},
  {"Orange", "70034"},
  {"Orange", "70035"},
  {"Orange", "70032"},
  {"Orange", "70033"},
  {"Orange", "70278"},
  {"Orange", "70279"},
  {"Orange", "70030"},
  {"Orange", "70031"}
]

Logger.info("Generating sample prediction_accuracy data")

service_dates =
  Enum.map(0..-14, fn day_offset ->
    Timex.local()
    |> Timex.shift(days: day_offset)
    |> DateTime.to_date()
  end)

for env <- ["prod", "dev-green"],
  service_date <- service_dates,
  hour_of_day <- 4..25,
  {route_id, stop_id} <- stops,
  a_d <- ["arrival", "departure"],
  bin <- Map.keys(PredictionAccuracy.bins()) do
    num_predictions = :rand.uniform(100)
    num_accurate_predictions = num_predictions - :rand.uniform(num_predictions)

    %{
      environment: env,
      service_date: service_date,
      hour_of_day: hour_of_day,
      stop_id: stop_id,
      route_id: route_id,
      arrival_departure: a_d,
      bin: bin,
      num_predictions: num_predictions,
      num_accurate_predictions: num_accurate_predictions
    }
end
|> Enum.chunk_every(1_000)
|> Enum.each(fn chunk ->
  Logger.info("Inserting chunk of sample data")
  Repo.insert_all(PredictionAccuracy, chunk)
end)

