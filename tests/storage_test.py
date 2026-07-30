from __future__ import annotations

import polars as pl

from prediction_analyzer_py.storage.flat_files import FlatFileStore


def test_flat_file_store_round_trip_parquet(tmp_path) -> None:
    store = FlatFileStore(base_uri=str(tmp_path))
    df = pl.DataFrame({"a": [1, 2], "b": ["x", "y"]})
    store.write_dataframe(df, "sample.parquet")
    read_df = store.read_dataframe("sample.parquet")
    assert read_df.to_dict(as_series=False) == {"a": [1, 2], "b": ["x", "y"]}
