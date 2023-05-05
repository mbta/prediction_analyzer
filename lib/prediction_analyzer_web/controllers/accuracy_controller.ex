defmodule PredictionAnalyzerWeb.AccuracyController do
  use PredictionAnalyzerWeb, :controller
  alias PredictionAnalyzer.PredictionAccuracy.PredictionAccuracy
  alias PredictionAnalyzer.Filters

  import Ecto.Query, only: [from: 2]
  import PredictionAnalyzer.QueryUtilities, only: [aggregate_mean_error: 2, aggregate_rmse: 2]

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
    mode_atom = PredictionAnalyzer.Utilities.string_to_mode(mode)
    routes = PredictionAnalyzer.Utilities.routes_for_mode(mode_atom)

    if time_filters_present?(filter_params) do
      {relevant_accuracies, error_msg} = PredictionAccuracy.filter(filter_params)

      [prod_num_accurate, prod_num_predictions, prod_mean_error, prod_rmse] =
        from(
          acc in relevant_accuracies,
          select: [
            sum(acc.num_accurate_predictions),
            sum(acc.num_predictions),
            aggregate_mean_error(acc.mean_error, acc.num_predictions),
            aggregate_rmse(acc.root_mean_squared_error, acc.num_predictions)
          ],
          where: acc.environment == "prod" and acc.route_id in ^routes
        )
        |> PredictionAnalyzer.Repo.one!()

      [dev_green_num_accurate, dev_green_num_predictions, dev_green_mean_error, dev_green_rmse] =
        from(
          acc in relevant_accuracies,
          select: [
            sum(acc.num_accurate_predictions),
            sum(acc.num_predictions),
            aggregate_mean_error(acc.mean_error, acc.num_predictions),
            aggregate_rmse(acc.root_mean_squared_error, acc.num_predictions)
          ],
          where: acc.environment == "dev-green" and acc.route_id in ^routes
        )
        |> PredictionAnalyzer.Repo.one!()

      prod_accuracies =
        relevant_accuracies
        |> Filters.stats_by_environment_and_chart_range("prod", filter_params)
        |> PredictionAnalyzer.Repo.all()
        |> Map.new(fn [scope, _num_predictions, _num_accurate, _mean_error, _rmse] = accuracy ->
          {scope, accuracy}
        end)

      dev_green_accuracies =
        relevant_accuracies
        |> Filters.stats_by_environment_and_chart_range("dev-green", filter_params)
        |> PredictionAnalyzer.Repo.all()
        |> Map.new(fn [scope, _num_predictions, _num_accurate, _mean_error, _rmse] = accuracy ->
          {scope, accuracy}
        end)

      sort_function =
        if filter_params["chart_range"] == "Daily" do
          fn d1, d2 -> Date.compare(d1, d2) == :lt end
        else
          fn x, y -> x < y end
        end

      accuracies =
        (Map.keys(prod_accuracies) ++ Map.keys(dev_green_accuracies))
        |> Enum.uniq()
        |> Enum.sort(sort_function)
        |> Enum.map(fn scope ->
          prod_accuracy = prod_accuracies[scope] || [scope, 0, 0, nil, nil]
          dev_green_accuracy = dev_green_accuracies[scope] || [scope, 0, 0, nil, nil]

          {prod_accuracy, dev_green_accuracy}
        end)

      render(
        conn,
        "index.html",
        accuracies: accuracies,
        chart_data: Jason.encode!(set_up_accuracy_chart(accuracies, filter_params)),
        prod_num_accurate: prod_num_accurate,
        prod_num_predictions: prod_num_predictions,
        prod_mean_error: prod_mean_error,
        prod_rmse: prod_rmse,
        dev_green_num_accurate: dev_green_num_accurate,
        dev_green_num_predictions: dev_green_num_predictions,
        dev_green_mean_error: dev_green_mean_error,
        dev_green_rmse: dev_green_rmse,
        error_msg: error_msg,
        mode: mode_atom,
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

  def subway(conn, params) do
    conn
    |> assign(:mode, :subway)
    |> index(params)
  end

  def opmi_csv(
        conn,
        %{
          "filters" => filter_params
        } = params
      ) do
    columns = [
      :service_date,
      :mode,
      :route_id,
      :arrival_departure,
      :bin,
      :num_predictions,
      :num_accurate_predictions
    ]

    if time_filters_present?(filter_params) do
      {relevant_accuracies, _} = PredictionAccuracy.filter(filter_params)

      query_result =
        from(acc in relevant_accuracies,
          select: [
            fragment("to_char(date_trunc('week', service_date), 'MM/DD/YYYY') as service_date"),
            fragment("'subway' as mode"),
            acc.route_id,
            fragment("'' as arrival_departure"),
            acc.bin,
            sum(acc.num_predictions),
            sum(acc.num_accurate_predictions)
          ],
          where: acc.environment == "prod",
          group_by: [fragment("date_trunc('week', service_date)"), acc.route_id, acc.bin]
        )
        |> PredictionAnalyzer.Repo.all()

      filename =
        "#{DateTime.utc_now() |> DateTime.to_iso8601()}_PredictionAnalyzer_#{filter_params["date_start"]}_#{filter_params["date_end"]}_#{filter_params["mode"]}_export.csv"

      send_download(
        conn,
        {:binary,
         query_result
         |> Enum.map(fn row ->
           Enum.zip(columns, row) |> Map.new()
         end)
         |> CSV.encode(headers: true)
         |> Enum.to_list()
         |> Enum.reduce("", fn line, acc -> "#{acc}#{line}" end)},
        content_type: "application/csv",
        filename: filename
      )
    else
      redirect_with_default_filters(conn, %{
        params
        | filters: %{filter_params | mode: "subway", chart_range: "Daily"}
      })
    end
  end

  def opmi_csv(conn, _) do
    conn
    |> redirect_with_default_filters(
      %{"filters" => %{"mode" => "subway", "chart_range" => "Daily"}},
      :opmi_csv
    )
  end

  def commuter_rail(conn, params) do
    conn
    |> assign(:mode, :commuter_rail)
    |> index(params)
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
          Map.take(filters, ["chart_range", "service_date"])

        true ->
          %{"chart_range" => "Hourly", "service_date" => Timex.local() |> Date.to_string()}
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
    Enum.reduce(accuracies, %{buckets: [], prod_accs: [], dg_accs: []}, fn {[
                                                                              bucket,
                                                                              prod_total,
                                                                              prod_accurate,
                                                                              _prod_mean_error,
                                                                              _prod_rmse
                                                                            ],
                                                                            [
                                                                              _bucket,
                                                                              dg_total,
                                                                              dg_accurate,
                                                                              _dg_mean_error,
                                                                              _dg_rmse
                                                                            ]},
                                                                           acc ->
      prod_accuracy = if prod_total == 0, do: [0], else: [prod_accurate / prod_total]
      dg_accuracy = if dg_total == 0, do: [0], else: [dg_accurate / dg_total]

      acc
      |> Map.put(
        :buckets,
        acc[:buckets] ++
          [PredictionAnalyzerWeb.AccuracyView.formatted_row_scope(filter_params, bucket)]
      )
      |> Map.put(:prod_accs, acc[:prod_accs] ++ prod_accuracy)
      |> Map.put(:dg_accs, acc[:dg_accs] ++ dg_accuracy)
    end)
    |> Map.put(:chart_type, filter_params["chart_range"] || "Hourly")
  end

  @spec time_filters_present?(map()) :: boolean()
  defp time_filters_present?(filters) do
    (filters["chart_range"] == "Hourly" && filters["service_date"]) ||
      (filters["chart_range"] in ["Daily", "By Station"] && filters["date_start"] &&
         filters["date_end"])
  end
end
