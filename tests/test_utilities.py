from __future__ import annotations

from datetime import datetime
from zoneinfo import ZoneInfo

from prediction_analyzer_py import utilities

TZ = ZoneInfo("America/New_York")


def test_service_date_info_returns_current_date_if_after_3am() -> None:
    time = datetime(2018, 10, 30, 10, 0, 0, tzinfo=TZ)
    assert utilities.service_date_info(time) == (time.date(), 10, 0, 1_540_908_000, 1_540_908_300)


def test_service_date_info_returns_previous_date_if_before_3am() -> None:
    time = datetime(2018, 10, 30, 1, 0, 0, tzinfo=TZ)
    assert utilities.service_date_info(time) == (datetime(2018, 10, 29, tzinfo=TZ).date(), 25, 0, 1_540_875_600, 1_540_875_900)


def test_service_date_info_returns_start_of_current_5m_block() -> None:
    time = datetime(2018, 10, 30, 10, 7, 0, tzinfo=TZ)
    assert utilities.service_date_info(time) == (time.date(), 10, 5, 1_540_908_300, 1_540_908_600)


def test_ms_to_next_5m_returns_millis_to_next_5m_segment() -> None:
    soon = datetime(2024, 1, 1, 12, 5, 12, tzinfo=TZ)
    late = datetime(2024, 1, 1, 12, 0, 28, tzinfo=TZ)
    assert utilities.ms_to_next_5m(soon) == 318_000
    assert utilities.ms_to_next_5m(late) == 302_000


def test_ms_to_next_hour_returns_millis_to_top_of_next_hour() -> None:
    soon = datetime(2024, 1, 1, 12, 58, 0, tzinfo=TZ)
    late = datetime(2024, 1, 1, 12, 2, 0, tzinfo=TZ)
    assert utilities.ms_to_next_hour(soon) == 150_000
    assert utilities.ms_to_next_hour(late) == 3_510_000


def test_get_week_range_gets_date_and_week_later_date() -> None:
    time = datetime(2019, 6, 9, 10, 0, 0, tzinfo=TZ)
    assert utilities.get_week_range(time) == (
        datetime(2019, 6, 9, tzinfo=TZ).date(),
        datetime(2019, 6, 15, tzinfo=TZ).date(),
    )


def test_ms_to_next_week_uses_days_to_end_of_week() -> None:
    time = datetime(2019, 6, 8, 10, 0, 0, tzinfo=TZ)
    assert utilities.ms_to_next_week(time) == 572_400_000


def test_ms_to_next_week_when_end_of_week_is_zero_adds_7_days() -> None:
    time = datetime(2019, 6, 9, 10, 0, 0, tzinfo=TZ)
    assert utilities.ms_to_next_week(time) == 486_000_000


def test_generic_stop_id_maps_terminal_child_to_generic() -> None:
    assert utilities.generic_stop_id("Alewife-01") == "70061"


def test_generic_stop_id_keeps_generic_terminal_stop() -> None:
    assert utilities.generic_stop_id("70061") == "70061"


def test_generic_stop_id_keeps_non_terminal_stop() -> None:
    assert utilities.generic_stop_id("70063") == "70063"
