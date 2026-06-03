# qdev D2 — Escalating Grounding Skill + Programmatic Egress Sanitizer (Design)

**Status:** Design approved (brainstorm 2026-06-03); **revised after spec audit rounds 1–2 (SA-001…SA-007 + SA-NEW-001 all resolved — see §12)**; ready for `superpowers:writing-plans`.
**Created:** 2026-06-03
**Owner harness:** Claude Code (Opus)
**Scope:** Deliverable 2 only — the auto-trigger grounding skill plus the programmatic egress sanitizer it depends on. Adjacent items remain deferred (see §8).
**Source brief:** [`docs/research/qdev/qdev-expansion-brief.md`](../research/qdev/qdev-expansion-brief.md) — "Deliverable 2 — The escalating grounding skill" + "Triggering reference".
**Backing research:** `docs/research/qdev/` — `qdev-research-backlog-resolution.md` (§9 External Content Safety), `qdev-research-backlog-resolution-2.md` (§2.3–2.4 sanitizer spec, §3.6–3.7 routing thresholds).
**Builds on:** D1 — [`docs/plans/2026-06-03-qdev-research-reporting-design.md`](2026-06-03-qdev-research-reporting-design.md) (shipped; reporting cycle + `qdev-researcher` routing). D2 reuses D1's engine **unchanged**.

---

## 1. Goal

Claude Code often fails to search when it should — it loops on a broken approach or trusts stale training data for fast-moving libraries/APIs. `/qdev:research` covers *deliberate* research, but nothing fires *automatically* mid-task. D2 fills that gap cheaply: one auto-invoked skill that starts with an inline lookup and escalates to the full `qdev-researcher` sweep only when the cheap path fails. Because the skill auto-fires on raw error text (the most likely place for a secret or internal hostname to appear), the **inline skill is the egress choke point**: it sanitizes every outbound payload — its own light-path queries *and* the stuck-context handoff it passes to the medium subagent — before anything leaves the machine.

**Success criteria:**

- **G1.** The skill fires reliably when the agent is stuck (Category A) or missing current information (Category C), and does **not** over-fire on routine work (Category B excluded).
- **G2.** The light path is genuinely cheap: no subagent, no report, output-capped, escalating to medium only on failure.
- **G3.** Category-A "already stuck" enters the medium path directly (a full sweep + persisted report is warranted) — **after** the inline skill sanitizes the handoff.
- **G4.** Every auto-fired outbound payload — light-path query **and** medium-path handoff — is sanitized deterministically by the skill before it leaves the machine; flagged payloads pause for human approval, and a rejected payload aborts the auto-research (never leaks, never silently proceeds).
- **G5.** The medium path reuses D1's `qdev-researcher` + reporting cycle **unchanged**; the only D2-side gates are sanitization-before-dispatch and, on *auto-fired* runs, **approval-before-dispatch** (`qdev-researcher` persists internally before it returns, so the gate must precede dispatch — SA-NEW-001).

---

## 2. Locked decisions (brainstorm 2026-06-03; D2-7…D2-9 added in audit round 1)

