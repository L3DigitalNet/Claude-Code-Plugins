---
name: qt-coverage-workflow
description: >
  This skill should be used when the user asks about "coverage", "test coverage", "coverage gaps",
  "untested code", "gcov", "lcov", "coverage report", "improve coverage", "missing tests",
  "coverage threshold", "coverage-driven test generation", or "what code isn't tested".
  Covers the full coverage feedback loop for both Python/PySide6 (coverage.py) and C++/Qt (gcov + lcov).
  Also activates for "pytest-cov", "run coverage on my Qt project", or "CI coverage report".
---

# Qt Coverage Workflow

Coverage-driven test generation is a loop: **run tests with instrumentation → generate report → identify gaps → generate targeted tests → re-run to verify improvement**. This skill covers the full loop for both Python and C++ Qt projects.

## The Coverage Loop

```
run instrumented tests
        ↓
parse coverage report (gaps list)
        ↓
send gaps to Claude / test-generator agent
        ↓
generate targeted tests
        ↓
run tests again → verify delta
        ↓
repeat until threshold met
```

Use `/qt:coverage` to execute this loop. The `test-generator` agent activates automatically after `/qt:coverage` identifies gaps.

## Python Projects (coverage.py)

**Full Python coverage walkthrough** — see [references/python-coverage-workflow.md](references/python-coverage-workflow.md) for installation, all report formats, branch coverage, CI integration, and agent-handoff parsing patterns.

Key CI step pattern:
```yaml
- name: Run coverage
  run: pytest --cov=myapp --cov-report=xml --cov-fail-under=80 tests/
```

## C++ Projects (gcov + lcov)

**Full gcov/lcov walkthrough** — see [references/gcov-lcov-workflow.md](references/gcov-lcov-workflow.md) for CMake presets, the complete lcov command sequence, Clang/LLVM alternative, gap parsing, and troubleshooting.

## Coverage Thresholds

Configure thresholds in `.qt-test.json`:

```json
{
  "coverage_threshold": 80,
  "coverage_exclude": ["tests/*", "*/migrations/*"]
}
```

| Threshold | When appropriate |
|---|---|
| 60–70% | Early-stage projects, rapid prototyping |
| 80% | General production code (recommended default) |
| 90%+ | Safety-critical components |
| 100% MC/DC | Aerospace/automotive (requires Coco) |

## Identifying High-Value Coverage Gaps

When analyzing gaps, prioritize:

1. **Business logic classes** — highest risk of regression
2. **Error paths** (exception handlers, validation failures) — often untested
3. **Complex conditionals** — branches with multiple conditions
4. **Public API methods** — surface area for other code to depend on
5. **Skip** test infrastructure, generated `moc_*` files, pure UI glue code

## Handoff to test-generator Agent

After identifying gaps, structure the handoff:

```
Gaps found in calculator.py: lines 18-22 (divide by zero path), line 45 (overflow check)
Gaps found in formatter.py: lines 8-10 (empty string handling)
Current coverage: 74%. Target: 80%.
Generate tests targeting these specific lines.
```

The `test-generator` agent activates automatically after `/qt:coverage` completes and gaps are found.

## Additional Resources

- **`references/gcov-lcov-workflow.md`** — Full gcov/lcov command reference, CMake preset patterns, troubleshooting
- **`references/python-coverage-workflow.md`** — coverage.py configuration, branch coverage, parallel test runs
- **`templates/qt-coverage.yml`** — Ready-to-use GitHub Actions workflow (Python + C++ variants)
- **`templates/run-coverage.sh`** — Portable shell script for local and generic CI use
