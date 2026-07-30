from __future__ import annotations


def bins() -> dict[str, tuple[int, int, int, int]]:
    return {
        "0-3 min": (-30, 180, -60, 60),
        "3-6 min": (180, 360, -90, 120),
        "6-12 min": (360, 720, -150, 210),
        "12-30 min": (720, 1800, -240, 360),
    }


_KIND_ROWS = [
    (60, "mid_trip", "mid-trip"),
    (120, "at_terminal", "at terminal"),
    (360, "reverse", "reverse trip"),
]


def kinds() -> dict[int, str]:
    return {uncertainty: kind for uncertainty, kind, _ in _KIND_ROWS}


def kind_labels() -> list[tuple[str, str]]:
    return [(label, kind) for _, kind, label in _KIND_ROWS]
