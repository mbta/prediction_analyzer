defmodule PredictionAnalyzer.Application do
  use Application
  alias Predictions.Utilities.Config

  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec

    set_runtime_config()
    # Define workers and child supervisors to be supervised
    children = [
      worker(Predictions.Download, [[name: Predictions.Download]]),
      # Start the Ecto repository
      supervisor(Predictions.Repo, []),
      # Start the endpoint when the application starts
      supervisor(PredictionAnalyzerWeb.Endpoint, [])
      # Start your own worker by calling: PredictionAnalyzer.Worker.start_link(arg1, arg2, arg3)
      # worker(PredictionAnalyzer.Worker, [arg1, arg2, arg3]),
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: PredictionAnalyzer.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    PredictionAnalyzerWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp set_runtime_config do
    Config.update_env(:aws_predictions_bucket, System.get_env("AWS_PREDICTIONS_BUCKET"))
    Config.update_env(:aws_predictions_path, System.get_env("AWS_PREDICTIONS_PATH"))
  end
end
