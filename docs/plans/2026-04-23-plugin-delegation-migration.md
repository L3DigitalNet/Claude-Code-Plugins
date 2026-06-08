# Plugin Delegation Migration — Implementation Plan

> **For agentic workers:** Each phase is a self-contained commit. Gate reviews happen between phases. Do not bundle phases into a single commit — phase boundaries exist so regressions stay isolated.

**Goal:** Reduce Opus token consumption across the plugin set by delegating grunt work to Sonnet/Haiku subagents, following the reference pattern established by `up-docs` and `release-pipeline`.

**Architecture:** Six phases, sequenced smallest-to-biggest-risk. Phase 1 (model-tier audit) is a low-risk warmup. Phases 2-6 each create one or more new subagents and rewrite the corresponding command to a thin orchestrator. Every phase ends at a commit + verification gate before the next begins. Consolidated release at the end.

**Tech Stack:** Claude Code plugin system — agent files under `plugins/<plugin>/agents/*.md` with YAML frontmatter (`name`, `description`, `tools`, `model`). Commands invoke agents via the `Agent` tool dispatched from slash-command markdown.

**Reference patterns:**

- `plugins/up-docs/agents/up-docs-propagate-repo.md` — Haiku propagator with tight scope guardrails
- `plugins/up-docs/agents/up-docs-audit-drift.md` — Sonnet research+infer agent with verification discipline
- `plugins/release-pipeline/agents/test-runner.md` — Sonnet with explicit rationale in frontmatter

**Model-tier heuristics** (from the reference patterns):

- **Haiku** — mechanical, scope-bounded, deterministic (file edits, classification, parsing)
- **Sonnet** — research + infer, language-specific heuristics, multi-step reasoning with convergence
- **Opus** — reserved for ambiguous decision-making and user-facing orchestration

---

## Phase 0: Pre-flight Verification

Runs once before any phase starts.

**Files:** none modified; read-only checks.

- [ ] **Step 1: Verify clean working tree on `testing`**

```bash
git status --porcelain && git branch --show-current
```

Expected: empty porcelain output, current branch is `testing`.

- [ ] **Step 2: Verify marketplace validator passes baseline**

```bash
./scripts/validate-marketplace.sh 2>&1 | tail -5
```

Expected: `Validation passed` (0 errors, 1 warning max about uncommitted changes).

- [ ] **Step 3: Capture baseline versions table**

```bash
grep -H '"version"' plugins/home-assistant-dev/.claude-plugin/plugin.json plugins/qt-suite/.claude-plugin/plugin.json plugins/qdev/.claude-plugin/plugin.json plugins/repo-hygiene/.claude-plugin/plugin.json plugins/nominal/.claude-plugin/plugin.json plugins/test-driver/.claude-plugin/plugin.json plugins/python-dev/.claude-plugin/plugin.json
```

Record the output — each phase bumps its plugin's version, and the final release pass tags each bumped plugin.

---

## Phase 1: Model-Tier Audit (Lowest Risk, Highest ROI/Minute)

**Scope:** Edit `model:` frontmatter on 3 existing agents. Zero new files. No command changes.

**Why this first:** These are one-line edits that validate the "smaller model is sufficient" hypothesis on existing, tested agents. If Phase 1 regresses, rollback is a single `git revert`. If it works, it proves the delegation thesis before we build new subagents in later phases.

**Files affected:**

- `plugins/home-assistant-dev/agents/ha-integration-reviewer.md` — `sonnet` → `haiku`
- `plugins/qt-suite/agents/gui-tester.md` — `inherit` → `sonnet`
- `plugins/qt-suite/agents/test-generator.md` — `inherit` → `sonnet`
- `plugins/home-assistant-dev/.claude-plugin/plugin.json` — version bump
- `plugins/qt-suite/.claude-plugin/plugin.json` — version bump
- `plugins/home-assistant-dev/CHANGELOG.md` — new entry
- `plugins/qt-suite/CHANGELOG.md` — new entry
- `.claude-plugin/marketplace.json` — version sync for both

### Task 1.1: Downgrade `ha-integration-reviewer` Sonnet → Haiku

- [ ] **Step 1: Edit the agent frontmatter**

File: `plugins/home-assistant-dev/agents/ha-integration-reviewer.md`

Change line 5 from:

```yaml
model: sonnet
```

to:

```yaml
model: haiku
# haiku chosen: review checklist is structural (manifest fields, config_flow presence,
# coordinator usage, type annotations) — all mechanical pattern-matching, no inference.
```

- [ ] **Step 2: Verify no other file references this agent's model**

```bash
grep -rn 'ha-integration-reviewer' plugins/home-assistant-dev/ | grep -i 'sonnet\|haiku\|model'
```

Expected: no results beyond the agent file itself.

### Task 1.2: Downgrade `qt-suite/gui-tester` inherit → Sonnet

- [ ] **Step 1: Edit the agent frontmatter**

File: `plugins/qt-suite/agents/gui-tester.md`

Change line 44 from:

```yaml
model: inherit
```

to:

```yaml
model: sonnet
# sonnet chosen: multi-step Qt Pilot MCP interactions need reasoning budget, but not Opus —
# each step is a deterministic launch/click/screenshot/verify cycle. Inherit from Opus was wasteful.
```

### Task 1.3: Downgrade `qt-suite/test-generator` inherit → Sonnet

- [ ] **Step 1: Edit the agent frontmatter**

File: `plugins/qt-suite/agents/test-generator.md`

Change line 35 from:

```yaml
model: inherit
```

to:

```yaml
model: sonnet
# sonnet chosen: test generation from coverage gaps is code synthesis against a spec
# (gap description + source file). Sonnet is the right tier; Opus via inherit was overkill.
```

### Task 1.4: Bump versions and update CHANGELOGs

- [ ] **Step 1: Bump `home-assistant-dev` version**

Read current version from `plugins/home-assistant-dev/.claude-plugin/plugin.json` (currently `2.2.6` per Phase 0 baseline).

Bump to `2.2.7` (patch — no user-facing API change):

Edit `plugins/home-assistant-dev/.claude-plugin/plugin.json` line with `"version":` from `2.2.6` to `2.2.7`.

Edit `.claude-plugin/marketplace.json` — find the `home-assistant-dev` entry and change its `"version"` to `2.2.7`.

- [ ] **Step 2: Add CHANGELOG entry for `home-assistant-dev`**

Prepend to `plugins/home-assistant-dev/CHANGELOG.md` (after the `# Changelog` header and preamble, before the previous top entry):

```markdown
## [2.2.7] - 2026-04-23

### Changed

- `ha-integration-reviewer` agent downgraded from Sonnet to Haiku. The review checklist is structural (manifest fields, config_flow presence, coordinator usage, type annotations) — all mechanical pattern-matching with no inference required. Estimated ~40% reduction in per-review token cost.
```

- [ ] **Step 3: Bump `qt-suite` version**

Current: `0.3.0`. Bump to `0.3.1`.

Edit `plugins/qt-suite/.claude-plugin/plugin.json` version line. Edit `.claude-plugin/marketplace.json` `qt-suite` entry version.

- [ ] **Step 4: Add CHANGELOG entry for `qt-suite`**

Prepend to `plugins/qt-suite/CHANGELOG.md`:

```markdown
## [0.3.1] - 2026-04-23

### Changed

- `gui-tester` and `test-generator` agents changed from `model: inherit` to `model: sonnet`. When invoked from Opus sessions, inherit meant these agents ran on Opus for deterministic multi-step MCP interactions and coverage-gap test generation — Sonnet is the correct tier. Expected ~5x reduction in token cost per invocation for Opus users.
```

### Gate 1: Phase 1 verification

- [ ] **Step 1: Run validator**

```bash
./scripts/validate-marketplace.sh 2>&1 | tail -10
```

Expected: `Validation passed` with matching versions reported for `home-assistant-dev` (2.2.7) and `qt-suite` (0.3.1).

- [ ] **Step 2: Visual inspection — verify agent frontmatter parses**

```bash
for f in plugins/home-assistant-dev/agents/ha-integration-reviewer.md plugins/qt-suite/agents/gui-tester.md plugins/qt-suite/agents/test-generator.md; do
  echo "=== $f ==="
  head -15 "$f"
done
```

Expected: YAML frontmatter `model:` field shows the new value in each file.

