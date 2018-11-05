defmodule PredictionAnalyzerWeb.AccuracyController do
  use PredictionAnalyzerWeb, :controller
  alias PredictionAnalyzer.PredictionAccuracy.PredictionAccuracy

  import Ecto.Query, only: [from: 2]

  def index(conn, params) do
    relevant_accuracies = PredictionAccuracy.filter(params["filters"] || %{})

    [prod_num_accurate, prod_num_predictions] =
      from(
        acc in relevant_accuracies,
        select: [sum(acc.num_accurate_predictions), sum(acc.num_predictions)],
        where: acc.environment == "prod"
      )
      |> PredictionAnalyzer.Repo.one!()

    [dev_green_num_accurate, dev_green_num_predictions] =
      from(
        acc in relevant_accuracies,
        select: [sum(acc.num_accurate_predictions), sum(acc.num_predictions)],
        where: acc.environment == "dev-green"
      )
      |> PredictionAnalyzer.Repo.one!()

    accuracies =
      relevant_accuracies
      |> PredictionAccuracy.stats_by_environment_and_hour()
      |> PredictionAnalyzer.Repo.all()

    render(
      conn,
      "index.html",
      accuracies: accuracies,
      prod_num_accurate: prod_num_accurate,
      prod_num_predictions: prod_num_predictions,
      dev_green_num_accurate: dev_green_num_accurate,
      dev_green_num_predictions: dev_green_num_predictions
    )
  end
end
