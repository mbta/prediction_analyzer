defmodule PredictionAnalyzer do
  @moduledoc """
  Documentation for PredictionAnalyzer.
  """

  use Application
  alias Predictions.Utilities.Config

  def start(_type, _args) do
    import Supervisor.Spec

    set_runtime_config()

    # Define workers and child supervisors to be supervised
    children = [
      # Start the endpoint when the application starts
      worker(Predictions.Download, [[name: Predictions.Download]]),
      supervisor(Predictions.Repo, [])
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Predictions.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp set_runtime_config do
    Config.update_env(:aws_predictions_bucket, System.get_env("AWS_PREDICTIONS_BUCKET"))
    Config.update_env(:aws_predictions_path, System.get_env("AWS_PREDICTIONS_PATH"))
  end
end
