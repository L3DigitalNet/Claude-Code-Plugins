# qdev Plugin — Design Spec

**Date:** 2026-04-13 (last reviewed: 2026-05-08 via /qdev:spec-update)
**Plugin:** `qdev`
**Commands:** `/qdev:quality-review`, `/qdev:research`, `/qdev:deps-audit`, `/qdev:doc-sync`, `/qdev:spec-update`

---

## Purpose

A five-command plugin that acts as a quality companion across the full development lifecycle — research before design, spec/plan/code review, dependency audit, inline-doc sync, and spec-to-code reconciliation. Explicitly invoked only; no contextual auto-loading.

---

## Plugin Structure

```
plugins/qdev/
├── .claude-plugin/
│   └── plugin.json
├── agents/
│   ├── qdev-deps-auditor.md
│   ├── qdev-doc-syncer.md
│   ├── qdev-quality-reviewer.md
│   └── qdev-researcher.md
├── commands/
│   ├── deps-audit.md
│   ├── doc-sync.md
│   ├── quality-review.md
│   ├── research.md
│   └── spec-update.md
├── CHANGELOG.md
└── README.md
```

No `skills/`, `hooks/`, or `scripts/` directories. Four of the five commands (`research`, `quality-review`, `deps-audit`, `doc-sync`) are thin orchestrators that dispatch a corresponding sub-agent under `agents/`; `spec-update` remains self-contained inline. See **Sub-agents** below for the orchestrator/agent split rationale.

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

## Command 2: `/qdev:research [topic]`

Thin orchestrator that dispatches the `qdev-researcher` sub-agent (Sonnet). Added in v1.1.0 (inline) and extracted to a sub-agent in v1.5.0.

### Allowed Tools

`Agent`, `AskUserQuestion`, `Read`, `Bash`

### Step 1: Establish Topic

If `$ARGUMENTS` is provided, use it. Otherwise read `git log --oneline -5` and project `CLAUDE.md` to infer candidates. If still ambiguous, present up to 3 inferred candidates plus the implicit Other entry via a single bounded `AskUserQuestion` (no two-step pattern). If no topic emerges, emit `No topic provided.` and stop.

### Step 2: Dispatch

Call the `Agent` tool with `subagent_type: qdev-researcher`, passing the topic and `depth=standard` (default). The orchestrator does NOT run search tools, `find`, or manifest reads itself — keeping raw search results out of the orchestrator context is the entire point of the delegation.

### Step 3: Present and Chain

Surface the agent's report verbatim (it is preformatted with the `## ⚠ Existing solution` callout already positioned). If Open Questions are non-empty or material Footguns surfaced, offer downstream chaining via `AskUserQuestion`: `Brainstorm next` (→ `superpowers:brainstorming`), `Quality-review related artifact` (→ `/qdev:quality-review` with the persisted research path as context), or `Just save and exit`. Apply the chosen handoff in-session.

The persisted report at `docs/research/<YYYY-MM-DD>-<slug>.md` is the canonical handoff artifact.

---

## Command 3: `/qdev:deps-audit [directory]`

Thin orchestrator that dispatches the `qdev-deps-auditor` sub-agent (Haiku). Added in v1.2.0 (inline) and extracted to a sub-agent in v1.3.0.

### Allowed Tools

`Agent`, `AskUserQuestion`

### Step 1: Dispatch

Call `Agent` with `subagent_type: qdev-deps-auditor`, passing `$ARGUMENTS` as the scope path (default: cwd). The agent discovers manifests across all supported ecosystems (Python, Node, Rust, Go, Ruby, PHP), runs dual-source CVE/version research per dependency, and returns a prioritized findings table classified Critical / High / Medium / Info. Read-only — never modifies manifests or lockfiles.

### Step 2: Present and Optionally Generate Upgrade Commands

Present the findings table verbatim. If Critical or High findings exist, prompt via `AskUserQuestion` whether to generate exact ecosystem-appropriate upgrade commands (`npm install pkg@X.Y.Z`, `pip install "pkg==X.Y.Z"`, `go get pkg@vX.Y.Z`, `cargo update -p pkg --precise X.Y.Z`). If none exist, emit a clean summary line and stop without prompting.

---

## Command 4: `/qdev:doc-sync [path]`

Thin orchestrator that dispatches the `qdev-doc-syncer` sub-agent (Haiku). Added in v1.2.0 (inline) and extracted to a sub-agent in v1.3.0.

### Allowed Tools

`Agent`, `AskUserQuestion`

### Step 1: Dry-Run Dispatch

Call `Agent` with `subagent_type: qdev-doc-syncer`, scope from `$ARGUMENTS` (default: `./` or `src/`), and `dry_run=true`. The agent enumerates public symbols, detects the codebase's docstring convention (Google / NumPy / reST / JSDoc / TSDoc / Go-line / Rust-`///`), classifies each symbol Missing / Stale / Current, and returns a proposals table. Never modifies function bodies or signatures.

### Step 2: Approval Gating

Zero proposals → emit success line and stop. >25 proposals → ask via `AskUserQuestion` to narrow scope (Apply all / Public-surface only / Narrow to a path / Review each one / Cancel). ≤25 → simpler prompt (Apply all / Review each one / Cancel).

### Step 3: Apply

For bulk options, re-dispatch the agent with `dry_run=false` (and any narrowed scope). For per-proposal review, walk the table one item at a time with `AskUserQuestion`; apply approved changes via `Edit` in this session (do not re-dispatch the agent for individual edits). Emit a final summary: `N added, M updated, K skipped`.

