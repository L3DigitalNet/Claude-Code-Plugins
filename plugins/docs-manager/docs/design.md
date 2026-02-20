# docs-manager — Design Document

Version: 0.1 (Draft)
Status: Design Review Complete — IMPLEMENTATION READY
Last Updated: 2026-02-19
Authors: TBD
Reviewers: TBD

---

## Table of Contents

1. [Overview & Problem Statement](#1-overview--problem-statement)
2. [Goals & Non-Goals](#2-goals--non-goals)
3. [Design Principles](#3-design-principles)
4. [Plugin Architecture](#4-plugin-architecture)
5. [Core Workflows](#5-core-workflows)
6. [Library & Index Data Model](#6-library--index-data-model)
7. [Hook Design](#7-hook-design)
8. [Template System](#8-template-system)
9. [Queue Architecture](#9-queue-architecture)
10. [Upstream Verification System](#10-upstream-verification-system)
11. [Onboarding Command & Intake Workflow](#11-onboarding-command--intake-workflow)
12. [Testing Strategy](#12-testing-strategy)
13. [Multi-machine Access Model](#13-multi-machine-access-model)
14. [Open Questions & Decisions Log](#14-open-questions--decisions-log)
15. [Appendix](#15-appendix)

---

## 1. Overview & Problem Statement

docs-manager is a Claude Code plugin that manages the full documentation lifecycle for solo maintainers and homelab enthusiasts working across multiple domains. It addresses two intertwined problems:

**The fragmentation problem**: Developers, sysadmins, and hobbyists each need different documentation formats and structures, but existing solutions are domain-specific. A developer uses README.md and GitHub; a sysadmin uses runbooks and config backups; a homelab enthusiast uses a mix of both and more. Switching contexts means learning and maintaining multiple systems, creating cognitive overhead and fragmentation.

**The drift and forgetting problem**: Even when a structured documentation system is established, solo maintainers cannot reliably remember what they have documented, where it is, or whether it is still accurate. Documentation gets created and forgotten, and the structured folder approach that seemed well-organized six months ago is full of orphaned files that no longer reflect the current state of the systems they describe. This is confirmed in the author's own environment: 758+ Markdown files across projects, with near-identical content duplicated in separate subtrees, per-source `*_doc.md` files coexisting with `docs/` folders in the same project, and a dedicated `documentation/` repository that has itself begun fragmenting.

docs-manager solves this by providing a single, flexible plugin that:
- Maintains a discoverable index of all documentation across all domains and machines
- Proactively detects when documentation needs attention without interrupting active work
- Applies domain-appropriate structure automatically, based on context and user-established patterns
- Ensures documentation is current before work sessions close
- Verifies third-party documentation against authoritative upstream sources

---

## 2. Goals & Non-Goals

### Goals

- Provide a single unified documentation management tool across all domains (development, sysadmin, personal/homelab)
- Maintain a persistent, discoverable library index accessible across machines
- Proactively detect and queue documentation debt without interrupting active workflows
- Ensure documentation accurately reflects the current state of its subject at session close
- Apply domain-appropriate templates inferred from context and user-established patterns
- Verify third-party documentation against upstream authoritative sources
- Support the full documentation lifecycle: create, onboard, organize, update, deduplicate, compress, verify, archive

### Non-Goals

- **Not a documentation hosting platform** — GitHub serves this role; docs-manager manages the lifecycle, not the publishing
- **Not a documentation generator from source code** — docs-manager helps keep existing docs in sync with code changes, but does not auto-generate docs from code comments or type signatures
- **Not a wiki or CMS** — all documentation remains plain Markdown files in version-controlled repositories
- **Not an offline-first tool** — GitHub access is assumed; headless-server-without-network is an accepted limitation
- **Not designed for multi-user teams** — the primary user model is a solo maintainer; team use is incidental, not an optimization target
- **Not a replacement for mkdocs or rendering tools** — docs-manager manages source Markdown; rendering is a separate concern

---

## 3. Design Principles

### Preamble

These seven principles were selected specifically for this project's constraints and failure modes — not as generic documentation best practices. They reflect three realities surfaced during design:

**Why these principles**: The primary constraint is a solo maintainer with a documented memory bottleneck. Prior attempts at structured documentation — including a dedicated `documentation/` repository with organized categories — failed not because the structure was wrong, but because the system depended on the maintainer remembering to use it. Correctness was identified as non-negotiable because incorrect sysadmin documentation followed during a disaster recovery event causes active harm, not just inconvenience.

**What these principles collectively de-prioritize**: docs-manager explicitly trades user experience for correctness, and simplicity for intelligence. The tool carries the cognitive burden rather than the user — generating drafts autonomously, inferring templates from context, accumulating detection results silently. Offline access was also explicitly de-prioritized in favour of cross-machine availability via GitHub.

**Resolved tension — P4 vs P5**: Templates inferred by P4 might produce structured data without prose framing in survival-context documents. P5 takes precedence: Claude attempts to generate prose before accepting structured-only content, and surfaces missing prose as a deficiency in the queue. Hard blocking is not used; the standard is recorded and worked toward.

---

### P1 — Domain Libraries, Not a Global Web

**Statement**:
Documentation is organized into domain libraries (project, sysadmin, personal, etc.). Each library maintains internal cross-references where meaningful, and every document must belong to at least one library — but libraries are not obligated to cross-link, and isolated notes within a library are acceptable when no meaningful connection exists.

**Intent**:
Prevents documentation from becoming a collection of undiscoverable orphan files scattered across projects. Forces at minimum a declaration of library membership, enabling discovery at the library level even when individual docs are not cross-linked. Prevents the specific failure mode of creating a document, losing it in a folder, and never finding it again — confirmed as a real problem across 758+ existing Markdown files.

**Enforcement Heuristic**:
A document saved without library membership registration. A doc that references another document by concept without a link. An index that lists a library but cannot enumerate its contents. A document with no `library` frontmatter field.

**Cost of Following This Principle**:
Every document creation requires declaring which library it belongs to — even niche notes that feel standalone. The tool gives up frictionless "save anywhere" in exchange for the discovery guarantee.

**Tiebreaker**: None.

**Risk Areas**:
Initial onboarding of existing 758+ docs — temptation to skip library assignment to reduce import cost. New ad-hoc notes created in contexts where library context is unclear.

---

### P2 — Detection is Automatic; Resolution is Deferred and Batched

**Statement**:
The tool monitors workflows via hooks and accumulates documentation tasks into a queue rather than interrupting active work. At logical transition points (task completion, session end, explicit request), the queue is surfaced for batch review. Detection is automatic; resolution is deferred and batched.

**Intent**:
Prevents two failure modes simultaneously: the tool that gets forgotten because it requires manual invocation (identified as the #1 failure mode for this user's documentation systems), and the tool that gets disabled because it interrupts too aggressively. The queue model is the mechanism that makes all other principles survive contact with a solo maintainer who cannot rely on their own memory.

**Enforcement Heuristic**:
A hook that fires a blocking prompt mid-session rather than appending silently to the queue. A queue with no persistence — if the session ends without review, items are lost rather than carried forward.

**Cost of Following This Principle**:
Documentation debt accumulates visibly and cannot be silently discarded — the queue must be reviewed at transition points. The user gives up the ability to "finish a session and forget about docs" in exchange for the guarantee that nothing falls through unnoticed.

**Tiebreaker**: None.

**Risk Areas**:
Queue growth on heavy sessions. Hook scope too broad — fires on every file write including non-documentation-relevant changes, creating noise that erodes trust in the detection system. [→ P7 for the area where more human collaboration in the queue is expected]

---

### P3 — Staleness is Surfaced at the Point of Use and at Session Close

**Statement**:
Staleness is surfaced at the point of use and at session close, not proactively across all docs. When a document is accessed or a project becomes active, its freshness is checked and concerning issues are queued. When work on a project concludes, the queue must be cleared — documentation should accurately reflect the project state before the session ends. Dormant docs are not alarmed; active docs are not allowed to go silently out of date.

**Intent**:
Prevents the specific harm of incorrect sysadmin documentation being followed in a crisis without anyone knowing it is stale. Avoids the opposite failure — flagging all 758+ docs simultaneously and creating a paralysing backlog. Establishes that finishing a project session means both the code and the documentation are in good order.

**Enforcement Heuristic**:
A document accessed in the current session without a freshness check. A project session closed with documentation debt still in the queue. An active document that has not been verified since its associated source files changed.

**Cost of Following This Principle**:
A project session cannot be considered finished while documentation debt remains unreviewed. Quick fixes that touch code without updating docs create an obligation at session end, not optional cleanup for later.

**Tiebreaker**: None.

**Risk Areas**:
Session-end queue size on heavy coding days. The project-entry trigger firing too broadly across many projects simultaneously, producing an overwhelming scan.

---

### P4 — Templates are Inferred, Not Imposed

**Statement**:
Templates are inferred from context, industry standards, and user-established patterns — not chosen from a fixed menu. The tool recognizes what kind of document is being created and applies the most appropriate structure, including user-defined templates. Users can register their own preferred templates for the tool to recognize and reuse.

**Intent**:
Prevents the tool from becoming a documentation bureaucracy where every document requires navigating a template taxonomy before content can be created. Equally prevents the "universal schema" failure where sysadmin config documents and personal hobby notes are forced into the same structure. Specifically protects user-evolved formats — such as the per-service runbook pattern developed for homelab servers — as first-class citizens of the template system.

**Enforcement Heuristic**:
A user prompted to select from a menu of template types rather than having the appropriate one inferred. A sysadmin service doc missing Dependencies / Restore Procedure / Verification sections that established patterns provide as standard. A personal note forced to populate server-specific metadata fields.

**Cost of Following This Principle**:
The tool carries the intelligence burden of template inference. If it gets the template wrong, the user has more editing to do than starting from scratch. The tool cannot offload this decision to the user by presenting a selection menu.

**Tiebreaker**: When P4 produces a survival-context document with structured data but missing prose sections, P5 takes precedence — Claude attempts prose generation; missing sections are queued as deficiencies, not silently accepted. No hard blocking. [→ P5]

**Risk Areas**:
Cross-domain documents (e.g., a Home Assistant integration that is simultaneously a sysadmin and developer concern). First-time document types with no registered template and no obvious industry standard.

---

### P5 — Human-First in Survival Contexts

**Statement**:
For any document a human may ever need to follow without AI assistance, human readability is non-negotiable — structured data is always accompanied by explanatory prose. For artifacts designed exclusively for AI consumption (prompts, voice context, agent instructions), this constraint does not apply and token efficiency takes precedence. The test: "Could a competent person follow this document in a crisis with no AI available?"

**Intent**:
Prevents sysadmin documents from becoming dense configuration dumps that are parseable by AI but opaque to a human under pressure. Protects against the disaster-recovery failure mode where a correct but unreadable document is as useless as no document. Explicitly carves out AI-only artifacts — such as Home Assistant voice assistant context prompts — where token efficiency is the real requirement.

**Enforcement Heuristic**:
A sysadmin or operational document with configuration tables but no prose "Purpose" or "Architecture" sections. A document that answers "what are the values" but not "what is this and why does it matter." A Restore Procedure section consisting solely of shell commands with no explanatory framing between steps.

**Cost of Following This Principle**:
Every survival-context document requires prose sections that take time to generate and verify. The tool gives up the efficiency of configuration-dump documentation in exchange for documents that remain usable when AI assistance is unavailable.

**Tiebreaker**: When P4's template inference produces a survival-context document with structured data but missing prose, P5 wins. Claude attempts prose generation; missing sections are queued as deficiencies. No hard blocking. [→ P4]

**Risk Areas**:
Auto-generated documents where Claude infers structure from file state but cannot infer narrative intent. AI-only artifact classification — what counts as "exclusively for AI consumption" must be registered explicitly via `audience: ai` frontmatter, not inferred.

---

### P6 — Lighter Than the Problem

**Statement**:
Any workflow the tool imposes must demand less effort than the documentation problem it solves. If maintaining documentation with docs-manager costs more than the documentation is worth, it will be abandoned, and the problem returns.

**Intent**:
Prevents the tool from becoming the thing the user dreads opening — a documentation system that itself requires documentation overhead to maintain. Protects the homelab enthusiast audience: technically capable but unwilling to tolerate bureaucratic friction that exceeds the value of the output. High initial onboarding cost is the explicit exception: front-loaded investment for long-term maintenance ease is acceptable.

**Enforcement Heuristic**:
New document creation requiring more than three questions before a first draft is produced. Session-end queue review requiring the user to manually write or edit multiple document sections rather than approve a Claude-drafted summary. Any workflow that blocks active work to demand metadata completion.

**Cost of Following This Principle**:
The tool carries the intelligence burden — it must infer enough from context, session activity, and file state to produce autonomous document drafts requiring only go/no-go approval. "Lighter than the problem" is not a UX courtesy; it is a hard constraint that moves complexity from the user to the tool.

**Tiebreaker**: None. All prior tensions with P6 were resolved by the deferred queue model — P2, P3, and P7 all feed into the same queue structure without adding separate overhead.

**Risk Areas**:
Queue growth on heavy sessions — if the session-end summary itself is overwhelming, P6 is violated at the review stage, not the detection stage. Initial onboarding of 758+ existing documents — bulk import must front-load cost, not spread it across ongoing use.

---

### P7 — Anchor to Upstream Truth

**Statement**:
Documentation that describes third-party systems, tools, or applications must be periodically verified against its upstream authoritative source — internal consistency is not enough when the ground truth is maintained externally.

**Intent**:
Prevents the failure mode of following a well-maintained personal document for a third-party tool that was accurate when written but reflects a deprecated API, renamed configuration key, or removed feature. Protects specifically against documents that pass internal staleness checks (nothing in your system changed) but have drifted from upstream reality.

**Enforcement Heuristic**:
A third-party tool document with no registered `upstream-url` frontmatter field. A document that has passed internal freshness checks but has never been compared against its upstream source. A configuration key documented as valid that no longer exists in the current upstream release.

**Cost of Following This Principle**:
Third-party documents require registering an upstream source and accepting that Claude may periodically flag discrepancies for human review. Upstream verification is the most collaborative workflow in the system — Claude leads, but uncertain cases require human judgement that cannot be fully automated. This is the one area where ongoing collaboration is expected and accepted.

**Tiebreaker**: None. The P7 × P6 tension was resolved by the queue model — background upstream checks feed results into the same deferred queue as session-detected changes.

**Risk Areas**:
Third-party documents created without `upstream-url` registration — most likely during initial bulk onboarding of existing documents. Upstream sources that restructure their URLs or move content without preserving redirects, causing verification to fail silently.

---

## 4. Plugin Architecture

docs-manager is composed of five component types, each chosen for a specific role in the context cost and execution model. [→ P6]

### Components

**Commands** (`/docs <subcommand>`)
User-invocable slash commands for explicit, on-demand operations. Load into context only on invocation. The full command surface covers: `new`, `onboard`, `find`, `update`, `review`, `organize`, `library`, `index`, `status`, `audit`, `dedupe`, `consistency`, `streamline`, `compress`, `full-review`, `queue`, `template`, `verify`, `help`. Commands are the user's escape hatch — they force actions the automatic system would otherwise defer. [→ P2]

**Skills**
AI-invoked markdown files that load into context when Claude deems them relevant. Used for: surfacing the docs-manager workflow when a user is about to create a document in an unregistered location; reminding Claude to check the queue at session boundaries; providing doc-type classification guidance.

**Hooks** (PostToolUse, Stop)
Shell scripts that run externally in response to Claude Code tool events. Hook stdout is injected into context; scripts themselves never enter the context window. Hooks implement the detection layer of P2 — observing file writes and session events, appending to the queue silently. Detailed in §7.

**Scripts**
External shell scripts called by hooks or commands. Used for: queue management (append, read, clear), index operations (register doc, rebuild index, query), session-state management. Scripts run entirely outside the context window.

**Agents**
Sub-process agents with defined tool restrictions, used for multi-step operations that would otherwise consume significant context in the main session. Used for: bulk onboarding, full-review sweeps, upstream verification. Agent outputs are returned as summaries. [→ P6]

### State & Configuration Files

```
~/.docs-manager/
  config.yaml                       # Index type, location, machine identity
  queue.json                        # Session queue (persists across restarts)
  queue.json.bak                    # Auto-backup on queue corruption
  queue.fallback.json               # Fallback queue when queue.json is locked/unwriteable
  index.lock                        # Index write lock (PID + timestamp)
  hooks/
    post-tool-use.last-fired        # Timestamp of last PostToolUse hook execution
    stop.last-fired                 # Timestamp of last Stop hook execution
  cache/
    docs-index.snapshot.json        # Last known good full index snapshot (offline fallback)
    pending-writes.json             # Queued index writes during offline operation
```

```yaml
# ~/.docs-manager/config.yaml (example)
machine: raspi5          # Defaults to hostname if not set
index:
  type: git-markdown     # see §6.4 for all supported backends
  location: ~/projects/documentation/
```

The `index.type` and `index.location` fields form the **index configuration abstraction** — changing these values migrates the index backend without requiring changes to plugin logic. [→ OQ1]

### Installation & Bootstrap

docs-manager requires no manual post-install configuration. After installing the plugin via the standard Claude Code plugin mechanism, the first invocation of any `/docs` command checks for `~/.docs-manager/config.yaml`. If absent, the First-Run Setup Flow (§11.0) launches automatically before the requested command runs. No separate `/docs setup` invocation is needed — setup is triggered transparently on first use.

The only prerequisite is that the target index backend (e.g. a `documentation/` git repo) exists or can be created — the setup flow handles this interactively.

### Context Cost Model

| Component | Enters context? | When? |
|-----------|-----------------|-------|
| Command markdown | Yes | On `/docs <command>` invocation |
| Skills | Conditionally | When Claude deems relevant |
| Hooks | No | Run externally; only stdout returned |
| Scripts | No | Run externally; only stdout returned |
| Agent definitions | No (for parent) | Loaded by spawned agent |
| Queue summary | Yes | At session end / `/docs queue review` |

### Failure Modes & Graceful Degradation

The plugin operates silently in the background (P2). Silent failures must surface explicitly — the user cannot discover a broken detection system by observing missing behaviour.

| Failure | Detection | Behaviour | Recovery |
|---------|-----------|-----------|----------|
| `queue.json` missing | Hook script checks for file before appending | Re-created empty on next hook write; no items lost (nothing was queued yet) | Automatic |
| `queue.json` corrupted | Hook script validates JSON on read; command reads validate on load | Warning injected into context: "Queue file corrupted — backed up to `queue.json.bak`, starting fresh." | Automatic with backup |
| `documentation/` repo not cloned on current machine | Any index-dependent command checks for repo existence at startup | Fails fast with actionable message: "Index not found at `~/projects/documentation/`. Run `/docs index init` to clone and initialise." | `/docs index init` guided flow |
| Git merge conflict in `docs-index.json` | Detected on `git pull` or `git push` in hook/script | Falls back to human-readable `docs-index.md` mirror for read operations; blocks write operations with: "Index conflict detected — run `/docs index repair` to resolve." | `/docs index repair` command |
| Hook script execution failure | Hook exit code checked; non-zero exit logged | Warning injected into context: "Documentation hook failed — detection may be incomplete this session. Check `/docs hook status`." | `/docs hook status` diagnostic |
| **Index sync drift — local behind remote** | Detected at session start or on first index operation (git fetch + compare) | Warning injected: "Local index is N commits behind remote. Run `git pull` in `~/projects/documentation/` or use `/docs index sync`." Index is read-only until synced. | `/docs index sync` (wraps `git pull`) |
| **Index sync drift — remote behind local** | Detected when a write operation would push to a remote with unpushed local commits | Injects context: "Local index has N unpushed commits — pushing before writing." Push is confirmed with the user in interactive sessions; non-interactive sessions push automatically. If push fails (e.g. remote has diverged), surfaces as merge conflict case above. | User-confirmed push or conflict escalation |

**Index sync policy**: For the `git-markdown` backend, docs-manager checks index staleness at session start. If the local index is more than 24 hours old (configurable via `index.max-staleness-hours` in `config.yaml`), a sync warning is injected before the first index operation. Write operations always attempt a pull-before-push to minimise conflict likelihood. [→ P6, P2]

---

## 5. Core Workflows

### 5.1 Creating a New Document

1. User invokes `/docs new` or Claude determines a new document is needed contextually
2. Tool checks the library index for existing related documents and surfaces any relevant matches before drafting [→ P1]
3. Three high-signal questions are asked:
   - **State snapshot?** — Should this doc capture current system or code state?
   - **Process flow?** — Is there a procedure or action sequence to document?
   - **Dependencies?** — Should this doc enumerate what this system or feature depends on?
4. Tool infers the appropriate template from current directory, library context, document intent, and registered user templates [→ P4]
5. Claude drafts the document with appropriate structure; prose sections are generated for all survival-context documents [→ P5]
6. User reviews, confirms, or edits the draft
7. Document is saved with frontmatter populated (library, machine, doc-type, last-verified, template)
8. Document is registered in the library index [→ P1]
9. If the document describes a third-party tool, user is prompted for `upstream-url` [→ P7]

### 5.2 Session-End Queue Review

1. Stop hook fires; queue is non-empty
2. Claude reads queue plus current state of all associated code and config files [→ P6]
3. Claude autonomously drafts updates for each queue item (1–3 sentences per item describing the proposed change)
4. Claude presents items using a **multi-select checkbox UI** (Claude Code's native `multiSelect` interface — navigate with arrow keys, toggle with spacebar, confirm with enter). Each item shows: document name, change type, and the proposed 1–3 sentence update. User selects which items to approve. Unselected items proceed to step 4b.
4b. *(Secondary step — only shown if unselected items remain.)* Claude presents the unselected items in a second multi-select: "These N items were not approved. Select any to permanently dismiss — the rest will be deferred to the next session." For each item selected for dismissal, Claude infers a reason from session context (e.g. "temp edit — not a documentation change") and presents it for user confirmation before writing to the session history log.
5. Approved drafts are applied; dismissed items are written to the session history log with their reasons; deferred items are carried forward in queue.json.
6. Session is considered complete when the queue is cleared [→ P3]

### 5.3 Project-Entry Freshness Scan

1. When Claude detects entry into a new project directory, a freshness scan is triggered for that project's registered library [→ P3]
2. Scan checks: last-verified dates, source-file associations (have associated code files changed?), and upstream-url docs flagged for periodic re-verification [→ P7]
3. Concerning items are appended to the queue silently — no interruption [→ P2]
4. If the queue is non-empty after scanning, a brief context injection notifies Claude: "N documentation items queued for this project."

### 5.4 Finding Existing Documentation

1. User invokes `/docs find <query>` or Claude surfaces the skill contextually
2. Query runs against the library index, filtered to current machine scope [→ P1]
3. Results show: document title, library, path, last-verified date, one-line summary
4. Cross-references are included: "This document links to: [X, Y]" and "Linked from: [Z]"

### 5.5 Organizing a Document

1. User invokes `/docs organize <path>` for a document whose location, name, or structure is incorrect
2. Claude analyzes document content and infers: correct library, appropriate directory, standard filename, correct template structure [→ P4]
3. Proposed reorganization is presented: "Move to `~/projects/homelab/raspi5/unbound/README.md`, assign to `raspi5-homelab` library."
4. User confirms; tool moves/renames, updates frontmatter, updates index, and repairs any cross-references pointing to the old path

### 5.6 Upstream Verification

Detailed in §10. Triggered by `/docs verify`, periodic freshness scan, or queue review surfacing a P7-flagged item.

---

## 6. Library & Index Data Model

### 6.1 Library Definition

A **library** is a named collection of documents associated with a domain, project, or machine. Libraries do not need to cross-link. Every document belongs to exactly one primary library.

```yaml
# Library definition (stored in structured index)
name: raspi5-homelab
machine: raspi5
description: Configuration backups and documentation for Raspberry Pi 5 server
root-path: ~/projects/homelab/raspi5/
```

**Reserved system library — `meta`**: The `meta` library is reserved for plugin-managed internal documents (setup notes, configuration records, migration logs). It is filtered from user-facing library listings (`/docs library`) and `/docs find` results by default. It appears in `/docs status` output and `/docs index audit` but is never presented as a user library. Users cannot create documents in `meta` directly — only the plugin writes to it.

### 6.2 Document Frontmatter Schema

All documents managed by docs-manager carry YAML frontmatter. Existing documents receive frontmatter during onboarding.

**Required fields:**
```yaml
---
library: raspi5-homelab
machine: raspi5
doc-type: sysadmin          # sysadmin | dev | personal | ai-artifact | system
last-verified: 2026-02-18
status: active              # draft | active | archived | deprecated
---
```

**Recommended fields** (populated at creation or onboarding where applicable):
```yaml
upstream-url: https://caddyserver.com/docs/
source-files:
  - /etc/caddy/Caddyfile
version: "Caddy v2.7"
cross-refs:
  - ../README.md
  - ../pihole/README.md
template: homelab-service-runbook
```

**Optional fields** (low-cost additions that enable future capability):
```yaml
tags: [reverse-proxy, https, tls]
audience: human             # human | ai | both
criticality: critical       # critical | standard | reference
review-frequency: on-change # on-change | weekly | monthly | quarterly
created: 2025-08-15
updated: 2026-02-18
owner: chris
```

**Survival-Context Classification Rule** [→ P5]

A document is **survival-context** (human-readable prose required; P5 enforced) when ALL of the following are true:

1. `doc-type` is `sysadmin`, `dev`, or `personal` — not `ai-artifact` and not `system`
2. `audience` is `human` or `both` — not `ai`

**Tiebreaker**: `audience: ai` overrides `doc-type`. An explicit AI-only designation (e.g. an HA voice assistant context file with `doc-type: sysadmin`) is treated as non-survival-context — token efficiency takes precedence per P5's carved-out exception.

**`doc-type: system`** documents (plugin-internal records in the `meta` library) are excluded from survival-context classification entirely. They are never subject to P5 enforcement.

This rule is the canonical decision procedure used by: template inference (§8), hook scripts evaluating P5 compliance (§7), and document creation workflows (§5.1). All three components must implement this rule identically — they should call the same shared script rather than each encoding it independently.

### 6.3 Dual Index

The library index is maintained in two forms: [→ P6]

**Structured index** (`docs-index.json` in the `documentation/` repo):
The machine-queryable source of truth. Claude reads this for all index operations. Contains library definitions, document entries, a bidirectional cross-reference graph, and upstream verification status.

The cross-reference graph is bidirectional: each document entry records its outgoing refs (sourced from `cross-refs` frontmatter) and its incoming refs as a derived reverse-index. The reverse-index is rebuilt automatically on every index write — it is never edited manually. This allows `/docs organize` to find all documents that link to a moved document in O(1) without scanning every file. The `cross-refs` frontmatter field remains the authoritative source of truth for outgoing links; the reverse-index is always regeneratable from it.

**Human-readable index** (`docs-index.md` in the `documentation/` repo):
A Markdown mirror of the structured index, auto-generated after any index write operation. The user reads this directly to understand the library's state at a glance. Never edited manually — always regenerated from the structured index.

### 6.4 Index Configuration Abstraction

The index backend is user-selected during first-run setup (§11.0) and recorded in `config.yaml`. Plugin logic is index-backend-agnostic — all backends expose the same read/write/query interface. Changing `type` and `location` migrates the backend without redesigning plugin logic. [→ OQ1]

```yaml
# ~/.docs-manager/config.yaml
index:
  type: git-markdown       # See backend registry below
  location: ~/projects/documentation/
  # api-key: stored in system keychain — never in config file
```

**Supported Index Backends**

| Type | Description | External Requirements | Cross-machine? | Best For |
|------|-------------|----------------------|----------------|----------|
| `git-markdown` | Structured JSON + human-readable Markdown mirror in a git repo | Git, optional GitHub/remote | ✓ via push/pull | Default — homelab, GitHub users |
| `local-git` | Same as git-markdown but no remote push | Git | ✗ (single machine) | Offline-only, private installs |
| `sqlite` | Local SQLite database | None (SQLite is stdlib) | ✗ unless shared drive | Power users wanting fast queries |
| `remote-db` | Hosted database (PostgreSQL, MySQL, etc.) | DB connection + credentials in keychain | ✓ via shared DB | Teams, advanced homelab |
| `json` | Flat JSON files, no git | None | ✗ | Minimal installs, testing |
| `csv` | Flat CSV index, human-editable | None | ✗ | Ultra-lightweight, spreadsheet users |
| `text` | Plain text index, one entry per line | None | ✗ | Minimal, emergency fallback |
| `hosted-api` | Managed cloud API endpoint | HTTP, API key in keychain | ✓ via API | Future — managed service [→ OQ1] |

**For unlisted environments** (NAS-hosted databases, custom APIs, exotic git hosts), the first-run setup flow (§11.0) guides the user conversationally and generates the appropriate `config.yaml` entries. Claude documents the resulting configuration in a machine-specific setup note stored in the library.

### 6.5 Machine Scoping

All index queries are filtered by `machine` field matching the current machine's identifier (hostname by default). A document on `raspi5` is invisible to queries from `pc-fed` unless explicitly marked `machine: global`. [→ P1]

### 6.6 Index Consistency Model

#### Orphan Detection

A document deleted from the filesystem leaves a stale entry in the index — a dead link that breaks cross-reference lookups and `/docs find` results. Orphan detection runs as part of `/docs index audit`:

1. For each entry in `docs-index.json`, check whether the referenced file exists at its recorded path
2. Orphaned entries (file missing) are listed separately: "3 orphaned index entries found — files no longer exist at recorded paths."
3. User chooses: remove from index, update path (file was moved), or keep (file is temporarily absent, e.g. on another machine)
4. Orphan audit also runs automatically during `/docs index sync` and before any cross-reference repair operation

#### Index Locking

To coordinate concurrent writes from multiple local Claude Code instances (e.g. two parallel sessions on the same machine), all index write operations acquire an exclusive lockfile before modifying `docs-index.json`.

**Lock file location**: `~/.docs-manager/index.lock`

**Lock file contents**:
```json
{ "pid": 12345, "acquired": "2026-02-18T14:30:00Z", "operation": "register-doc" }
```

**Lock acquisition protocol** (implemented in index write scripts):
1. Check if `index.lock` exists
2. If it exists, read the PID and check if that process is still running (`kill -0 <pid>`)
3. If the PID is dead (stale lock from a crashed session), remove the lock and proceed
4. If the PID is alive, wait up to 5 seconds (configurable via `index.lock-timeout-seconds` in `config.yaml`, default: `5`) then warn and abort: "Index is locked by another Claude session (PID 12345). Retry or run `/docs index unlock` if the lock is stale."
5. Write the lock file atomically using a temp file + rename: write to `index.lock.tmp` first, then `mv index.lock.tmp index.lock` (`mv` is atomic within a single filesystem). Perform the operation. Remove the lock with `rm index.lock`.

**What locking solves**: Multiple Claude sessions on the same machine writing to the index simultaneously (e.g. orchestrated agents, parallel sessions).

**What locking does not solve**: Concurrent writes from different machines to a shared `git-markdown` or `local-git` backend. This remains a git merge conflict problem — handled by the union-merge strategy below.

#### Multi-machine Merge Conflict Resolution

When `docs-index.json` has a git merge conflict (two machines registered documents simultaneously):

1. **Union-merge strategy**: Both machines' new document entries are valid and non-conflicting — a union of both change sets is the correct resolution in most cases. The `/docs index repair` command implements this: extract both sides of the conflict, merge all document entries by ID (deduplicating any identical entries), write the merged result.

2. **True conflict** (same document modified on both machines): Surfaces as a named conflict in the repair flow: "Document `raspi5-homelab/caddy/README.md` was modified on both `raspi5` and `pc-fed`. Keep raspi5 version, pc-fed version, or merge manually?"

3. The human-readable `docs-index.md` mirror is always regenerated from the resolved structured index — it is never itself the conflict resolution target.

---

## 7. Hook Design

### 7.1 Hook Events

| Hook event | Trigger | Purpose |
|------------|---------|---------|
| PostToolUse (Write/Edit) | Any file write or edit | Detect doc-relevant changes; append to queue silently |
| Stop | Session end | Surface queue for review; enforce P3 session-close |

### 7.2 Detection Logic — Two-Path Model

**Path A — Direct doc change**: The written file is a registered document (has docs-manager frontmatter or is listed in the index).
Queue item type: `doc-modified` — "Document modified, verify still accurate."

**Path B — Source-file association**: The written file appears in a registered document's `source-files` list.
Queue item type: `source-file-changed` — "Source file changed; associated document [X] may need update." [→ P3, P4]

Files matching neither path are ignored. This prevents queue noise on every `.py` or config file write. [→ P6]

### 7.3 Queue Append Behavior

All hook-detected events append to `~/.docs-manager/queue.json` silently. No context injection at detection time. Exception: if the queue exceeds a configurable threshold (default: 20 items), a brief notice is injected: "Documentation queue has N items. Consider `/docs queue review` before continuing."

### 7.4 Session-Close Trigger

The Stop hook checks queue length. If items are present, it injects: "Session ending with N queued documentation items. Run `/docs queue review` to review, or `/docs queue clear` to dismiss all (reason required — Claude will suggest one)." This enforces P3's session-close requirement without hard blocking. [→ P3]

### 7.5 Project-Entry Trigger

Project-entry detection is implemented as a skill that fires when Claude observes a new working directory context at session start or on explicit project navigation. The skill appends a freshness scan request to the queue for the new project's library. [→ P3]

### 7.6 Hook Error Handling [→ P2, P6]

Hook scripts **always exit 0**. A non-zero exit from a hook is treated as a hard failure by the Claude Code runtime and can interrupt the session — this is never the right outcome for a background documentation tool. Instead, all error states are surfaced as stdout context injections, allowing Claude to read the failure, diagnose it intelligently, propose a resolution, and continue working.

**Error handling contract for all hook scripts:**

```bash
# All hook scripts follow this pattern:
set -euo pipefail   # catch errors internally...

main() {
    # ... hook logic ...
}

# ...but never let them escape to the runtime:
if ! main "$@"; then
    echo "⚠ docs-manager hook encountered an issue: ${HOOK_ERROR:-unknown error}"
    echo "Documentation detection may be incomplete. Claude will handle this."
    echo "Run /docs hook status to diagnose, or /docs hook repair to fix."
fi
exit 0   # Always. No exceptions.
```

**What Claude does on receiving a hook warning:**
The injected warning gives Claude sufficient context to: identify the failure type (permissions, missing queue file, corrupted JSON, etc.), propose a concrete fix ("Run `chmod 644 ~/.docs-manager/queue.json`"), and continue with documentation duties for the current session. Claude does not treat hook failures as blocking — the session proceeds.

**Queue write failures specifically:**
If `queue.json` cannot be written (locked, permissions, corruption), the item is written to `~/.docs-manager/queue.fallback.json` instead. On next successful queue access, the fallback file is merged into the main queue and removed. This ensures no detection events are lost even during transient filesystem issues.

**Last-fired timestamp:**
Each hook script writes a timestamp to `~/.docs-manager/hooks/<hook-name>.last-fired` on successful completion only. This is what `/docs status` reads to assess hook health — a missing or stale timestamp indicates the hook ran but failed, or hasn't run at all.

---

## 8. Template System

### 8.1 Template Sources (Priority Order)

1. **User-registered templates** — highest priority; learned from existing documents or defined explicitly
2. **Industry standard templates** — Claude's knowledge of standard document formats (software design docs, API references, service runbooks, etc.)
3. **Inferred structure** — when no template matches, Claude infers structure from document location, filename, library type, and content intent [→ P4]

### 8.2 Template Registration

**From an existing document** (`/docs template register --from <path>`):
Claude analyzes the document's structure (section headings, table patterns, frontmatter fields, prose-to-structure ratio) and extracts a reusable template skeleton. The raspi5 per-service runbook format (Dependencies → Dependents → Purpose → Architecture → Configuration → Management → Restore Procedure → Verification → Troubleshooting → Log Locations) is registered this way.

**As an explicit template file** (`/docs template register --file <path>`):
A Markdown template file with `{{placeholder}}` syntax. Stored in the `documentation/` repo under `templates/` for cross-machine availability.

### 8.3 Template Storage

```
~/projects/documentation/
  templates/
    homelab-service-runbook.md    # Learned from raspi5/caddy/README.md
    sysadmin-machine-overview.md  # Learned from raspi5/README.md
    dev-readme.md                 # Industry standard
    personal-note.md              # Minimal structure
```

Templates live in the `documentation/` repository — available on all machines that pull it. [→ P1]

### 8.4 Template Inference

When creating a new document, the tool evaluates: current directory (known library path?), filename pattern, library type, and the three creation questions. If inference confidence is low, Claude asks one question: "This looks like a [type] document. Should I use the [template] template?" — never a menu of options. [→ P6]

---

## 9. Queue Architecture

### 9.1 Queue Data Model

The queue persists at `~/.docs-manager/queue.json`. It survives Claude Code session restarts and is only cleared by explicit review or `/docs queue clear`.

```json
{
  "created": "2026-02-18T14:30:00Z",
  "items": [
    {
      "id": "q-001",
      "type": "doc-modified",
      "doc-path": "~/projects/homelab/raspi5/caddy/README.md",
      "library": "raspi5-homelab",
      "detected-at": "2026-02-18T14:22:00Z",
      "trigger": "direct-write",
      "priority": "standard",
      "status": "pending",
      "note": null
    },
    {
      "id": "q-002",
      "type": "source-file-changed",
      "doc-path": "~/projects/homelab/raspi5/pihole/README.md",
      "source-file": "/etc/pihole/pihole.toml",
      "library": "raspi5-homelab",
      "detected-at": "2026-02-18T14:25:00Z",
      "trigger": "source-file-association",
      "priority": "standard",
      "status": "pending",
      "note": null
    }
  ]
}
```

### 9.2 Queue Priority

Queue items are prioritised based on document `criticality` frontmatter:
- `criticality: critical` → high (surfaced first in review)
- `criticality: standard` → standard
- `criticality: reference` → low (can be deferred)

### 9.3 Session-End Review Flow

The interaction flow is defined in §5.2. From the queue's perspective, the state transitions on review completion are:

| Action | queue.json change |
|--------|------------------|
| Item approved | Entry removed from `items[]` |
| Item deferred | Entry retained; `status` set to `"deferred"`; `note` updated with deferral reason if provided |
| Item dismissed | Entry removed; written to session history log with Claude-inferred reason (confirmed by user). Per-item dismiss is available in the secondary step of the session-end review flow (§5.2 step 4b); bulk dismiss via `/docs queue clear`. Dismiss policy detail (reason format, log retention) — see §14 OQ2. |

The queue file is only rewritten during explicit review actions (`/docs queue review`, Stop hook review, `/docs queue clear`). Hook detection events append to the file but never rewrite existing entries. This ensures concurrent hook writes and review reads don't race.

### 9.4 Mid-Session Queue Access

`/docs queue` — display current queue items
`/docs queue review` — trigger review flow immediately, mid-session
`/docs queue clear` — dismiss all items; Claude infers a reason from session context (e.g. "No documentation-relevant changes this session — deferring to a dedicated review") and presents it for user confirmation. The user confirms, edits, or replaces the reason. The reason and cleared item list are written to a session history log. Without an accepted reason the clear does not proceed. Use `--reason "text"` to skip the interactive prompt.

---

## 10. Upstream Verification System

### 10.1 Trigger Conditions

Upstream verification is triggered by:
- `/docs verify` — explicit, on demand
- Project-entry freshness scan detects a doc with `upstream-url` not verified within its `review-frequency` window [→ P3]
- `/docs full-review` runs verification as part of its comprehensive sweep
- Session-end queue review surfaces an item with `type: upstream-check-due`

### 10.2 Verification Process [→ P7]

For each document with a registered `upstream-url`:

1. Claude fetches or searches the upstream source for content relevant to the document's subject
2. Claude compares: configuration keys, version requirements, deprecated options, procedure steps
3. **Confident match** — no discrepancy; `last-verified` and `version` frontmatter are updated
4. **Confident discrepancy** — queue item created with Claude's proposed correction
5. **Uncertain** — queue item created with the upstream excerpt and a specific question for the user: "The upstream docs now show [X]. My doc says [Y]. Are these the same thing?"

### 10.3 Virtuous Cycle

As the library grows and patterns solidify, each verified document adds context that makes future Claude inference more accurate — registered templates, known `upstream-url` patterns, established library structures. The library teaches the tool, progressively reducing the frequency and depth of human collaboration requests over time. [→ P7]

### 10.4 Verification Batching Policy [→ P6]

Upstream verification sweeps are presented to the user in severity tiers, not as a single unbounded operation. Claude groups all documents due for verification by `criticality` frontmatter and presents each tier as a discrete decision:

**Tier 1 — Critical documents:**
> "7 critical documents are due for upstream verification. Verify these now?"
> → User approves or skips. Verified docs update in place; discrepancies are queued.

**Tier 2 — Standard documents:**
> "The 7 critical documents are up-to-date. 14 standard documents are also due. Continue, or add them to the queue for later?"
> → User can continue in-session or defer the tier to the queue.

**Tier 3 — Reference documents:**
> "14 standard documents verified. 31 reference documents are also due. Continue, or defer?"

This gives the user explicit control over session depth. Deferred tiers are queued as `type: upstream-check-due` items and re-surfaced at the next natural review point. The `/docs verify --all` flag bypasses tier prompting and verifies everything in sequence (for intentional full sweeps). [→ P2]

## 11. Onboarding Command & Intake Workflow

### 11.0 First-Run Setup Flow (`/docs setup`)

On first invocation (or when `~/.docs-manager/config.yaml` is absent), docs-manager runs a conversational setup flow before any other command can complete. This flow establishes the index backend and documents the resulting configuration for the current machine. [→ P4, P6]

**Setup conversation (example):**
> "Where would you like to store your documentation index? I can use a GitHub repo, a local git repo, a database, or simple flat files. What does your current setup look like?"

Claude listens to the user's description of their environment and maps it to the appropriate backend from the registry (§6.4). For common setups, no explicit backend knowledge is required from the user — "I use GitHub for my projects" maps to `git-markdown`. For unusual setups, Claude asks one clarifying question at a time.

**What setup produces:**
1. `~/.docs-manager/config.yaml` — written with the chosen backend type, location, and machine identity
2. A machine setup note — stored as a registered doc in the `meta` library: `library: meta, doc-type: system, machine: <hostname>`. Contains: the backend chosen, location, any credentials summary (not values), and any environment-specific quirks discovered during setup.
3. Backend validation — Claude verifies the index location is accessible (git repo exists and is cloned, DB is reachable, directory exists) before proceeding.

If the user's environment doesn't match any built-in backend, Claude generates a custom config and documents the integration steps conversationally, storing the result as the machine setup note.

### 11.1 Overview

`/docs onboard` registers existing documents into the library. Initial onboarding carries a deliberately high upfront cost — doing it right the first time makes ongoing maintenance significantly easier. [→ P6]

### 11.2 Single Document Onboarding (`/docs onboard <path>`)

1. Claude reads the document and infers: likely library, doc-type, machine scope, any source-file associations
2. Proposed assignments are presented for confirmation: "This looks like a sysadmin document for raspi5. Library: raspi5-homelab. Type: sysadmin. Machine: raspi5."
3. User confirms or corrects
4. Frontmatter is added to the document
5. Document is registered in the library index [→ P1]
6. If a third-party tool is described, user is prompted for `upstream-url` [→ P7]
7. Cross-references to existing documents in the same library are suggested

### 11.3 Directory Bulk Import (`/docs onboard <directory>`)

1. All `.md` files in the directory (recursively) are scanned
2. Claude groups them by inferred library and presents a summary: "Found 23 documents. Proposed groupings: [list with confidence indicators]"
3. User reviews groupings, corrects misclassifications
4. Frontmatter is added to all documents in batch
5. Index is updated in a single operation
6. A follow-up pass collects upstream URLs: "X documents describe third-party tools. Provide upstream URLs for each or skip."

### 11.4 Post-Onboarding

After onboarding, `/docs status` provides two sections: operational health (is the plugin working?) and library health (is the content in good shape?). [→ P2, P6]

**Operational Health** — verifies the silent machinery is functioning:

```
Operational Health
──────────────────────────────────────────────────────
Hooks:     ✓ PostToolUse registered and last fired 4m ago
           ✓ Stop registered and last fired (prev session)
Index:     ✓ In sync — pulled 2h ago, 0 commits behind remote
           ✓ No orphaned entries
Queue:     ✓ Valid — 3 pending items
Lock:      ✓ No active lock
Pending:   ✓ No offline writes queued
           (or: ⚠ 3 offline writes pending — run /docs index sync)
──────────────────────────────────────────────────────
```

Hook health is inferred from observable evidence — docs-manager cannot query Claude Code's hook registry directly. Instead, `/docs status` reads the last-fired timestamps written by each hook script on successful execution (§7.6):

| Timestamp state | Status shown | Meaning |
|----------------|--------------|---------|
| Recent (current or prior session) | ✓ | Hook is firing normally |
| Stale (>24h on an active machine) | ⚠ | Hook may have stopped firing |
| Missing (file never written) | ✗ | Hook has never fired — likely not installed |

If hook health shows ✗, `/docs status` instructs: "No hook activity detected. Verify the plugin is installed: run `/plugin list` and confirm docs-manager appears. If installed, trigger a file write to test the PostToolUse hook."

**Library Health** — content quality signals:

```
Library Health  (machine: raspi5)
──────────────────────────────────────────────────────
Registered documents:   47
Missing recommended fields:  3  (run /docs audit for details)
No upstream-url registered:  8  (run /docs audit --p7)
Overdue for verification:    2
Queue items pending:         3  (run /docs queue to review)
──────────────────────────────────────────────────────
```

---

## 12. Testing Strategy

docs-manager testing uses four layers, each addressing a different part of the plugin that can't be tested by the others.

### 12.1 Self-Test (`/docs status --test`)

The lightest testing layer — built into the plugin itself. A subset of `/docs status` operational health checks that runs a quick non-destructive self-test against the live environment. Runs automatically when `/docs status` is called; can also be triggered explicitly with `--test` for a more detailed diagnostic report.

**Self-test checks** (all read-only, non-destructive):
- `config.yaml` exists and is valid YAML with required fields (`machine`, `index.type`, `index.location`)
- `queue.json` exists and is valid JSON (or absent — not an error)
- `index.lock` is absent or holds a live PID (stale lock detection)
- Hook last-fired timestamps exist for PostToolUse and Stop hooks
- Index location is accessible (path exists, git repo initialised for `git-markdown` backend)
- Index JSON (`docs-index.json`) is valid and parseable

Self-test results feed directly into the Operational Health section of `/docs status` output (§11.4). Any failure emits an actionable message with the repair command.

### 12.2 Hook Script Unit Tests (bats)

Hook scripts (§7) are bash — testable with [bats](https://github.com/bats-core/bats-core) (Bash Automated Testing System). Tests live in `tests/` at the plugin root.

**What bats covers:**
- Happy path: queue append writes a valid JSON entry to `queue.json`
- Path A detection: a file with docs-manager frontmatter is classified as `doc-modified`
- Path B detection: a file listed in `source-files` of a registered doc triggers `source-file-changed`
- Ignored files: a file matching neither path produces no queue entry
- Error handling: hook script exits 0 and emits a warning on queue write failure (§7.6)
- Fallback queue: items written to `queue.fallback.json` when main queue is locked
- Last-fired timestamp: written on success, absent on failure

All bats tests operate against a disposable temp directory (`$BATS_TMPDIR/docs-manager-test/`) — never against `~/.docs-manager/` or any production index.

### 12.3 Integration Tests via Plugin Test Harness (PTH)

The [plugin-test-harness](../../plugin-test-harness/README.md) (`plugin` mode) drives iterative testing of the plugin's source files — hooks, commands, and skills — against expected behaviours.

**PTH session setup:**
```bash
pth_preflight    # detects plugin type as 'plugin' (hook-based, not MCP)
pth_start_session --plugin-path ./plugins/docs-manager
pth_generate_tests   # auto-generates tests from hook scripts, commands, skills
```

**PTH test categories for docs-manager:**
- Hook registration: PostToolUse and Stop hooks are present and correctly structured in `hooks.json`
- Command structure: all `/docs` subcommands exist as command files with required frontmatter
- Skill triggers: skill files have appropriate trigger metadata for their use cases
- Queue schema: `queue.json` entries match the defined schema (§9.1)
- Index schema: `docs-index.json` entries match the library definition and document entry shapes

PTH creates a `pth/docs-manager-<timestamp>` branch in the plugin repo for each session — providing a full audit trail of tests added and fixes applied.

### 12.4 Sandboxed Workflow Tests

Core workflows (§5) are tested in isolated Claude Code sessions against a sandboxed index, never touching the production `documentation/` repo.

**Sandbox setup:**
```bash
# Create a throwaway index for testing
mkdir -p /tmp/docs-manager-sandbox/{index,docs,templates}
git init /tmp/docs-manager-sandbox/index
# Override config to point at sandbox
echo "machine: test\nindex:\n  type: git-markdown\n  location: /tmp/docs-manager-sandbox/index" \
  > ~/.docs-manager/config.yaml.test
```

**Manual test scenarios** (one session per scenario):
1. `/docs new` — create a document, verify frontmatter, verify index registration, verify library membership
2. `/docs onboard` — import a directory, verify grouping proposals, verify frontmatter batch write
3. Session-end queue review — trigger Stop hook, verify queue surface, approve/defer items
4. `/docs organize` — move a document, verify cross-reference repair, verify index path update
5. `/docs verify` — run upstream verification with a known URL, verify tiered batching (§10.4)
6. `/docs status --test` — run self-test against sandbox, verify all checks pass

**Upstream verification isolation:** Mock HTTP responses are used for all `/docs verify` tests — live upstream URLs are never hit in testing. A simple local HTTP server (Python's `http.server`) serves controlled response fixtures.

---

## 13. Multi-machine Access Model

### 13.1 Machine Identity

Each machine is identified by its hostname, matching the directory organization already in use (e.g., `homelab/raspi5/` for the Raspberry Pi 5 server). Machine identity can be overridden in `~/.docs-manager/config.yaml` if the hostname doesn't match the desired identifier.

### 13.2 Library Scoping

Index queries are machine-filtered by default. On `raspi5`, queries return only libraries with `machine: raspi5` or `machine: global`. This prevents cross-machine confusion — PC configuration documentation does not appear in raspi5 sessions. [→ P1]

### 13.3 Sync Model

All documentation and the library index live in GitHub-hosted repositories, synced via standard `git push/pull`. No special sync infrastructure is required. The `documentation/` repository serves as the global registry; project-specific libraries live in their respective repositories.

The session queue (`~/.docs-manager/queue.json`) is **never synced** — it is machine-local and cleared after review.

### 13.4 Headless Server Access

On headless servers where network access may be intermittent, the local index cache (`~/.docs-manager/cache/`) provides read access to the last known good index snapshot. Write operations (registering new docs, updating frontmatter) require network access to push to the index backend. This is an accepted limitation. [→ OQ1 — a future hosted-api index type would address this more cleanly]

### 13.5 Local Index Cache

The cache stores a full snapshot of `docs-index.json` — not individual query results — so all read operations remain available offline regardless of which queries were previously issued.

**Cache file**: `~/.docs-manager/cache/docs-index.snapshot.json`

| Property | Behaviour |
|----------|-----------|
| **Content** | Full copy of `docs-index.json` at last successful sync |
| **Population** | Written on every successful `git pull` / `/docs index sync` |
| **Invalidation** | Replaced on every successful sync; treated as stale after 7 days (configurable via `index.cache-ttl-days` in config.yaml) |
| **Size** | Single-file snapshot — no unbounded growth |
| **Read fallback** | When the index location is unreachable, all read commands fall back to the cache automatically |

**Staleness warning**: When a command reads from the cache (rather than the live index), Claude injects a notice into context: "Index is offline — using cached snapshot from [date]. Results may not reflect recent changes from other machines."

**Write behaviour during offline**: Write operations (document registration, frontmatter updates) are queued locally and applied when network access is restored and `/docs index sync` succeeds. Queued writes are stored in `~/.docs-manager/cache/pending-writes.json`. `/docs index sync` always checks for `pending-writes.json` as part of its normal execution — if the file exists and is non-empty, pending writes are applied to the live index immediately after the pull succeeds, and `pending-writes.json` is cleared. No separate invocation is required.

---

## 14. Open Questions & Decisions Log

| # | Question | Why it matters | Owner | Status |
|---|----------|----------------|-------|--------|
| OQ1 | When migrating from the git-markdown index to a hosted database (e.g., docs.l3digital.net), what authentication model applies and how is data migrated without loss? | The index configuration abstraction in §6.4 assumes a migration path exists, but the hosted-api backend's auth mechanism (API keys, OAuth) and initial data export process from the Markdown index are undesigned. Implementing the hosted backend without this will create an undocumented migration gap. | TBD | Open |
| OQ2 | What is the dismiss policy for queue items? | §5.2 exposes a "dismiss all" option. The unresolved questions are: (1) should a reason be required before dismissal? (2) are dismissed items written to a permanent session history log, a rolling log, or simply deleted? (3) does dismissal without reason violate P3's session-close intent? The answer determines whether `queue.fallback.json` needs a `dismissed` entry format, and whether `/docs status` should surface a dismiss history count. | TBD | Open |

---

## 15. Appendix

*Fill this section incrementally during implementation as the command surface and frontmatter schema stabilise. Seed entries below establish format — expand as features are built.*

---

### 15.1 Glossary

| Term | Definition |
|------|------------|
| **Library** | A named collection of documents associated with a domain, project, or machine. Every document belongs to exactly one primary library. Libraries do not need to cross-link. |
| **Queue item** | A pending documentation task detected by a hook and stored in `~/.docs-manager/queue.json`. Each item has a type (`doc-modified`, `source-file-changed`, `upstream-check-due`), a target document, and a status (`pending`, `deferred`). |
| **Survival-context document** | Any document a human may need to follow without AI assistance (e.g. in a disaster recovery scenario). Classified by `doc-type` (sysadmin/dev/personal) and `audience` (human/both). P5 mandates explanatory prose in all sections of these documents. See §6.2 for the full classification rule. |
| **upstream-url** | A frontmatter field registering the authoritative external source for a document that describes a third-party tool or system. Used by the upstream verification system (§10) to check for drift. |
| **source-files** | A frontmatter field listing files whose changes should trigger a documentation review queue item (Path B detection, §7.2). Used for sysadmin config files and source code files whose state the document describes. |
| **Index configuration abstraction** | The `index.type` + `index.location` fields in `config.yaml` that allow switching between index backends (git-markdown, sqlite, hosted-api, etc.) without changing plugin logic. See §6.4. |
| **Orphaned index entry** | An entry in `docs-index.json` whose referenced file no longer exists at the recorded path. Detected by `/docs index audit`. |
| *(add terms here during implementation)* | |

---

### 15.2 Command Reference

*Expand each entry with flags, examples, and edge-case behaviour as commands are implemented.*

| Command | Description | Key flags |
|---------|-------------|-----------|
| `/docs new [title]` | Create a new document with inferred template and library | `--library`, `--type`, `--template` |
| `/docs onboard <path>` | Register an existing document or directory into the library | `--library`, `--dry-run` |
| `/docs find <query>` | Search the library index for documents matching a query | `--library`, `--type`, `--machine` |
| `/docs update <path>` | Update an existing document; checks freshness and queues review | — |
| `/docs review <path>` | Review a specific document for staleness, consistency, P5 compliance | `--full` |
| `/docs organize <path>` | Move, rename, or restructure a document; repairs cross-references | `--dry-run` |
| `/docs library` | List all libraries on the current machine | `--all-machines` |
| `/docs index init` | Clone and initialise the index backend on a new machine | `--backend`, `--location` |
| `/docs index sync` | Pull latest index from remote; resolve drift; automatically apply any pending offline writes from `pending-writes.json` | `--force` |
| `/docs index audit` | Find orphaned entries, missing files, and consistency issues | `--fix` |
| `/docs index repair` | Resolve merge conflicts in `docs-index.json` | — |
| `/docs status` | Show operational health and library health | `--test` |
| `/docs audit` | Full library audit: missing fields, stale docs, P7 candidates | `--p7`, `--p5` |
| `/docs dedupe` | Find and resolve near-duplicate documents within a library | `--across-libraries` |
| `/docs consistency` | Check internal and cross-document consistency | — |
| `/docs streamline` | Identify and remove redundant content within a document | — |
| `/docs compress <path>` | Compress a document for token efficiency (AI-audience docs only) | — |
| `/docs full-review` | Comprehensive sweep: all review types + upstream verification | — |
| `/docs queue` | Display current queue items | — |
| `/docs queue review` | Trigger queue review flow mid-session | — |
| `/docs queue clear` | Dismiss all items; Claude infers a reason from session context for confirmation; reason and cleared item list written to session history | `--reason "text"` (skip interactive prompt) |
| `/docs template register` | Register a new template from an existing document or file | `--from`, `--file`, `--name` |
| `/docs verify [path]` | Run upstream verification for a document or library | `--all`, `--tier` |
| `/docs hook status` | Check hook registration and last-fired timestamps | `--repair` |
| `/docs help` | Show command list and usage summary | — |
| *(add commands here during implementation)* | | |

---

### 15.3 Frontmatter Field Reference

*Expand with types, defaults, validation rules, and examples as fields are finalised during implementation.*

| Field | Required | Type | Values / Format | Notes |
|-------|----------|------|-----------------|-------|
| `library` | ✓ | string | Library name slug | Must match a registered library in the index |
| `machine` | ✓ | string | hostname or `global` | Defaults to system hostname; `global` makes doc cross-machine visible |
| `doc-type` | ✓ | enum | `sysadmin` \| `dev` \| `personal` \| `ai-artifact` \| `system` | Affects survival-context classification (§6.2); `system` reserved for `meta` library |
| `last-verified` | ✓ | date | ISO 8601 `YYYY-MM-DD` | Updated on review or upstream verification pass |
| `status` | ✓ | enum | `draft` \| `active` \| `archived` \| `deprecated` | — |
| `upstream-url` | recommended | URL | Full https:// URL | Required for P7 compliance on third-party tool docs |
| `source-files` | recommended | list of paths | Absolute or repo-relative paths | Triggers Path B hook detection (§7.2) |
| `version` | recommended | string | Free-form version string | e.g. `"Caddy v2.7"` |
| `cross-refs` | recommended | list of paths | Relative paths to other docs | Source of truth for outgoing refs in the bidirectional graph |
| `template` | recommended | string | Template name slug | Must match a registered template in `documentation/templates/` |
| `audience` | optional | enum | `human` \| `ai` \| `both` | `ai` overrides doc-type in survival-context classification |
| `tags` | optional | list of strings | Free-form tags | Used for filtering in `/docs find` |
| `criticality` | optional | enum | `critical` \| `standard` \| `reference` | Determines queue review priority order |
| `review-frequency` | optional | enum | `on-change` \| `weekly` \| `monthly` \| `quarterly` | Controls staleness check cadence |
| `created` | optional | date | ISO 8601 `YYYY-MM-DD` | Set at document creation; never updated |
| `updated` | optional | date | ISO 8601 `YYYY-MM-DD` | Updated on every substantive edit |
| `owner` | optional | string | Username or name | Informational only |
| *(add fields here during implementation)* | | | | |
