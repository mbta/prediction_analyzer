defmodule PredictionAnalyzerWeb.PageController do
  use PredictionAnalyzerWeb, :controller

  def index(conn, _params) do
    redirect(conn, to: "/accuracy")
  end
end
