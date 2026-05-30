---
bug_id: 6
date: 2026-05-30
title: "up-docs propagate-repo emits handoff-v3-nonconformant AGENTS.md pointer and Lesson-less bug bodies"
services: [up-docs, handoff]
tags: [docs-propagation, handoff, conformance]
status: open
supersedes: null
superseded_by: null
---
# Bug 6: up-docs propagate-repo emits handoff-v3-nonconformant AGENTS.md pointer and Lesson-less bug bodies

## Cause

`agents/up-docs-propagate-repo.md` inlines a copy of the Agent Handoff System contract rather than calling the canonical validator, and that copy predates handoff **v3.0** (2026-05-29). Two of its inlined rules now produce artifacts that fail `~/projects/agent-configs/scripts/validate-layout.sh`:

1. **AGENTS.md remediation** (`:117`, `:119`) writes only a `**Session state:** detect layout first. V2:… V1:…` line. v3 §"Repo File Rules" mandates three exact lines near the top (`Session state:`, `Full conventions reference:`, `Detailed review workflows:`), and the validator's Codex block checks all three substrings. A propagator-"fixed" AGENTS.md is left missing two required lines.
2. **Bug-file body template** (`:93-99`) emits only `## Cause` + `## Fix`. v3 requires **Cause / Fix / Lesson**; this repo's KB (`001`–`002`) and commit `f627ad7` standardized on it. Every new bug the agent creates regresses the standard.

Root pattern: an agent prompt that duplicates an external spec in prose silently drifts the moment the spec advances. The state.md 2 KiB cap stayed correct only because it happened to move in lockstep; the AGENTS.md block and bug body did not. (Full audit: 12 divergences total — 2 🔴 here, plus 6 🟡 / 4 🟢 enforcement-and-labeling gaps captured in the alignment plan.)

## Fix

Planned, not yet applied (user elected capture-only on 2026-05-30, no code changes at audit time). Tracked in [`docs/plans/2026-05-30-up-docs-handoff-v3-alignment.md`](../plans/2026-05-30-up-docs-handoff-v3-alignment.md) Tasks 1–2 (🔴) for up-docs **v0.9.0**; the same plan closes the 🟡/🟢 gaps in Tasks 3–8. Flip this entry to `fixed` with the commit SHA when T1–T2 land.

## Lesson

Do not duplicate a moving spec inside an agent prompt — have the agent (or its drift auditor) shell out to the spec's canonical validator instead. Where the prompt must restate a rule for the model's benefit, pin the restatement to a spec version and add a grep/schema assertion in the test suite so the next spec bump fails loudly rather than shipping silent non-conformant output. The drift auditor — whose job is doc-vs-reality drift — is the natural home for a `validate-layout.sh` conformance phase (plan Task 7).
