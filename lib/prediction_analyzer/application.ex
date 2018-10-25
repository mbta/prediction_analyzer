defmodule PredictionAnalyzer.Application do
  use Application
  alias Predictions.Utilities.Config
  require Logger

  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec

    set_runtime_config()
    # Define workers and child supervisors to be supervised
    children = [
      # Start the Ecto repository
      supervisor(PredictionAnalyzer.Repo, []),
      worker(PredictionAnalyzer.VehiclePositions.Tracker, []),
      worker(PredictionAnalyzer.Predictions.Download, [[name: PredictionAnalyzer.Predictions.Download]]),
      # Start the endpoint when the application starts
      supervisor(PredictionAnalyzerWeb.Endpoint, [])
      # Start your own worker by calling: PredictionAnalyzer.Worker.start_link(arg1, arg2, arg3)
      # worker(PredictionAnalyzer.Worker, [arg1, arg2, arg3]),
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: PredictionAnalyzer.Supervisor]
    case Supervisor.start_link(children, opts) do
      {:ok, _} = success ->
        Logger.info("Started application, running migrations")
        Application.get_env(:prediction_analyzer, :migration_task).migrate()
        success

      error ->
        error
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    PredictionAnalyzerWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp set_runtime_config do
    Config.update_env(:aws_predictions_url, System.get_env("AWS_PREDICTIONS_URL"))
    Config.update_env(:aws_vehicle_positions_url, System.get_env("AWS_VEHICLE_POSITIONS_URL"))
  end
end
