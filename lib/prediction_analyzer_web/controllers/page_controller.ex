defmodule PredictionAnalyzerWeb.PageController do
  use PredictionAnalyzerWeb, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end
end