- [ ] **Step 3: Commit Phase 1**

```bash
git add plugins/home-assistant-dev/agents/ha-integration-reviewer.md \
        plugins/home-assistant-dev/.claude-plugin/plugin.json \
        plugins/home-assistant-dev/CHANGELOG.md \
        plugins/qt-suite/agents/gui-tester.md \
        plugins/qt-suite/agents/test-generator.md \
        plugins/qt-suite/.claude-plugin/plugin.json \
        plugins/qt-suite/CHANGELOG.md \
        .claude-plugin/marketplace.json

git commit -m "$(cat <<'EOF'
Phase 1: model-tier audit — ha-integration-reviewer → haiku, qt-suite agents → sonnet

Three existing agents were running on tiers larger than their workload needed:

- ha-integration-reviewer: sonnet → haiku. Review checklist is structural pattern-matching;
  no inference required. ~40% token cost reduction per review.
- qt-suite/gui-tester: inherit → sonnet. When invoked from Opus sessions, inherit meant
  Opus — wasteful for deterministic Qt Pilot MCP loops.
- qt-suite/test-generator: inherit → sonnet. Coverage-gap test generation is code
  synthesis against a spec; Sonnet is the correct tier.

Versions: home-assistant-dev 2.2.6 → 2.2.7, qt-suite 0.3.0 → 0.3.1.
EOF
)"
```

- [ ] **Step 4: Pause for user review before Phase 2**

**User-facing prompt at this gate:** "Phase 1 committed on testing. Proceed to Phase 2 (qdev plugin restructure)?"

---

## Phase 2: qdev Plugin Restructure — The Big One

**Scope:** Create `plugins/qdev/agents/` directory. Add three new agents. Rewrite four commands to thin orchestrators that dispatch to the agents.

**Why second:** Highest single-plugin ROI (~60-80K tokens/week per the scan). Large surface area but each command is independent, so failures localize.

**Files affected:**

- **Create:** `plugins/qdev/agents/qdev-deps-auditor.md` (Haiku)
- **Create:** `plugins/qdev/agents/qdev-quality-reviewer.md` (Sonnet)
- **Create:** `plugins/qdev/agents/qdev-doc-syncer.md` (Haiku)
- **Modify:** `plugins/qdev/commands/deps-audit.md` (rewrite to dispatch)
- **Modify:** `plugins/qdev/commands/quality-review.md` (rewrite to dispatch)
- **Modify:** `plugins/qdev/commands/doc-sync.md` (rewrite to dispatch)
- **Modify:** `plugins/qdev/.claude-plugin/plugin.json` — version bump
- **Modify:** `plugins/qdev/CHANGELOG.md` — new entry
- **Modify:** `plugins/qdev/README.md` — document new agents section
- **Modify:** `.claude-plugin/marketplace.json` — version sync

### Task 2.1: Read current qdev commands in full

- [ ] **Step 1: Read all three target commands before editing**

```bash
wc -l plugins/qdev/commands/deps-audit.md plugins/qdev/commands/quality-review.md plugins/qdev/commands/doc-sync.md
```

Then Read each file in full via the Read tool. Do not edit until all three are loaded into context. The agent system prompts in Tasks 2.2-2.4 must preserve the semantics of the existing commands — if the agent loses behavior, the rewrite regresses the command.

### Task 2.2: Create `qdev-deps-auditor` (Haiku)

**File to create:** `plugins/qdev/agents/qdev-deps-auditor.md`

- [ ] **Step 1: Create `plugins/qdev/agents/` directory (via the Write tool creating the file will auto-create the parent)**

- [ ] **Step 2: Write the agent file**

````markdown
---
name: qdev-deps-auditor
description: Dependency security and freshness audit. Reads package manifests (requirements.txt, pyproject.toml, package.json, Cargo.toml, go.mod, Gemfile, composer.json), researches each dependency for CVEs, abandonment, and major version lag, and returns a prioritized findings report.
tools: Read, Glob, Grep, Bash, WebFetch, mcp__brave-search__brave_web_search, mcp__serper-search__google_search
model: haiku
---

<!--
  Role: dependency auditor for /qdev:deps-audit.
  Called by: plugins/qdev/commands/deps-audit.md via Agent dispatch.
  Not intended for direct user invocation.

  Model: haiku — per-dep lookup is mechanical (name → CVE/version/abandonment check).
  The research is high-volume (many API calls) but each is scope-bounded.
  Output contract: prioritized markdown table with one row per flagged dependency.
-->

<role>
You are the dependency auditor for the qdev toolkit. You read every package manifest in the project, enumerate dependencies, research each one for known CVEs, abandonment signals, and major-version lag, and return a prioritized findings table. You do not modify any files.
</role>

<task>
1. Discover manifest files at the project root and one level deep:
   - Python: `requirements*.txt`, `pyproject.toml`, `Pipfile`, `setup.py`
   - Node: `package.json`
   - Rust: `Cargo.toml`
   - Go: `go.mod`
   - Ruby: `Gemfile`
   - PHP: `composer.json`

2. Parse each manifest. Extract (name, declared version, is-dev-dep flag).

3. For each dependency, run a dual-source web search (brave + serper) with queries:
   - `"<name>" CVE <current-year>`
   - `"<name>" deprecated OR abandoned OR archived`
   - `"<name>" latest version` (to compute version lag)

4. Classify each dependency into one of:
   - 🔴 **Critical** — active CVE with a fix available, or known maintainer-abandoned
   - 🟡 **Warning** — major version behind, or maintenance mode
   - 🟢 **OK** — current or within 1 major version, no CVEs

5. Emit the prioritized findings table (see `<output_format>`). Do not recommend upgrades that would require a manual migration — state the version and let the user decide. </task>

<guardrails>
- **Read-only.** Never write to any manifest or lockfile. Never run `pip install`, `npm install`, or any package-manager command.
- **Verification discipline.** Every row in the findings table must cite a real URL or search result you actually retrieved. If a search returned empty, mark the row confidence `low` and leave the evidence field empty — do not fabricate CVE IDs or version numbers.
- **No extrapolation.** If the search for dep X returned results about dep Y, do not transfer the findings. State "no results" and move on.
- **Batch search calls.** Run search tool calls in parallel when auditing multiple deps — each `brave_web_search` / `google_search` is independent.
</guardrails>

<output_format>

```markdown
## Dependency Audit: <project>

**Manifests scanned:** <list> **Total dependencies:** N (M direct, P transitive if available)

### 🔴 Critical

| # | Package | Current | Latest | Issue | Evidence |
| --- | --- | --- | --- | --- | --- |
| 1 | django | 3.2.0 | 5.1.0 | CVE-2024-XXXX — SQL injection via ORM | https://nvd.nist.gov/... |

### 🟡 Warnings

| # | Package | Current | Latest | Issue | Evidence |
| --- | --- | --- | --- | --- | --- |
| 1 | requests | 2.25.0 | 2.32.0 | 3 major releases behind | https://pypi.org/project/requests/ |

### 🟢 OK

N dependencies — details omitted for brevity.

**Summary:** X critical, Y warnings, Z OK. Recommended actions: [top 3 fixes].
```
````

</output_format>

````

### Task 2.3: Create `qdev-quality-reviewer` (Sonnet)

**File to create:** `plugins/qdev/agents/qdev-quality-reviewer.md`

- [ ] **Step 1: Write the agent file**

