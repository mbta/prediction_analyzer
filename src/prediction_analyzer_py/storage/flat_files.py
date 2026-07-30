from __future__ import annotations

from pathlib import PurePosixPath

import fsspec
import polars as pl


class FlatFileStore:
    def __init__(self, base_uri: str = ".", storage_options: dict | None = None) -> None:
        self.base_uri = base_uri
        self.storage_options = storage_options or {}

    def resolve_path(self, relative_or_absolute_path: str) -> str:
        if relative_or_absolute_path.startswith("s3://"):
            return relative_or_absolute_path
        if self.base_uri.startswith("s3://"):
            return str(PurePosixPath(self.base_uri.rstrip("/")) / relative_or_absolute_path)
        return str(PurePosixPath(self.base_uri) / relative_or_absolute_path)

    def read_dataframe(self, path: str, file_type: str | None = None) -> pl.DataFrame:
        resolved = self.resolve_path(path)
        file_type = file_type or _infer_type(resolved)
        if file_type == "parquet":
            return pl.read_parquet(resolved, storage_options=self.storage_options)
        if file_type == "json":
            return pl.read_json(resolved)
        if file_type == "csv":
            return pl.read_csv(resolved)
        raise ValueError(f"Unsupported file type: {file_type}")

    def write_dataframe(self, df: pl.DataFrame, path: str, file_type: str | None = None) -> None:
        resolved = self.resolve_path(path)
        file_type = file_type or _infer_type(resolved)
        if file_type == "parquet":
            df.write_parquet(resolved, storage_options=self.storage_options)
            return
        if file_type == "json":
            df.write_json(resolved)
            return
        if file_type == "csv":
            df.write_csv(resolved)
            return
        raise ValueError(f"Unsupported file type: {file_type}")

    def list_files(self, glob_path: str) -> list[str]:
        fs, _, paths = fsspec.get_fs_token_paths(self.resolve_path(glob_path), storage_options=self.storage_options)
        return sorted(fs.glob(paths[0]))


def _infer_type(path: str) -> str:
    if path.endswith(".parquet"):
        return "parquet"
    if path.endswith(".json"):
        return "json"
    if path.endswith(".csv"):
        return "csv"
    raise ValueError("Could not infer file type from extension")
