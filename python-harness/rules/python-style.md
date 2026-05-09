---
globs: "*.py"
description: "Python code style conventions following Google Python Style Guide"
---

# Python Style Guide

This project follows the **Google Python Style Guide** (https://google.github.io/styleguide/pyguide.html).

Key conventions:
- Use Google-style docstrings (Args, Returns, Raises sections)
- Use 4-space indentation
- Use `snake_case` for functions, methods, and variables
- Use `CamelCase` for classes
- Use `UPPER_SNAKE_CASE` for constants
- Maximum line length: 80 characters
- Use type annotations where appropriate
- Imports should be on separate lines, grouped (stdlib, third-party, local)
- Use absolute imports only. `from . import x` or `from ..module import y` are not allowed.
- Use top-level imports only. Place all `import` statements at the top of the file, not inside functions, methods, or conditionals. (Exception: test files are exempt from this rule.)
- Use direct attribute access instead of `setattr`/`getattr`/`hasattr`.
- Always include `from __future__ import annotations` at the top of every Python file (before other imports).
