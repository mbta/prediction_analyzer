# Python Rewrite Parity Scope

This scope is frozen as **all currently tested behavior** in the Elixir codebase.

## Core/domain parity targets
- Pruner
- Prediction accuracy modules: aggregator, query, filters, tracker
- Missed predictions
- Query utilities
- Stop groups
- Utilities
- Stop name fetcher
- Vehicle parsing/tracking/comparison
- Prediction download
- Partition worker and repo hooks

## Web-facing parity targets
- Controllers: health, page, vehicle-events, accuracy, missed-predictions
- View helpers and accuracy view behavior

## Initial converted Python tests in this change
- `tests/test_utilities.py`
- `tests/filters/test_stop_groups.py`
- `tests/web/test_view_helpers.py`
- `tests/web/test_accuracy_view.py`
- `tests/storage_test.py`
