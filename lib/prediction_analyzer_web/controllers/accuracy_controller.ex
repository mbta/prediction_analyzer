defmodule PredictionAnalyzerWeb.AccuracyController do
  use PredictionAnalyzerWeb, :controller
  alias PredictionAnalyzer.PredictionAccuracy.PredictionAccuracy

  import Ecto.Query, only: [from: 2]

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(
        conn,
        params = %{"filters" => %{"chart_range" => chart_range, "service_date" => service_date}}
      )
      when (chart_range == "Hourly" and not is_nil(service_date) and service_date != "") or
             chart_range == "Daily" do
    filter_params = params["filters"]
    relevant_accuracies = PredictionAccuracy.filter(filter_params)

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
      |> PredictionAccuracy.stats_by_environment_and_hour(filter_params)
      |> PredictionAnalyzer.Repo.all()

    render(
      conn,
      "index.html",
      accuracies: accuracies,
      chart_data: Jason.encode!(set_up_accuracy_chart(accuracies, filter_params)),
      prod_num_accurate: prod_num_accurate,
      prod_num_predictions: prod_num_predictions,
      dev_green_num_accurate: dev_green_num_accurate,
      dev_green_num_predictions: dev_green_num_predictions
    )
  end

  def index(conn, params) do
    filters = params["filters"] || %{}

    default_filters = %{
      "chart_range" => "Hourly",
      "service_date" => Timex.local() |> Date.to_string()
    }

    filters = Map.merge(default_filters, filters)

    redirect(
      conn,
      to: accuracy_path(conn, :index, %{"filters" => filters})
    )
  end

  defp set_up_accuracy_chart(accuracies, filter_params) do
    Enum.reduce(accuracies, %{time_buckets: [], prod_accs: [], dg_accs: []}, fn [
                                                                                  time_bucket,
                                                                                  prod_total,
                                                                                  prod_accurate,
                                                                                  dg_total,
                                                                                  dg_accurate
                                                                                ],
                                                                                acc ->
      prod_accuracy = if prod_total == 0, do: [0], else: [prod_accurate / prod_total]
      dg_accuracy = if dg_total == 0, do: [0], else: [dg_accurate / dg_total]

      acc
      |> Map.put(:time_buckets, acc[:time_buckets] ++ [time_bucket])
      |> Map.put(:prod_accs, acc[:prod_accs] ++ prod_accuracy)
      |> Map.put(:dg_accs, acc[:dg_accs] ++ dg_accuracy)
    end)
    |> Map.put(:chart_type, filter_params["chart_range"] || "Hourly")
  end
end
