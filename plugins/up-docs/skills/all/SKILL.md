---
name: all
description: 'Update all three documentation layers (repo, wiki, Notion) via parallel sub-agent propagation, then run drift audit. This skill should be used when the user runs /up-docs:all.'
allowed-tools: Read, Bash, Agent, AskUserQuestion
---

# /up-docs:all

Orchestrates up-docs: gather session context, build a canonical session-change summary, dispatch three propagator sub-agents in parallel (all on Sonnet), then run the drift auditor (Sonnet), and collate all output into a single combined report.

## Architecture

```text
This skill (orchestrator, inherits caller model)
  │
  ├─ run context-gather.sh once
  ├─ assemble canonical session-change summary
  │
  ├─▶ up-docs-propagate-repo     (Sonnet, parallel)
  ├─▶ up-docs-propagate-wiki     (Sonnet, parallel)
  ├─▶ up-docs-propagate-notion   (Sonnet, parallel)
  │
  ├─▶ up-docs-audit-drift        (Sonnet, after propagators complete)
  │
  └─ collate reports → emit combined summary
```

## Workflow

### 0. Pre-flight: Dirty-tree guard

Before doing anything else, check for uncommitted changes (staged, unstaged, or untracked — `--porcelain` reports all three, and the STOP applies to all three):

```bash
git status --porcelain
```

If the output is **non-empty**, STOP immediately:

- Emit the list of dirty files to the user.
- Refuse with: _"Uncommitted changes detected — stash or commit them before running `/up-docs:all` to prevent data loss."_
- Do NOT dispatch any sub-agents. Do NOT read session context. Do NOT proceed to Step 1.

If the output is empty, continue.

