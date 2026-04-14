---
name: quality-review
description: Research-first quality review with iterative gap/consistency check and fix loop until convergence. Detects spec, plan, or code mode automatically. Runs comprehensive web research first to establish ground truth, then iterates until zero findings remain.
argument-hint: "[optional: path to file or directory to review]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
  - AskUserQuestion
  - WebFetch
  - mcp__brave-search__brave_web_search
  - mcp__serper-search__google_search
---

# /qdev:quality-review

Research-first quality review with an iterative fix loop until convergence.

## Step 1: Artifact Detection

If `$ARGUMENTS` is provided, use it as the target path.

Otherwise, scan the working directory:

```bash
find . -maxdepth 3 \( -name "*.md" -o -name "*.py" -o -name "*.ts" -o -name "*.js" -o -name "*.go" -o -name "*.rs" -o -name "*.sh" -o -name "*.rb" -o -name "*.java" -o -name "*.cpp" \) -not -path "*/.git/*" -not -path "*/node_modules/*" | sort
```

Apply this priority order to identify mode:

1. `.md` file whose name contains `spec`, `design`, or `architecture` → **spec mode**
2. `.md` file whose name contains `plan`, `implementation`, or `roadmap` → **plan mode**
3. Source files (`.py`, `.ts`, `.js`, `.sh`, `.go`, `.rs`, `.rb`, `.java`, `.cpp`) → **code mode**

If multiple candidates match or the type is ambiguous, use `AskUserQuestion` to present the top candidates as bounded choices. Do not guess.

Announce the detected mode and target before proceeding:
```
Target: <path>
Mode:   <spec | plan | code>
```

## Step 2: Research Phase

Extract every dependency, library, API, framework, protocol, and external tool referenced in the target artifact. For source code, also extract version pins from any lock files, `requirements.txt`, `package.json`, `go.mod`, `pyproject.toml`, or equivalent present in the project.

If no dependencies or external technologies are identified (e.g., a pure prose spec with no tool references), skip the per-dependency search queries and proceed directly to Step 3 with an empty research context.

For each identified dependency or technology, query **both** `mcp__brave-search__brave_web_search` and `mcp__serper-search__google_search` with 10+ results each. If a dependency has no pinned version (e.g., listed without a version constraint), research the latest stable release as the version likely in use. Cover:

- **Current official docs**: latest API signatures, configuration options, behavioral changes, deprecations since the version in use
- **Known bugs and CVEs**: open issues, security advisories, version-specific defects relevant to this codebase
- **Community best practices**: patterns the ecosystem currently recommends or has deprecated
- **Common pitfalls**: known footguns, gotchas, version compatibility issues

Compile a **research context**: a structured list of findings grouped by dependency that will inform all analysis in Step 3.

After compiling, scan the research context for critical findings:
- Known CVE in a dependency version currently in use
- Breaking change in a dependency that makes the current implementation incorrect
- Severe deprecation with no migration path documented

If any critical findings exist, surface them immediately before entering the loop:

```
⚠ Critical finding(s) from research:
  • [VULNERABLE] <dependency>: <CVE or issue summary>
  • [BREAKING] <dependency>: <breaking change description>
```

Then use `AskUserQuestion`:
- question: `"Critical issues found. How would you like to proceed?"`
- options:
  1. label: `"Proceed with review"`, description: `"Continue into the analysis loop with these issues noted"`
  2. label: `"Stop and fix these first"`, description: `"End the review here so you can address the critical issues"`

If `"Stop and fix these first"` is chosen, list the critical findings and stop.

## Step 3: Iterative Analysis + Fix Loop

Initialize a pass counter at 1. Maintain a deferred-findings list (starts empty).

Begin each pass with: `--- Pass N ---`

### 3a. Static Analysis

Read the target artifact(s) in full. Analyze against the research context from Step 2.

**Spec mode checks:**
- **Completeness**: every feature or behavior mentioned anywhere in the spec has its own section with sufficient detail to implement
- **Internal consistency**: no two sections describe the same behavior differently
- **Unambiguous requirements**: flag every "should", "might", "could", "may" (these are weak requirements that cause implementation drift); replace with "must" or remove
- **Scope gaps**: behaviors implied by the spec but not explicitly specified (e.g., error states mentioned but not described, edge cases acknowledged but not handled)
- **Term consistency**: defined terms used consistently throughout (no synonyms for the same concept)

**Plan mode checks:**
- **Spec coverage**: every requirement in the referenced spec has at least one plan step that implements it
- **Sequencing**: no step depends on an output that a later step produces; no circular dependencies
- **Missing dependencies**: a step uses a function, file, type, or schema that is defined in a step not listed as a prerequisite
- **Estimability**: each step describes a concrete action; "implement X" without showing how is a gap

