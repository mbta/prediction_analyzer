defmodule PredictionAnalyzerWeb.AccuracyController do
  use PredictionAnalyzerWeb, :controller
  alias PredictionAnalyzer.PredictionAccuracy.PredictionAccuracy

  import Ecto.Query, only: [from: 2]

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(
        conn,
        %{
          "filters" =>
            %{
              "route_id" => route_id,
              "stop_id" => stop_id,
              "arrival_departure" => arrival_departure,
              "bin" => bin
            } = filter_params
        } = params
      )
      when not is_nil(route_id) and not is_nil(stop_id) and byte_size(arrival_departure) > 0 and
             byte_size(bin) > 0 do
    if time_filters_present?(filter_params) do
      {relevant_accuracies, error_msg} = PredictionAccuracy.filter(filter_params)

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
        |> PredictionAccuracy.stats_by_environment_and_chart_range(filter_params)
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
        error_msg: error_msg
      )
    else
      redirect_with_default_filters(conn, params)
    end
  end

  def index(conn, params) do
    redirect_with_default_filters(conn, params)
  end

  @spec redirect_with_default_filters(Plug.Conn.t(), map()) :: Plug.Conn.t()
  defp redirect_with_default_filters(conn, params) do
    filters = params["filters"] || %{}

    default_filters = %{
      "route_id" => "",
      "stop_id" => "",
      "arrival_departure" => "all",
      "bin" => "All"
    }

    time_filters =
      cond do
        filters["chart_range"] in ["Daily", "By Station"] && filters["daily_date_start"] &&
            filters["daily_date_end"] ->
          Map.take(filters, ["chart_range", "daily_date_start", "daily_date_end"])

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
      |> Map.put(:buckets, acc[:buckets] ++ [bucket])
      |> Map.put(:prod_accs, acc[:prod_accs] ++ prod_accuracy)
      |> Map.put(:dg_accs, acc[:dg_accs] ++ dg_accuracy)
    end)
    |> Map.put(:chart_type, filter_params["chart_range"] || "Hourly")
  end

  @spec time_filters_present?(map()) :: boolean()
  defp time_filters_present?(filters) do
    (filters["chart_range"] == "Hourly" && filters["service_date"]) ||
      (filters["chart_range"] in ["Daily", "By Station"] && filters["daily_date_start"] &&
         filters["daily_date_end"])
  end
end