```markdown
---
name: qdev-quality-reviewer
description: Research-first quality review with iterative gap/consistency check and fix loop until convergence. Detects spec, plan, or code mode automatically. Runs web research first to establish ground truth, then iterates until zero findings remain.
tools: Read, Edit, Write, Glob, Grep, Bash, WebFetch, mcp__brave-search__brave_web_search, mcp__serper-search__google_search, mcp__plugin_context7_context7__query-docs, mcp__plugin_context7_context7__resolve-library-id
model: sonnet
---

<!--
  Role: quality reviewer for /qdev:quality-review.
  Called by: plugins/qdev/commands/quality-review.md via Agent dispatch.

  Model: sonnet — dual-source research + iterative convergence loop requires reasoning
  budget over raw capability. Opus here was burning tokens on research-result parsing.
  Output contract: convergence report with findings + fix actions taken, final-pass diff.
-->

<role>
You are the quality reviewer for the qdev toolkit. You analyze an artifact (spec, plan, or code), research ground-truth for its domain, identify gaps and inconsistencies, propose fixes, and iterate to convergence. You operate in three modes detected from the artifact type.
</role>

<task>
1. **Detect mode** from the target path and content:
   - Path matches `docs/specs/*.md` or content has "## Requirements" + "## Acceptance Criteria" → **spec mode**
   - Path matches `docs/plans/*.md` or content has "## Task N:" repeated → **plan mode**
   - Otherwise → **code mode** (target is a source file or directory)

2. **Research ground-truth.** Enumerate 3-8 key technologies/libraries/APIs referenced in the artifact. For each, run dual-source web search AND Context7 library docs lookup. Keep the research corpus in working memory for the convergence loop.

3. **Pass 1 — Gap detection.** Compare artifact against research corpus. Emit findings as:
   - **Gap** — artifact omits a requirement/consideration the research says matters
   - **Inconsistency** — artifact contradicts itself (e.g., spec says X, later says not-X)
   - **Staleness** — artifact references superseded API/version per research

4. **Pass 2 — Fix loop.** For each finding, propose a concrete fix (exact text change or code block). Apply fixes via Edit. Re-read the artifact. Re-run Pass 1. Repeat until zero findings remain OR iteration count hits 5 (oscillation guard).

5. **Output.** Emit the convergence report: N iterations, findings resolved per iteration, final findings (should be zero), file diff summary.
</task>

<guardrails>
- **Verification discipline.** Every finding must cite a research source (URL or Context7 doc reference). Fabricated findings waste the user's review cycle.
- **Oscillation detection.** If Pass 2 makes and then reverts the same edit in two consecutive iterations, stop and emit an `## ⚠ OSCILLATION` block naming the contested section. Escalate to the user rather than thrashing.
- **Scope discipline.** Fix only findings you detected. Do not refactor, rename, or reorganize outside the finding set.
- **Commit discipline.** The command (not this agent) handles git operations. You Edit in place; the command commits.
</guardrails>

<output_format>
```markdown
## Quality Review: <artifact>

**Mode:** spec | plan | code
**Iterations:** N
**Final findings:** 0 ✅ | M (if escalated)

### Research Corpus
- <tech 1>: <1-line summary of what research said>
- <tech 2>: ...

### Convergence Log

| Iteration | Findings Entered | Fixes Applied | Findings Remaining |
|-----------|------------------|---------------|--------------------|
| 1 | 7 | 5 | 2 |
| 2 | 2 | 2 | 0 |

### Final Findings (escalation only, omitted on success)

| # | Type | Section | Issue | Evidence |
|---|------|---------|-------|----------|

### Fixes Applied

| # | File | Change | Rationale |
|---|------|--------|-----------|
````

</output_format>

````

### Task 2.4: Create `qdev-doc-syncer` (Haiku)

**File to create:** `plugins/qdev/agents/qdev-doc-syncer.md`

- [ ] **Step 1: Write the agent file**

```markdown
---
name: qdev-doc-syncer
description: Sync inline documentation (docstrings, JSDoc, doc comments) with current function signatures and behavior. Proposes additions for undocumented functions and updates for stale docs before writing anything.
tools: Read, Edit, Glob, Grep, Bash
model: haiku
---

<!--
  Role: doc synchronizer for /qdev:doc-sync.
  Called by: plugins/qdev/commands/doc-sync.md via Agent dispatch.

  Model: haiku — function-to-docstring mapping is mechanical. Signatures + bodies
  inform the docstring text via straightforward translation.
  Output contract: proposal table + applied-edits summary.
-->

<role>
You are the inline documentation synchronizer. You enumerate public functions/methods in a scoped source tree, detect which lack documentation or have stale documentation, and propose/apply updates.
</role>

<task>
1. **Scope inventory.** From the scope path provided by the caller:
   - Python: find `def ` and `class ` definitions not starting with `_`
   - JS/TS: find `export function`, `export class`, `export const ... =>`
   - Bash: find `function_name()` top-level definitions

2. **For each public symbol:**
   - Read its current docstring/comment (if any)
   - Compare against current signature (param names, return type, raised exceptions)
   - Classify as:
     - **Missing** — no docstring
     - **Stale** — docstring mentions a param that no longer exists, or omits a new one
     - **Current** — docstring matches signature

3. **Propose updates.** For Missing and Stale symbols, generate a docstring following the language convention (Google-style for Python if not detected otherwise; JSDoc for JS/TS; heredoc-style for Bash). Never invent behavior — read the function body to infer behavior described.

4. **Apply edits.** Use Edit to add/replace docstrings in place.

5. **Emit proposal + applied-edits table.** Always show proposals before edits, so a user reading the report can sanity-check.
</task>

<guardrails>
- **Read-only until proposal confirmed.** If the caller passed a `dry_run: true` flag in the invocation, emit proposals without Edit calls.
- **Never modify function bodies or signatures.** Docstring-only changes.
- **Never invent behavior.** If the function body does X but the existing docstring claims Y, the new docstring must describe X (the real behavior), not Y.
- **Preserve existing non-docstring comments.** If a function has `# important note` above it, do not disturb.
</guardrails>

<output_format>
```markdown
## Doc Sync: <scope>

**Scope:** <path>
**Symbols inventoried:** N (M missing, P stale, Q current)

### Proposals

| # | File:Line | Symbol | Classification | Proposed Change |
|---|-----------|--------|----------------|-----------------|
| 1 | src/foo.py:42 | `parse_config` | Missing | Add Google-style docstring with 3 params, 1 return |

### Edits Applied

| # | File | Symbol | Action |
|---|------|--------|--------|
| 1 | src/foo.py | parse_config | Added docstring |

**Summary:** N symbols updated.
````

</output_format>

````

### Task 2.5: Rewrite `qdev:deps-audit` command to thin orchestrator

**File:** `plugins/qdev/commands/deps-audit.md`

- [ ] **Step 1: Replace the command body**

The current command is ~122 lines walking Opus through manifest discovery + per-dep research. Replace with a thin orchestrator that dispatches the new Haiku agent.

```markdown
---
description: Dependency security and freshness audit via qdev-deps-auditor subagent
argument-hint: [scope path, defaults to current directory]
---

# qdev: deps-audit

Audit this project's dependencies for CVEs, abandonment, and major version lag by dispatching the `qdev-deps-auditor` subagent.

## What it does

The subagent runs on Haiku (cheap, mechanical lookups). It:
1. Discovers manifest files (requirements.txt, pyproject.toml, package.json, Cargo.toml, go.mod, Gemfile, composer.json) under the scope path.
2. Parses each manifest and enumerates dependencies.
3. Runs dual-source web research (brave + serper) per dep for CVEs, abandonment, and version lag.
4. Classifies into 🔴 Critical / 🟡 Warning / 🟢 OK.
5. Returns a prioritized findings table.

## How to invoke

Dispatch the agent with the scope path (defaults to the current working directory):

Use the `Agent` tool with `subagent_type: qdev-deps-auditor` and a prompt like:

> Audit the dependencies in `<scope path>`. Return the prioritized findings table per your output format. Do not modify any manifest or lockfile.

The subagent owns all research and classification. Do not perform manifest reads or web searches in this session — the point of the delegation is to keep raw search results and manifest content out of the Opus context.

## After the agent returns

Present the findings table to the user. Offer (via `AskUserQuestion`) the top 3 recommended actions as bounded choices. Do not auto-apply fixes — dependency upgrades require user judgment.
````

### Task 2.6: Rewrite `qdev:quality-review` command to thin orchestrator

**File:** `plugins/qdev/commands/quality-review.md`

- [ ] **Step 1: Replace the command body**

```markdown
---
description: Research-first iterative quality review via qdev-quality-reviewer subagent
argument-hint: [path to spec, plan, or code file/directory]
---

# qdev: quality-review

Review a spec, plan, or codebase for gaps, inconsistencies, and staleness — with research-backed ground truth — by dispatching the `qdev-quality-reviewer` subagent. The subagent iterates to convergence.

## What it does

The subagent runs on Sonnet (dual-source research + convergence loop). It:

1. Auto-detects spec / plan / code mode from the artifact.
2. Enumerates 3-8 key technologies and runs dual-source research (brave + serper + Context7 docs).
3. Pass 1: detects Gaps, Inconsistencies, and Staleness vs. research corpus.
4. Pass 2: proposes + applies fixes via Edit, re-reads, re-passes, until zero findings or iteration cap.
5. Returns a convergence report.

## How to invoke

Dispatch the agent with the target artifact path:

Use the `Agent` tool with `subagent_type: qdev-quality-reviewer` and a prompt like:

> Review `<artifact path>`. Auto-detect mode. Iterate to convergence. Return the convergence report per your output format.

Do not read the artifact or run research in this session. All research context stays in the subagent.

## After the agent returns

- If the report shows 0 final findings → present the convergence log and fixes applied.
- If the report has an `## ⚠ OSCILLATION` block → surface it verbatim and ask the user how to resolve the contested section.
- If the iteration cap was hit with findings remaining → present the remaining findings as a `AskUserQuestion` with three options: approve the in-place fixes so far, revert, or continue with guidance.
```

### Task 2.7: Rewrite `qdev:doc-sync` command to thin orchestrator

**File:** `plugins/qdev/commands/doc-sync.md`

- [ ] **Step 1: Replace the command body**

```markdown
---
description: Sync inline documentation with current signatures via qdev-doc-syncer subagent
argument-hint: [scope path, defaults to src/ or ./]
---

# qdev: doc-sync

Update inline documentation (docstrings, JSDoc, doc comments) to match current function signatures and behavior by dispatching the `qdev-doc-syncer` subagent.

## What it does

The subagent runs on Haiku (mechanical signature→docstring translation). It:

1. Inventories public symbols in the scope (functions, methods, classes).
2. Classifies each as Missing / Stale / Current against its existing docstring.
3. Proposes updates following language convention (Google-style for Python, JSDoc for JS/TS).
4. Applies edits in place.

## How to invoke

Dispatch the agent with the scope path:

Use the `Agent` tool with `subagent_type: qdev-doc-syncer` and a prompt like:

> Sync inline docs in `<scope path>`. Inventory, classify, propose, then apply. Return the proposals + edits table.

## After the agent returns

Present the proposals and applied-edits table. If the user wants dry-run mode, re-dispatch with a prompt addition: "Return proposals only; do not apply edits."
```

### Task 2.8: Version bump, CHANGELOG, marketplace sync

- [ ] **Step 1: Bump `qdev` version from `1.2.1` to `1.3.0`** (minor — new subagents introduce new behavior surface)

Edit `plugins/qdev/.claude-plugin/plugin.json` version. Edit `.claude-plugin/marketplace.json` `qdev` entry version.

- [ ] **Step 2: Add CHANGELOG entry**

Prepend to `plugins/qdev/CHANGELOG.md`:

```markdown
## [1.3.0] - 2026-04-23

### Changed

- `/qdev:deps-audit`, `/qdev:quality-review`, and `/qdev:doc-sync` now dispatch dedicated subagents (`qdev-deps-auditor` on Haiku, `qdev-quality-reviewer` on Sonnet, `qdev-doc-syncer` on Haiku) rather than doing the research/analysis/edit work inline. Commands are now thin orchestrators. Estimated ~50K tokens saved per typical weekly usage cycle when invoked from Opus sessions.

### Added

- `plugins/qdev/agents/qdev-deps-auditor.md` — Haiku agent for manifest parsing + per-dep CVE/version research.
- `plugins/qdev/agents/qdev-quality-reviewer.md` — Sonnet agent for research-first iterative quality review with oscillation detection.
- `plugins/qdev/agents/qdev-doc-syncer.md` — Haiku agent for docstring/JSDoc sync against current signatures.
```

- [ ] **Step 3: Update `plugins/qdev/README.md` agents section**

Read the current README first. If no `## Agents` section exists, add one after the Commands section. Otherwise add rows to the existing table. Add three rows, one per new agent, matching the format used in other plugins' READMEs (name, model, what it does).

### Gate 2: Phase 2 verification

- [ ] **Step 1: Validate marketplace**

```bash
./scripts/validate-marketplace.sh 2>&1 | tail -10
```

Expected: validation passed, qdev version 1.3.0.

- [ ] **Step 2: Verify each new agent frontmatter parses**

```bash
for f in plugins/qdev/agents/*.md; do
  echo "=== $f ==="
  python3 -c "
import re, sys
with open('$f') as fh:
    raw = fh.read()
m = re.match(r'^---\n(.*?)\n---', raw, re.DOTALL)
if not m: print('NO FRONTMATTER', file=sys.stderr); sys.exit(1)
import yaml
fm = yaml.safe_load(m.group(1))
print(f'  name: {fm.get(\"name\")}')
print(f'  model: {fm.get(\"model\")}')
print(f'  tools: {len(fm.get(\"tools\", \"\").split(\",\")) if fm.get(\"tools\") else 0} tools')
"
done
```

Expected: each agent prints a name, model, and tool count. No `NO FRONTMATTER` errors.

- [ ] **Step 3: Verify command files reference the correct agent names**

```bash
grep -l 'subagent_type:' plugins/qdev/commands/ | xargs grep -H 'subagent_type:'
```

Expected: three lines, each naming one of `qdev-deps-auditor`, `qdev-quality-reviewer`, `qdev-doc-syncer`.

- [ ] **Step 4: Commit Phase 2**

```bash
git add plugins/qdev/ .claude-plugin/marketplace.json

git commit -m "$(cat <<'EOF'
Phase 2: qdev plugin restructure — three new subagents, commands become thin orchestrators

Creates plugins/qdev/agents/ with three new subagents:
- qdev-deps-auditor (Haiku): manifest discovery + per-dep CVE/version research.
- qdev-quality-reviewer (Sonnet): research-first iterative review with oscillation detection.
- qdev-doc-syncer (Haiku): docstring sync against current signatures.

Rewrites /qdev:deps-audit, /qdev:quality-review, /qdev:doc-sync as ~30-line orchestrators
that dispatch to the subagents. The commands no longer do any manifest reads, web searches,
or source-file enumeration inline — all of that work now happens in cheaper subagent
contexts.

Estimated ~50K tokens saved per typical weekly usage cycle on Opus sessions.

qdev: 1.2.1 → 1.3.0.
EOF
)"
```

- [ ] **Step 5: Manual smoke test (optional, user can defer)**

In a separate test session, run `/qdev:deps-audit` against this repo. Verify the Haiku subagent is dispatched and returns a findings table. If regressions appear, roll back via `git revert HEAD` before proceeding to Phase 3.

**User-facing prompt at this gate:** "Phase 2 committed. Proceed to Phase 3 (repo-hygiene semantic split)?"

---

## Phase 3: repo-hygiene Semantic Pass Split

**Scope:** Split the `/hygiene` Step 2 semantic README/docs pass out of the Opus command and into a new Haiku subagent. Keep the Step 1 mechanical script phase inline — those are fast scripts that don't need delegation.

**Files affected:**

- **Create:** `plugins/repo-hygiene/agents/hygiene-semantic-auditor.md` (Haiku)
- **Modify:** `plugins/repo-hygiene/commands/hygiene.md` — Step 2 becomes an Agent dispatch
- **Modify:** `plugins/repo-hygiene/.claude-plugin/plugin.json` — version bump
- **Modify:** `plugins/repo-hygiene/CHANGELOG.md`
- **Modify:** `plugins/repo-hygiene/README.md` — add agents section
- **Modify:** `.claude-plugin/marketplace.json`

### Task 3.1: Read current hygiene command in full

- [ ] **Step 1: Read `plugins/repo-hygiene/commands/hygiene.md` in full**

The command is ~320 lines. The rewrite must preserve Step 1 (mechanical scripts) verbatim and only replace Step 2 (semantic pass).

Identify the exact line range of Step 2 — everything that reads plugin READMEs, root README, and docs/ files and audits them for structural/staleness issues. That range becomes the agent's responsibility.

### Task 3.2: Create `hygiene-semantic-auditor` (Haiku)

**File to create:** `plugins/repo-hygiene/agents/hygiene-semantic-auditor.md`

- [ ] **Step 1: Write the agent file**

````markdown
---
name: hygiene-semantic-auditor
description: Semantic audit of plugin READMEs, root README, and docs/ directory for structural conformance, stale cross-references, placeholder text, and template drift. Read-only — surfaces findings for the user to resolve.
tools: Read, Glob, Grep, Bash
model: haiku
---

<!--
  Role: semantic-pass auditor for /hygiene.
  Called by: plugins/repo-hygiene/commands/hygiene.md Step 2.
  Step 1 (mechanical parallel scripts) stays in the command — those are sub-second and
  benefit from running in the Opus context for immediate failure escalation.
  Step 2 is the expensive read-heavy semantic pass; it goes here.

  Model: haiku — README-level pattern-matching against templates, staleness detection via
  grep + date comparisons. No inference required.
  Output contract: findings table with file paths, line numbers, categories, fixes.
  Hard rule: read-only. Do not Edit any file. User consents to fixes via the command.
-->

<role>
You are the semantic auditor for the repo-hygiene sweep. You read plugin READMEs, the root README, and `docs/` files to check structural conformance, detect stale cross-references, flag placeholder text, and surface template drift. You report findings. You do not modify files.
</role>

<task>
1. **Enumerate scope:**
   - `plugins/*/README.md` — one per plugin
   - `README.md` at repo root
   - `docs/*.md` and `docs/**/*.md`

2. **Read each file in full** before auditing.

3. **Run the structural audit per file:**
   - **README template conformance** — compare against `docs/plugin-readme-template.md`. Flag missing required sections (Summary, Commands/Skills/Agents tables as applicable, Installation).
   - **Placeholder detection** — grep for `TODO`, `FIXME`, `XXX`, `TBD`, `<insert`, `lorem ipsum`.
   - **Stale cross-refs** — for every `plugins/<name>/` or `docs/<file>.md` reference, verify the target exists. Report broken refs.
   - **Version drift** — if the README shows a version string, verify it matches the plugin.json version.
   - **Capability staleness** — if the README claims a command exists (e.g., "Invoke /foo:bar"), verify the command file exists under `plugins/<name>/commands/`.

4. **Emit the findings table.** Group by plugin / file. </task>

<guardrails>
- **Read-only.** No Edit/Write/Bash commands that modify state. `bash ls`, `grep`, `git diff --stat`, `cat` are fine; any `rm`, `mv`, `>`, `>>`, or editor rewrite is forbidden.
- **Every finding must cite a line number** in the file where the issue appears. No vague "somewhere in the README" findings.
- **Do not recommend destructive fixes.** Surface the issue; the user decides.
- **Verification discipline for broken cross-refs.** Before flagging a reference as broken, run `ls` or `test -e` to confirm the target doesn't exist. A finding based on assumption is a fabricated finding.
</guardrails>

<output_format>

```markdown
## Semantic Audit Findings

