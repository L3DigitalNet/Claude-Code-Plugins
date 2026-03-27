# /design-draft to /design-review Handoff Contract

## Step 1: Emit the Handoff Block

Before invoking /design-review, emit the following block in full. /design-review reads it as authoritative prior context, not as content to re-derive.

```
══════════════════════════════════════════════════════════════════════
/design-draft → /design-review HANDOFF
══════════════════════════════════════════════════════════════════════
Project: [name]
Handoff type: Warm transfer — principles registry pre-loaded.
  Do NOT re-extract principles from document text.
  Import registry as locked and health-checked below.

── PRINCIPLES REGISTRY (authoritative — import as-is) ───────────────
[The /design-review Appendix block from the canonical Principles
 Export — includes Auto-Fix Heuristics and all fields required by
 /design-review's registry format. Emit it here in full.]

Auto-Fix Eligible:    [P1, P2, ...]
Auto-Fix Ineligible:  [Pn, ...] or None

── TENSION RESOLUTION LOG (authoritative — import as-is) ────────────
[Full tension log from Phase 2C: T[N], principles involved,
 resolution type (A-E), tiebreaker rule or None]
Note for /design-review: these tensions have been explicitly resolved.
Do NOT re-surface them as new SYSTEMIC: Health findings. If the
document text creates a NEW tension not in this log, surface normally.

── OPEN QUESTIONS LOG (import — do not flag as GAP findings) ─────────
[Full OQ log: OQ[N], question, why it matters, owner, status]
Note for /design-review: these are known open decisions documented
intentionally. Stub sections associated with OQ entries are expected
gaps, not Track C findings. Flag only if: (a) a stub has no
corresponding OQ entry, or (b) an OQ entry's "why it matters" reveals
a gap category not otherwise covered in the document.

── PHASE 1 CONTEXT SUMMARY (for gap baseline calibration) ───────────
Domain: [inferred domain from Phase 1]
Non-negotiable quality attribute: [from Q8]
Hard constraints: [from Q2]
Governance requirements: [from Q9, or None]
Key risks: [from Q6]
Note for /design-review: use this to calibrate gap baseline categories
rather than inferring domain from document text alone.

── HANDOFF INSTRUCTIONS FOR /design-review ──────────────────────────
1. Import the principles registry above as the locked, confirmed
   registry. Skip Step 1 of the Initialization Sequence (principles
   extraction) — registry is pre-loaded.
2. Run the Principle Health Check in document-verification scope:
   check that the document text is consistent with each imported
   principle as stated, and flag any new tensions introduced by the
   draft that do not appear in the Tension Resolution Log above.
   Do not re-check tensions already in the log — those are resolved
   and closed. This is not a mid-loop update trigger; it is a
   one-time verification that the generated draft honours the
   registry it was built from.
3. Use the Phase 1 Context Summary above to inform gap baseline
   category selection (Step 4). Present the baseline for confirmation
   as normal — the summary is a calibration input, not a replacement
   for the confirmation gate.
4. Treat all stub sections with a corresponding OQ entry as
   intentional. Do not queue them as GAP findings unless the OQ entry
   itself reveals an unaddressed gap category.
5. Treat stub sections with NO corresponding OQ entry as legitimate
   GAP findings — they represent unintentional omissions.
6. Proceed to Step 5 (auto-fix mode selection) and Pass 1 normally.
══════════════════════════════════════════════════════════════════════
```

## Step 2: Invoke /design-review

After emitting the Handoff Block, proceed directly into the /design-review Initialization Sequence, treating the Handoff Block as having completed Steps 1 and partial Step 2 already. Announce the transition:

```
──────────────────────────────────────────────────────────────────────
Handing off to /design-review with warm context.
Principles registry pre-loaded ([N] principles, locked).
[N] resolved tensions imported — will not be re-surfaced.
[N] open questions imported — associated stubs are expected.
Proceeding to Principle Health Check (document-scope only),
then gap baseline confirmation and auto-fix mode selection.
──────────────────────────────────────────────────────────────────────
```
