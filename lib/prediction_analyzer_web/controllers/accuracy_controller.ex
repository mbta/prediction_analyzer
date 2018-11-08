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
      chart_data: Jason.encode!(set_up_accuracy_chart(accuracies)),
      prod_num_accurate: prod_num_accurate,
      prod_num_predictions: prod_num_predictions,
      dev_green_num_accurate: dev_green_num_accurate,
      dev_green_num_predictions: dev_green_num_predictions
    )
  end

  defp set_up_accuracy_chart(accuracies) do
    Enum.reduce(accuracies, %{hours: [], prod_accs: [], dg_accs: []}, fn [
                                                                           hour,
                                                                           prod_total,
                                                                           prod_accurate,
                                                                           dg_total,
                                                                           dg_accurate
                                                                         ] = data,
                                                                         acc ->
      acc
      |> Map.put(:hours, acc[:hours] ++ [hour])
      |> Map.put(:prod_accs, acc[:prod_accs] ++ [prod_accurate / prod_total])
      |> Map.put(:dg_accs, acc[:dg_accs] ++ [dg_accurate / dg_total])
    end)
  end
end
