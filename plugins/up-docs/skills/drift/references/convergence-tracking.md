# Convergence Tracking

Shared iteration mechanics for all four phases of drift analysis.

The auditor is **read-only**: no pass ever applies a fix. Iteration exists to _stabilize the finding set_ — a narrowed re-pass chases one-hop dependents of what the prior pass surfaced — not to verify fixes. Fixes happen later, via the propagators, on a user-consented follow-up run with the findings as a new session-change summary.

## Tracker Call Sequence

`scripts/convergence-tracker.sh` is the mechanical state holder. Per phase, the call order is:

1. `start-phase <phase>` — **required before pass 1**; `record-iteration` hard-fails with `phase not started` otherwise. (`init` creates the session state file but does not start any phase.)
2. After each pass: `record-iteration <phase>` with the findings JSON (including the `touched_pages` path array that drives narrowing) on stdin.
3. `check-convergence <phase>` and, from pass 3 on, `check-oscillation <phase>`.

## Loop Structure

Each phase follows the same pattern:

```toml
iteration = 0
max_iterations = 10
previous_findings = []

loop:
    iteration += 1
    findings = run_pass()   # pass 1 full; pass N+1 narrowed (see below)
    record_iteration(findings)

    if len(findings) == 0:
        → CLEAN. No drift in this phase. Move to next phase.
        # (the tracker's check-convergence reports converged=true on a zero-finding pass)

    if findings == previous_findings:
        → FINAL. The finding set is stable across consecutive passes — it is
          confirmed and complete for this phase. Record it and move to the next
          phase. This is the expected terminal state when drift exists; it is
          success, not an error. Do NOT attempt to fix anything to "converge".

    if is_oscillating(findings, history):
        → OSCILLATING. Findings flip-flopping. Stop phase, report pattern.

    if iteration >= max_iterations:
        → TIMEOUT. Report remaining findings and move on.

    previous_findings = findings
    continue loop   # re-pass narrows to touched pages + one-hop dependents
```

## Convergence Criteria by Phase

A phase terminates when its finding set is CLEAN (empty) or FINAL (stable). Phase-specific meaning of a clean pass:

**Phase 1 (Infrastructure → Wiki)**: Zero discrepancies between live state and wiki content across all checked pages.

**Phase 2 (Wiki Consistency)**: Zero contradictions between any pair of wiki pages in scope.

**Phase 3 (Link Integrity)**: Zero broken links (external or inter-wiki) and zero high-value enrichment opportunities. "High-value" means a missing cross-reference where the source page explicitly discusses the target page's subject.

**Phase 4 (Notion-relevance review)**: Single pass (no loop). Report — never apply — the Notion-relevant drift identified in Phases 1-3 as `layer: "notion"` findings.

## Narrowing on Re-pass

The narrowing rule is **owned by the auditor task step** (`agents/up-docs-audit-drift.md`, step 4): pass 1 is full; pass N+1 scans only the prior pass's `touched_pages` (from `convergence-tracker.sh touched-pages <phase>`) plus one-hop `related` dependents. This prevents O(n^2) re-scan growth. Do not restate the rule here — defer to the task step so the two cannot drift.

## Oscillation Detection

An oscillation occurs when the same finding appears, disappears on a re-pass, and reappears — without anything having been fixed. Track the last 3 iterations of findings. If a finding (identified by page + discrepancy type) appears in iteration N, disappears in N+1, and reappears in N+2, flag it as oscillating. Common causes: flaky evidence commands, ambiguous ground truth, or infrastructure actively changing during analysis.

When oscillation is detected:

1. Stop the phase immediately
2. Report the oscillating findings with context
3. These likely require human judgment to resolve (ambiguous ground truth, competing conventions, etc.)

## Progress Reporting

At the end of each iteration within a phase, emit a single-line status:

```text
Phase N, iteration M: X findings (Y new, Z carried from prior pass)
```

At the end of each phase, emit the terminal status:

```text
Phase N CLEAN|FINAL after M iterations. Pages examined: X. Findings recorded: Y.
```

Or if not cleanly terminated:

```text
Phase N stopped after M iterations (OSCILLATING/TIMEOUT). Findings recorded: X.
```

## Max Iterations

Default: 10 per phase. In practice, most phases terminate in 2-3 iterations (drift findings usually stabilize on the first narrowed re-pass). If hitting 10, something is likely wrong (circular dependencies, conflicting authoritative sources, or an infrastructure that is actively changing during analysis).
