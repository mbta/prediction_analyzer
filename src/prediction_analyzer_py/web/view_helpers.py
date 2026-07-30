from __future__ import annotations

from prediction_analyzer_py.utilities import string_to_mode


def mode_string(mode: str) -> str:
    return "Commuter Rail" if mode == "commuter_rail" else "Subway"


def button_class(conn: dict, mode: str) -> str:
    mode_id = conn.get("params", {}).get("filters", {}).get("mode")
    if mode_id is None:
        return "button-link mode-button"
    return "button-link button-link-active mode-button" if string_to_mode(mode_id) == mode else "button-link mode-button"


def chart_range_class(conn: dict, chart_range: str) -> str:
    current = conn.get("params", {}).get("filters", {}).get("chart_range")
    if current == "Hourly" and chart_range == "Single Day":
        return "chart-range-link chart-range-link-active"
    if current == "Daily" and chart_range == "Multi-Day":
        return "chart-range-link chart-range-link-active"
    if current == chart_range:
        return "chart-range-link chart-range-link-active"
    return "chart-range-link"


def chart_range_id(chart_range: str) -> str:
    if chart_range == "Single Day":
        return "link-hourly"
    if chart_range == "Multi-Day":
        return "link-daily"
    return f"link-{chart_range.lower().replace(' ', '_')}"