**Code mode checks:**
- **Anti-patterns**: patterns the research context flags as deprecated or problematic for this language/framework
- **Naming consistency**: function, variable, and type names follow a consistent convention across all files in scope
- **Dead code**: functions, imports, or variables defined but never referenced
- **Cross-file inconsistencies**: the same concept handled differently in different files without a documented reason
- **Error handling at system boundaries**: external calls, file I/O, and user input without error handling
- **Structural issues**: functions or modules with more than one clear responsibility

Also evaluate deferred findings from prior passes to determine if any are now addressable.

### 3b. Targeted Follow-up Research

Before proposing a fix for any finding that involves an external dependency, API call, or ecosystem pattern not already covered by the Step 2 research context, run targeted searches using both `mcp__brave-search__brave_web_search` and `mcp__serper-search__google_search` to verify the proposed resolution against current official documentation and community standards.

Do not propose fixes based on training knowledge alone when a live source can be consulted.

### 3c. Finding Classification

Classify each finding using a single test:

> **"Could a competent developer apply this fix confidently, without asking the author, and be correct every time?"**

**Auto-fixable** (apply silently, count in pass summary) — the fix satisfies ALL of the following:
1. Exactly one correct fix exists — no design decision is required to choose it
2. Does not change the intent of a requirement, step, or algorithm
3. Does not involve an external dependency action (upgrade, patch, removal)
4. Does not remove non-trivial logic or functionality

This covers: formatting, punctuation, structural whitespace; broken internal cross-references; weak requirement words ("should", "might", "could", "may") → "must" when the intended behavior is unambiguous from context; term inconsistency where the defined term is established elsewhere in the artifact; naming convention violations where the established convention is unambiguous from surrounding code; dead imports or variables that have no effect on behavior; GAP findings where the correct behavior is fully derivable from other parts of the artifact; missing error handling where an identical handling pattern already exists in the same file and can be directly applied.

**Needs-approval** (non-obvious — surface to user one at a time) — the fix fails any of the above criteria. Specifically:
- Resolving an ambiguity where multiple valid interpretations exist
- Any change that alters the intent or semantics of a requirement or step
- GAP findings where the correct behavior cannot be inferred from existing content
- All research-originated findings: `[OUTDATED]`, `[VULNERABLE]`, `[BEST-PRACTICE]`, `[DOCS-MISMATCH]`
- Removing non-trivial logic or functionality (not just dead imports/variables)
- Dependency actions (upgrade, patch, replace, remove)
- Structural changes to functions or modules requiring architectural judgment

### 3d. Apply Auto-fixes

Apply each auto-fixable finding using the `Edit` tool. Do not announce individual fixes. Accumulate the count for the pass summary.

### 3e. Surface Needs-Approval Findings

For each needs-approval finding, use `AskUserQuestion`:

- header: `"Finding [N]"`
- question: `"[OUTDATED | VULNERABLE | BEST-PRACTICE | DOCS-MISMATCH | STRUCTURAL | GAP | AMBIGUOUS]\n\nIssue: <what the problem is and why it matters>\nSource: <research URL or analysis basis>\nProposed fix: <specific change>"`
- options:
  1. label: `"Apply fix"`, description: `"Implement the proposed change"`
  2. label: `"Apply with modifications"`, description: `"Apply, but I'll describe what to change"`
  3. label: `"Defer"`, description: `"Skip for now, reconsider on the next pass"`
  4. label: `"Skip permanently"`, description: `"Do not raise this finding again"`

For `"Apply with modifications"`: ask a follow-up open-ended question for the modification, then apply the modified version and close the finding. If the user's modification changes the scope significantly enough that it introduces a new design decision, surface that as a separate finding on the next pass rather than resolving it inline.

### 3f. Pass Summary

After all findings in the pass are resolved, emit:

```
Pass N complete: N found / N auto-fixed / N approved / N deferred / N skipped-permanently
```

### 3g. Convergence Check

If this pass produced **zero new findings** (deferred items and permanently-skipped finding types are excluded from this count): proceed to the Convergence Declaration.

When re-running 3a on subsequent passes, do not re-raise findings whose type and location match a previously "Skip permanently" decision.

Otherwise, begin Pass N+1. Deferred items from prior passes are re-evaluated in 3a of every subsequent pass. They are never silently dropped.

## Convergence Declaration

```
✓ Quality review complete. N passes, N total fixes applied.
Deferred: N items
```

If deferred items exist, list them:

```
Deferred items (not fixed):
  • [Type] <description>
```
