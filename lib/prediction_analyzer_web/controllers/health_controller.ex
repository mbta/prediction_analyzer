defmodule PredictionAnalyzerWeb.HealthController do
  use PredictionAnalyzerWeb, :controller

  def index(conn, _params) do
    conn
    |> send_resp(200, "Healthy")
    |> halt()
  end
end
