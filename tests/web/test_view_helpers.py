from __future__ import annotations

from prediction_analyzer_py.web.view_helpers import button_class, chart_range_class, chart_range_id


def test_button_class() -> None:
    assert "mode-button" in button_class({"params": {"filters": {"route_id": "Blue"}}}, "Blue")
    assert "mode-button" in button_class({"params": {"filters": {"route_id": "Blue"}}}, "Red")
    assert "mode-button" in button_class({}, "Red")
    assert "mode-button" in button_class({}, "")


def test_chart_range_class() -> None:
    matching_conn = {"params": {"filters": {"chart_range": "some_range"}}}
    unmatching_conn = {"params": {"filters": {"chart_range": "other_range"}}}
    assert chart_range_class(matching_conn, "some_range") == "chart-range-link chart-range-link-active"
    assert chart_range_class(unmatching_conn, "some_range") == "chart-range-link"


def test_chart_range_id() -> None:
    assert chart_range_id("SomeRange") == "link-somerange"
