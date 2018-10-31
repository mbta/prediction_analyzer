defmodule PredictionAnalyzer.Predictions.Download do
  use GenServer

  require Logger
  alias PredictionAnalyzer.Predictions.Prediction

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  def init(args) do
    schedule_prod_fetch(self(), 1_000)
    schedule_dev_green_fetch(self(), 11_000)
    {:ok, args}
  end

  def get_predictions(env) do
    {aws_predictions_url, http_fetcher} = get_vars(env)
    Logger.info("Downloading predictions from #{aws_predictions_url}")
    %{body: body} = http_fetcher.get!(aws_predictions_url)

    body
    |> Jason.decode!()
    |> store_predictions(env)
  end

  defp get_vars(:prod) do
    prod_aws_predictions_url = Application.get_env(:prediction_analyzer, :aws_predictions_url)
    http_fetcher = Application.get_env(:prediction_analyzer, :http_fetcher)
    {prod_aws_predictions_url, http_fetcher}
  end

  defp get_vars(:dev_green) do
    dev_green_aws_predictions_url =
      Application.get_env(:prediction_analyzer, :dev_green_aws_predictions_url)

    http_fetcher = Application.get_env(:prediction_analyzer, :http_fetcher)
    {dev_green_aws_predictions_url, http_fetcher}
  end

  defp schedule_prod_fetch(pid, ms) do
    Process.send_after(pid, :get_prod_predictions, ms)
  end

  defp schedule_dev_green_fetch(pid, ms) do
    Process.send_after(pid, :get_dev_green_predictions, ms)
  end

  def handle_info(:get_prod_predictions, _state) do
    schedule_prod_fetch(self(), 60_000)
    predictions = get_predictions(:prod)
    {:noreply, predictions}
  end

  def handle_info(:get_dev_green_predictions, _state) do
    schedule_dev_green_fetch(self(), 60_000)
    predictions = get_predictions(:dev_green)
    {:noreply, predictions}
  end

  defp store_predictions(%{"entity" => entities, "header" => %{"timestamp" => timestamp}}, env) do
    predictions =
      Enum.flat_map(entities, fn prediction ->
        trip_prediction = %{
          file_timestamp: timestamp,
          environment:
            case env do
              :prod -> "prod"
              :dev_green -> "dev-green"
            end,
          trip_id: prediction["trip_update"]["trip"]["trip_id"],
          route_id: prediction["trip_update"]["trip"]["route_id"],
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

  defp store_predictions(_, _) do
    nil
  end
end
