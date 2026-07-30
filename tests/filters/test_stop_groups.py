from __future__ import annotations

from prediction_analyzer_py.filters.stop_groups import expand_groups, group_names


def test_expand_groups_replaces_group_ids_with_stops() -> None:
    assert expand_groups(["stop1", "_ashmont_branch", "stop2"]) == [
        "stop1",
        "70085",
        "70086",
        "70087",
        "70088",
        "70089",
        "70090",
        "70091",
        "70092",
        "70093",
        "70094",
        "stop2",
    ]


def test_group_names_returns_group_ids_and_labels() -> None:
    assert group_names()[0] == ("Trunk stops", "_trunk")
