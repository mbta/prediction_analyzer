from __future__ import annotations

from prediction_analyzer_py.stop_name_fetcher import FakeStopNameFetcher


def fake_stop_name_fetcher() -> FakeStopNameFetcher:
    return FakeStopNameFetcher()
