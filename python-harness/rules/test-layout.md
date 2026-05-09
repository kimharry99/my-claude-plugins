---
globs: "tests/**/*.py"
description: "Test file placement rules: mirror source tree under tests/"
---

# Test File Layout

Test files mirror the source tree under a `tests/` directory.

- **Unit tests**: `tests/unit/<package>/<path>/test_<module>.py` mirrors `src/<package>/<path>/<module>.py`
- **Example/integration tests**: `tests/examples/test_<name>.py`

For example:
- `src/module/submodule/code.py` → `tests/unit/module/submodule/code.py`
