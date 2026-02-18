# Test R1 — Cold Start: Document With Embedded Principles

Command: /design-review
Milestone: M11
Scenario ID: R1

## What it validates

Standard cold start on a document that already has a principles section.
Principle extraction, health check, gap baseline confirmation, Mode B
auto-fix, convergence.

## Setup

Use the output of test D1 (`[project-folder]/docs/design-draft.md`) as
the input document, or any design document with an embedded principles
section (3+ principles, at least one inter-principle tension in the doc).

## Session Script

**Step 1:** `/design-review path/to/design-draft.md`
Expected:
- File read via Read tool
- DOCUMENT INVENTORY emitted (title, sections, domain hints)
- Principles extracted from document text
- DESIGN PRINCIPLES REGISTRY presented

**Step 2:** `(A) Accept all inferred principles as stated`
Expected:
- Principle Health Check runs (4 dimensions: tensions, vagueness,
  auto-fix reliability, goal conflicts)
- Health check result emitted (✓ PASSED or ⚠ issues)
- Auto-Fix Eligible list established

**Step 3:** Gap baseline presented
Expected:
- GAP ANALYSIS BASELINE presented with domain-appropriate categories
- At least G1–G10 present; domain-specific G11+ if applicable

**Step 4:** `(A) Accept gap baseline`
Expected:
- Auto-fix mode selection presented

**Step 5:** `(B) Auto-fix eligible, review the rest`
Expected:
- Pass 1 begins
- Pass header emitted

**Step 6:** Pass 1 runs
Expected:
- Findings queue emitted with # / Type / Sev / Scope / Section / Auto-Fix columns
- Mode B: Auto-Fix Summary presented before resolution
- Eligible findings listed with violation, proposed fix, confidence: HIGH
- Review-required findings listed with reason

**Step 7:** `(A) Approve auto-fixes`
Expected:
- Eligible findings implemented with diff format
  (`IMPLEMENTING FINDING #[N] [AUTO-FIX per Pn ✓]`)
- Review-required findings surfaced individually with (A)–(H) options

**Step 8:** Resolve review-required findings
Expected:
- Each finding resolved via Q&A
- Diffs emitted per resolution

**Step 9:** Pass 1 complete
Expected:
- END OF PASS SUMMARY emitted with finding counts, auto-fix counts,
  principle compliance per principle, gap coverage table, change volume
- End of pass options (A)–(G) presented

**Step 10:** Continue passes until convergence
Expected:
- Each pass: findings decrease
- Final pass: zero findings across all three tracks
- DESIGN REVIEW COMPLETE declaration emitted with final principles
  and gap coverage

## Pass Criteria

- [ ] File read via Read tool (not pasted)
- [ ] Snapshot header is `⏸ PAUSE STATE SNAPSHOT — /design-review`
- [ ] Health check runs across all 4 dimensions
- [ ] Gap baseline presented for confirmation before Pass 1
- [ ] Mode selection presented before Pass 1
- [ ] Findings queue shows Auto-Fix column
- [ ] Mode B summary separates eligible from review-required
- [ ] Auto-fixed diffs include `[AUTO-FIX per Pn ✓]` annotation
- [ ] Pass summary includes principle compliance and gap coverage tables
- [ ] Convergence declared only on zero-finding pass across all 3 tracks

## Fail Indicators

- [ ] Paste or inline content accepted (should require file path)
- [ ] Chunk handling referenced anywhere
- [ ] Snapshot header missing `/design-review` label
- [ ] Health check skipped
- [ ] Mode B summary missing (findings surfaced individually without summary)
- [ ] Auto-fix applied to Critical severity finding
- [ ] Convergence declared with open findings remaining