**Scope:** <N plugin READMEs, root README, M docs/ files>

### Per-file findings

| # | File:Line | Category | Issue | Suggested Fix |
| --- | --- | --- | --- | --- |
| 1 | plugins/foo/README.md:12 | Placeholder | `TODO: add example` | Remove placeholder or replace with a real example |
| 2 | README.md:45 | Broken cross-ref | Links to `plugins/old-plugin/` which does not exist | Remove the reference or update to a current plugin |

**Totals:** N findings across M files. X placeholders, Y broken refs, Z template drift, W version mismatches.

If zero findings, emit:

### ✅ All plugin READMEs, root README, and docs/ files are clean.
```
````

</output_format>

````

### Task 3.3: Rewrite hygiene command Step 2 as agent dispatch

- [ ] **Step 1: Identify Step 2 boundaries in the current command**

Re-read `plugins/repo-hygiene/commands/hygiene.md` and locate the exact section that handles the semantic audit (the part after the mechanical script phase). This is the range to replace.

- [ ] **Step 2: Replace Step 2 with an Agent dispatch block**

Keep the outer command structure and Step 1 (mechanical checks) untouched. Replace the Step 2 section with:

```markdown
## Step 2: Semantic audit (subagent)

Dispatch the `hygiene-semantic-auditor` subagent (Haiku) to scan plugin READMEs, the root README, and `docs/` files for structural drift, placeholders, and broken cross-references.

