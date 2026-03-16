---
name: test-design
description: >
  Universal test design principles for writing effective tests regardless of framework.
  Use when writing tests, reviewing test quality, designing test structure, choosing what
  to test, or applying test patterns. Covers isolation, boundary testing, error paths,
  Arrange-Act-Assert, naming, mock boundaries, and meaningful assertions.
---

# Test Design: Universal Principles

These principles apply to every test you write, regardless of language or framework. Consult the active stack profile for framework-specific syntax; this skill provides the design thinking.

## 1. Test Isolation

Each test must be independent. Running tests in any order, or running a single test in isolation, must produce the same result.

**Rules:**
- No shared mutable state between tests. Each test sets up its own data.
- Use fixtures (pytest fixtures, setUp/tearDown, @Before/@After) for per-test setup.
- Avoid class-level or module-level state that persists across tests.
- Never depend on test execution order.

**Anti-pattern:**
```python
# BAD: test_update depends on state from test_create
class TestUser:
    user_id = None

    def test_create(self):
        self.user_id = service.create_user(data).id
        assert self.user_id is not None

    def test_update(self):
        service.update_user(self.user_id, new_data)  # fails if test_create didn't run first
```

**Fix:** Each test creates its own user via a fixture.

## 2. Boundary Testing

For every function parameter, test the edges, not just the middle.

**Checklist for each parameter:**
- **Zero/empty case:** 0, "", [], None, empty dict
- **Single element:** 1, "a", [x], one-item dict
- **Boundary value:** the exact threshold (e.g., if max is 100, test 100)
- **One past boundary:** 101, -1, one character over the limit
- **Typical case:** a normal, representative value

**Common boundaries to test:**
- Integer overflow/underflow limits
- String length limits
- Collection size limits (empty, one, many, max)
- Date boundaries (midnight, end of month, leap year, timezone transitions)
- Unicode edge cases (empty string, single char, multi-byte, emoji)

## 3. Error Path Coverage

Every code path that can fail should have a test that verifies it fails correctly.

**Rule:** If a function has N distinct error paths (exceptions, error returns, validation failures), write at least N error tests.

**What to verify for each error path:**
- The correct exception type is raised (not just "some exception")
- The error message is useful and specific (match against key phrases)
- Side effects are properly rolled back (no partial state left behind)
- Error propagation works (callers handle the error appropriately)

```python
# Test the specific exception and message
def test_divide_by_zero_raises_value_error():
    with pytest.raises(ValueError, match="Cannot divide by zero"):
        calculator.divide(10, 0)

# Not just "it raises something"
def test_divide_by_zero_bad():
    with pytest.raises(Exception):  # too broad, catches anything
        calculator.divide(10, 0)
```

## 4. Arrange-Act-Assert (AAA)

Structure every test in three distinct phases:

```python
def test_user_creation_stores_email():
    # Arrange: set up preconditions
    email = "user@example.com"
    service = UserService(db=test_database)

    # Act: execute the behavior under test
    user = service.create_user(email=email)

    # Assert: verify the outcome
    assert user.email == email
    assert user.id is not None
```

**Rules:**
- **One Act per test.** If you're calling multiple methods, you're testing multiple behaviors; split into separate tests.
- **Multiple Asserts are OK** if they verify different aspects of the same behavior (e.g., checking both the return value and a side effect of a single operation).
- **Keep phases visually distinct.** A blank line or comment between each phase helps readability.

## 5. Test Naming

The test name should read as a specification: what unit, what scenario, what expected outcome.

**Pattern:** `test_<unit>_<scenario>_<expected_outcome>`

```python
# Good: tells you what's being tested and what should happen
def test_create_user_with_duplicate_email_raises_conflict():
def test_calculate_tax_for_zero_income_returns_zero():
def test_parse_date_with_invalid_format_raises_value_error():

# Bad: tells you nothing
def test_1():
def test_user():
def test_it_works():
```

**The name is documentation.** When a test fails, the name should tell you exactly what broke without reading the test body. If you can't tell what failed from the name alone, rename it.

## 6. Mock Boundaries

Mock the things you don't control. Use real implementations for the things you do.

**Mock these (external boundary):**
- Network calls (HTTP, gRPC, database connections to external services)
- File system operations (when testing logic, not I/O)
- Clock/time (use freezegun, frozen_time, or clock mocks)
- Third-party API clients
- Random number generators (when determinism matters)

**Don't mock these (internal boundary):**
- Your own classes and functions (test them with real instances)
- Internal data structures
- Pure functions
- Configuration loading (use test config instead)

**Rule of thumb:** If you wrote the code and it has no side effects, don't mock it. If it crosses a system boundary (network, disk, clock, external service), mock it.

**Over-mocking anti-pattern:** When you mock so much that the test only verifies your mock setup, not your code's behavior. If the test passes with any implementation, the mocks are too aggressive.

## 7. Meaningful Assertions

Assert specific expected values, not just that something exists or is truthy.

```python
# BAD: only checks truthiness
assert result
assert response
assert user

# GOOD: checks specific values
assert result == 42
assert response.status_code == 200
assert user.email == "expected@example.com"
```

**Assertion hierarchy (most to least specific):**
1. `assert result == expected_value` — exact equality
2. `assert expected_key in result` — containment
3. `assert isinstance(result, ExpectedType)` — type check
4. `assert result` — truthiness (weakest; avoid as sole assertion)

**Avoid magic numbers in assertions.** Use named constants or descriptive variables:
```python
# BAD
assert len(users) == 3

# GOOD
expected_user_count = 3  # admin + two test users created in arrange
assert len(users) == expected_user_count
```
