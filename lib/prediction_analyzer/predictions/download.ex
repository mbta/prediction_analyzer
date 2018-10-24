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
    {aws_requestor, bucket_name, path_name} = get_aws_vars()
    Logger.info("Downloading predictions from #{bucket_name}")
    {:ok, object} = ExAws.S3.get_object(bucket_name, path_name) |> aws_requestor.request()

    object[:body]
    |> Jason.decode!()
    |> store_predictions()
  end

  defp get_aws_vars() do
    bucket_name = Application.get_env(:prediction_analyzer, :aws_gtfs_rt_bucket)
    path_name = Application.get_env(:prediction_analyzer, :aws_predictions_path)
    aws_requestor = Application.get_env(:prediction_analyzer, :aws_requestor)
    {aws_requestor, bucket_name, path_name}
  end

  defp schedule_fetch(pid, ms) do
    Process.send_after(pid, :get_predictions, ms)
  end

  def handle_info(:get_predictions, _state) do
    schedule_fetch(self(), 60_000)
    predictions = get_predictions()
    {:noreply, predictions}
  end

  defp store_predictions(predictions) do
    predictions =
      Enum.flat_map(predictions["entity"], fn prediction ->
        trip_prediction = %{
          trip_id: prediction["id"],
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
end
