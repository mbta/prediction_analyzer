defmodule PredictionAnalyzerWeb.AccuracyController do
  use PredictionAnalyzerWeb, :controller
  alias PredictionAnalyzer.PredictionAccuracy.{PredictionAccuracy, MonthlyReport}
  alias PredictionAnalyzer.Filters

  import Ecto.Query, only: [from: 2]

  @envs ["prod", "dev-green", "dev-blue"]

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(
        conn,
        %{
          "filters" =>
            %{
              "route_ids" => route_ids,
              "direction_id" => direction_id,
              "bin" => bin,
              "mode" => mode
            } = filter_params
        } = params
      )
      when not is_nil(route_ids) and not is_nil(direction_id) and byte_size(bin) > 0 do
    if time_filters_present?(filter_params) do
      %{query: params_string} = conn |> current_url(params) |> URI.parse()

      {relevant_accuracies, error_msg} = PredictionAccuracy.filter(filter_params)
      stats_query = Filters.select_stats(relevant_accuracies)
      accuracies_by_chart_range = stats_query |> Filters.group_by_chart_range(filter_params)

      accuracy_context_tasks =
        for env <- @envs do
          Task.Supervisor.async(
            PredictionAnalyzer.TaskSupervisor,
            fn -> get_accuracy_context(stats_query, params_string, env) end
          )
        end

      accuracy_tasks =
        for env <- @envs do
          Task.Supervisor.async(
            PredictionAnalyzer.TaskSupervisor,
            fn -> get_accuracies(accuracies_by_chart_range, params_string, env) end
          )
        end

      [
        prod_context,
        dev_green_context,
        dev_blue_context,
        prod_accuracies,
        dev_green_accuracies,
        dev_blue_accuracies
      ] = Task.await_many(accuracy_context_tasks ++ accuracy_tasks, :timer.minutes(5))

      sort_function =
        if filter_params["chart_range"] == "Daily" do
          fn d1, d2 -> Date.compare(d1, d2) == :lt end
        else
          fn x, y -> x < y end
        end

      accuracies =
        (Map.keys(prod_accuracies) ++
           Map.keys(dev_green_accuracies) ++ Map.keys(dev_blue_accuracies))
        |> Enum.uniq()
        |> Enum.sort(sort_function)
        |> Enum.map(fn scope ->
          empty = %{scope: scope, num_predictions: 0, num_accurate: 0, mean_error: 0, rmse: 0}
          prod_accuracy = prod_accuracies[scope] || empty
          dev_green_accuracy = dev_green_accuracies[scope] || empty
          dev_blue_accuracy = dev_blue_accuracies[scope] || empty

          {prod_accuracy, dev_green_accuracy, dev_blue_accuracy}
        end)

      months =
        MonthlyReport.months()
        |> PredictionAnalyzer.Repo.all()
        |> Enum.map(&{Timex.format!(&1, "%Y-%m", :strftime), Date.to_string(&1)})

      render(
        conn,
        "index.html",
        accuracies: accuracies,
        chart_data: Jason.encode!(set_up_accuracy_chart(accuracies, filter_params)),
        prod_num_accurate: prod_context.num_accurate,
        prod_num_predictions: prod_context.num_predictions,
        prod_mean_error: prod_context.mean_error,
        prod_rmse: prod_context.rmse,
        dev_green_num_accurate: dev_green_context.num_accurate,
        dev_green_num_predictions: dev_green_context.num_predictions,
        dev_green_mean_error: dev_green_context.mean_error,
        dev_green_rmse: dev_green_context.rmse,
        dev_blue_num_accurate: dev_blue_context.num_accurate,
        dev_blue_num_predictions: dev_blue_context.num_predictions,
        dev_blue_mean_error: dev_blue_context.mean_error,
        dev_blue_rmse: dev_blue_context.rmse,
        error_msg: error_msg,
        months: months,
        mode: PredictionAnalyzer.Utilities.string_to_mode(mode),
        bins:
          Filters.bins()
          |> Enum.map(fn {bin, {bin_min, _bin_max, bin_error_min, bin_error_max}} ->
            {bin, bin_min, bin_error_min, bin_error_max}
          end)
          |> Enum.sort_by(fn {_, bin_min, _, _} -> bin_min end)
      )
    else
      redirect_with_default_filters(conn, params)
    end
  end

  def index(conn, params) do
    redirect_with_default_filters(conn, params)
  end

  defp get_accuracy_context(stats_query, params_string, env) do
    from(
      acc in stats_query,
      where: acc.environment == ^env
    )
    |> PredictionAnalyzer.Repo.one!(
      telemetry_event: PredictionAnalyzer.Repo.config()[:telemetry_prefix] ++ [:named_query],
      telemetry_options: [name: :accuracy_context, env: env, request_params: params_string]
    )
  end

  defp get_accuracies(accuracies_by_chart_range, params_string, env) do
    from(acc in accuracies_by_chart_range, where: acc.environment == ^env)
    |> PredictionAnalyzer.Repo.all(
      telemetry_event: PredictionAnalyzer.Repo.config()[:telemetry_prefix] ++ [:named_query],
      telemetry_options: [name: :accuracies, env: env, request_params: params_string]
    )
    |> Map.new(fn %{scope: scope} = accuracy ->
      {scope, accuracy}
    end)
  end

  def subway(conn, params) do
    conn
    |> assign(:mode, :subway)
    |> index(params)
  end

  def csv(
        conn,
        %{
          "filters" => filter_params
        } = params
      ) do
    if time_filters_present?(filter_params) do
      {relevant_accuracies, _} = PredictionAccuracy.filter(filter_params)

      accuracies_by_chart_range =
        relevant_accuracies
        |> Filters.select_stats()
        |> Filters.group_by_chart_range(filter_params)

      prod_accuracies =
        from(acc in accuracies_by_chart_range, where: acc.environment == "prod")
        |> PredictionAnalyzer.Repo.all()
        |> Enum.map(fn %{
                         scope: row_scope,
                         num_predictions: prod_total,
                         num_accurate: prod_accurate,
                         mean_error: prod_err,
                         rmse: prod_rmse
                       } ->
          %{
            filter_params["chart_range"] =>
              PredictionAnalyzerWeb.AccuracyView.formatted_row_scope(
                filter_params,
                row_scope
              ),
            "Prod Accuracy" =>
              PredictionAnalyzerWeb.AccuracyView.accuracy_percentage(
                prod_accurate,
                prod_total
              ),
            "Err" => Float.round(prod_err, 0),
            "RMSE" => Float.round(prod_rmse, 0),
            "Count" => prod_total
          }
        end)

      date_for_filename =
        if Map.has_key?(filter_params, "date_start"),
          do: "#{filter_params["date_start"]}_#{filter_params["date_end"]}",
          else: filter_params["service_date"]

      filename =
        "#{Timex.now("America/New_York") |> DateTime.to_iso8601()}_PredictionAnalyzer_#{date_for_filename}_#{filter_params["mode"]}_export.csv"

      send_download(
        conn,
        {:binary,
         prod_accuracies
         |> CSV.encode(
           headers: [filter_params["chart_range"], "Prod Accuracy", "Err", "RMSE", "Count"]
         )
         |> Enum.to_list()
         |> Enum.join()},
        content_type: "application/csv",
        filename: filename
      )
    else
      redirect_with_default_filters(conn, params, :csv)
    end
  end

  def csv(conn, params) do
    redirect_with_default_filters(conn, params, :csv)
  end

  def commuter_rail(conn, params) do
    conn
    |> assign(:mode, :commuter_rail)
    |> index(params)
  end

  def monthly_csv(conn, %{"month" => month}) do
    month = Date.from_iso8601!(month)

    report =
      from(acc in MonthlyReport, where: acc.month == ^month)
      |> PredictionAnalyzer.Repo.all()
      |> Enum.map(
        &Map.put(
          &1,
          :accuracy,
          PredictionAnalyzerWeb.AccuracyView.accuracy_percentage(
            &1.num_accurate,
            &1.num_predictions
          )
        )
      )

    filename = "monthly_summary_#{Timex.format!(month, "%Y-%m", :strftime)}.csv"

    send_download(
      conn,
      {:binary,
       report
       |> CSV.encode(
         headers: [
           query: "Query",
           accuracy: "Prod Accuracy",
           mean_error: "Err",
           rmse: "RMSE",
           num_predictions: "Count"
         ]
       )
       |> Enum.to_list()
       |> Enum.join()},
      content_type: "application/csv",
      filename: filename
    )
  end

  @spec redirect_with_default_filters(Plug.Conn.t(), map(), atom) :: Plug.Conn.t()
  defp redirect_with_default_filters(conn, params, redirect_target \\ :index) do
    filters = params["filters"] || %{}

    default_filters = %{
      "route_ids" => "",
      "direction_id" => "any",
      "bin" => "All",
      "mode" => conn.assigns[:mode] || filters["mode"] || "subway"
    }

    time_filters =
      cond do
        filters["chart_range"] in ["Daily", "By Station"] ->
          %{
            "chart_range" => "Daily",
            "date_start" => Timex.local() |> Timex.shift(days: -14) |> Date.to_string(),
            "date_end" => Timex.local() |> Date.to_string()
          }

        filters["chart_range"] == "Hourly" && filters["service_date"] ->
          filters
          |> Map.take(["chart_range", "service_date", "timeframe_resolution"])
          |> Map.put_new("timeframe_resolution", "60")

        true ->
          %{
            "chart_range" => "Hourly",
            "service_date" => Timex.local() |> Date.to_string(),
            "timeframe_resolution" => "60"
          }
      end

    filters =
      default_filters
      |> Map.merge(time_filters)
      |> Map.merge(filters)

    redirect(
      conn,
      to: Routes.accuracy_path(conn, redirect_target, %{"filters" => filters})
    )
  end

  @spec set_up_accuracy_chart(list(), map()) :: map()
  defp set_up_accuracy_chart(accuracies, filter_params) do
    Enum.reduce(
      accuracies,
      %{buckets: [], prod_accs: [], dg_accs: [], db_accs: []},
      fn {%{scope: bucket, num_predictions: prod_total, num_accurate: prod_accurate},
          %{num_predictions: dg_total, num_accurate: dg_accurate},
          %{num_predictions: db_total, num_accurate: db_accurate}},
         acc ->
        prod_accuracy = if prod_total == 0, do: [0], else: [prod_accurate / prod_total]
        dg_accuracy = if dg_total == 0, do: [0], else: [dg_accurate / dg_total]
        db_accuracy = if db_total == 0, do: [0], else: [db_accurate / db_total]

        acc
        |> Map.put(
          :buckets,
          acc[:buckets] ++
            [PredictionAnalyzerWeb.AccuracyView.formatted_row_scope(filter_params, bucket)]
        )
        |> Map.put(:prod_accs, acc[:prod_accs] ++ prod_accuracy)
        |> Map.put(:dg_accs, acc[:dg_accs] ++ dg_accuracy)
        |> Map.put(:db_accs, acc[:db_accs] ++ db_accuracy)
      end
    )
    |> Map.put(:chart_type, filter_params["chart_range"] || "Hourly")
    |> Map.put(:timeframe_resolution, filter_params["timeframe_resolution"] || "60")
  end

  @spec time_filters_present?(map()) :: boolean()
  defp time_filters_present?(filters) do
    (filters["chart_range"] == "Hourly" && filters["service_date"]) ||
      (filters["chart_range"] in ["Daily", "By Station"] && filters["date_start"] &&
         filters["date_end"])
  end
end
