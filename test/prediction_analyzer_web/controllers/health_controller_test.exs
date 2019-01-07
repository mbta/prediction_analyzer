defmodule PredictionAnalyzerWeb.HealthControllerTest do
  use PredictionAnalyzerWeb.ConnCase

  test "GET /_health", %{conn: conn} do
    conn = get(conn, "/_health")
    assert response(conn, 200) == "Healthy"
  end
end
