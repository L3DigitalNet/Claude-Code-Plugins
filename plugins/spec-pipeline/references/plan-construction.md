# Plan Construction Standard

Purpose: the structure and quality bar for implementation plans. Read this when authoring or reviewing a plan. This document is the rubric the plan review gate checks against.

A plan is a dense, self-contained implementation script: an agent with no prior context for the codebase should be able to work it task-by-task and land each task gate-green without deviating. The density is the point — the exact symbols, file positions, complete test code, complete implementation code, and verification commands are what make an unattended run reliable.

## Audience framing

Write for an implementer who is skilled but has zero context for this codebase and does not know the toolset or domain well, and assume they do not know good test design. Document everything: which files to touch, the complete code, how to test it, and the verification command. DRY, YAGNI, TDD, frequent commits.

## RED gate: preserved by step order, not by withholding code

Each task embeds its complete failing-test code AND its complete implementation code. This does NOT defeat the RED gate, because the gate is preserved at execution time by step ordering: the executor writes the test, runs it, watches it fail against a repo that has no implementation yet, then writes the implementation and watches it pass. The plan containing the code is a specification of what to write, not code already in the repo.

- Every task's steps MUST run in TDD order: write the failing test → run it and confirm it fails for the right reason → implement → run and confirm it passes → commit.
- The executor MUST NOT collapse the test and implementation steps (writing both before running the test). The "run to verify it fails" step is mandatory and its expected failure is stated in the plan.

## Plan header

- Goal — one sentence: what this builds.
- Architecture — 2-3 sentences: the approach, naming the key constructs.
- Tech stack — language, runtime, key tools/libraries.
- Spec — the governing spec path (and parent/master, with the conflict rule: which governs on conflict).
- Global constraints — project-wide requirements that bind every task: language/version floors, typing rules, error-handling rules, the test-harness facts a task's test code depends on, determinism requirements, and the exact verification gate command(s) that must pass before any task is "done".

## File structure

A table of every new symbol → its kind → the task that introduces it, in file order. This gives the implementer the whole shape before the first task and lets the reviewer check coverage at a glance.

## Task structure

A task is the smallest unit that carries its own test cycle and is worth a fresh reviewer's gate.

- Drawing boundaries: fold setup, configuration, scaffolding, and documentation into the task whose deliverable needs them. Split only where a reviewer could meaningfully reject one task while approving its neighbor.
- Each task ends with an independently testable deliverable, the full verification gate green, and a commit.
- Order tasks by dependency.

Each task contains:

- **Files** — Create: `exact/path`; Modify: `exact/path:line`; Test: `tests/exact/path`.
- **Interfaces** — Consumes (existing symbols/types it relies on); Produces (the exact signature(s) it adds, and who consumes them).
- **Steps** (checkbox `- [ ]` syntax, in TDD order):
  1. Any test-harness/scaffolding declaration the test code requires (e.g. registering a new symbol on a typed test protocol) — with the code.
  2. Write the failing test(s) — the COMPLETE test code, with the exact assertions. For load-bearing behavior, the assertion must make a wrong answer observable (mutation mindset), not merely assert membership/coverage.
  3. Run to verify it fails — the EXACT command, and the expected failure (e.g. "FAIL: name not defined").
  4. Implement — the COMPLETE minimal implementation code.
  5. Run to verify it passes — the exact command.
  6. Run the full verification gate; commit.

## Anti-patterns (a plan with any of these is incomplete)

- "Write tests for the above" without the actual test code.
- "Similar to Task N" instead of restating the code (the implementer may read tasks out of order).
- A step that says what to do without showing the code/command for it.
- A reference to a type, function, or method not defined in an earlier task, the spec, or an inherited contract.
- Test and implementation steps not separated by a run-and-verify-fail step.

## Self-review checklist

Run against the spec, yourself (not a subagent dispatch):

1. Spec coverage — skim each spec requirement; can you point to a task that implements it? List gaps.
2. Type consistency — names, signatures, and property names used in later tasks match those defined in earlier tasks. (A method called `clear_layers` in task 3 and `clear_full_layers` in task 7 is a bug.)
3. Placeholder scan — none of the anti-patterns above.
4. TDD order — every task separates write-test → run-fail → implement → run-pass; no task hands the implementer code without a preceding failing-test step.
5. Forward references — no task references a symbol not yet defined.

---

Attribution: this format follows the Superpowers `writing-plans` skill (obra/superpowers, MIT) — the comprehensive embedded-code, per-task TDD plan, the file-structure table, the anti-patterns, and the self-review checklist. The subagent-dispatch execution mechanics are omitted; execution is governed by the autonomous-phase-execution skill, whose per-task TDD steps and guardrails preserve the RED gate at run time.
