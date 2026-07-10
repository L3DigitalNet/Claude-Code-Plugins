---
bug_id: 9
date: 2026-07-02
title: 'ENV-001 global PATH guard shadowed npm/ssh test stubs in auto-build-plugins.sh and server-inspect.sh'
services: [release-pipeline, up-docs]
tags: [environment, path-shims, test-infrastructure, false-negative, cross-plugin]
status: fixed
supersedes: null
superseded_by: null
---

# Bug 9: ENV-001's global PATH guard shadowed npm/ssh test stubs

## Cause

Bug 8's fix (`4f9fd1c`, `19595e2`) applied ENV-001's guard uniformly: `export PATH="/usr/bin:/bin:$PATH"` at the top of every python3-invoking release-pipeline and up-docs script. That's safe when python3 is the _only_ external command the script calls afterward — but two scripts also call a **second** externally-stubbable command later in the same file:

- `release-pipeline/scripts/auto-build-plugins.sh` calls `npm run build`. Its bats test AB5 (`NPM_STUB_MODE=fail`) prepends a stub `npm` ahead of PATH, but the script's own global export re-prepended `/usr/bin:/bin` in front of that stub dir, so the real `/usr/bin/npm` won every time — the fault-injection test could never see a failed build, and `[ "$status" -eq 2 ]` failed.
- `up-docs/scripts/server-inspect.sh` calls `ssh` to reach the inspected host. Its bats tests SI2-SI4 PATH-stub `ssh`, but the same global export shadowed it with the real `/usr/bin/ssh`, so the script tried to actually connect to `testhost` and got `reachable:false` before ever reaching the `ss`/ports-parsing code — surfacing as `jq: Cannot iterate over null` on `listening_ports`.

Both bugs were discovered the same way: a batch-release pre-flight test run failed, and root-causing traced back to the identical global-export pattern in two unrelated plugins.

## Fix

Both 2026-07-02, both scope the guard to the python3 call site(s) instead of exporting it globally:

```bash
system_path="/usr/bin:/bin:$PATH"
...
cmd=$(printf '%s' "$input" | PATH="$system_path" python3 -c "...")
```

- `auto-build-plugins.sh` (`ba975a4`, released release-pipeline v2.2.3): three python3 call sites scoped; `npm run build` now sees the caller's PATH untouched.
- `server-inspect.sh` (`c0919f9`, released up-docs v0.13.1): the one python3 lookup scoped via a subshell-local `PATH=... command -v python3`; `ssh` downstream now sees the caller's PATH.

Verified: AB5 and SI2-SI4 pass; full suites green (release-pipeline 76 bats + 9 legacy scripts; up-docs 90 bats + 29 pytest).

**Swept and cleared:** the other 11 ENV-001-guarded scripts (release-pipeline's `bump-version.sh`, `detect-unreleased.sh`, `detect-test-runner.sh`, `check-waivers.sh`, `force-push-guard.sh`, `sync-local-plugins.sh`; up-docs's `commit-candidates.sh`, `convergence-tracker.sh`, `context-gather.sh`, `link-audit.sh`, `capture-transcript.sh`; uv-strict-python's `tests/run.sh`) call _only_ python3 (or nothing) downstream of the guard, or (for `tests/run.sh`) run as a top-level bats launcher where each `.bats` file's own `setup()` re-prepends its stub dir afterward — none are exposed to this failure mode. No changes needed there.

## Lesson

ENV-001's global `export PATH=...` is safe only when python3 (or coreutils) is the _last_ thing the script's PATH resolution needs to get right. The moment a script also shells out to another externally-stubbable command — `npm`, `ssh`, `gh`, anything a test fixture would want to intercept — the global export becomes a second, unrelated shim that the test author never anticipated. Refine ENV-001: **scope the system-PATH override to the specific call site(s)** (`PATH="$system_path" <cmd>`, or a subshell-local `command -v` lookup) rather than exporting it for the rest of the script, whenever the script calls more than one external command that isn't itself the guarded interpreter.
