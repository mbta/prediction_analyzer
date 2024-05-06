defmodule PredictionAnalyzerWeb.ViewHelpers do
  use Phoenix.HTML
  @spec mode_string(atom()) :: String.t()
  def mode_string(:commuter_rail) do
    "Commuter Rail"
  end

  def mode_string(_) do
    "Subway"
  end

  @spec button_class(map(), atom()) :: String.t()
  def button_class(%{params: %{"filters" => %{"mode" => mode_id}}}, mode) do
    case PredictionAnalyzer.Utilities.string_to_mode(mode_id) do
      ^mode -> "button-link button-link-active mode-button"
      _ -> "button-link mode-button"
    end
  end

  def button_class(%{}, _else), do: "button-link mode-button"

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

  defp explainer_text(:route_ids), do: "Limit results to a single route or route type"
  defp explainer_text(:stop_ids), do: "Limit results to a single stop or set of stops"
  defp explainer_text(:direction_id), do: "Limit results to a single direction"
  defp explainer_text(:date), do: "Lmit results to a service date"
  defp explainer_text(:env), do: "Select the environment to query"

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
