# docs-manager — Principles Registry

Version: 1.1
Status: Updated — design review completed 2026-02-19
Project: docs-manager

---

## Registry

### [P1] Domain Libraries, Not a Global Web

**Statement**: Documentation is organized into domain libraries (project, sysadmin, personal, etc.). Each library maintains internal cross-references where meaningful, and every document must belong to at least one library — but libraries are not obligated to cross-link, and isolated notes within a library are acceptable when no meaningful connection exists.

**Intent**: Prevents documentation from becoming a collection of undiscoverable orphan files scattered across projects. Forces at minimum a declaration of library membership, enabling discovery at the library level even when individual docs are not cross-linked. Prevents the specific failure mode of creating a document, losing it in a folder, and never finding it again — confirmed as a real problem across 758+ existing Markdown files.

**Enforcement Heuristic**: A document saved without library membership registration. A doc that references another document by concept without a link. An index that lists a library but cannot enumerate its contents. A document with no `library` frontmatter field.

**Cost of Following This Principle**: Every document creation requires declaring which library it belongs to — even niche notes that feel standalone. The tool gives up frictionless "save anywhere" in exchange for the discovery guarantee.

**Tiebreaker**: None.

**Risk Areas**: Initial onboarding of existing 758+ docs — temptation to skip library assignment to reduce import cost. New ad-hoc notes created in contexts where library context is unclear.

---

### [P2] Detection is Automatic; Resolution is Deferred and Batched

**Statement**: The tool monitors workflows via hooks and accumulates documentation tasks into a queue rather than interrupting active work. At logical transition points (task completion, session end, explicit request), the queue is surfaced for batch review. Detection is automatic; resolution is deferred and batched.

