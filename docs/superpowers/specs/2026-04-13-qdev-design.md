# qdev Plugin — Design Spec

**Date:** 2026-04-13
**Plugin:** `qdev`
**Commands:** `/qdev:quality-review`, `/qdev:spec-update`

---

## Purpose

A two-command plugin that acts as a quality companion across the full development lifecycle — spec, plan, and code. It is explicitly invoked only; no contextual auto-loading.

---

## Plugin Structure

```
plugins/qdev/
├── .claude-plugin/
│   └── plugin.json
├── commands/
│   ├── quality-review.md
│   └── spec-update.md
├── CHANGELOG.md
└── README.md
```

No `skills/`, `hooks/`, `agents/`, or `scripts/` directories. Both commands are self-contained markdown files with all logic inline.

---

## Command 1: `/qdev:quality-review [path]`

### Allowed Tools

`Read`, `Write`, `Edit`, `Glob`, `Grep`, `Bash`, `AskUserQuestion`, `WebFetch`, `mcp__brave-search__brave_web_search`, `mcp__serper-search__google_search`

### Step 1: Artifact Detection

If `path` is provided, use it directly. Otherwise scan the working directory for the most likely target using this priority order:

- `.md` file whose name contains `spec`, `design`, or `architecture` → **spec mode**
- `.md` file whose name contains `plan`, `implementation`, or `roadmap` → **plan mode**
- Source files (`.py`, `.ts`, `.js`, `.sh`, `.go`, `.rs`, etc.) → **code mode**

If multiple candidates match or the type is ambiguous, use `AskUserQuestion` to present the candidates as bounded choices before proceeding.

### Step 2: Research Phase (upfront, runs once)

Extract all dependencies, libraries, APIs, and external frameworks referenced in the target artifact. Then query **both** `brave-search` and `serper-search` (10+ results each) for each identified dependency/API, covering:

- **Current official docs**: API signatures, configuration options, behavioral changes, deprecations
- **Known bugs and CVEs**: open issues, security advisories, version-specific defects that could affect the implementation
- **Community best practices**: patterns the ecosystem currently recommends or has moved away from
- **Common pitfalls**: known footguns, gotchas, or version compatibility issues

Assemble a **research context** — a structured knowledge base of findings — before proceeding to any analysis. This ensures no gap is filled with stale or incorrect knowledge.

If the research phase surfaces a critical finding (known CVE, severe deprecated API in use, breaking change in a dependency version), surface it immediately to the user before entering the loop. Do not defer critical research findings to the finding queue.

### Step 3: Iterative Analysis + Fix Loop

Each pass consists of:

**3a. Static Analysis**

Run analysis appropriate to the detected mode, grounded in the research context from Step 2:

| Mode | Check dimensions |
|------|-----------------|
| **Spec** | Completeness (all features described), internal consistency (no contradictions between sections), unambiguous requirements (no "should" or "might"), scope gaps (behaviors implied but not specified), cross-section references (defined terms used consistently) |
| **Plan** | Step coverage (every spec requirement has a corresponding plan step), sequencing logic (no circular dependencies, no steps that depend on steps that come later), missing dependencies between steps, estimability (steps are concrete enough to implement) |
| **Code** | Anti-patterns, naming consistency across files, dead code, cross-file inconsistencies, missing error handling at system boundaries, structural issues |

**3b. Targeted Follow-up Research**

Before proposing a fix for any finding that involves an external dependency, API, or pattern not already covered by the Step 2 research context, run targeted searches to verify the proposed resolution against current official documentation and community standards. Do not propose fixes based on potentially outdated training knowledge alone.

**3c. Finding Classification**

Classify all findings:

- **Auto-fixable** (low-risk): formatting, broken internal references, minor phrasing gaps, straightforward omissions with a clear correct answer
- **Needs-approval** (structural/design): anything that changes intent, resolves an ambiguity by making a choice, or involves a dependency upgrade/patch decision

Research-originated findings (`[OUTDATED]`, `[VULNERABLE]`, `[BEST-PRACTICE]`, `[DOCS-MISMATCH]`) are always `needs-approval` — they require a human judgment call.

**3d. Apply Auto-fixes**

Apply auto-fixes silently. Do not narrate each one — report the count in the pass summary.

**3e. Surface Needs-Approval Findings**

Present each needs-approval finding with:
- What the issue is and why it matters
- A specific proposed resolution
- Bounded choices: `(A) Apply fix  (B) Apply with modifications  (C) Defer  (D) Skip`

**3f. Pass Summary**

After all findings in the pass are resolved:

```
Pass N complete: N found / N auto-fixed / N approved / N deferred / N skipped
```

**3g. Convergence Check**

If the pass produced zero new findings (after deferred items are excluded): declare convergence and stop.

Otherwise, begin the next pass. Deferred items are re-evaluated at the start of the next pass — they are not silently dropped.

### Convergence Declaration

```
✓ Quality review complete — N passes, N total fixes applied.
Deferred: N items (listed below if any)
```

---

## Command 2: `/qdev:spec-update [spec-path]`

### Allowed Tools

`Read`, `Write`, `Edit`, `Glob`, `Grep`, `AskUserQuestion`

### Purpose

A one-shot sync that brings a spec up to date with the current implementation. Addresses the natural drift that occurs when small features and fixes are added without going through a full spec update cycle.

### Step 1: Locate Spec

If `spec-path` is provided, use it. Otherwise scan for `.md` files matching `spec`, `design`, or `architecture` in the working directory. If multiple candidates exist, ask with bounded choices.

### Step 2: Read and Compare

Read the spec file in full. Read all source files in the current project. Identify:

- **Features added**: behaviors present in code that are absent from the spec
- **Behaviors changed**: code behavior that contradicts what the spec describes
- **Sections now stale**: spec language that no longer reflects the implementation
- **Removed features**: spec sections describing functionality that no longer exists

### Step 3: Propose Changes

Present a structured list of proposed spec changes before writing anything:

```
Proposed spec updates:
  [ADD]     Section X.Y — document new <feature>
  [UPDATE]  Section Z — behavior changed from <old> to <new>
  [REMOVE]  Section W — <feature> no longer exists
```

Use `AskUserQuestion` to ask for bulk approval or per-item review. Never overwrite the spec silently.

### Step 4: Apply and Summarize

Apply approved changes using the `Edit` tool (targeted edits, never a full file rewrite). Emit a final summary:

```
Spec updated: N additions, N modifications, N removals.
```

---

## Design Decisions

**Research-first ordering**: Research runs before static analysis so that no gap is filled with incorrect or outdated knowledge. Targeted follow-up research during the loop handles cases the initial sweep did not anticipate.

**No skills directory**: Both commands are explicit-invocation only. Skills would be auto-loaded contextually — which is the opposite of the intended behavior. All logic lives inline in the command files.

**spec-update as a separate command**: Code drifts from specs naturally. Folding spec-update into quality-review would create friction on every code review by forcing a decision about whether to update the spec. Keeping them separate lets you run either independently.

**Research findings always need-approval**: Dependency upgrades, CVE patches, and best-practice changes always involve tradeoffs the user must decide. Auto-fixing them would be scope overshoot.

**Deferred findings re-enter the queue**: Deferring is not the same as skipping. Deferred findings are reconsidered on the next pass so they don't silently accumulate into permanent technical debt.
