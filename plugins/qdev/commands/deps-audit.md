---
name: deps-audit
description: Dependency security and freshness audit via qdev-deps-auditor subagent (Haiku).
argument-hint: "[optional: directory to scope the audit]"
allowed-tools:
  - Agent
  - AskUserQuestion
---

# /qdev:deps-audit

Audit this project's dependencies for CVEs, abandonment, and version lag by dispatching the `qdev-deps-auditor` subagent.

## Why this is a subagent

Manifest parsing + per-dep dual-source web research (brave + serper, with tavily-extract for advisory page reads) for 30-50 dependencies is high-volume mechanical work. Running it in the main Opus context burns ~18K tokens per audit on search results alone. The Haiku subagent keeps all that traffic out of the Opus context and returns a compact findings table.

## How to run it

Dispatch `qdev-deps-auditor` with the scope path (default: current working directory). Pass `$ARGUMENTS` as the scope if the user provided one.

Use the `Agent` tool with `subagent_type: qdev-deps-auditor` and a prompt like:

> Audit the dependencies in `<scope path>`. Return the prioritized findings table per your output format. Do not modify any manifest or lockfile.

Do **not** run `find`, read manifests, or call search tools in this session. The whole point of the delegation is to keep raw manifests and 200+ search results out of the Opus context.

## After the agent returns

1. Present the findings table verbatim to the user.

2. If the agent returned the "no manifests found" block, stop — nothing further to do.

3. If there are any Critical or High findings, use `AskUserQuestion`:
   - header: `"Upgrade commands"`
   - question: `"Critical and High findings detected. Generate exact upgrade commands?"`
   - options:
     1. label: `"Yes, generate them"`, description: `"Print install commands for each affected package"`
     2. label: `"No thanks"`, description: `"The report is enough"`

   If chosen: emit the appropriate package-manager command for each Critical and High finding (e.g. `npm install package@X.Y.Z`, `pip install "package==X.Y.Z"`, `go get package@vX.Y.Z`, `cargo update -p package --precise X.Y.Z`). Note any where the safe upgrade version could not be confirmed.

4. If no Critical or High findings exist, emit:
   ```
   ✓ No critical or high-severity findings. N dependencies reviewed.
   ```
   then stop. Do not prompt for upgrade commands.
