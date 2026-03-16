---
name: testing-mindset
description: >
  Always-on testing awareness driver. MUST consult during any implementation task to evaluate
  whether testing is needed at this point. Applies to every task involving code changes.
  Governs: when to suggest gap analysis, how to assess test coverage needs, delegation to
  framework-specific testing plugins, and non-intrusive suggestion cadence.
  Triggers on: test, implement, feature, fix, bug, refactor, build, create, modify, change,
  add, update, debug, complete, finish, deploy, merge, PR, commit.
---

# Testing Mindset: Proactive Testing Awareness

You have a testing-aware mindset installed. This skill does not run tests or write tests itself; it teaches you *when* to think about testing and *what* to suggest. The actual test writing and execution is handled by the gap-analysis, convergence-loop, and test-design skills, plus framework-specific plugins.

*Intentionally always-on.* The broad trigger list ensures this skill loads for any implementation task. The cadence rules below prevent noise.

## 1. Proactive Testing Moments

After completing any code change, ask yourself these questions:

- **Did I add a new function, class, or module?** New code needs unit tests at minimum. Suggest a gap analysis if none exist.
- **Did I modify existing behavior?** Changed behavior may invalidate existing tests or reveal untested paths. Check if tests cover the changed code.
- **Did I fix a bug?** Every bug fix should have a regression test that would have caught the bug. If one wasn't written as part of the fix, flag it.
- **Did I complete a feature?** Feature completion is a natural breakpoint for a full gap analysis across all applicable test categories.
- **Am I about to commit or merge?** Pre-commit and pre-merge are the last chance to catch missing tests. Suggest a final gap check if the source-to-test change ratio is imbalanced.

## 2. Assessment Heuristic

Before suggesting a gap analysis, check these three conditions:

1. **Source files changed since last analysis.** Read `docs/testing/TEST_STATUS.json` (if it exists) and compare the `last_analysis.date` against recent file modifications.
2. **Natural breakpoint reached.** Feature complete, bug fixed, refactor done, or about to commit/merge.
3. **Source-to-test ratio imbalance.** If source files were modified but no test files were touched, testing likely fell behind.

**Decision:** If two or more conditions are true, suggest running `/test-driver:analyze`. If only one condition is true, note it silently and wait for the next check.

## 3. Delegation Rules

When writing tests, do not reinvent framework-specific patterns. Consult the matching plugin:

| Project Type | Consult |
|-------------|---------|
| Python (general) | `python-dev:python-testing-patterns` for pytest fixtures, mocking, parametrize |
| PySide6/PyQt6 | `qt-suite:qtest-patterns` for widget tests, `qt-suite:qt-pilot-usage` for GUI testing |
| Home Assistant | `home-assistant-dev:ha-testing` for hass fixtures, config flow tests |
| Swift/SwiftUI | Self-contained in the `swift-swiftui` stack profile |

**Graceful degradation:** If the delegated plugin is not installed, proceed using general knowledge. The framework plugin enhances accuracy but is not required.

**test-driver drives the *when* and *what*. Framework plugins provide the *how*.**

## 4. Cadence Rules

- **Never suggest testing after every individual edit.** Note changes silently. Surface testing suggestions only at natural breakpoints.
- **If the user declines a testing suggestion,** respect it. Do not re-suggest until the next natural breakpoint (a different feature, bug fix, or explicit request).
- **During active TDD flow,** do not suggest gap analysis. If `superpowers:test-driven-development` is driving the session (test-first workflow), testing-mindset defers entirely. TDD handles test-first; test-driver handles test-after and gap-filling.
- **At commit/merge boundaries,** defer to `superpowers:verification-before-completion` if it's active. Both skills care about pre-commit readiness; avoid duplicate suggestions.

## 5. Scope Boundaries

This skill does **not**:
- Run tests (that's the convergence-loop skill and stack profile commands)
- Write tests (that's the convergence-loop skill using test-design principles)
- Manage test infrastructure (Docker, databases, CI pipelines)
- Replace TDD workflows (defers to `superpowers:test-driven-development`)

It only drives **awareness and timing** for when testing should be considered.
