from __future__ import annotations

from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

Mode = str
TZ = ZoneInfo("America/New_York")

_GENERIC_STOP_MAP = {
    "Alewife-01": "70061",
    "Alewife-02": "70061",
    "Braintree-01": "70105",
    "Braintree-02": "70105",
    "Forest Hills-01": "70001",
    "Forest Hills-02": "70001",
    "Oak Grove-01": "70036",
    "Oak Grove-02": "70036",
    "70511": "70512",
}


def _ensure_tz(dt: datetime) -> datetime:
    if dt.tzinfo is None:
        return dt.replace(tzinfo=TZ)
    return dt.astimezone(TZ)


def service_date_info(timestamp: datetime) -> tuple[datetime.date, int, int, int, int]:
    timestamp = _ensure_tz(timestamp)
    minute = (timestamp.minute // 5) * 5
    beginning = int(timestamp.replace(minute=minute, second=0, microsecond=0).timestamp())
    end = beginning + 300

    if timestamp.hour < 3:
        return ((timestamp - timedelta(days=1)).date(), timestamp.hour + 24, minute, beginning, end)
    return (timestamp.date(), timestamp.hour, minute, beginning, end)


def get_week_range(timestamp: datetime) -> tuple[datetime.date, datetime.date]:
    timestamp = _ensure_tz(timestamp)
    beginning = timestamp.replace(hour=3, minute=0, second=0, microsecond=0)
    end = beginning + timedelta(days=6)
    return beginning.date(), end.date()


def ms_to_next_5m(local_now: datetime | None = None) -> int:
    local_now = _ensure_tz(local_now or datetime.now(TZ))
    minute_shift = 5 - (local_now.minute % 5)
    target = (local_now + timedelta(minutes=minute_shift)).replace(second=30, microsecond=0)
    return int((target - local_now).total_seconds() * 1000)


def ms_to_next_hour(local_now: datetime | None = None) -> int:
    local_now = _ensure_tz(local_now or datetime.now(TZ))
    target = (local_now + timedelta(hours=1)).replace(minute=0, second=30, microsecond=0)
    return int((target - local_now).total_seconds() * 1000)


def ms_to_next_week(local_now: datetime | None = None) -> int:
    local_now = _ensure_tz(local_now or datetime.now(TZ))
    # Mirrors Timex.days_to_end_of_week(:sun), where week starts on Sunday
    # and ends on Saturday.
    days_to_end_of_week = (5 - local_now.weekday()) % 7
    if days_to_end_of_week == 0:
        days_to_end_of_week = 7
    target = (local_now + timedelta(days=days_to_end_of_week)).replace(hour=1, minute=0, second=0, microsecond=0)
    return int((target - local_now).total_seconds() * 1000)


def generic_stop_id(stop_id: str) -> str:
    if stop_id.startswith("Union Square-"):
        return "70503"
    return _GENERIC_STOP_MAP.get(stop_id, stop_id)


def routes_for_mode(mode: Mode) -> list[str]:
    if mode == "commuter_rail":
        return [
            "CR-Fitchburg",
            "CR-Lowell",
            "CR-Haverhill",
            "CR-Newburyport",
            "CR-Worcester",
            "CR-Needham",
            "CR-Franklin",
            "CR-Providence",
            "CR-Fairmount",
            "CR-Middleborough",
            "CR-Kingston",
            "CR-Greenbush",
            "CR-Foxboro",
        ]
    return ["Red", "Blue", "Orange", "Green-B", "Green-C", "Green-D", "Green-E", "Mattapan"]


def string_to_mode(mode: str) -> Mode:
    return "commuter_rail" if mode == "commuter_rail" else "subway"