| # | Decision | Source |
| --- | --- | --- |
| D2-1 | **Scope = skill + programmatic sanitizer.** `qdev doctor`, the `brave_llm_context` light-primary benchmark, the empirical benchmark harness, and the meta-doc retrofit are all deferred (§8). | Q1 |
| D2-2 | **`requires_human_approval` → surface to user.** On a flagged payload the skill pauses and shows `safe_query` + `dropped_fields` (redacted labels only). **Approve → send; reject → abort the auto-research and proceed ungrounded** (one-line notice; the main agent continues without external grounding). The flag only trips on the risky subset, so friction is rare. | Q2 + audit |
| D2-3 | **Sanitizer enforcement lives in the inline skill, not in `qdev-researcher`.** The skill sanitizes both its own light-path queries and the medium-path handoff *before* any MCP call or `Agent` dispatch. `qdev-researcher` (a subagent that cannot call `Agent`/`AskUserQuestion`) is **not modified** — it keeps its D1 prose guardrail and receives an already-sanitized handoff (defense in depth). This honors "don't retouch D1" while closing the Category-A gap (SA-001). | Q3 + audit |
| D2-4 | **Skill shape C — skill + reference (progressive disclosure).** Lean `SKILL.md` (frontmatter + entry routing + escalation tree + medium dispatch); a `references/` file holds the verbose Category catalog, Category-B note, per-provider egress verdicts, dedup pointer, and the trigger matrix. Keeps the invoked body small — the light path's whole point is context economy. | Q4 |
| D2-5 | **One inline skill, escalating.** Not `context: fork` — a forked skill runs as a subagent and loses the `Agent` tool, so it could never dispatch `qdev-researcher` (and could not run the sanitizer gate or ask for approval). The single auto-trigger lives on the inline entry; the medium path never self-triggers. | Brief (locked) |
| D2-6 | **Light primary = `brave_web_search` + targeted `tavily_extract`**, not `brave_llm_context`. The brief's decision rule (resolution-2 §3.6) adopts `brave_llm_context` only if it stays under ~5k serialized tokens; its 8,192-token default busts the <3,000-token light-path budget. Ship the conservative default; the benchmark that could flip this is deferred. | resolution-2 §3.6 |
| D2-7 | **Auto-fired medium runs require approval *before dispatch*.** `qdev-researcher` persists the report (write + index regen) internally *before* it returns and has no `AskUserQuestion`, so the gate cannot sit "before persist" without modifying D1. Instead, on an *auto-fired* medium run (Category-A or escalation) the skill confirms first — "run a full research sweep and persist a report to `docs/research/` on `<topic>`?" — and only dispatches on approval; reject → never dispatched, nothing written. This keeps `qdev-researcher` unchanged, gates before token spend, and still prevents an unrequested auto-trigger from dirtying the tree. Trade-off: the prompt shows the topic, not the final report summary. (Manual `/qdev:research` is unaffected — no extra gate.) | audit r1 + r2 (SA-NEW-001) |
| D2-8 | **Fail-closed egress; Brave ZDR assumed absent.** No provider is treated as "safe enough to auto-send a borderline-sensitive query." Brave's lowest-risk ranking applies only with enterprise Zero-Data-Retention, which this environment does not document — so ZDR is assumed absent and any payload that would be flagged requires approval regardless of provider. Sanitizer-unavailable / malformed-output / missing-`uv` all fail closed (no external call). | audit (SA-003) |
| D2-9 | **Reword README [P2] to scope it to commands + carve out the grounding skill.** D2 is the plugin's first auto-trigger; [P2] "Explicit Invocation Only" is rewritten to state that the five *commands* never load contextually and that the single grounding skill is the deliberate, sole auto-trigger exception (sanitizer-gated, approval-on-risk). Stale "all three" → current command count. | audit (SA-007) |

---

## 3. Architecture & file layout

```text
plugins/qdev/
  skills/
    research-grounding/
      SKILL.md                      # frontmatter + entry routing + escalation tree + medium dispatch + sanitizer gate
      references/
        detection-and-egress.md     # Category A/C catalog, Category-B note, per-provider egress verdicts,
                                     # dedup-reuse pointer, and the manual trigger matrix
  scripts/
    sanitize_query.py               # NEW — PEP 723, dependencies = []; the egress sanitizer (stdin-driven)
  tests/
    test_sanitize_query.py          # NEW — pytest, one test per pipeline + approval branch + no-leak assertions + CLI smoke
```

**Reused from D1 (unchanged):** `agents/qdev-researcher.md` (medium engine), `scripts/build_research_index.py`, `scripts/validate_research_frontmatter.py`, `scripts/dedup.py`, `scripts/_frontmatter.py`.