---

## Command 5: `/qdev:spec-update [spec-path]`

The only remaining inline command — kept self-contained because it produces structural edits to a single file under direct user supervision and does not benefit from sub-agent isolation.

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

## Sub-agents

Four of the five commands dispatch a dedicated sub-agent under `agents/`. The orchestrator command file owns user interaction (`AskUserQuestion`, final summaries, file `Edit` for individually-approved changes); the sub-agent owns the high-volume work (search, manifest parsing, signature analysis, convergence loop).

| Agent | Model | Called by | Responsibility |
|-------|-------|-----------|----------------|
| `qdev-researcher` | Sonnet | `/qdev:research` | Six-angle dual-source sweep with Context7 routing for libraries, footgun corroboration (2+ independent sources OR an official source), authority-graded citations (`[official]` / `[community]` / `[blog]` / `[unverified]`), single-iteration follow-up pass for thin angles, persists report to `docs/research/<YYYY-MM-DD>-<slug>.md`. Read-only on project source. |
| `qdev-quality-reviewer` | Sonnet | `/qdev:quality-review` | Mode auto-detection (spec / plan / code), research phase, critical-finding gate, iterative pass loop with oscillation detection, applies auto-fixes silently, emits structured needs-approval list for the command to drive via `AskUserQuestion`. Never calls `AskUserQuestion` itself. |
| `qdev-deps-auditor` | Haiku | `/qdev:deps-audit` | Manifest discovery across Python / Node / Rust / Go / Ruby / PHP, per-dep dual-source CVE + version research, advisory page extraction via `tavily_extract`, prioritized findings table (Critical / High / Medium / Info). Read-only. |
| `qdev-doc-syncer` | Haiku | `/qdev:doc-sync` | Public-symbol inventory, convention detection (Google / NumPy / reST / JSDoc / TSDoc / Go-line / Rust-`///`), Missing / Stale / Current classification, dry-run proposals table or apply mode. Never modifies function bodies or signatures. |

**Orchestrator/agent split rationale.** The four extracted commands all share a hot path that does not benefit from Opus reasoning: hundreds of raw search results, dozens of manifest entries, full source-tree walks, or N-pass convergence loops. Holding that traffic in the main Opus context cost ~50K tokens per typical weekly cycle (measured in v1.3.0 extractions; v1.5.0 added another ~25K saved per `/qdev:research` invocation). Sonnet handles synthesis-heavy work (`qdev-researcher`, `qdev-quality-reviewer`); Haiku handles mechanical translation (`qdev-deps-auditor`, `qdev-doc-syncer`). The orchestrator command remains in Opus and owns only the parts that actually need user judgment.

---

## Design Decisions

**Research-first ordering**: Research runs before static analysis so that no gap is filled with incorrect or outdated knowledge. Targeted follow-up research during the loop handles cases the initial sweep did not anticipate.

**No skills directory**: All commands are explicit-invocation only. Skills would be auto-loaded contextually — the opposite of the intended behavior. Logic lives in command files (orchestrators) and sub-agents (`agents/`); no skill ever fires without a slash command.

**Sub-agent extraction (v1.3.0, v1.5.0)**: `research`, `quality-review`, `deps-audit`, and `doc-sync` were originally inline in the command file. They were extracted into dedicated sub-agents because their hot paths (search-result parsing, manifest enumeration, signature analysis, multi-pass convergence) burn Opus context on work that doesn't need Opus reasoning. Sonnet handles synthesis-heavy agents (`qdev-researcher`, `qdev-quality-reviewer`); Haiku handles mechanical agents (`qdev-deps-auditor`, `qdev-doc-syncer`). Cumulative measured savings: ~75K tokens per typical weekly cycle. The orchestrator command keeps the user-interaction and approval logic; the sub-agent never calls `AskUserQuestion`.

**Context7 routing for library questions (v1.5.0)**: `qdev-researcher` detects library/framework topics via topic-kind classification and routes documentation queries through Context7 (`resolve-library-id` + `query-docs`) before falling back to web search. Library docs are first-class; pattern/topic queries skip Context7 entirely.

**Footgun corroboration discipline (v1.5.0)**: A footgun does not enter the report unless it appears in 2+ independent sources OR in an official source (project docs, security advisory, official changelog). Single-source items are demoted to `[unverified]` or omitted. Combined with the source-authority grading (`[official]` / `[community]` / `[blog]` / `[unverified]`), this prevents propagating stale or apocryphal advice from a single blog post.

**Persisted research artifact (v1.5.0)**: `qdev-researcher` writes its report to `docs/research/<YYYY-MM-DD>-<slug>.md`. Downstream commands (`/qdev:quality-review`) and skills (`superpowers:brainstorming`, `feature-dev:feature-dev`) consume the artifact by reading the path, not by re-running the sweep. Reports are not auto-cleaned; pruning is manual.

**spec-update as a separate command**: Code drifts from specs naturally. Folding spec-update into quality-review would create friction on every code review by forcing a decision about whether to update the spec. Keeping them separate lets you run either independently. Also, spec-update's structural-edit shape doesn't share the high-volume hot path that motivated sub-agent extraction for the other four commands — it stays inline.

**Research findings always need-approval**: Dependency upgrades, CVE patches, and best-practice changes always involve tradeoffs the user must decide. Auto-fixing them would be scope overshoot.

**Deferred findings re-enter the queue**: Deferring is not the same as skipping. Deferred findings are reconsidered on the next pass so they don't silently accumulate into permanent technical debt.
