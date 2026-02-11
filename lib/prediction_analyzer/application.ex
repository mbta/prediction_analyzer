defmodule PredictionAnalyzer.Application do
  use Application
  alias Predictions.Utilities.Config
  require Logger

  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    set_runtime_config()
    PredictionAnalyzer.Telemetry.setup_telemetry()
    # Define workers and child supervisors to be supervised
    supervisors = [
      PredictionAnalyzer.Repo,
      {Phoenix.PubSub, name: PredictionAnalyzerWeb.PubSub},
      PredictionAnalyzerWeb.Endpoint
    ]

    workers =
      if Application.get_env(:prediction_analyzer, :start_workers) do
        [
          Supervisor.child_spec(
            {
              PredictionAnalyzer.VehiclePositions.Tracker,
              [environment: "dev-green"]
            },
            id: DevGreenVehiclePositionsTracker
          ),
          Supervisor.child_spec(
            {
              PredictionAnalyzer.VehiclePositions.Tracker,
              [environment: "dev-blue"]
            },
            id: DevBlueVehiclePositionsTracker
          ),
          Supervisor.child_spec(
            {PredictionAnalyzer.VehiclePositions.Tracker, [environment: "prod"]},
            id: ProdVehiclePositionsTracker
          ),
          {PredictionAnalyzer.Predictions.Download,
           [name: PredictionAnalyzer.Predictions.Download]},
          PredictionAnalyzer.PredictionAccuracy.Aggregator,
          PredictionAnalyzer.PredictionAccuracy.AccuracyTracker,
          {PredictionAnalyzer.StopNameFetcher, [name: PredictionAnalyzer.StopNameFetcher]},
          PredictionAnalyzer.Pruner
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

    Config.update_env(
      :dev_blue_aws_predictions_url,
      System.get_env("DEV_BLUE_AWS_PREDICTIONS_URL") ||
        "https://s3.amazonaws.com/mbta-gtfs-s3-dev-blue/rtr/TripUpdates_enhanced.json"
    )

    Config.update_env(
      :dev_blue_aws_vehicle_positions_url,
      System.get_env("DEV_BLUE_AWS_VEHICLE_POSITIONS_URL") ||
        "https://s3.amazonaws.com/mbta-gtfs-s3-dev-blue/rtr/VehiclePositions_enhanced.json"
    )
  end
end