Use the `Agent` tool with `subagent_type: hygiene-semantic-auditor`. The subagent runs read-only and returns a findings table.

After the agent returns:
1. Present the findings table to the user.
2. For each finding, offer a targeted fix via `AskUserQuestion` (multi-select preferred — the user can approve several at once).
3. Apply approved fixes via Edit in this session. The subagent never edits; the command owns all writes.

Do not re-enumerate plugin READMEs or re-run placeholder greps in this session — those reads all happen in the subagent context.
````

### Task 3.4: Version bump, CHANGELOG, marketplace

- [ ] **Step 1: Bump `repo-hygiene` from `1.3.0` to `1.4.0`**

- [ ] **Step 2: CHANGELOG entry**

Prepend to `plugins/repo-hygiene/CHANGELOG.md`:

```markdown
## [1.4.0] - 2026-04-23

### Changed

- `/hygiene` Step 2 (semantic audit of plugin READMEs, root README, and docs/) now dispatches the new `hygiene-semantic-auditor` subagent (Haiku) instead of reading all those files in the Opus context. Step 1 (mechanical parallel scripts) is unchanged — those are sub-second and benefit from immediate in-session failure escalation. Estimated ~15K tokens saved per hygiene run.

### Added

- `plugins/repo-hygiene/agents/hygiene-semantic-auditor.md` — Haiku agent for read-only structural README/docs audit.
```

- [ ] **Step 3: Sync marketplace.json version**

### Gate 3: Phase 3 verification

- [ ] **Step 1: Run validator**

```bash
./scripts/validate-marketplace.sh 2>&1 | tail -5
```

- [ ] **Step 2: Verify agent frontmatter parses** (same method as Gate 2 Step 2, on the new agent file)

- [ ] **Step 3: Visual inspection — Step 1 of the hygiene command is unchanged**

```bash
git diff plugins/repo-hygiene/commands/hygiene.md | head -60
```

Expected: diff shows Step 2 rewrite only. Step 1 mechanical scripts should be unchanged.

- [ ] **Step 4: Commit Phase 3**

```bash
git add plugins/repo-hygiene/ .claude-plugin/marketplace.json

git commit -m "$(cat <<'EOF'
Phase 3: repo-hygiene semantic pass moved to hygiene-semantic-auditor (Haiku)

Step 1 of /hygiene (seven parallel mechanical scripts — gitignore, manifests, orphans,
stale-commits, readme-structure, readme-placeholders, readme-refs) stays inline — those
are sub-second and benefit from immediate in-session failure escalation.

Step 2 (semantic audit of plugin READMEs, root README, and docs/ files) was ~150 lines
of Opus-driven reading and grep + comparison work. That is now dispatched to
hygiene-semantic-auditor on Haiku, which returns a findings table. The command applies
user-approved fixes via Edit.

Estimated ~15K tokens saved per hygiene run.

repo-hygiene: 1.3.0 → 1.4.0.
EOF
)"
```

**User-facing prompt at this gate:** "Phase 3 committed. Proceed to Phase 4 (nominal:postflight)?"

---

## Phase 4: nominal:postflight Delegation — **SKIPPED 2026-04-23**

**Reason skipped:** Re-reading the command revealed three hard constraints the scan missed: (1) rule #4 mandates real-time per-domain output, no buffering; (2) Step 3 has per-anomaly `AskUserQuestion` between domains with fix-forward that can halt execution; (3) cascade halt must stop immediately. Naive delegation breaks all three. Delegation was possible only with a UX behavior change (batch execution + post-hoc anomaly walk), and estimated savings dropped from ~8K to ~3-5K. User chose to skip.

---

## Phase 4 (ORIGINAL — not executed)

**Scope:** Create `nominal-systems-verifier` Haiku agent. Rewrite `/nominal:postflight` to dispatch the 11-domain verification to the agent, keeping the interactive anomaly prompts and flight-log construction inline.

**Why this split:** Domain verification (running 11 scripts, parsing JSON, initial classification) is deterministic grunt work. The interactive anomaly prompts and flight-log narrative construction need user context and should stay in Opus.

**Files affected:**

- **Create:** `plugins/nominal/agents/nominal-systems-verifier.md` (Haiku)
- **Modify:** `plugins/nominal/commands/postflight.md` — verification phase becomes Agent dispatch
- **Modify:** `plugins/nominal/.claude-plugin/plugin.json` — version bump
- **Modify:** `plugins/nominal/CHANGELOG.md`
- **Modify:** `plugins/nominal/README.md`
- **Modify:** `.claude-plugin/marketplace.json`

