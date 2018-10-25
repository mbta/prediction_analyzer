defmodule PredictionAnalyzer.Predictions.Download do
  use GenServer

  require Logger
  alias PredictionAnalyzer.Predictions.Prediction

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  def init(args) do
    schedule_fetch(self(), 1_000)
    {:ok, args}
  end

  def get_predictions() do
    {aws_predictions_url, http_fetcher} = get_vars()
    Logger.info("Downloading predictions from #{aws_predictions_url}")
    %{body: body} = http_fetcher.get!(aws_predictions_url)

    body
    |> Jason.decode!()
    |> store_predictions()
  end

  defp get_vars() do
    aws_predictions_url = Application.get_env(:prediction_analyzer, :aws_predictions_url)
    http_fetcher = Application.get_env(:prediction_analyzer, :http_fetcher)
    {aws_predictions_url, http_fetcher}
  end

  defp schedule_fetch(pid, ms) do
    Process.send_after(pid, :get_predictions, ms)
  end

  def handle_info(:get_predictions, _state) do
    schedule_fetch(self(), 60_000)
    predictions = get_predictions()
    {:noreply, predictions}
  end

  defp store_predictions(%{"entity" => entities}) do
    predictions =
      Enum.flat_map(entities, fn prediction ->
        trip_prediction = %{
          trip_id: prediction["trip_update"]["trip"]["trip_id"],
          is_deleted: prediction["is_deleted"]
        }

        if prediction["trip_update"]["stop_time_update"] != nil do
          Enum.map(prediction["trip_update"]["stop_time_update"], fn update ->
            Map.merge(trip_prediction, %{
              arrival_time: update["arrival"]["time"],
              departure_time: update["departure"]["time"],
              boarding_status: update["boarding_status"],
              schedule_relationship: update["schedule_relationship"],
              stop_id: update["stop_id"],
              stop_sequence: update["stop_sequence"],
              stops_away: update["stops_away"]
            })
          end)
        end
      end)

    PredictionAnalyzer.Repo.insert_all(Prediction, predictions)
  end

  defp store_predictions(_) do
    nil
  end
end