**Net new in D2:** one skill (2 files) + one script + one test file. No D1 *behavioral* file is modified (README/manifest/marketplace metadata updates per §9 are doc/version changes, not D1 logic).

### 3.1 SKILL.md frontmatter contract (SA-006)

Matches the local convention (up-docs skills: `name` · `description` · `argument-hint` · `allowed-tools`). The grounding skill is inline (no `context: fork`) and `user-invocable` so it can also be run deliberately:

```yaml
---
name: qdev-grounding
description: "<the §4.1 auto-trigger text>"
argument-hint: "[topic]"
allowed-tools: Bash, Agent, AskUserQuestion, Read, mcp__brave-search__brave_web_search, mcp__serper-search__google_search, mcp__tavily-mcp__tavily_extract, mcp__plugin_context7_context7__resolve-library-id, mcp__plugin_context7_context7__query-docs, mcp__plugin_context7_context7__get-library-docs
---
```

- `Bash` — run `sanitize_query.py` and the (medium-path) D1 reporting-cycle scripts.
- `Agent` — dispatch `qdev:qdev-researcher` (medium); requires inline (D2-5).
- `AskUserQuestion` — the approval pauses (D2-2 risk gate, D2-7 persist gate).
- Both Context7 tool-name variants are granted (D1 SA-004 precedent: granting an unexposed name is a no-op).
- The exact tool list is pinned here so the plan cannot silently invent it; verify each name resolves in a plugin-loaded session during the trigger matrix.

---

## 4. The skill

### 4.1 Trigger `description` (make-or-break, eagerly matched)

The `description` frontmatter is the always-resident matcher. It must (a) fire when stuck or missing current data, (b) not over-fire on routine work, (c) convey "starts cheap, escalates" so Claude invokes it freely. The auto-trigger matching mechanism is undocumented (keyword / embedding / model-judged / hybrid); the text is written to read well under all of them and is verified empirically via the trigger matrix (§7), not assumed reliable.

> *Use when you're stuck or missing current information mid-task — the same command/API/approach failed twice, an error looks like a changed or deprecated API, or you need the current version of something, a fact from after your training cutoff, or to verify something you cannot confirm from the code in context. Starts with a cheap inline lookup and only escalates to a full research sweep if that fails. Do not use for routine pre-emptive checks before ordinary library work — for deliberate research, use `/qdev:research`.*

### 4.2 Entry routing (the lean decision tree in `SKILL.md`)

| Entry condition | Path |
| --- | --- |
| **Category A** — demonstrably stuck (same call failed ×2, ≥2 approaches failed, fix-then-same-failure, about to retry something already tried) | **sanitize the stuck-context handoff (§4.5) → medium** — dispatch `qdev-researcher` at `depth=quick` |
| **Category C** — context gap (needs latest version / post-cutoff fact / unverifiable claim / current ecosystem state) | **light path** (§4.3), escalate on failure |
| **Category B** — proactive pre-search | **not handled** — one-line "use `/qdev:research` instead"; never auto-fire |

The full detection-signal catalog for A/C and the B exclusion note live in `references/detection-and-egress.md` (D2-4), not in the eagerly-invoked body.

### 4.3 Light path (inline — no subagent, no report)

For one-off, low-stakes lookups: a current version, an API signature, "is library X still maintained?"