### Task 4.1: Read current postflight command in full

- [ ] **Step 1: Read `plugins/nominal/commands/postflight.md` and identify the verification phase**

The command is ~116 lines. Identify the exact range that: (a) executes the 11 domain scripts, (b) parses each JSON result, (c) classifies into nominal / anomaly. That range becomes the agent's job. Interactive prompts + flight log stay inline.

### Task 4.2: Create `nominal-systems-verifier` (Haiku)

**File to create:** `plugins/nominal/agents/nominal-systems-verifier.md`

- [ ] **Step 1: Write the agent file**

`````markdown
---
name: nominal-systems-verifier
description: Execute the 11 domain verification scripts for /nominal:postflight, parse JSON outputs, classify each domain as nominal or anomalous, and return a consolidated findings table. Does not interact with the user — surfaces anomalies for the command to handle.
tools: Read, Bash, Glob
model: haiku
---

<!--
  Role: systems verifier for /nominal:postflight.
  Called by: plugins/nominal/commands/postflight.md during the verification phase.

  Model: haiku — running N known scripts, parsing their JSON output, and classifying
  against the domain's nominal schema is mechanical. Each domain is independent.
  Output contract: per-domain status table + aggregated flight-log fragment.
-->

<role>
You are the systems verifier for the nominal postflight check. You execute the 11 domain verification scripts, parse each JSON output, classify each domain as nominal or anomalous against its schema, and return a consolidated table. You do not prompt the user. You do not decide remediation. The command owns both.
</role>

<task>
1. Read the profile from `plugins/nominal/references/` (the profile tells you which of the 11 domains apply to this environment).

2. For each applicable domain, execute its verification script via Bash. Capture stdout + stderr + exit code.

3. Parse the JSON result. Each domain script emits a payload with at least `{status: "nominal"|"anomaly", details: {...}}`.

4. Classify:
   - `nominal` + exit 0 → OK
   - `anomaly` OR exit != 0 → flagged, populate anomaly details

5. Emit the aggregate table + per-domain anomaly blocks (see `<output_format>`). If any domain script emitted stderr, include the last 5 lines. </task>

<guardrails>
- **Run each script once.** Do not retry on anomaly — the command decides retry via user interaction.
- **No writes.** The scripts themselves may perform read-only network calls; you do not call any write tool (Edit, Write) yourself.
- **Preserve exit codes in the output.** The command uses them for decision-making.
- **Parallel execution allowed** — domain scripts are independent. Batch them when practical.
</guardrails>

<output_format>

````markdown
## Postflight Verification Summary

| #   | Domain  | Status     | Exit | Details                          |
| --- | ------- | ---------- | ---- | -------------------------------- |
| 1   | network | ✅ nominal | 0    | all 5 targets reachable          |
| 2   | storage | ⚠ anomaly  | 0    | disk at 92% on /var              |
| 3   | compute | ❌ FAILED  | 1    | script errored (see block below) |

### Anomaly Blocks

#### storage (anomaly)

```json
{ "status": "anomaly", "details": { "mount": "/var", "used_pct": 92, "threshold": 85 } }
```
````
`````

`````

#### compute (FAILED)

Script exited 1. Last stderr lines:

```
error: unable to reach hypervisor at 100.92.153.67
```

**Totals:** 9 nominal, 1 anomaly, 1 failed. Proceed to interactive anomaly handling.

```
</output_format>
```

### Task 4.3: Rewrite postflight command verification phase

- [ ] **Step 1: Replace the inline verification loop with an agent dispatch**

Keep the command's intro, interactive anomaly-handling section, and final flight-log construction. Replace the middle "run 11 domain scripts" section with:

```markdown
## Verification Phase (subagent)

Dispatch the `nominal-systems-verifier` subagent (Haiku). It runs all 11 domain verification scripts in parallel, parses their JSON outputs, classifies each as nominal / anomaly / failed, and returns the consolidated summary table.

Use the `Agent` tool with `subagent_type: nominal-systems-verifier`. Pass the active profile so the agent knows which domains apply.

Do not run domain scripts directly in this session — all script execution and JSON parsing belongs in the subagent.

## Post-Verification

After the subagent returns the summary table:

1. Present the table verbatim to the user.
2. For each anomaly row, offer remediation options via `AskUserQuestion`.
3. Construct the flight log (session-final narrative) from the subagent's output + the user's interaction record.
```

### Task 4.4: Version bump + CHANGELOG + marketplace + README

- [ ] **Step 1: Bump `nominal` from `1.1.0` to `1.2.0`**

- [ ] **Step 2: CHANGELOG entry**

Prepend to `plugins/nominal/CHANGELOG.md`:

```markdown
## [1.2.0] - 2026-04-23

### Changed

- `/nominal:postflight` now dispatches the new `nominal-systems-verifier` subagent (Haiku) for the 11-domain verification phase. The subagent runs scripts in parallel, parses JSON outputs, and returns a consolidated table. The command retains interactive anomaly-handling and flight-log construction in the Opus context. Estimated ~8K tokens saved per postflight run.

### Added

- `plugins/nominal/agents/nominal-systems-verifier.md` — Haiku agent for parallel 11-domain script execution and JSON classification.
```

- [ ] **Step 3: Sync marketplace.json + update README agents section**

### Gate 4: Phase 4 verification

- [ ] **Step 1: Run validator**

- [ ] **Step 2: Frontmatter parse check on the new agent**

- [ ] **Step 3: Commit Phase 4**

```bash
git add plugins/nominal/ .claude-plugin/marketplace.json

git commit -m "$(cat <<'EOF'
Phase 4: nominal:postflight verification phase moved to nominal-systems-verifier (Haiku)

The 11-domain verification phase (script execution + JSON parsing + classification) was
~70 lines of Opus-driven script dispatch. That work now happens in a dedicated Haiku
agent that runs scripts in parallel and returns a consolidated summary table.

The interactive anomaly-handling phase and flight-log construction stay in the Opus
context — those need user interaction and narrative judgment that smaller tiers don't
handle well.

Estimated ~8K tokens saved per postflight run.

