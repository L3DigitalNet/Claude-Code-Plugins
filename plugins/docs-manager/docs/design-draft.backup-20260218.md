# docs-manager — Design Document

Version: 0.1 (Draft)
Status: In Progress — NOT FOR IMPLEMENTATION
Last Updated: 2026-02-18
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
  config.yaml          # Index type, location, machine identity
  queue.json           # Session queue (persists across restarts)
  cache/               # Local cache of recent index queries
```

```yaml
# ~/.docs-manager/config.yaml (example)
machine: raspi5          # Defaults to hostname if not set
index:
  type: git-markdown     # git-markdown | sqlite | hosted-api
  location: ~/projects/documentation/
```

The `index.type` and `index.location` fields form the **index configuration abstraction** — changing these values migrates the index backend without requiring changes to plugin logic. [→ OQ1]

### Context Cost Model

| Component | Enters context? | When? |
|-----------|-----------------|-------|
| Command markdown | Yes | On `/docs <command>` invocation |
| Skills | Conditionally | When Claude deems relevant |
| Hooks | No | Run externally; only stdout returned |
| Scripts | No | Run externally; only stdout returned |
| Agent definitions | No (for parent) | Loaded by spawned agent |
| Queue summary | Yes | At session end / `/docs queue review` |

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
4. User receives a consolidated summary: approve all / approve selected / defer with note / clear
5. Approved drafts are applied; rejected items are deferred to next session with a note
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

### 6.2 Document Frontmatter Schema

All documents managed by docs-manager carry YAML frontmatter. Existing documents receive frontmatter during onboarding.

**Required fields:**
```yaml
---
library: raspi5-homelab
machine: raspi5
doc-type: sysadmin          # sysadmin | dev | personal | ai-artifact
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

### 6.3 Dual Index

The library index is maintained in two forms: [→ P6]

**Structured index** (`docs-index.json` in the `documentation/` repo):
The machine-queryable source of truth. Claude reads this for all index operations. Contains library definitions, document entries, the cross-reference graph, and upstream verification status.

**Human-readable index** (`docs-index.md` in the `documentation/` repo):
A Markdown mirror of the structured index, auto-generated after any index write operation. The user reads this directly to understand the library's state at a glance. Never edited manually — always regenerated from the structured index.

### 6.4 Index Configuration Abstraction

```yaml
# ~/.docs-manager/config.yaml
index:
  type: git-markdown       # Current: files in documentation/ repo
  location: ~/projects/documentation/
  # Future:
  # type: sqlite
  # location: ~/.docs-manager/docs.db
  # type: hosted-api
  # location: https://docs.l3digital.net/api/v1
  # api-key: (stored in system keychain, not in config file)
```

Changing `type` and `location` migrates the backend. Plugin logic is index-backend-agnostic. [→ OQ1]

### 6.5 Machine Scoping

All index queries are filtered by `machine` field matching the current machine's identifier (hostname by default). A document on `raspi5` is invisible to queries from `pc-fed` unless explicitly marked `machine: global`. [→ P1]

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

The Stop hook checks queue length. If items are present, it injects: "Session ending with N queued documentation items. Run `/docs queue review` or `/docs queue clear` to resolve." This enforces P3's session-close requirement without hard blocking. [→ P3]

### 7.5 Project-Entry Trigger

Project-entry detection is implemented as a skill that fires when Claude observes a new working directory context at session start or on explicit project navigation. The skill appends a freshness scan request to the queue for the new project's library. [→ P3]

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

1. Stop hook fires; queue is non-empty
2. Claude reads queue and current state of all associated files [→ P6]
3. Claude generates a consolidated review summary: for each item, a proposed update (1–3 sentences describing what changed and what the doc update should say)
4. User selects: approve all / approve selected / defer with note / clear
5. Approved updates are applied; rejected items are deferred with a note
6. Queue file is updated; resolved items are removed [→ P3]

### 9.4 Mid-Session Queue Access

`/docs queue` — display current queue items
`/docs queue review` — trigger review flow immediately, mid-session
`/docs queue clear` — clear all items with confirmation

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

---

## 11. Onboarding Command & Intake Workflow

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

After onboarding, `/docs status` shows library health: registered document count, documents missing recommended frontmatter fields, documents with no upstream URL, and initial queue state.

---

## 12. Testing Strategy

[STUB — content needed: unit testing approach for hook scripts (bats or equivalent), integration testing for index read/write operations, manual test scenarios for core workflows (create, onboard, queue review, upstream verify, organize), and how to test the plugin in a Claude Code session without modifying production documentation.]

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

On headless servers where network access may be intermittent, the local index cache (`~/.docs-manager/cache/`) provides read access to recently queried index data. Write operations (registering new docs, updating frontmatter) require network access to push to GitHub. This is an accepted limitation. [→ OQ1 — a future hosted-api index type would address this more cleanly]

---

## 14. Open Questions & Decisions Log

| # | Question | Why it matters | Owner | Status |
|---|----------|----------------|-------|--------|
| OQ1 | When migrating from the git-markdown index to a hosted database (e.g., docs.l3digital.net), what authentication model applies and how is data migrated without loss? | The index configuration abstraction in §6.4 assumes a migration path exists, but the hosted-api backend's auth mechanism (API keys, OAuth) and initial data export process from the Markdown index are undesigned. Implementing the hosted backend without this will create an undocumented migration gap. | TBD | Open |

---

## 15. Appendix

[STUB — content needed: glossary of terms (library, queue item, survival-context document, upstream-url, source-files association); full `/docs` command reference with flags and examples; complete frontmatter field reference with types, defaults, and validation rules.]
