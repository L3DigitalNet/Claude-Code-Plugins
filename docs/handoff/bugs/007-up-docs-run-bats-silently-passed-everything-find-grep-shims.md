---
bug_id: 7
date: 2026-06-07
title: 'up-docs run-bats.sh silently passed everything — find/grep shimmed to fd/ugrep broke bats test discovery'
services: [up-docs]
tags: [testing, bats, tooling, false-green, environment]
status: fixed
supersedes: null
superseded_by: null
---

# Bug 7: up-docs run-bats.sh silently passed everything (find/grep shims broke bats discovery)

## Cause

On this workstation the interactive/agent shell defines `find` and `grep` as **functions that route to fd/ugrep** (Claude Code search accelerators; `grep` is a bash function via `CLAUDE_CODE_EXECPATH`, `find` resolves to a non-`/usr/bin` shim). GNU coreutils are intact at `/usr/bin/{grep,find}` (GNU grep 3.12).

`bats` uses `find`/`grep` for **test discovery**. With those shims winning the PATH, discovery returned **zero tests and exited 0** — so `bash plugins/up-docs/tests/run-bats.sh` reported green even when the suite was broken or a test failed. A deliberately failing `@test "x" { [ 1 -eq 2 ]; }` "passed" with no output; `bats --version` worked, which masked it. This silently invalidated the entire up-docs bats gate locally (and would in any CI image with the same shims). Direct-worker symptom: `bats_readlinkf: command not found` + an empty `//bats-core/validator.bash` path; `bats --count` empty.

Discovered during the up-docs 0.10.0 release pre-flight (the Task-0 baseline looked suspiciously silent: rc 0, no TAP). Bisected to a PATH issue: `PATH=/usr/bin:$PATH bash run-bats.sh` ran the real 52 tests and a failing test correctly returned rc 1.

## Fix

Fixed in **`d4119ae`** — `plugins/up-docs/tests/run-bats.sh` now prepends the system coreutils to PATH before invoking bats:

```bash
PATH="/usr/bin:/bin:$PATH"
export PATH
```

So bats's internal `find`/`grep` are GNU regardless of the caller's shell config or CI image. Self-contained (no env setup required by callers). Verified: the full suite runs **52/52** and a deliberately failing test returns **rc 1**. `bash -n` + `shellcheck -S warning` clean.

## Lesson

Any test runner or script that calls bare `find`/`grep` for control flow can be silently neutered by an interactive shell's search-accelerator shims — and the failure mode is the worst kind: a broken or failing suite reports green. When a suite looks suspiciously green (no output, instant exit 0), prepend `/usr/bin` and re-run before trusting it; harden the wrapper to force GNU coreutils rather than depending on the caller's PATH. A green suite is only evidence if you've confirmed it can also go red (run one deliberately failing test).
