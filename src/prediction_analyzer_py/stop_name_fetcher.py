from __future__ import annotations

from typing import Protocol


class StopNameFetcher(Protocol):
    def get_stop_descriptions(self, mode: str) -> dict[str, str | None]:
        ...

    def get_stop_name(self, mode: str, stop_id: str) -> str:
        ...


class FakeStopNameFetcher:
    def get_stop_descriptions(self, mode: str) -> dict[str, str | None]:
        if mode == "subway":
            return {"12345": "John Doe Square", "67890": "Jane Roe St"}
        return {"No Description Stop": None}

    def get_stop_name(self, mode: str, stop_id: str) -> str:
        if mode == "subway" and stop_id == "70238":
            return "Cleveland Circle (Park Street & North)"
        return stop_id
