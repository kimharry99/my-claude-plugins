---
globs: "tests/**/*.py"
description: "Test coding patterns: how to access class internals safely in tests"
---

# Test Patterns

## Do not access protected members directly in tests

Directly accessing `_protected` attributes or methods of the class under test is an anti-pattern — it couples tests to implementation details and breaks encapsulation.

**Instead**, create a minimal derived class inside the test file that exposes the protected internals through a public API:

```python
# Anti-pattern — do NOT do this
def test_internal_value(self) -> None:
    obj = MyClass()
    assert obj._internal == 42  # accessing protected member directly

# Correct pattern — derive a test subclass
class _TestableMyClass(MyClass):
    def get_internal(self) -> int:
        return self._internal

def test_internal_value(self) -> None:
    obj = _TestableMyClass()
    assert obj.get_internal() == 42
```

The derived test class should:
- Be defined in the test file (not in source)
- Use a leading underscore in its name (e.g., `_TestableFoo`) to indicate it is not part of the public API
- Only expose what is needed for that test module
