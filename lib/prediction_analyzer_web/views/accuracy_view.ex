defmodule PredictionAnalyzerWeb.AccuracyView do
  use PredictionAnalyzerWeb, :view
  alias PredictionAnalyzer.Filters

  def accuracy_percentage(num_accurate, num_predictions)
      when is_integer(num_accurate) and is_integer(num_predictions) and num_predictions != 0 do
    Float.round(100 * num_accurate / num_predictions, 2)
  end

  def accuracy_percentage(_, _) do
    0
  end

  @spec mode_string(atom()) :: String.t()
  def mode_string(:commuter_rail) do
    "Commuter Rail"
  end

  def mode_string(_) do
    "Subway"
  end

  @spec route_options(PredictionAnalyzer.Utilities.mode()) :: [{String.t(), String.t()}]
  def route_options(mode) do
    route_options = [
      {"All", ""}
      | Enum.map(
          PredictionAnalyzer.Utilities.routes_for_mode(mode),
          &{&1, &1}
        )
    ]

    route_options ++ route_grouping_options(mode)
  end

  @spec route_grouping_options(PredictionAnalyzer.Utilities.mode()) :: [
          {String.t(), String.t()}
        ]
  defp route_grouping_options(:subway) do
    [
      {"Green-All", "Green-B,Green-C,Green-D,Green-E"},
      {"Light Rail", "Green-B,Green-C,Green-D,Green-E,Mattapan"},
      {"Heavy Rail", "Red,Orange,Blue"}
    ]
  end

  defp route_grouping_options(:commuter_rail), do: []

  @spec bin_options() :: [String.t()]
  def bin_options() do
    Filters.bins()
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
  def formatted_row_scope(_, {hour_of_day, minute_of_hour}) do
    hour = hour_of_day |> Integer.to_string() |> String.pad_leading(2, "0")
    minute = minute_of_hour |> Integer.to_string() |> String.pad_leading(2, "0")

    "#{hour}:#{minute}"
  end

  def formatted_row_scope(filter_params, row_scope) do
    if filter_params["chart_range"] == "By Station" do
      stop_name_fetcher = Application.get_env(:prediction_analyzer, :stop_name_fetcher)

      filter_params["mode"]
      |> PredictionAnalyzer.Utilities.string_to_mode()
      |> stop_name_fetcher.get_stop_name(row_scope)
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

  @spec kind_filter_options() :: [{String.t(), String.t()}]
  def kind_filter_options, do: Filters.kind_labels()

  @spec stop_filter_options(PredictionAnalyzer.Utilities.mode()) ::
          %{String.t() => [{String.t(), String.t()}]} | [{String.t(), String.t()}]
  def stop_filter_options(mode) do
    stop_options =
      Application.get_env(:prediction_analyzer, :stop_name_fetcher).get_stop_descriptions(mode)
      |> Enum.map(&stop_option/1)
      |> Enum.sort()

    # Groups are currently not applicable to Commuter Rail
    case mode do
      :commuter_rail -> stop_options
      :subway -> %{"Groups" => Filters.StopGroups.group_names(), "Stops" => stop_options}
    end
  end

  @spec stop_option({String.t(), String.t() | nil}) :: {String.t(), String.t()}
  defp stop_option({id, nil}), do: {id, id}
  defp stop_option({id, description}), do: {"#{description} (#{id})", id}

  @spec button_class(map(), atom()) :: String.t()
  def button_class(%{params: %{"filters" => %{"mode" => mode_id}}}, mode) do
    case PredictionAnalyzer.Utilities.string_to_mode(mode_id) do
      ^mode -> "button-link button-link-active mode-button"
      _ -> "button-link mode-button"
    end
  end

  def button_class(%{}, _else), do: "button-link mode-button"

  @spec chart_range_class(map(), String.t()) :: String.t()
  def chart_range_class(%{params: %{"filters" => %{"chart_range" => "Hourly"}}}, "Single Day"),
    do: "chart-range-link chart-range-link-active"

  def chart_range_class(%{params: %{"filters" => %{"chart_range" => "Daily"}}}, "Multi-Day"),
    do: "chart-range-link chart-range-link-active"

  def chart_range_class(%{params: %{"filters" => %{"chart_range" => chart_range}}}, chart_range),
    do: "chart-range-link chart-range-link-active"

  def chart_range_class(_, _), do: "chart-range-link"

  @spec chart_range_id(String.t()) :: String.t()
  def chart_range_id("Single Day"), do: "link-hourly"
  def chart_range_id("Multi-Day"), do: "link-daily"

  def chart_range_id(chart_range) do
    normalized_chart_range =
      chart_range
      |> String.downcase()
      |> String.replace(~r/\s+/, "_")
      |> String.downcase()

    "link-#{normalized_chart_range}"
  end

  def time_resolution_options() do
    [
      {"10 minutes", "10"},
      {"15 minutes", "15"},
      {"30 minutes", "30"},
      {"60 minutes", "60"}
    ]
  end

  def explainer_label(f, field), do: explainer_label(f, field, humanize(field))

  def explainer_label(f, field, label_text) do
    label f, field do
      [
        label_text,
        " ",
        explainer_element(field)
      ]
    end
  end

  defp explainer_element(field), do: explainer_element(field, explainer_text(field))

  defp explainer_element(_, tooltip),
    do: [
      content_tag(
        :span,
        [
          content_tag(:div, tooltip, class: "explainer-text")
        ],
        class: "explainer"
      )
    ]

  defp explainer_text(:route_ids), do: "Limit results to a single route or route type"
  defp explainer_text(:stop_ids), do: "Limit results to a single stop or set of stops"
  defp explainer_text(:direction_id), do: "Limit results to a single direction"

  defp explainer_text(:kinds),
    do: [
      content_tag(:p, "Limit results to a type/type(s) of predictions:"),
      content_tag(:ul, [
        content_tag(:li, "At terminal: Trips that originate at a terminal"),
        content_tag(:li, "Mid-trip: Trips that do not originate at a terminal"),
        content_tag(
          :li,
          "Reverse trip: Trips that involve a reversal of direction and a departure back to a terminal"
        )
      ])
    ]

  defp explainer_text(:bin),
    do:
      "Limit results to predictions that match a certain time period bin (based on the duration of the predicted trip)"

  defp explainer_text(:service_date), do: "Select a service date for which to view predictions"

  defp explainer_text(:date_start),
    do: "Select a starting date to view past predictions over a period of multiple days"

  defp explainer_text(:date_end),
    do: "Select an end date to view past predictions over a period of multiple days"

  defp explainer_text(:timeframe_resolution),
    do: "Adjust the timeframe resolution to view results for smaller timespans"

  defp explainer_text(:in_next_two),
    do:
      "Limit results to predictions riders see, i.e. those that are displayed on in-station countdown signs (typically the next two arrival predictions)"
end
