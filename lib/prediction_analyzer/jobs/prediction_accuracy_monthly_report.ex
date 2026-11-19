defmodule PredictionAnalyzer.Jobs.PredictionAccuracyMonthlyReport do
  alias PredictionAnalyzer.PredictionAccuracy.PredictionAccuracy
  alias PredictionAnalyzer.Filters

  require Ecto.Query
  require Logger

  use Oban.Worker,
    max_attempts: 3,
    unique: [states: :incomplete]

  config =
    Application.compile_env!(:prediction_analyzer, :monthly_report) |> Map.new()

  @queries config.queries

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    Logger.info("monthly_report_start")

    {today, repo} = parse_args(args)
    date_start = today |> Timex.shift(months: -1) |> Date.beginning_of_month()
    date_end = date_start |> Date.end_of_month()

    base_params = %{
      "chart_range" => "Daily",
      "date_start" => Date.to_string(date_start),
      "date_end" => Date.to_string(date_end)
    }

    for {query_name, params} <- @queries do
      {relevant_accuracies, nil} = base_params |> Map.merge(params) |> PredictionAccuracy.filter()

      stats =
        relevant_accuracies
        |> Filters.select_stats()
        |> Ecto.Query.where(environment: "prod")
        |> repo.one()

      %{
        "Query" => query_name,
        "Prod Accuracy" =>
          PredictionAnalyzerWeb.AccuracyView.accuracy_percentage(
            stats.num_accurate,
            stats.num_predictions
          ),
        "Err" => Float.round(stats.mean_error || 0.0, 0),
        "RMSE" => Float.round(stats.rmse || 0.0, 0),
        "Count" => stats.num_predictions
      }
    end
    |> CSV.encode(headers: ["Query", "Prod Accuracy", "Err", "RMSE", "Count"])

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
