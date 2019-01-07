defmodule PredictionAnalyzerWeb.HealthController do
  use PredictionAnalyzerWeb, :controller

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    conn
    |> send_resp(200, "Healthy")
    |> halt()
  end
end