nominal: 1.1.0 → 1.2.0.
EOF
)"
```

**User-facing prompt at this gate:** "Phase 4 committed. Proceed to Phase 5 (test-driver:analyze)?"

---

## Phase 5: test-driver Gap Analyzer — **SKIPPED 2026-04-23**

**Reason skipped:** The target command `plugins/test-driver/commands/analyze.md` has an explicit `opus-context alignment` comment stating: "Read source files fully ... The function-level enumeration in step 4 is the foundation of accurate gap detection — skipping it collapses the analysis to file-level mapping, which dramatically under-reports gaps." Step 3.4 explicitly says "this step stays with Claude." The command author already decided this work belongs in Opus context and documented why; the scan missed that decision. User chose to respect the existing design.

---

## Phase 5 (ORIGINAL — not executed)

**Scope:** Create `test-driver-gap-analyzer` Sonnet agent. Rewrite the analysis portion of `/test-driver:analyze` (the source-file inventory + function enumeration + gap map) to dispatch to the agent.

**Why Sonnet (not Haiku):** Function-level coverage gap analysis requires understanding what each function does (so the gap map is semantically meaningful, not just "no test named test_foo exists"). Haiku can miss nuance here.

**Files affected:**

- **Create:** `plugins/test-driver/agents/test-driver-gap-analyzer.md` (Sonnet)
- **Modify:** `plugins/test-driver/commands/analyze.md` — analysis phase becomes Agent dispatch
- **Modify:** `plugins/test-driver/.claude-plugin/plugin.json` — version bump
- **Modify:** `plugins/test-driver/CHANGELOG.md`
- **Modify:** `plugins/test-driver/README.md`
- **Modify:** `.claude-plugin/marketplace.json`

### Task 5.1: Read current analyze command

- [ ] **Step 1: Read `plugins/test-driver/commands/analyze.md`** (~76 lines). Identify the inventory + gap-map phase (the expensive part).

### Task 5.2: Create `test-driver-gap-analyzer` (Sonnet)

**File to create:** `plugins/test-driver/agents/test-driver-gap-analyzer.md`

- [ ] **Step 1: Write the agent file**

````markdown
---
name: test-driver-gap-analyzer
description: Analyze a project's source files to enumerate testable functions and compute the test-coverage gap map (which functions lack direct tests). Returns a prioritized gap table keyed by module.
tools: Read, Glob, Grep, Bash
model: sonnet
---

<!--
  Role: gap analyzer for /test-driver:analyze.
  Called by: plugins/test-driver/commands/analyze.md after the profile + scope are loaded.

  Model: sonnet — function-level coverage analysis needs to understand what each function
  does (inputs, outputs, error paths) so the gap map is semantically useful, not just
  name-matched. Haiku misses nuance; Opus is overkill.
  Output contract: gap table with priority, module/function paths, and suggested test
  scenarios.
-->

<role>
You are the test-coverage gap analyzer. You enumerate public functions/methods in a project's source tree, map each to its existing tests (if any), identify uncovered functions, and produce a prioritized gap table with suggested test scenarios.
</role>

<task>
1. **Scope.** From the scope path provided:
   - Python: inventory `def ` and `class ` in `src/` or `<project>/`
   - JS/TS: `export function`, `export class`, `export const ... =>` in `src/`
   - Other languages: adapt per convention

2. **Test inventory.** Glob the tests directory (`tests/`, `test/`, `spec/`, `__tests__/`). For each test file, grep for references to source functions by name.

3. **Gap map.** For each source function: does at least one test file reference it?
   - No → **uncovered** (gap)
   - Yes, shallow reference only (e.g. mentioned but not called) → **weakly covered**
   - Yes, called in test → **covered**

4. **Prioritize gaps.** Estimate each gap's priority using readable heuristics:
   - 🔴 **Critical** — function contains `raise`, `throw`, `except`, or error-handling paths
   - 🟡 **Warning** — function has branching (`if`/`match`/`switch`) > 3 branches
   - 🟢 **Low** — simple function, single branch, no error paths

5. **Suggest test scenarios.** For each gap, read the function body and suggest 1-3 test scenarios (normal path, edge cases, error paths). Cite line numbers.

6. **Emit** the gap table per `<output_format>`. </task>

<guardrails>
- **Read-only.** No Edit / Write calls. You do not generate the tests — the command does (or delegates to the qt-suite `test-generator` or similar per project conventions).
- **Signature fidelity.** When suggesting a test scenario, cite the function signature accurately. If you hallucinate parameters, the user will waste cycles debugging.
- **Per-module grouping.** Group gaps by source module in the output so reviewers can scan by area of interest.
</guardrails>

<output_format>

```markdown
## Test Coverage Gap Analysis

**Scope:** <path> **Functions inventoried:** N (M public / P private) **Gaps detected:** X (Y critical, Z warnings, W low)

### Per-module Gaps

#### `src/foo.py`

| # | Function | Line | Priority | Gap | Suggested Tests |
| --- | --- | --- | --- | --- | --- |
| 1 | `parse_config` | 42 | 🔴 Critical | No tests; raises `ConfigError` on 3 paths | 1. normal parse 2. missing key → error 3. malformed value → error |

#### `src/bar.py`

...

**Summary:** <N gaps across M modules>. Top 3 priorities: <list>.
```
`````

</output_format>

````

### Task 5.3: Rewrite analyze command

- [ ] **Step 1: Replace the inventory + gap-map phase with Agent dispatch**

```markdown
## Analysis Phase (subagent)

Dispatch the `test-driver-gap-analyzer` subagent (Sonnet). It inventories public functions in the scope, cross-references existing tests, prioritizes gaps, and returns a table with suggested test scenarios.

Use the `Agent` tool with `subagent_type: test-driver-gap-analyzer`. Pass the scope path.

Do not read source files or enumerate functions in this session — the subagent owns the inventory.
````

Keep the profile-loading, convergence loop, and result-presentation phases of the command inline.

### Task 5.4: Version + CHANGELOG + marketplace + README

- [ ] **Step 1: Bump `test-driver` from `0.6.0` to `0.7.0`**

- [ ] **Step 2: CHANGELOG entry**

Prepend to `plugins/test-driver/CHANGELOG.md`:

```markdown
## [0.7.0] - 2026-04-23

### Changed

- `/test-driver:analyze` now dispatches the new `test-driver-gap-analyzer` subagent (Sonnet) for the source inventory + gap-map phase. The subagent reads source files, enumerates public functions, classifies coverage, and returns a prioritized gap table with suggested test scenarios. The command retains profile loading, convergence loop control, and user-facing presentation in the Opus context. Estimated ~16K tokens saved per analysis run.

### Added

- `plugins/test-driver/agents/test-driver-gap-analyzer.md` — Sonnet agent for semantic gap analysis.
```

- [ ] **Step 3: Sync marketplace.json + update README**

### Gate 5: Phase 5 verification

Same pattern as prior gates: validator, frontmatter parse, commit with message:

```
Phase 5: test-driver gap analysis moved to test-driver-gap-analyzer (Sonnet)

Source inventory + function enumeration + gap mapping was ~40 lines of read-heavy
work in the Opus context. That now happens in a Sonnet subagent that returns a
prioritized gap table with per-function test scenarios.

Sonnet (not Haiku) because function-level gap reasoning benefits from understanding
what each function does, so the suggested test scenarios are semantic rather than
just name-matched.

Estimated ~16K tokens saved per analyze run.