**Capture commit baselines** (for the Step 6 commit offer): BEFORE any propagation, snapshot each committable repo's dirty set into a freshly **`mktemp`'d** file (NOT a fixed path — concurrent runs would collide, CR-004) and remember the generated paths: `BASELINE_REPO=$(mktemp); bash ${CLAUDE_PLUGIN_ROOT}/scripts/commit-candidates.sh snapshot . > "$BASELINE_REPO"` and the wiki baseline **unconditionally** (layer scope isn't known until the Step 2 routing matrix runs, and one SSH snapshot is cheap; the wiki repo is REMOTE on CT 103): `BASELINE_WIKI=$(mktemp); ssh llm-wiki 'bash -s' snapshot /srv/workspaces/llm-wiki < ${CLAUDE_PLUGIN_ROOT}/scripts/commit-candidates.sh > "$BASELINE_WIKI"`. If the wiki snapshot fails (host unreachable), note it and continue — the Step 6 guard refuses wiki commits without a baseline, and the wiki propagator's own pre-flight handles the unreachable host. Thread `$BASELINE_REPO` / `$BASELINE_WIKI` to Step 6 — do not hardcode baseline filenames there.

### 1. Gather Session Context (once)

First, verify Python 3 is available — all helper scripts depend on it:

```bash
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 not found in PATH — install python3 and retry."; exit 1; }
bash ${CLAUDE_PLUGIN_ROOT}/scripts/context-gather.sh
```

Combine with conversation history.

### 2. Build the Canonical Session-Change Summary

Read the template at `${CLAUDE_PLUGIN_ROOT}/templates/session-change-summary.md` and produce a concrete summary following that format. This artifact is the **single critical input** to every sub-agent — garbage in, garbage out. Spend main-agent tokens to produce it well.

Field rules (from the template):

- One numbered item per semantically independent change.
- Name exact keys/values/paths — not "updated config" but "`BAO_ADDR=127.0.0.1` → `100.90.121.89` in `/usr/local/bin/backup-dumps.sh`".
- Every item includes {Change, Reason, Affected area, Files touched, Verifiable against}.

**Routing matrix (tag each numbered item with target layer(s)).** Kept in sync with the agents' layer-boundary sections (`agents/up-docs-propagate-{repo,wiki,notion}.md`). Tag, do not drop:

| Item characteristic | Routes to |
| --- | --- |
| Project-repo artifact: README/docs/CLAUDE.md/AGENTS.md, handoff files, CLI flags, repo build/test config | `repo` |
| Credential **reference** added/rotated/removed (env-var name, OpenBao path — _not_ the secret value) | `repo` (handoff/credentials.md) + `wiki` if a page cites it |
| Implementation reference: config values, env-var names, file paths, service procedures, troubleshooting, command usage, auth/networking wiring (incl. homelab implementation) | `wiki` |
| Strategic/organizational: new service in the stack, architecture decision, ownership/roadmap, personnel | `notion` |
| **Secret VALUE or live inventory RECORD only** (a secret's actual value in OpenBao; a device/IP/VLAN row in NetBox; an actual DNS/firewall entry) — owned by its system-of-record | none — no propagator |
| **Ambiguous / spans concerns** | **all candidate layers (fail-open)** |

**CR-002 — do not over-route to "none".** Only the _value/record itself_ is system-of-record-owned. A change _about_ such a thing (an OpenBao **listener rebind**, a **config path**, a **credential reference**, the **strategic fact** that a service was added) still routes to repo/wiki/notion. Worked cases live in `${CLAUDE_PLUGIN_ROOT}/tests/fixtures/routing-cases.md`; consult them when classifying. An item may route to multiple layers; a layer is "routed-to" if ≥1 item carries its tag.

### 3. Dispatch Propagators in Parallel

Dispatch **only the propagators with ≥1 routed item** (from the Step 2 routing matrix), still in a single message with one Agent call each so they run concurrently. For every layer with zero routed items, do NOT dispatch its propagator; instead record a combined-report line `<Layer> — skipped (0 items routed to this layer)`.

**Two exceptions to the zero-item skip:**

- **The repo propagator is ALWAYS dispatched, even with zero routed items.** Its mandatory live-state audit (`docs/handoff/state.md`, `docs/handoff/conventions.md`, the monthly session-log append) and stale-file scan run on every invocation regardless of session scope — skipping it would break the session-end handoff guarantee. With zero routed items, pass it an explicitly empty summary ("no repo-routed items this session — run the mandatory audit and stale scan only"). The skip rule applies only to **wiki** and **notion**.
- The auditor — Step 4 still **audits all three layers** regardless of which propagators ran.

Invoke each propagator being dispatched (from the ≥1-routed-item set above) **in a single message, one Agent call each,** so they run concurrently (the tool was called `Task` before Claude Code v2.1.63 and still accepts that name as an alias). Each receives the session-change summary as the stable front of its prompt; layer-specific detail goes at the end (cache-friendly structure).

| Sub-agent — pass as `subagent_type` | Purpose |
| --- | --- |
| `up-docs:up-docs-propagate-repo` | Updates README.md, docs/, CLAUDE.md |
| `up-docs:up-docs-propagate-wiki` | Updates llm-wiki wiki/ pages at implementation-reference level |
| `up-docs:up-docs-propagate-notion` | Updates Notion at strategic/organizational level |

The `up-docs:` prefix is mandatory — plugin-defined agents are only addressable through their plugin namespace. Calling `Agent` with the bare name (e.g. `"up-docs-propagate-repo"`) returns "Agent type not found".

Each sub-agent returns a single-layer markdown table per `templates/summary-report.md`.

#### Failure handling

If a propagator returns a FAILED row or errors out entirely, record the failure in the combined report as a clear "layer not updated due to `<reason>`" row for that layer. Do not retry across sub-agents and do not abort the other layers — propagation is independent by design.

### 4. Dispatch Drift Auditor (sequentially, after propagators)

Once all dispatched propagators return, invoke the auditor via the Agent tool with `subagent_type: "up-docs:up-docs-audit-drift"`. Pass it the same session-change summary plus the dispatched propagators' reports and the skip lines for any layer not dispatched (so the auditor knows what was already fixed and does not re-report those items).

The auditor returns **both** a JSON findings block and a markdown findings table. It is read-only: it does not fix.

If the auditor emits an `⚠ ESCALATION RECOMMENDED` block, include it in the combined report verbatim.

### 5. Collate and Emit Combined Report

Read `${CLAUDE_PLUGIN_ROOT}/templates/summary-report.md` for the `/up-docs:all` format.

Produce one combined report: a heading per layer, each with its own table and totals line, followed by the drift findings table and (if present) the escalation block. For any layer skipped in Step 3, emit its "`<Layer>` — skipped (0 items routed to this layer)" line in place of that layer's table; it is presentation-only and carries no action-row totals.

Do not re-fetch pages or files. Do not make your own edits. Your job after dispatching is pure collation.

### 6. Post-Propagation Steps (stale-candidate review + handoff brief)

Read `${CLAUDE_PLUGIN_ROOT}/templates/post-propagation-steps.md` and follow all three procedures after the combined report (Step 5):

- **Stale File Candidate Review** — if the repo propagator's report has a `## Stale File Candidates` section, present it via `AskUserQuestion` (`multiSelect`) and `git rm` only user-approved paths. Skip silently if none.
- **Handoff for Next Session** — emit a per-layer update confirmation, then the layout-detected (V2/V1/NONE) handoff brief.
- **Commit offer (part (c))** — after the handoff brief, run the template's consent-gated, baseline-safe, no-push commit offer, passing the pre-flight baselines you captured: `$BASELINE_REPO` for the project repo and `$BASELINE_WIKI` for the remote wiki repo (CT 103, `/srv/workspaces/llm-wiki`) (when the wiki layer ran).

The brief is READ-only over already-updated state files; do not re-edit.

## Layer Boundaries (reference)

| Layer | Content Level | Example |
| --- | --- | --- |
| Repo | Project-specific | "Added `--verbose` flag to the CLI" |
| Wiki | Implementation reference | "Authentik OIDC client config for the new service" |
| Notion | Strategic/organizational | "New monitoring service added to the homelab stack" |

Each sub-agent enforces its own layer boundary via the guidelines inlined in its system prompt. You don't need to re-enforce here — just trust the sub-agent reports and collate.

## When to Offer Opus Escalation

The drift auditor will flag escalation when any of these hold:

- Findings count > 10
- Any affected doc is > 1000 lines
- Cross-layer contradictions detected
- A fix would require destructive action

When an escalation block appears in the auditor output, include it in the combined report **but do not auto-invoke anything**. The user decides whether to re-run with Opus.
