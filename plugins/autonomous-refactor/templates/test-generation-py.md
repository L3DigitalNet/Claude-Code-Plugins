# Test Generation Instructions — Python

<!-- Loaded by agents/test-generator.md when language == "python".
     Defines the test structure, coverage requirements, and file conventions
     the agent must follow when generating the baseline test suite. -->

## Framework

Use **pytest** with standard fixtures and `pytest.mark.parametrize`. Import from `unittest.mock` for patching.

Do NOT use `unittest.TestCase` subclasses — use plain pytest functions and fixtures.

## File Naming

Write the test file to: `.claude/state/refactor-tests/test_<original-basename>.py`

Example: target is `src/auth/validator.py` → test file is `.claude/state/refactor-tests/test_validator.py`

If the test file imports from the target module, add the target's parent directory to `sys.path` at the top:
```python
import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
```

## Coverage Requirements

For every **public** function and method (i.e., not prefixed with `_`):

1. **Happy path** — normal input, expected return value or side effect
2. **Boundary conditions** — empty string, empty list, `None`, zero, negative integers
3. **Exception handling** — confirm raises `ValueError`, `TypeError`, etc. on invalid input using `pytest.raises`
4. **Parametrize common patterns** — use `@pytest.mark.parametrize` when testing the same function with multiple inputs

## Mocking Rules

- Mock ALL external I/O: file system (`open`, `os.path`), network (`requests`, `httpx`, `aiohttp`), database
- Use `@pytest.fixture` + `unittest.mock.patch` or `monkeypatch` for isolation
- Prefer `monkeypatch` for environment variables and simple attribute replacement
- Use `unittest.mock.MagicMock` / `AsyncMock` for callable mocks
- Do NOT mock the functions being tested — test their real behavior

## Structure Template

```python
import pytest
from unittest.mock import patch, MagicMock
# sys.path manipulation here if needed
from <target_module> import <symbols>


@pytest.fixture
def mock_external():
    with patch('<module>.<symbol>') as m:
        yield m


class TestFunctionName:
    def test_happy_path(self):
        result = function_under_test(valid_input)
        assert result == expected

    def test_empty_input(self):
        result = function_under_test([])
        assert result == []

    def test_none_input(self):
        with pytest.raises(TypeError):
            function_under_test(None)

    @pytest.mark.parametrize("input,expected", [
        ("a", 1),
        ("bb", 2),
    ])
    def test_parametrized(self, input, expected):
        assert function_under_test(input) == expected
```

## Self-Verification

After writing the test file, run: `bash <PLUGIN_ROOT>/scripts/run-tests.sh --test-file <test-file>`

If tests fail: diagnose whether the failure is in the test code (fix it) or the source code (report it — do NOT change the source).

Retry up to 3 times before reporting an unresolvable baseline failure.

## Output Contract

Return exactly:
```
## Test-Generator Results
Test file: <path>
Passed: N | Failed: 0
Exported symbols covered: [list of function/class names]
```

If baseline cannot reach green after 3 retries:
```
## Test-Generator Results
BASELINE FAILURE — cannot reach green
Failing tests: [list]
Reason: <diagnosis>
```