1. **Sanitize first (mandatory gate — §4.5).** Run `sanitize_query.py` on every outbound query *before* any MCP/Context7 call. `requires_human_approval: true` → pause, show `safe_query` + `dropped_fields`; **approve → send `safe_query`; reject → abort the auto-research, emit a one-line notice, proceed ungrounded** (D2-2). Otherwise send `safe_query`, preferring the lowest-risk allowed provider per `provider_allowed` (subject to D2-8: ZDR assumed absent).
2. **Docs-or-web gate.** If the lookup is *how to use* a named library/framework/SDK/API/CLI (syntax, config, version behavior) → **Context7 first** (resolve with candidate scoring — never the first match; score by exact-name · official-vs-community · reputation · snippet-count · benchmark · version-match · task-fit). **Bypass straight to the web stack** for latest-release / changelog / CVE / issue / PR / maintainer-status / roadmap / pricing / incident lookups, or when the library is missing / low-reputation / low-snippet / ambiguous.
3. **Web stack (light-path source rule — SA-004).** On the light path, **`brave_web_search` and `serper` (`google_search`) are both general-recall sources** (this differs from D1's Tavily-first model, which the medium path keeps). `brave_web_search` is primary; add `serper` as the second recall source (pass `gl: us, hl: en`; use its `site:`/`filetype:` operators when helpful). Use `tavily_extract` only to read one specific page in full. Route news/finance angles to Brave (`tavily_search` `topic` is `general`-only in the MCP schema; the light path does not use `tavily_search` for recall — token budget).
4. **Minimum search:** for any fact that will be acted on, use **≥2 recall sources** = `brave_web_search` + `serper` (never single-source). If only one recall provider is available/allowed, that is an **escalation signal**, not a license to single-source. Prefer the freshest result; include the current year for version/changelog queries.
5. **Output cap (context economy):** `max_results` 3–5, snippets over raw pages, no raw-content / crawl / base64-images by default. A lookup projected to exceed ~8k tokens of MCP output or need >1 extraction is an **escalation signal**, not light work.
6. **Rounds:** round 1 = the initial sweep meeting the minimum; round 2 = one refined retry (reworded/expanded queries, an added server, or a single `tavily_extract` on the best page). **After 2 unsuccessful rounds → escalate.** "Unsuccessful" = results thin / empty / conflicting, OR applied but the question/blocker persists. Escalate early (before round 2) if scope turns substantial or a blocker is confirmed.

### 4.4 Medium path (escalated, or Category-A direct)

Ordered gates — nothing external happens until each clears:

1. **Approval-before-dispatch (auto-fired runs only — D2-7, SA-NEW-001).** Because `qdev-researcher` writes the report and regenerates the index *internally before it returns* ([qdev-researcher.md:91-116]) and has no `AskUserQuestion`, the persist gate must precede dispatch. On a Category-A / escalation (auto) run, the skill confirms via `AskUserQuestion` — "run a full research sweep and persist a report to `docs/research/` on `<topic>`?" — and dispatches only on approval; reject → not dispatched, nothing written. Manual `/qdev:research` skips this gate.
2. **Sanitize the handoff (§4.5).** The stuck-context handoff clears the egress gate before any dispatch.
3. **Dispatch** **`qdev:qdev-researcher`** (qualified name — repo convention PLUGIN-001; a bare name no-ops) via the `Agent` tool at `depth=quick`. **Cost model = `qdev-researcher`'s existing quick mode as shipped** (≈3–4 queries plus its own deep-read and single follow-up bounds — [qdev-researcher.md:60,75,83]); D2 does **not** assume a lighter variant and does **not** modify the agent (SA-005). The handoff hands over what light found (queries tried, best links, why it stalled) so the subagent does not restart cold — already sanitized (D2-3), plus `qdev-researcher`'s own prose guardrail (defense in depth). It runs D1's **full reporting cycle** unchanged (frontmatter + `## Sources` + dedup + index regen). "Medium" is search *breadth*, not skipping the report.
4. **Announce before firing:** e.g. `Auto-research: <topic> (escalated after 2 light rounds)`. Return a compact result and hand control back.

### 4.5 The sanitize gate (shared by light + medium)

A single procedure the skill applies to any outbound payload (a light-path query, or the medium-path handoff text). **Transport (SA-002):** the skill writes the raw payload to a mode-`600` tmpfile, runs `uv run sanitize_query.py < tmpfile` (stdin — never argv, so the raw text never appears in process listings), then deletes the tmpfile. It then acts on the JSON:

- `requires_human_approval: true` → `AskUserQuestion` showing `safe_query` + `dropped_fields` (labels only). Approve → proceed with `safe_query`; reject → abort (light: proceed ungrounded; medium: do not dispatch, report the abort).
- `requires_human_approval: false` → proceed with `safe_query`, choosing a provider allowed by `provider_allowed` under D2-8.
- Sanitizer non-zero exit / malformed JSON / `uv` unavailable → **fail closed**: no external call, one-line notice, proceed ungrounded (light) or do not dispatch (medium).

---

## 5. The `sanitize_query.py` contract

A pure, deterministic PEP 723 script — `# requires-python = ">=3.11"`, `dependencies = []` (runs standalone via `uv run`; the empty list is mandatory per uv's PEP 723 rules — D1 CR-NEW-001). It exposes one testable function (`sanitize(text: str) -> dict`) the way D1's `dedup.py` exposes `decide()`. It **never** makes network calls and **never** decides routing; the skill owns send/abort/approval (§4.5).

### 5.1 Input contract (SA-002)

- **Reads the raw payload from stdin**, not from a command-line argument — raw text (tracebacks, logs, tokens) must not appear in argv or process listings.
- CLI: `uv run sanitize_query.py < tmpfile` (the §4.5 transport); the function form `sanitize(text)` is used by tests.
- **Threat model = egress, not local transcript (SA-002 scope).** Per the workstation security model, plaintext secrets may legitimately appear in local conversation/tool output (single-user, disk-encrypted) and the binding rule is "don't upload secrets to external services." The triggering error text already exists in local context, so the sanitizer's testable guarantee is **egress-safety**: `safe_query` is secret-free and is the only thing sent to a provider. It does not (and cannot) retroactively scrub the local transcript.

### 5.2 Pipeline (ordered — resolution-2 §2.3–2.4)

Detection families are **required acceptance criteria**, not an open question (SA-002). Pin them to recognized rule families (e.g. gitleaks / detect-secrets) so the set is reviewable and testable:

1. **Drop secrets** — token/key/credential families: provider API keys (`sk-…`, `ghp_…`/`gho_…`, `AKIA…` AWS, Google `AIza…`, Slack `xox[baprs]-…`), bearer/JWT tokens, `password=`/`api_key=`/`secret=` assignments, PEM/private-key blocks, and signed-URL query params (`?...&Signature=`/`X-Amz-Signature`).
2. **Strip private identifiers** — internal hostnames, Tailscale CGNAT IPs (`100.64.0.0/10`), absolute home/repo paths (`/home/<user>/…`), email addresses, and customer-like identifiers.
3. **Collapse stack traces** → public package · error-type · version terms only (drop file paths, line numbers, local frames).

### 5.3 Output (JSON — consumed like the dedup helper)

```json
{
  "safe_query": "<sanitized, generic task description>",
  "dropped_fields": ["secret:provider-api-key", "path:home-dir", "host:internal", "pii:email"],
  "provider_allowed": {"brave": true, "context7": true, "tavily": true, "serper": true},
  "requires_human_approval": false
}
```

- **`dropped_fields` carries redacted CLASS LABELS only — never raw substrings or values** (SA-002 ambiguity). `path:home-dir`, not `path:/home/chris/...`.
- `provider_allowed` ranks the *sanitized-but-still-external* query against per-provider risk verdicts (Brave lowest **only** with enterprise ZDR — assumed absent per D2-8; Context7 medium; Tavily/Serper high). It is a preference hint; it never overrides the approval gate.
- `requires_human_approval` is set `true` when secrets, regulated/customer data, or more than a tiny proprietary excerpt are detected → triggers the approval pause (D2-2). Ordinary private-identifier stripping (paths, hostnames, emails) is dropped silently and the safe query proceeds **only if** nothing in the higher-sensitivity set was detected; under D2-8 the script does not mark any provider "safe enough" to bypass approval for a flagged payload.

---

## 6. Component reuse summary

| Component | Origin | D2 action |
| --- | --- | --- |
| `qdev-researcher` agent | D1 | reuse unchanged (medium engine; existing quick mode) |
| Reporting cycle (`build_research_index`, `validate_research_frontmatter`, `dedup`, `_frontmatter`) | D1 | reuse unchanged (medium path runs it, gated by D2-7) |
| `sanitize_query.py` | D2 | new — stdin-driven; called by the skill's §4.5 gate |
| `research-grounding` skill | D2 | new — the only auto-trigger in the system; the egress choke point |

---

## 7. Verification

| Layer | What | How |
| --- | --- | --- |
| **Deterministic** | `sanitize_query.py` | pytest — one test per pipeline branch (each secret family, identifier strip, stack-trace collapse), both `requires_human_approval` branches, `provider_allowed` ranking, **no-leak assertions** (fake tokens / PEM / signed URLs / paths / hostnames / emails / customer-like ids never appear in `safe_query` *or* `dropped_fields`), stdin handling, malformed-output/fail-closed path, plus a **CLI smoke exercising the real §4.5 transport** (fake-token payload in a mode-`600` tmpfile → `uv run sanitize_query.py < tmpfile` → assert no secret in the JSON **and** the tmpfile is removed on both success and failure). Mirrors D1's `test_dedup.py` + CR-NEW-001 pattern. |
| **Trigger (manual)** | Fires on A/C, not on B | A documented **trigger matrix** in `references/`: ~5 Category-A prompts, ~5 Category-C, ~5 Category-B negatives; run in a plugin-loaded session, record fire/no-fire. Auto-trigger matching is undocumented and not unit-testable outside a live session — this is honestly manual, not fake-automated. Also confirm every `allowed-tools` name resolves. |
| **Safety (manual)** | The egress gate actually gates | A **Category-A entry carrying a fake token must pause at the approval prompt before any `Agent` dispatch or MCP call**; verify the **outbound payload sent to the provider** (the actual MCP-call args) and **argv** contain no fake token (egress-safety, not transcript-absence — §5.1 scope); verify reject → abort with no dispatch. |
| **End-to-end (manual)** | Escalation + dispatch gate | Light path writes nothing, uses ≥2 recall sources, escalates after 2 rounds; an **auto-fired medium run pauses for approval *before dispatch*** — reject → nothing dispatched and `git status --short` stays clean; approve → `qdev-researcher` writes the report + index per the D1 cycle. Manual `/qdev:research` persists with no extra gate. |

**Testing philosophy (from D1):** deterministic logic gets pytest; judgment gets a documented manual matrix. We deliberately do **not** fake-automate the trigger with a `description`-substring assertion — that would test the static text, not the runtime matcher, and produce a green check that proves nothing.

---

## 8. Out of scope (deferred — carried from D1 §12)

- **`qdev doctor` preflight command** — the §4.5 fail-soft/fail-closed fallback covers essential degrade behavior; a standalone doctor is optional.
- **`brave_llm_context` as the light-path primary** — pending the resolution-2 §3.6 paired-workflow token benchmark (D2-6 ships the conservative default).
- **The empirical benchmark harness** (backlog topics 4–7) — a measurement task that would replace research-informed thresholds (p95 < 5 s, footprint < 3,000 tokens, precision@5 > 0.60, stale < 20%) with measured ones; not a build blocker.
- **Retrofitting `sanitize_query.py` into `qdev-researcher`** — D2-3 keeps enforcement in the skill; a later cycle may unify it into the agent.
- **Retrofitting `docs/research/qdev/` meta-docs** with frontmatter — build research about qdev, not the runtime KB.

---

## 9. Repo-doc & metadata touchpoints (for the plan)

- `plugins/qdev/README.md` — **reword [P2] per D2-9** (commands explicit-only; the one grounding skill is the deliberate auto-trigger exception; fix stale "all three" → current count); add the grounding skill (light/medium escalation + sanitizer gate) to Summary/Requirements.
- `plugins/qdev/.claude-plugin/plugin.json` — **version bump** (1.5.0 → next) + description mentions the grounding skill (SA-007).
- `.claude-plugin/marketplace.json` — matching qdev `version` + `description` update (SA-007).
- `plugins/qdev/CHANGELOG.md` — `[Unreleased]` Added entries (skill + sanitizer).
- `docs/conventions.md` TEST-001 — bump qdev's pytest count to include `test_sanitize_query.py`.
- `docs/architecture.md` — qdev now ships a skill + a second script family + its first auto-trigger.
- **No global `~/.claude/CLAUDE.md` change** — D1 already reconciled the per-path routing guidance (D1 Task 8).
- `docs/specs-plans.md` — index this design + (later) its plan.
- **Post-implementation:** run `./scripts/validate-marketplace.sh`; grep README for stale explicit-only language.

---

## 10. Prerequisites & open questions

**Prerequisite (gate before D2 ships):**

- **D1 plugin-loaded manual smoke** — `docs/state.md` records D1's `/qdev:research` dispatch smoke as still pending. D2's medium path *is* that dispatch, so run/confirm the D1 smoke before (or as the first step of) D2 acceptance (SA / missing-consideration).

**Open questions (non-blocking):**

- **Skill directory / `name`** — `research-grounding` dir + `qdev-grounding` name are provisional. Note (round-2 audit): for a plugin `skills/<dir>/SKILL.md`, the deliberate slash command derives from the **directory name** (→ `/qdev:research-grounding`), while `name:` is display metadata — so pick the directory name with the intended command in mind. Confirm against any qdev skill-naming convention at plan time.
- **Trigger `description` final wording** — §4.1 is the proposed text; it is the make-or-break field and may be tuned during the manual trigger-matrix pass.

*(Resolved in audit round 1 and no longer open: the secret/identifier pattern set — now required acceptance criteria, §5.2; sanitizer invocation safety — stdin, §5.1; provider/ZDR posture — fail-closed, D2-8.)*

---

## 11. Component isolation check

- **`sanitize_query.py`** — does one thing (text → redaction decision); pure, no network, no routing; testable in isolation by `sanitize(text)`.
- **The skill** — owns judgment (category detection, routing, escalation, approval, dispatch); depends on the script (deterministic facts) and `qdev-researcher` (medium engine) through well-defined interfaces (stdin/JSON; the `Agent` dispatch contract).
- **`qdev-researcher` + reporting cycle** — unchanged D1 units; the skill consumes them without reaching inside.

---

## 12. Spec-review audit ledger

**Round 1 (2026-06-03, external adversarial review):** verdict *needs major correction* — 3 blocking + 4 non-blocking. All verified against repo truth (README [P2], `plugin.json`/`marketplace.json` at v1.5.0, `qdev-researcher` quick-mode lines 60/75/83, up-docs skill frontmatter convention) and current external docs (Claude subagent limits, uv PEP 723, Tavily MCP `topic`, Brave ZDR/DPA, OWASP LLM01). All resolved:

| ID | Severity | Resolution |
| --- | --- | --- |
| SA-001 | High | Enforcement relocated to the inline skill (D2-3, §4.5): light queries **and** the Category-A/escalation handoff are sanitized before any MCP call or `Agent` dispatch. `qdev-researcher` stays unmodified. G3/G4 reworded. |
| SA-002 | High | Sanitizer reads payload from **stdin** (§5.1, no argv leak); `dropped_fields` = **redacted class labels only** (§5.3); detection families promoted to **required** acceptance criteria with named rule families (§5.2); fail-closed handling for malformed output / missing `uv` (§4.5, D2-8); no-leak unit tests (§7). |
| SA-003 | High | **Fail-closed egress, Brave ZDR assumed absent** (D2-8): no provider auto-sends a flagged payload; ZDR-dependent "Brave lowest" never bypasses approval. |
| SA-004 | Medium | Explicit light-path source rule (§4.3 steps 3–4): Brave + Serper are both general recall on the light path; single-provider availability is an escalation signal, not single-sourcing. |
| SA-005 | Medium | Medium cost model corrected to `qdev-researcher`'s **shipped** quick mode (§4.4); invented "skip follow-up / cap deep-reads" removed; agent stays unchanged. |
| SA-006 | Medium | Full SKILL.md frontmatter contract pinned (§3.1): `name`/`description`/`argument-hint`/`allowed-tools` with the exact tool list; both Context7 variants granted. |
| SA-007 | Medium | README **[P2] reworded** (D2-9); `plugin.json` + `marketplace.json` version-bump + description; `validate-marketplace.sh` + stale-language grep added to §9. |

**Decisions taken during the round (user):** reject-flagged-query → abort & proceed ungrounded (D2-2); auto-fired medium → approval-before-persist (D2-7); P2 → reword to scope commands + carve out the grounding skill (D2-9).

**Round 2 (2026-06-03, external adversarial review):** verdict *needs major correction* — 6 of 7 resolved, SA-002 partial, 1 new blocking, 0 regressions. Verified against `qdev-researcher.md` (Write tool, no `AskUserQuestion`, internal persist at lines 91–116) and the workstation security model. Both resolved:

| ID | Severity | Resolution |
| --- | --- | --- |
| SA-002 | High (partial → resolved) | Transport pinned: mode-`600` tmpfile + `uv run … < tmpfile` (stdin, no argv/process-listing leak), then deleted (§4.5, §5.1). The "no transcript line" acceptance claim was **over-scoped vs the workstation security model** (local plaintext is acceptable; egress is the boundary) — narrowed to **egress-safety**: `safe_query` is secret-free and is the only payload sent externally; tests assert no secret in the outbound MCP-call args or argv (§5.1, §7). |
| SA-NEW-001 | High | `qdev-researcher` persists internally before returning and lacks `AskUserQuestion`, so "approval before persist" was impossible without changing D1. Resolved by moving the gate to **approval-before-dispatch** on auto-fired runs (D2-7, §4.4): the skill confirms before dispatching; reject → never dispatched, nothing written. D1 stays unchanged; gates before token spend. |

**Decisions taken (round 2, user):** SA-NEW-001 → approval-before-dispatch (over modifying `qdev-researcher` or a D2 persistence wrapper). SA-002 egress-scoping applied under the workstation security model (binding rule: don't upload secrets externally).

**Round 3 (2026-06-03, external adversarial review):** verdict *no significant findings remain; the audit/fix loop can stop.* SA-001…007 + SA-NEW-001 all confirmed resolved, 0 regressions. One new low-severity polish, fixed:

| ID | Severity | Resolution |
| --- | --- | --- |
| SA-NEW-002 | Low | §7's deterministic CLI-smoke row still named the old `printf \| uv run` form after the §5.1 transport changed to `< tmpfile`. Updated to smoke the real §4.5 transport (mode-`600` tmpfile → `uv run … < tmpfile` → assert no secret in JSON + tmpfile removed on success/failure). |

**Audit loop closed (round 3 clean).** Spec is execution-ready.

**Carry-forward to plan/implementation validation:** D1 plugin-loaded smoke (prerequisite, §10); live auto-trigger reliability via the trigger matrix; the fake-token **egress** safety smoke (§7 — outbound args + argv, not transcript); auto-fired medium reject→clean-tree / approve→writes (§7); `allowed-tools` name resolution in a plugin-loaded session.
