defmodule PredictionAnalyzerWeb.Router do
  use PredictionAnalyzerWeb, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_flash)
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/", PredictionAnalyzerWeb do
    # Use the default browser stack
    pipe_through(:browser)

    get("/", PageController, :index)
    get("/vehicle_events", VehicleEventsController, :index)
    get("/accuracy", AccuracyController, :index)
    get("/_health", HealthController, :index)
  end

  scope "/accuracy", PredictionAnalyzerWeb do
    pipe_through(:browser)
    get("/subway", AccuracyController, :subway)
    get("/commuter_rail", AccuracyController, :commuter_rail)
  end

  # Other scopes may use custom stacks.
  # scope "/api", PredictionAnalyzerWeb do
  #   pipe_through :api
  # end
end
