from __future__ import annotations

from datetime import datetime
from zoneinfo import ZoneInfo

from prediction_analyzer_py.stop_name_fetcher import FakeStopNameFetcher
from prediction_analyzer_py.web.accuracy_view import (
    bin_options,
    chart_range_scope_header,
    formatted_row_scope,
    route_options,
    service_dates,
    stop_filter_options,
)

TZ = ZoneInfo("America/New_York")


def test_route_options_subway_returns_subway_values() -> None:
    options = route_options("subway")
    assert ("All", "") in options
    assert ("Blue", "Blue") in options
    assert ("Heavy Rail", "Red,Orange,Blue") in options


def test_route_options_commuter_rail_returns_cr_values() -> None:
    options = route_options("commuter_rail")
    assert ("All", "") in options
    assert ("CR-Fitchburg", "CR-Fitchburg") in options
    assert ("Heavy Rail", "Red,Orange,Blue") not in options


def test_bin_options_returns_bin_names_in_order() -> None:
    assert bin_options() == ["0-3 min", "3-6 min", "6-12 min", "12-30 min"]


def test_chart_range_scope_header_returns_proper_value() -> None:
    assert chart_range_scope_header("Hourly") == "Hour"
    assert chart_range_scope_header("Daily") == "Date"
    assert chart_range_scope_header("By Station") == "Station"


def test_formatted_row_scope_returns_station_name_for_by_station() -> None:
    assert (
        formatted_row_scope({"chart_range": "By Station", "mode": "subway"}, "70238", FakeStopNameFetcher())
        == "Cleveland Circle (Park Street & North)"
    )


def test_formatted_row_scope_returns_row_scope_unchanged_otherwise() -> None:
    assert formatted_row_scope({"chart_range": "Hourly"}, "some_hour") == "some_hour"
    assert formatted_row_scope({"chart_range": "Daily"}, "some_day") == "some_day"


def test_service_dates() -> None:
    now = datetime(2018, 10, 31, 12, 0, tzinfo=TZ)
    assert service_dates(now) == [
        "2018-10-31",
        "2018-10-30",
        "2018-10-29",
        "2018-10-28",
        "2018-10-27",
        "2018-10-26",
        "2018-10-25",
        "2018-10-24",
    ]


def test_stop_filter_options_returns_subway_stops_and_groups() -> None:
    options = stop_filter_options("subway", FakeStopNameFetcher())
    assert options["Groups"][0] == ("Trunk stops", "_trunk")
    assert options["Stops"] == [
        ("Jane Roe St (67890)", "67890"),
        ("John Doe Square (12345)", "12345"),
    ]


def test_stop_filter_options_returns_commuter_rail_stops() -> None:
    assert stop_filter_options("commuter_rail", FakeStopNameFetcher()) == [
        ("No Description Stop", "No Description Stop")
    ]
