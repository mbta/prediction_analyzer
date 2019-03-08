defmodule PredictionAnalyzerWeb.AccuracyView do
  use PredictionAnalyzerWeb, :view
  alias PredictionAnalyzer.PredictionAccuracy.PredictionAccuracy

  def accuracy_percentage(num_accurate, num_predictions)
      when is_integer(num_accurate) and is_integer(num_predictions) and num_predictions != 0 do
    Float.round(100 * num_accurate / num_predictions, 2)
  end

  def accuracy_percentage(_, _) do
    0
  end

  def service_dates(now \\ Timex.local()) do
    0..7
    |> Enum.map(fn n ->
      now
      |> Timex.shift(days: -1 * n)
      |> DateTime.to_date()
      |> Date.to_string()
    end)
  end

  @spec show_download?(map()) :: boolean()
  def show_download?(%{
        "filters" => %{
          "stop_id" => stop_id,
          "service_date" => service_date,
          "chart_range" => "Hourly"
        }
      })
      when not is_nil(stop_id) and stop_id != "" and not is_nil(service_date) and
             service_date != "" do
    true
  end

  def show_download?(_params) do
    false
  end

  def stop_names() do
    stop_name_fetcher = Application.get_env(:prediction_analyzer, :stop_name_fetcher)

    stop_name_fetcher.get_stop_map()
    |> Enum.map(&stop_name/1)
    |> Enum.sort()
  end

  defp stop_name({"", ""}), do: {"", ""}

  defp stop_name({id, description}) do
    {"#{description} (#{id})", id}
  end

  def predictions_path_with_filters(
        %{params: %{"filters" => %{"stop_id" => stop_id, "service_date" => service_date}}} = conn,
        hour
      ) do
    predictions_path(conn, :index, %{
      "stop_id" => stop_id,
      "service_date" => service_date,
      "hour" => hour
    })
  end

  def predictions_path_with_filters(_params, _hour) do
    "#"
  end

  @spec button_class(map(), String.t()) :: String.t()
  def button_class(%{params: %{"filters" => %{"route_id" => route_id}}}, route_id),
    do: "button-link button-link-active route-button"

  def button_class(%{params: %{"filters" => %{"route_id" => _route}}}, _other_route),
    do: "button-link route-button"

  def button_class(%{}, ""), do: "button-link button-link-active route-button"
  def button_class(%{}, _else), do: "button-link route-button"

  @spec chart_range_class(map(), String.t()) :: String.t()
  def chart_range_class(%{params: %{"filters" => %{"chart_range" => chart_range}}}, chart_range),
    do: "chart-range-link chart-range-link-active"

  def chart_range_class(_, _), do: "chart-range-link"

  @spec chart_range_id(String.t()) :: String.t()
  def chart_range_id(chart_range), do: "link-#{String.downcase(chart_range)}"
end
