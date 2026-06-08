# Convergence Tracking

Shared iteration mechanics for all four phases of drift analysis.

## Loop Structure

Each phase follows the same pattern:

```
iteration = 0
max_iterations = 10
previous_findings = []

loop:
    iteration += 1
    findings = run_full_pass()

    if len(findings) == 0:
        → CONVERGED. Move to next phase.

    if findings == previous_findings:
        → STALLED. Same findings on consecutive passes. Report and stop phase.

    if is_oscillating(findings, history):
        → OSCILLATING. Findings flip-flopping. Stop phase, report pattern.

    if iteration >= max_iterations:
        → TIMEOUT. Report remaining findings and move on.

    apply_fixes(findings)
    previous_findings = findings
    continue loop
```

## Convergence Criteria by Phase

**Phase 1 (Infrastructure → Wiki)**: Zero discrepancies between live state and wiki content across all checked pages.

**Phase 2 (Wiki Consistency)**: Zero contradictions between any pair of wiki pages in scope.

**Phase 3 (Link Integrity)**: Zero broken links (external or inter-wiki) and zero high-value enrichment opportunities. "High-value" means a missing cross-reference where the source page explicitly discusses the target page's subject.

**Phase 4 (Notion Sync)**: Single pass (no loop). Apply all Notion-relevant changes identified from Phases 1-3.

## Narrowing on Re-pass

The narrowing rule is **owned by the auditor task step** (`agents/up-docs-audit-drift.md`, step 4): pass 1 is full; pass N+1 scans only the prior pass's `touched_pages` (from `convergence-tracker.sh touched-pages <phase>`) plus one-hop `related` dependents. This prevents O(n^2) re-scan growth. Do not restate the rule here — defer to the task step so the two cannot drift.

## Oscillation Detection

An oscillation occurs when the same finding appears, gets fixed, and reappears. Track the last 3 iterations of findings. If a finding (identified by page + discrepancy type) appears in iteration N, disappears in N+1, and reappears in N+2, flag it as oscillating.

When oscillation is detected:
1. Stop the phase immediately
2. Report the oscillating findings with context
3. These likely require human judgment to resolve (ambiguous ground truth, competing conventions, etc.)

## Progress Reporting

At the end of each iteration within a phase, emit a single-line status:

```
Phase N, iteration M: X findings (Y fixed, Z remaining)
```

At the end of each phase, emit the convergence status:

```
Phase N converged after M iterations. Pages touched: X. Changes applied: Y.
```

Or if not converged:

```
Phase N stopped after M iterations (STALLED/OSCILLATING/TIMEOUT). Remaining findings: X.
```

## Max Iterations

Default: 10 per phase. In practice, most phases converge in 2-3 iterations. If hitting 10, something is likely wrong (circular dependencies, conflicting authoritative sources, or an infrastructure that is actively changing during analysis).