**Intent**: Prevents two failure modes simultaneously: the tool that gets forgotten because it requires manual invocation (identified as the #1 failure mode for this user's documentation systems), and the tool that gets disabled because it interrupts too aggressively. The queue model is the mechanism that makes all other principles survive contact with a solo maintainer who cannot rely on their own memory.

**Enforcement Heuristic**: A hook that fires a blocking prompt mid-session rather than appending silently to the queue. A queue with no persistence — if the session ends without review, items are lost rather than carried forward.

**Cost of Following This Principle**: Documentation debt accumulates visibly and cannot be silently discarded — the queue must be reviewed at transition points. The user gives up the ability to "finish a session and forget about docs" in exchange for the guarantee that nothing falls through unnoticed.

**Tiebreaker**: None.

**Risk Areas**: Queue growth on heavy sessions. Hook scope too broad — fires on every file write including non-documentation-relevant changes, creating noise that erodes trust in the detection system.

---

### [P3] Staleness is Surfaced at the Point of Use and at Session Close

**Statement**: Staleness is surfaced at the point of use and at session close, not proactively across all docs. When a document is accessed or a project becomes active, its freshness is checked and concerning issues are queued. When work on a project concludes, the queue must be cleared — documentation should accurately reflect the project state before the session ends. Dormant docs are not alarmed; active docs are not allowed to go silently out of date.

**Intent**: Prevents the specific harm of incorrect sysadmin documentation being followed in a crisis without anyone knowing it is stale. Avoids the opposite failure — flagging all 758+ docs simultaneously and creating a paralysing backlog. Establishes that finishing a project session means both the code and the documentation are in good order.

**Enforcement Heuristic**: A document accessed in the current session without a freshness check. A project session closed with documentation debt still in the queue. An active document that has not been verified since its associated source files changed. A `/docs queue clear` invocation that does not record a reason — all bulk queue dismissals must include a Claude-inferred reason confirmed by the user; clearing without a reason is a P3 violation (the session-close obligation was bypassed without acknowledgment).

**Cost of Following This Principle**: A project session cannot be considered finished while documentation debt remains unreviewed. Quick fixes that touch code without updating docs create an obligation at session end, not optional cleanup for later.

**Tiebreaker**: None.

**Risk Areas**: Session-end queue size on heavy coding days. The project-entry trigger firing too broadly across many projects simultaneously, producing an overwhelming scan. Queue clear/dismiss flows that offer a frictionless escape hatch without recording intent — mitigated by the inferred-reason requirement on all dismiss paths.

---

### [P4] Templates are Inferred, Not Imposed

**Statement**: Templates are inferred from context, industry standards, and user-established patterns — not chosen from a fixed menu. The tool recognizes what kind of document is being created and applies the most appropriate structure, including user-defined templates. Users can register their own preferred templates for the tool to recognize and reuse.

**Intent**: Prevents the tool from becoming a documentation bureaucracy where every document requires navigating a template taxonomy before content can be created. Equally prevents the "universal schema" failure where sysadmin config documents and personal hobby notes are forced into the same structure. Specifically protects user-evolved formats — such as the per-service runbook pattern developed for homelab servers — as first-class citizens of the template system.

**Enforcement Heuristic**: A user prompted to select from a menu of template types rather than having the appropriate one inferred. A sysadmin service doc missing Dependencies / Restore Procedure / Verification sections that established patterns provide as standard. A personal note forced to populate server-specific metadata fields.

**Cost of Following This Principle**: The tool carries the intelligence burden of template inference. If it gets the template wrong, the user has more editing to do than starting from scratch. The tool cannot offload this decision to the user by presenting a selection menu.

**Tiebreaker**: When P4 produces a survival-context document with structured data but missing prose sections, P5 takes precedence — Claude attempts prose generation; missing sections are queued as deficiencies, not silently accepted. No hard blocking. [→ P5]

**Risk Areas**: Cross-domain documents (e.g., a Home Assistant integration that is simultaneously a sysadmin and developer concern). First-time document types with no registered template and no obvious industry standard.

---

### [P5] Human-First in Survival Contexts

**Statement**: For any document a human may ever need to follow without AI assistance, human readability is non-negotiable — structured data is always accompanied by explanatory prose. For artifacts designed exclusively for AI consumption (prompts, voice context, agent instructions), this constraint does not apply and token efficiency takes precedence. The test: "Could a competent person follow this document in a crisis with no AI available?"

**Intent**: Prevents sysadmin documents from becoming dense configuration dumps that are parseable by AI but opaque to a human under pressure. Protects against the disaster-recovery failure mode where a correct but unreadable document is as useless as no document. Explicitly carves out AI-only artifacts — such as Home Assistant voice assistant context prompts — where token efficiency is the real requirement.

**Enforcement Heuristic**: A sysadmin or operational document with configuration tables but no prose "Purpose" or "Architecture" sections. A document that answers "what are the values" but not "what is this and why does it matter." A Restore Procedure section consisting solely of shell commands with no explanatory framing between steps.

**Cost of Following This Principle**: Every survival-context document requires prose sections that take time to generate and verify. The tool gives up the efficiency of configuration-dump documentation in exchange for documents that remain usable when AI assistance is unavailable.

**Tiebreaker**: When P4's template inference produces a survival-context document with structured data but missing prose, P5 wins. Claude attempts prose generation; missing sections are queued as deficiencies. No hard blocking. [→ P4]

**Risk Areas**: Auto-generated documents where Claude infers structure from file state but cannot infer narrative intent. AI-only artifact classification — what counts as "exclusively for AI consumption" must be registered explicitly via `audience: ai` frontmatter, not inferred.

---

### [P6] Lighter Than the Problem

**Statement**: Any workflow the tool imposes must demand less effort than the documentation problem it solves. If maintaining documentation with docs-manager costs more than the documentation is worth, it will be abandoned, and the problem returns.

**Intent**: Prevents the tool from becoming the thing the user dreads opening — a documentation system that itself requires documentation overhead to maintain. Protects the homelab enthusiast audience: technically capable but unwilling to tolerate bureaucratic friction that exceeds the value of the output. High initial onboarding cost is the explicit exception: front-loaded investment for long-term maintenance ease is acceptable.

**Enforcement Heuristic**: New document creation requiring more than three questions before a first draft is produced. Session-end queue review requiring the user to manually write or edit multiple document sections rather than approve a Claude-drafted summary. Any workflow that blocks active work to demand metadata completion.

**Cost of Following This Principle**: The tool carries the intelligence burden — it must infer enough from context, session activity, and file state to produce autonomous document drafts requiring only go/no-go approval. "Lighter than the problem" is not a UX courtesy; it is a hard constraint that moves complexity from the user to the tool.

**Tiebreaker**: None. All prior tensions with P6 were resolved by the deferred queue model — P2, P3, and P7 all feed into the same queue structure without adding separate overhead.

**Risk Areas**: Queue growth on heavy sessions — if the session-end summary itself is overwhelming, P6 is violated at the review stage, not the detection stage. Initial onboarding of 758+ existing documents — bulk import must front-load cost, not spread it across ongoing use.

---

### [P7] Anchor to Upstream Truth

**Statement**: Documentation that describes third-party systems, tools, or applications must be periodically verified against its upstream authoritative source — internal consistency is not enough when the ground truth is maintained externally.

**Intent**: Prevents the failure mode of following a well-maintained personal document for a third-party tool that was accurate when written but reflects a deprecated API, renamed configuration key, or removed feature. Protects specifically against documents that pass internal staleness checks (nothing in your system changed) but have drifted from upstream reality.

**Enforcement Heuristic**: A third-party tool document with no registered `upstream-url` frontmatter field. A document that has passed internal freshness checks but has never been compared against its upstream source. A configuration key documented as valid that no longer exists in the current upstream release.

**Cost of Following This Principle**: Third-party documents require registering an upstream source and accepting that Claude may periodically flag discrepancies for human review. Upstream verification is the most collaborative workflow in the system — Claude leads, but uncertain cases require human judgement that cannot be fully automated.

**Tiebreaker**: None. The P7 × P6 tension was resolved by the queue model — background upstream checks feed results into the same deferred queue as session-detected changes.

**Risk Areas**: Third-party documents created without `upstream-url` registration — most likely during initial bulk onboarding of existing documents. Upstream sources that restructure their URLs or move content without preserving redirects, causing verification to fail silently.

---

## Tension Resolution Log

| ID | Principles | Resolution | Tiebreaker Rule |
|----|-----------|------------|-----------------|
| T1 | P1 × P2 | RETIRED | Resolved by queue model; no operational conflict |
| T2 | P2 × P3 | RETIRED | Both feed into same queue; resolved structurally |
| T3 | P4 × P5 | (A) P5 wins, soft enforcement | "When P4 inference produces structured-only content for a survival-context doc, P5 takes precedence — Claude generates prose; missing sections queued as deficiencies; no hard blocking." |
| T4 | P2 × P6 | RETIRED | Resolved by queue model; batching makes P2 lighter |

---

## Candidates Not Adopted

None — all 7 candidates were accepted (some with revisions during stress testing).

---

## /design-review Appendix

*This block is for /design-review handoff use only. It includes Auto-Fix Heuristics not present in the reader-facing registry.*

### [P1] Domain Libraries, Not a Global Web
**Auto-Fix Heuristic**: Add `library: [inferred-library-name]` to frontmatter. Propose library assignment based on file location and project context. If library context is ambiguous, present two options with rationale rather than asking an open question.

### [P2] Detection is Automatic; Resolution is Deferred and Batched
**Auto-Fix Heuristic**: For blocking hook violations — convert inline prompt to queue append. For lost-queue violations — ensure queue.json path is defined in state config and hook writes to absolute path.

### [P3] Staleness is Surfaced at the Point of Use and at Session Close
**Auto-Fix Heuristic**: For missing freshness checks — add `last-verified` frontmatter field and queue a verification item. For session-close violations — surface pending queue items before the Stop hook completes. For queue clear/dismiss without a reason — block and prompt Claude to infer a reason from session context (recent file activity, session topic, project state); present to user for confirmation or editing before the dismiss proceeds.

### [P4] Templates are Inferred, Not Imposed
**Auto-Fix Heuristic**: Remove template selection menu. Replace with inferred template presented as a pre-filled draft with a go/no-go prompt. If inference confidence is low, present the top two options with reasoning.

### [P5] Human-First in Survival Contexts
**Auto-Fix Heuristic**: For missing prose sections in survival-context docs — generate a prose draft for the missing section and queue it for review. Do not block. Set `audience: human` in frontmatter if not present and document type is sysadmin or operational.

### [P6] Lighter Than the Problem
**Auto-Fix Heuristic**: For >3-question creation flows — collapse into a single context-rich prompt. For heavy session-end summaries — present as a tiered list (critical / standard / low priority) with batch-approve option for standard tier.

### [P7] Anchor to Upstream Truth
**Auto-Fix Heuristic**: For missing upstream-url — prompt once during onboarding with example URLs. For failed upstream verification — queue discrepancy for human review rather than auto-updating. Flag `upstream-url` as stale if 3+ consecutive fetches return 404.

---

## Post-Review Update Log

*Changes to this registry after initial lock. Each entry records the finding that prompted the change.*

| Date | Version | Principle | Change | Source Finding |
|------|---------|-----------|--------|----------------|
| 2026-02-19 | 1.1 | P3 | Enforcement Heuristic extended: queue clear/dismiss without a recorded reason is now an explicit P3 violation. Claude must infer a reason and confirm with user before any bulk dismiss proceeds. | #24 (Pass 3) — consolidated from deferred #1 |
| 2026-02-19 | 1.1 | P3 | Risk Areas extended: added queue clear/dismiss escape-hatch risk and its mitigation. | #24 (Pass 3) |
| 2026-02-19 | 1.1 | P3 | Auto-Fix Heuristic extended: added pattern for handling queue clear without reason (infer reason from session context, confirm, then proceed). | #24 (Pass 3) |
