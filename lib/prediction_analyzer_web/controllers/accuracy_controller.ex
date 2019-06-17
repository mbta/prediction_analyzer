defmodule PredictionAnalyzerWeb.AccuracyController do
  use PredictionAnalyzerWeb, :controller
  alias PredictionAnalyzer.PredictionAccuracy.PredictionAccuracy
  alias PredictionAnalyzer.WeeklyAccuracies.WeeklyAccuracies
  alias PredictionAnalyzer.Filters

  import Ecto.Query, only: [from: 2]

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(
        conn,
        %{
          "filters" =>
            %{
              "route_ids" => route_ids,
              "stop_id" => stop_id,
              "direction_id" => direction_id,
              "arrival_departure" => arrival_departure,
              "chart_range" => "Weekly",
              "bin" => bin,
              "mode" => mode
            } = filter_params
        } = params
      )
      when not is_nil(route_ids) and not is_nil(stop_id) and not is_nil(direction_id) and
             byte_size(arrival_departure) > 0 and byte_size(bin) > 0 do
    mode_atom = PredictionAnalyzer.Utilities.string_to_mode(mode)
    routes = PredictionAnalyzer.Utilities.routes_for_mode(mode_atom)

    if time_filters_present?(filter_params) do
      {relevant_accuracies, error_msg} = WeeklyAccuracies.filter(filter_params)

      [prod_num_accurate, prod_num_predictions] =
        from(
          acc in relevant_accuracies,
          select: [sum(acc.num_accurate_predictions), sum(acc.num_predictions)],
          where: acc.environment == "prod" and acc.route_id in ^routes
        )
        |> PredictionAnalyzer.Repo.one!()

      [dev_green_num_accurate, dev_green_num_predictions] =
        from(
          acc in relevant_accuracies,
          select: [sum(acc.num_accurate_predictions), sum(acc.num_predictions)],
          where: acc.environment == "dev-green" and acc.route_id in ^routes
        )
        |> PredictionAnalyzer.Repo.one!()

      accuracies =
        relevant_accuracies
        |> Filters.stats_by_environment_and_chart_range(filter_params)
        |> PredictionAnalyzer.Repo.all()

      render(
        conn,
        "index.html",
        accuracies: accuracies,
        chart_data: Jason.encode!(set_up_accuracy_chart(accuracies, filter_params)),
        prod_num_accurate: prod_num_accurate,
        prod_num_predictions: prod_num_predictions,
        dev_green_num_accurate: dev_green_num_accurate,
        dev_green_num_predictions: dev_green_num_predictions,
        error_msg: error_msg,
        mode: mode_atom
      )
    else
      redirect_with_default_filters(conn, params)
    end
  end

  def index(
        conn,
        %{
          "filters" =>
            %{
              "route_ids" => route_ids,
              "stop_id" => stop_id,
              "direction_id" => direction_id,
              "arrival_departure" => arrival_departure,
              "bin" => bin,
              "mode" => mode
            } = filter_params
        } = params
      )
      when not is_nil(route_ids) and not is_nil(stop_id) and not is_nil(direction_id) and
             byte_size(arrival_departure) > 0 and byte_size(bin) > 0 do
    mode_atom = PredictionAnalyzer.Utilities.string_to_mode(mode)
    routes = PredictionAnalyzer.Utilities.routes_for_mode(mode_atom)

    if time_filters_present?(filter_params) do
      {relevant_accuracies, error_msg} = PredictionAccuracy.filter(filter_params)

      [prod_num_accurate, prod_num_predictions] =
        from(
          acc in relevant_accuracies,
          select: [sum(acc.num_accurate_predictions), sum(acc.num_predictions)],
          where: acc.environment == "prod" and acc.route_id in ^routes
        )
        |> PredictionAnalyzer.Repo.one!()

      [dev_green_num_accurate, dev_green_num_predictions] =
        from(
          acc in relevant_accuracies,
          select: [sum(acc.num_accurate_predictions), sum(acc.num_predictions)],
          where: acc.environment == "dev-green" and acc.route_id in ^routes
        )
        |> PredictionAnalyzer.Repo.one!()

      accuracies =
        relevant_accuracies
        |> Filters.stats_by_environment_and_chart_range(filter_params)
        |> PredictionAnalyzer.Repo.all()

      render(
        conn,
        "index.html",
        accuracies: accuracies,
        chart_data: Jason.encode!(set_up_accuracy_chart(accuracies, filter_params)),
        prod_num_accurate: prod_num_accurate,
        prod_num_predictions: prod_num_predictions,
        dev_green_num_accurate: dev_green_num_accurate,
        dev_green_num_predictions: dev_green_num_predictions,
        error_msg: error_msg,
        mode: mode_atom
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

  def commuter_rail(conn, params) do
    conn
    |> assign(:mode, :commuter_rail)
    |> index(params)
  end

  @spec redirect_with_default_filters(Plug.Conn.t(), map()) :: Plug.Conn.t()
  defp redirect_with_default_filters(conn, params) do
    filters = params["filters"] || %{}

    default_filters = %{
      "route_ids" => "",
      "stop_id" => "",
      "direction_id" => "any",
      "arrival_departure" => "all",
      "bin" => "All",
      "mode" => conn.assigns[:mode] || filters["mode"] || "subway"
    }

    time_filters =
      cond do
        filters["chart_range"] in ["Daily", "By Station"] ->
          %{
            "chart_range" => "Daily",
            "daily_date_start" => Timex.local() |> Timex.shift(days: -14) |> Date.to_string(),
            "daily_date_end" => Timex.local() |> Date.to_string()
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
      to: accuracy_path(conn, :index, %{"filters" => filters})
    )
  end

  @spec set_up_accuracy_chart(list(), map()) :: map()
  defp set_up_accuracy_chart(accuracies, filter_params) do
    Enum.reduce(accuracies, %{buckets: [], prod_accs: [], dg_accs: []}, fn [
                                                                             bucket,
                                                                             prod_total,
                                                                             prod_accurate,
                                                                             dg_total,
                                                                             dg_accurate
                                                                           ],
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
      (filters["chart_range"] in ["Weekly", "Daily", "By Station"] && filters["daily_date_start"] &&
         filters["daily_date_end"])
  end
end
