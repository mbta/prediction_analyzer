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

  @spec bin_options() :: [String.t()]
  def bin_options() do
    PredictionAccuracy.bins()
    |> Map.keys()
    |> Enum.sort_by(fn key ->
      String.split(key, "-", parts: 2)
      |> hd
      |> String.to_integer()
    end)
  end

  @spec chart_range_scope_header(String.t()) :: String.t()
  def chart_range_scope_header(chart_range) do
    case chart_range do
      "Hourly" -> "Hour"
      "Daily" -> "Date"
      "By Station" -> "Station"
    end
  end

  @spec formatted_row_scope(map(), String.t()) :: String.t()
  def formatted_row_scope(filter_params, row_scope) do
    if filter_params["chart_range"] == "By Station" do
      stop_name_fetcher = Application.get_env(:prediction_analyzer, :stop_name_fetcher)
      stop_name_fetcher.get_stop_name(row_scope)
    else
      row_scope
    end
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

  @spec stop_descriptions() :: [{String.t(), String.t()}]
  def stop_descriptions() do
    stop_name_fetcher = Application.get_env(:prediction_analyzer, :stop_name_fetcher)

    description_pairs =
      stop_name_fetcher.get_stop_descriptions()
      |> Enum.map(&stop_description/1)
      |> Enum.sort()

    [{"", ""} | description_pairs]
  end

  @spec stop_description({String.t(), String.t()}) :: {String.t(), String.t()}
  defp stop_description({id, description}) do
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
  def chart_range_id(chart_range) do
    normalized_chart_range =
      chart_range
      |> String.downcase()
      |> String.replace(~r/\s+/, "_")
      |> String.downcase()

    "link-#{normalized_chart_range}"
  end
end
