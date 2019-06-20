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
    supervisors = [
      # Start the Ecto repository
      supervisor(PredictionAnalyzer.Repo, []),
      # Start the endpoint when the application starts
      supervisor(PredictionAnalyzerWeb.Endpoint, [])
      # Start your own worker by calling: PredictionAnalyzer.Worker.start_link(arg1, arg2, arg3)
      # worker(PredictionAnalyzer.Worker, [arg1, arg2, arg3]),
    ]

    workers =
      if Application.get_env(:prediction_analyzer, :start_workers) do
        [
          worker(
            PredictionAnalyzer.VehiclePositions.Tracker,
            [[environment: "dev-green"]],
            id: DevGreenVehiclePositionsTracker
          ),
          worker(
            PredictionAnalyzer.VehiclePositions.Tracker,
            [[environment: "prod"]],
            id: ProdVehiclePositionsTracker
          ),
          worker(PredictionAnalyzer.Predictions.Download, [
            [name: PredictionAnalyzer.Predictions.Download]
          ]),
          worker(PredictionAnalyzer.PredictionAccuracy.Aggregator, []),
          worker(PredictionAnalyzer.WeeklyAccuracies.Aggregator, []),
          worker(PredictionAnalyzer.PredictionAccuracy.AccuracyTracker, []),
          worker(PredictionAnalyzer.StopNameFetcher, [[name: PredictionAnalyzer.StopNameFetcher]]),
          worker(PredictionAnalyzer.Pruner, [])
        ]
      else
        []
      end

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: PredictionAnalyzer.Supervisor]

    case Supervisor.start_link(supervisors ++ workers, opts) do
      {:ok, _} = success ->
        spawn(fn ->
          Logger.info("Started application, running migrations")
          Application.get_env(:prediction_analyzer, :migration_task).migrate()
          Logger.info("Finished migrations")
        end)

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
    Config.update_env(:api_v3_key, System.get_env("API_V3_KEY"))
    Config.update_env(:aws_predictions_url, System.get_env("AWS_PREDICTIONS_URL"))
    Config.update_env(:aws_vehicle_positions_url, System.get_env("AWS_VEHICLE_POSITIONS_URL"))

    Config.update_env(
      :dev_green_aws_predictions_url,
      System.get_env("DEV_GREEN_AWS_PREDICTIONS_URL")
    )

    Config.update_env(
      :dev_green_aws_vehicle_positions_url,
      System.get_env("DEV_GREEN_AWS_VEHICLE_POSITIONS_URL")
    )
  end
end
