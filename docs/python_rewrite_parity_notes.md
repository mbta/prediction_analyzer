# Python Rewrite Parity Notes

## Non-clean conversions tracked
- DB-specific `Repo.before_connect/1` IAM token + TLS behavior will be replaced by storage/S3 client auth configuration tests.
- SQL-fragment macros and raw INSERT/SELECT query paths will be recreated as Polars transformations; SQL-string parity is not a goal.
- Postgres partition/table management workers will become file partition management (date-based layout).
- Ecto/Phoenix test harness behavior is being replaced by `pytest` fixtures and Python HTTP test clients.
- Oban retry semantics will be mapped to Python worker retry/backoff behavior with equivalent assertions.

## Current status
- Initial Python package and test harness created.
- Pure helper modules and tests converted first.
