from __future__ import annotations

from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

from prediction_analyzer_py.filters.core import bins, kind_labels
from prediction_analyzer_py.filters.stop_groups import group_names
from prediction_analyzer_py.stop_name_fetcher import FakeStopNameFetcher, StopNameFetcher
from prediction_analyzer_py.utilities import routes_for_mode, string_to_mode

TZ = ZoneInfo("America/New_York")


def accuracy_percentage(num_accurate: int, num_predictions: int) -> float:
    if isinstance(num_accurate, int) and isinstance(num_predictions, int) and num_predictions != 0:
        return round(100 * num_accurate / num_predictions, 2)
    return 0.0


def route_options(mode: str) -> list[tuple[str, str]]:
    options = [("All", "")] + [(route, route) for route in routes_for_mode(mode)]
    if mode == "subway":
        options += [
            ("Green-All", "Green-B,Green-C,Green-D,Green-E"),
            ("Light Rail", "Green-B,Green-C,Green-D,Green-E,Mattapan"),
            ("Heavy Rail", "Red,Orange,Blue"),
        ]
    return options


def bin_options() -> list[str]:
    return sorted(bins().keys(), key=lambda item: int(item.split("-", 1)[0]))


def chart_range_scope_header(chart_range: str) -> str:
    return {"Hourly": "Hour", "Daily": "Date", "By Station": "Station"}[chart_range]


def formatted_row_scope(filter_params: dict[str, str], row_scope: str | tuple[int, int], stop_name_fetcher: StopNameFetcher | None = None) -> str:
    if isinstance(row_scope, tuple):
        return f"{row_scope[0]:02d}:{row_scope[1]:02d}"

    if filter_params.get("chart_range") == "By Station":
        fetcher = stop_name_fetcher or FakeStopNameFetcher()
        mode = string_to_mode(filter_params.get("mode", "subway"))
        return fetcher.get_stop_name(mode, row_scope)

    return row_scope


def service_dates(now: datetime | None = None) -> list[str]:
    now = now or datetime.now(TZ)
    return [(now - timedelta(days=n)).date().isoformat() for n in range(8)]


def kind_filter_options() -> list[tuple[str, str]]:
    return kind_labels()


def stop_filter_options(mode: str, stop_name_fetcher: StopNameFetcher | None = None):
    fetcher = stop_name_fetcher or FakeStopNameFetcher()
    stop_options = sorted((_stop_option(item) for item in fetcher.get_stop_descriptions(mode).items()))
    if mode == "commuter_rail":
        return stop_options
    return {"Groups": group_names(), "Stops": stop_options}


def _stop_option(item: tuple[str, str | None]) -> tuple[str, str]:
    stop_id, description = item
    if description is None:
        return (stop_id, stop_id)
    return (f"{description} ({stop_id})", stop_id)


def time_resolution_options() -> list[tuple[str, str]]:
    return [("10 minutes", "10"), ("15 minutes", "15"), ("30 minutes", "30"), ("60 minutes", "60")]
