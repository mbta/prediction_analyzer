# Python Rewrite Testing Commands

## Local
- Install: `python -m pip install -e .[dev]`
- Run all Python tests: `pytest`
- Run a subset: `pytest tests/web/test_accuracy_view.py`

## CI equivalent command
- Python test command to add/use in CI: `python -m pip install -e .[dev] && pytest`
