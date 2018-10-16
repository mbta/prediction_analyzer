defmodule Predictions.Download do
  use GenServer

  require Logger

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  def init(args) do
    schedule_fetch(self(), 1_000)
    {:ok, args}
  end

  def get_predictions() do
    {aws_requestor, bucket_name, path_name} = get_aws_vars()
    ExAws.S3.get_object(bucket_name, path_name) |> aws_requestor.request()
  end

  defp get_aws_vars() do
    bucket_name = Application.get_env(:prediction_analyzer, :aws_predictions_bucket)
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
end
