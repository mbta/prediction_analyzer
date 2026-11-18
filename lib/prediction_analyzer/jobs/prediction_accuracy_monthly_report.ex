defmodule PredictionAnalyzer.Jobs.PredictionAccuracyMonthlyReport do
  alias PredictionAnalyzer.PredictionAccuracy.PredictionAccuracy
  alias PredictionAnalyzer.Filters

  require Ecto.Query
  require Logger

  use Oban.Worker,
    max_attempts: 3,
    unique: [states: :incomplete]

  @light_rail "Green-B,Green-C,Green-D,Green-E,Mattapan"
  @heavy_rail "Red,Blue,Orange"

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    Logger.info("monthly_report_start")

    {today, repo} = parse_args(args)
    date_start = today |> Timex.shift(months: -1) |> Date.beginning_of_month()
    date_end = date_start |> Date.end_of_month()

    base_params = %{
      "chart_range" => "Daily",
      "date_start" => Date.to_string(date_start),
      "date_end" => Date.to_string(date_end),
      "mode" => "subway"
    }

    additional_queries = [
      %{"stop_ids" => ["_terminal"]},
      %{"bin" => "0-3 min"},
      %{"bin" => "3-6 min"},
      %{"bin" => "6-12 min"},
      %{"bin" => "12-30 min"}
    ]

    queries = [
      base_params
      | for route_ids <- [@light_rail, @heavy_rail],
            extra_params <- additional_queries do
          base_params |> Map.merge(extra_params) |> Map.put("route_ids", route_ids)
        end
    ]

    for params <- queries do
      {relevant_accuracies, nil} = PredictionAccuracy.filter(params)

      _prod_accuracies =
        relevant_accuracies
        |> Filters.stats_by_chart_range(params)
        |> Ecto.Query.where(environment: "prod")
        |> repo.all()
        |> Enum.map(fn [row_scope, prod_total, prod_accurate, prod_err, prod_rmse] ->
          %{
            params["chart_range"] => row_scope,
            "Prod Accuracy" =>
              PredictionAnalyzerWeb.AccuracyView.accuracy_percentage(
                prod_accurate,
                prod_total
              ),
            "Err" => Float.round(prod_err || 0.0, 0),
            "RMSE" => Float.round(prod_rmse || 0.0, 0),
            "Count" => prod_total
          }
        end)
        |> CSV.encode(headers: [params["chart_range"], "Prod Accuracy", "Err", "RMSE", "Count"])
        |> Enum.join()
    end

    :ok
  end

  defp parse_args(args) do
    today =
      case Map.fetch(args, "today") do
        {:ok, datestamp} -> Date.from_iso8601!(datestamp)
        :error -> Date.utc_today()
      end

    repo =
      case Map.fetch(args, "repo") do
        {:ok, repo_mod_string} -> String.to_atom(repo_mod_string)
        :error -> PredictionAnalyzer.Repo
      end

    {today, repo}
  end
end