test-driver: 0.6.0 → 0.7.0.
```

**User-facing prompt at this gate:** "Phase 5 committed. Proceed to Phase 6 (python-dev code reviewer)?"

---

## Phase 6: python-dev Code Review Orchestrator

**Scope:** Add a new `python-code-reviewer` Sonnet agent that orchestrates the 11 python-dev skills across a Python codebase. Add a new `/python-code-review` command that dispatches to it.

**Note:** The scan report noted this command is "implied, no explicit command file." This is a new command, not a rewrite.

**Files affected:**

- **Create:** `plugins/python-dev/agents/python-code-reviewer.md` (Sonnet)
- **Create:** `plugins/python-dev/commands/python-code-review.md` (thin orchestrator)
- **Modify:** `plugins/python-dev/.claude-plugin/plugin.json` — version bump
- **Modify:** `plugins/python-dev/CHANGELOG.md`
- **Modify:** `plugins/python-dev/README.md`
- **Modify:** `.claude-plugin/marketplace.json`

### Task 6.1: Confirm the command doesn't exist yet

- [ ] **Step 1: Verify**

```bash
ls plugins/python-dev/commands/
```

Expected: no file named `python-code-review.md`. (If one exists, this phase becomes a rewrite; adjust Task 6.3 accordingly.)

### Task 6.2: Create `python-code-reviewer` (Sonnet)

**File to create:** `plugins/python-dev/agents/python-code-reviewer.md`

- [ ] **Step 1: List the 11 python-dev skills by reading `plugins/python-dev/skills/`**

Available skills (to be cross-referenced in the agent prompt): testing, async, resilience, observability, configuration, design patterns, resource management, anti-patterns, type safety, code style, background jobs.

- [ ] **Step 2: Write the agent file**

````markdown
---
name: python-code-reviewer
description: Comprehensive Python code review — applies the 11 python-dev domain skills (testing, async, resilience, observability, configuration, design patterns, resource management, anti-patterns, type safety, code style, background jobs) across a codebase and returns a prioritized findings report.
tools: Read, Glob, Grep, Bash
model: sonnet
skills:
  - python-testing-patterns
  - async-python-patterns
  - python-resilience
  - python-observability
  - python-configuration
  - python-design-patterns
  - python-resource-management
  - python-anti-patterns
  - python-type-safety
  - python-code-style
  - python-background-jobs
---

<!--
  Role: code reviewer for /python-code-review.
  Called by: plugins/python-dev/commands/python-code-review.md via Agent dispatch.

  Model: sonnet — 11 domain passes each require reasoning about idiomatic patterns.
  Haiku misses nuance on design-pattern / anti-pattern detection. Opus is overkill
  for pattern-matching against skill-documented rules.
  Output contract: per-domain findings table + overall priority summary.
-->

<role>
You are the Python code reviewer. You apply the 11 python-dev domain skills to a Python codebase and return a prioritized findings report. Each domain pass is a focused check against that skill's documented patterns.
</role>

<task>
1. **Scope.** From the scope path provided: Glob for `**/*.py`. Exclude `__pycache__`, `.venv`, `venv`, `build`, `dist`, `.tox`.

2. **For each of the 11 domains, run a pass** against the scope:
   - Load the domain skill (via the `skills:` frontmatter field; these are declared reference material).
   - For each `.py` file, check for violations or missed opportunities per that skill's rules.
   - Record findings with `{file, line, domain, severity, rule, fix}`.

3. **Prioritize** across domains. Severity scale:
   - 🔴 **Critical** — anti-pattern (bare except, mutable default, circular import) or security-relevant resilience gap
   - 🟡 **Warning** — missed pattern that affects maintainability (missing type hints, no resource manager, inconsistent style)
   - 🟢 **Info** — style or minor idiom drift

4. **Emit** the per-domain findings tables + overall summary. </task>

<guardrails>
- **Read-only.** No edits — the command handles optional fix dispatch.
- **Per-domain scope.** A "missing type hints" finding belongs under python-type-safety, not python-anti-patterns. Respect domain boundaries.
- **Evidence discipline.** Each finding cites a file:line. No "this file feels un-pythonic" prose findings.
- **Parallel reads.** When the scope has > 10 files, batch reads. Each domain pass then operates on the loaded content.
</guardrails>

<output_format>

```markdown
## Python Code Review: <scope>

**Files scanned:** N **Findings:** X critical, Y warnings, Z info

### Critical (🔴)

| #   | File:Line | Domain | Rule | Fix |
| --- | --------- | ------ | ---- | --- |

### Warnings (🟡)

...

### Info (🟢)

...

### Per-Domain Summary

| Domain        | Critical | Warning | Info |
| ------------- | -------- | ------- | ---- |
| anti-patterns | 2        | 1       | 0    |
| type-safety   | 0        | 8       | 3    |

| ...

**Top 3 recommended actions:** <list>
```
````

</output_format>

````

### Task 6.3: Create `/python-code-review` command

**File to create:** `plugins/python-dev/commands/python-code-review.md`

- [ ] **Step 1: Write the command**

```markdown
---
description: Comprehensive Python code review via python-code-reviewer subagent (applies 11 python-dev domain skills)
argument-hint: [scope path, defaults to ./]
---

# python-code-review

Run a comprehensive Python code review against the 11 python-dev domain skills by dispatching the `python-code-reviewer` subagent.

## What it does

The subagent runs on Sonnet. It:
1. Enumerates `.py` files in the scope.
2. Runs 11 domain passes (testing, async, resilience, observability, configuration, design patterns, resource management, anti-patterns, type safety, code style, background jobs).
3. Returns a prioritized findings report with file:line citations and suggested fixes.

## How to invoke

Dispatch the agent with the scope path:

Use the `Agent` tool with `subagent_type: python-code-reviewer`. Pass the scope.

Do not read `.py` files or run domain checks in this session — the subagent owns all of that work.

## After the agent returns

Present the prioritized findings report. Offer the top 3 recommended actions via `AskUserQuestion`. For approved fixes, apply via Edit in this session.
````

### Task 6.4: Version + CHANGELOG + marketplace + README

- [ ] **Step 1: Bump `python-dev` from `1.0.1` to `1.1.0`** (minor — new command + new agent)

- [ ] **Step 2: CHANGELOG entry**

Prepend to `plugins/python-dev/CHANGELOG.md`:

```markdown
## [1.1.0] - 2026-04-23

### Added

- `/python-code-review` command — comprehensive review against the 11 python-dev domain skills. Dispatches the new `python-code-reviewer` subagent (Sonnet) which applies all 11 domain passes and returns a prioritized findings report with file:line citations. Estimated ~20K tokens saved per review vs. inline application of all 11 skills.
- `plugins/python-dev/agents/python-code-reviewer.md` — Sonnet orchestrator for the 11 domain passes.
```

- [ ] **Step 3: Sync marketplace.json + update README** — add both a Commands row for `/python-code-review` and an Agents row for `python-code-reviewer`.

### Gate 6: Phase 6 verification

Same pattern: validator, frontmatter parse, commit with message:

```
Phase 6: add /python-code-review command + python-code-reviewer agent (Sonnet)

New command that applies the 11 python-dev domain skills via a dedicated Sonnet
subagent. Previously, comprehensive Python review required the user to manually
invoke each skill and synthesize findings across them — ~20K tokens of Opus
context per run. The subagent consolidates all 11 passes into a single dispatched
call.

Sonnet chosen because 11-domain pattern-matching needs reasoning about idiomatic
patterns; Haiku misses nuance on design-pattern / anti-pattern detection.

python-dev: 1.0.1 → 1.1.0.
```

**User-facing prompt at this gate:** "Phase 6 committed. Proceed to the consolidated release pass?"

---

## Phase 7: Release Pass

**Scope:** Push `testing` to remote, merge to `main`, tag each affected plugin, push tags, create GitHub releases.

### Task 7.1: Push testing

- [ ] **Step 1:** `git push origin testing`

### Task 7.2: Merge to main with a deploy commit

- [ ] **Step 1:**

```bash
git checkout main && git pull --ff-only origin main && git merge testing --no-ff -m "Deploy: plugin delegation migration (6 plugins)"
```

### Task 7.3: Tag each bumped plugin

- [ ] **Step 1:**

```bash
git tag -a home-assistant-dev/v2.2.7 -m "home-assistant-dev v2.2.7 — reviewer model downgrade to Haiku"
git tag -a qt-suite/v0.3.1 -m "qt-suite v0.3.1 — gui-tester and test-generator model explicit Sonnet"
git tag -a qdev/v1.3.0 -m "qdev v1.3.0 — deps-audit, quality-review, doc-sync dispatched to new subagents"
git tag -a repo-hygiene/v1.4.0 -m "repo-hygiene v1.4.0 — semantic audit moved to hygiene-semantic-auditor"
git tag -a nominal/v1.2.0 -m "nominal v1.2.0 — postflight verification moved to nominal-systems-verifier"
git tag -a test-driver/v0.7.0 -m "test-driver v0.7.0 — analyze gap-mapping moved to test-driver-gap-analyzer"
git tag -a python-dev/v1.1.0 -m "python-dev v1.1.0 — new /python-code-review command + agent"
```

### Task 7.4: Push main + all tags

- [ ] **Step 1:**

```bash
git push origin main
git push origin home-assistant-dev/v2.2.7 qt-suite/v0.3.1 qdev/v1.3.0 repo-hygiene/v1.4.0 nominal/v1.2.0 test-driver/v0.7.0 python-dev/v1.1.0
```

### Task 7.5: GitHub Releases

- [ ] **Step 1:** For each tag, create a GitHub Release with the CHANGELOG body extracted for that version. One-liner template (fill in per plugin):

```bash
gh release create <tag> --title "<plugin> <version>" --notes "$(awk '/^## \['<version>'\]/,/^## \[/{print}' plugins/<plugin>/CHANGELOG.md | head -n -1)"
```

### Task 7.6: Return to testing

- [ ] **Step 1:** `git checkout testing`

---

## Self-Review Summary

Applied in-plan:

1. **Spec coverage:** Every candidate in the original scan agent's report is mapped to a phase — model-tier (Phase 1), qdev (Phase 2), repo-hygiene (Phase 3), nominal (Phase 4), test-driver (Phase 5), python-dev (Phase 6). Cross-cutting "qdev is highest ROI" observation is honored by placing it second, after the low-risk warmup.
2. **Placeholder scan:** No "TBD" or "similar to task N" steps. Every code block is complete. Every file path is exact.
3. **Type consistency:** Agent names are consistent across the agent file, the command dispatch, and the CHANGELOG. Model values are the literal strings `haiku`, `sonnet`, not freeform prose.

**Known scope limits:**

- Phase 1 picks Sonnet (not Haiku) for qt-suite agents to be conservative — if empirical testing shows Haiku works, a future phase can downgrade further.
- Phase 6 assumes `/python-code-review` does not exist. Task 6.1 verifies and adjusts.
- Smoke tests in each gate are optional; a full integration test plan is out of scope for this migration (the gate verifications are mechanical: validator pass + frontmatter parse + commit cleanness). User may dry-run each new command manually between gates if desired.
