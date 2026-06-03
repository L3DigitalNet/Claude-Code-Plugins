# qdev D2 — Escalating Grounding Skill + Programmatic Egress Sanitizer (Design)

**Status:** Design approved (brainstorm 2026-06-03); ready for `superpowers:writing-plans`.
**Created:** 2026-06-03
**Owner harness:** Claude Code (Opus)
**Scope:** Deliverable 2 only — the auto-trigger grounding skill plus the programmatic egress sanitizer it depends on. Adjacent items remain deferred (see §8).
**Source brief:** [`docs/research/qdev/qdev-expansion-brief.md`](../research/qdev/qdev-expansion-brief.md) — "Deliverable 2 — The escalating grounding skill" + "Triggering reference".
**Backing research:** `docs/research/qdev/` — `qdev-research-backlog-resolution.md` (§9 External Content Safety), `qdev-research-backlog-resolution-2.md` (§2.3–2.4 sanitizer spec, §3.6–3.7 routing thresholds).
**Builds on:** D1 — [`docs/plans/2026-06-03-qdev-research-reporting-design.md`](2026-06-03-qdev-research-reporting-design.md) (shipped; reporting cycle + `qdev-researcher` routing). D2 reuses D1's engine unchanged.

---

## 1. Goal

Claude Code often fails to search when it should — it loops on a broken approach or trusts stale training data for fast-moving libraries/APIs. `/qdev:research` covers *deliberate* research, but nothing fires *automatically* mid-task. D2 fills that gap cheaply: one auto-invoked skill that starts with an inline lookup and escalates to the full `qdev-researcher` sweep only when the cheap path fails. Because the skill auto-fires on raw error text (the most likely place for a secret or internal hostname to appear), it ships with a programmatic egress sanitizer that runs before any outbound query.

**Success criteria:**

- **G1.** The skill fires reliably when the agent is stuck (Category A) or missing current information (Category C), and does **not** over-fire on routine work (Category B excluded).
- **G2.** The light path is genuinely cheap: no subagent, no report, output-capped, escalating to medium only on failure.
- **G3.** Category-A "already stuck" enters the medium path directly (a full sweep + persisted report is warranted).
- **G4.** Every auto-fired outbound query is sanitized deterministically before it leaves the machine; un-sanitizable queries pause for human approval rather than leaking or silently dropping.
- **G5.** The medium path reuses D1's `qdev-researcher` + reporting cycle unchanged.

---

## 2. Locked decisions (brainstorm 2026-06-03)

| # | Decision | Source |
| --- | --- | --- |
| D2-1 | **Scope = skill + programmatic sanitizer.** `qdev doctor`, the `brave_llm_context` light-primary benchmark, the empirical benchmark harness, and the meta-doc retrofit are all deferred (§8). | Q1 |
| D2-2 | **`requires_human_approval` → surface to user.** On a flagged auto-fired query the skill pauses and shows `safe_query` + `dropped_fields`, sending only on approval. Prioritizes not silently losing a wanted lookup; the flag only trips on the risky subset, so friction is rare. | Q2 |
| D2-3 | **Sanitizer is light-path-only.** It enforces egress on the auto-fired light path (highest-leak surface). The medium path keeps D1's prose guardrail and receives an already-sanitized handoff. D2 does **not** re-touch shipped D1 code. | Q3 |
| D2-4 | **Skill shape C — skill + reference (progressive disclosure).** Lean `SKILL.md` (trigger + escalation tree + medium dispatch); a `references/` file holds the verbose Category catalog, Category-B note, per-provider egress verdicts, and dedup pointer. Keeps the invoked body small — the light path's whole point is context economy. | Q4 |
| D2-5 | **One inline skill, escalating.** Not `context: fork` — a forked skill runs as a subagent and loses the `Agent` tool, so it could never dispatch `qdev-researcher`. The single auto-trigger lives on the inline entry; the medium path never self-triggers. | Brief (locked) |
| D2-6 | **Light primary = `brave_web_search` + targeted `tavily_extract`**, not `brave_llm_context`. The brief's decision rule (resolution-2 §3.6) adopts `brave_llm_context` only if it stays under ~5k serialized tokens; its 8,192-token default busts the <3,000-token light-path budget. Ship the conservative default; the benchmark that could flip this is deferred. | resolution-2 §3.6 |

---

## 3. Architecture & file layout

```text
plugins/qdev/
  skills/
    research-grounding/
      SKILL.md                      # trigger description + entry routing + escalation tree + medium dispatch
      references/
        detection-and-egress.md     # Category A/C catalog, Category-B note,
                                     # per-provider egress verdicts, dedup-reuse pointer
  scripts/
    sanitize_query.py               # NEW — PEP 723, dependencies = []; the egress sanitizer (light-path-only)
  tests/
    test_sanitize_query.py          # NEW — pytest, one test per pipeline + approval branch + CLI smoke
```

**Reused from D1 (unchanged):** `agents/qdev-researcher.md` (medium engine), `scripts/build_research_index.py`, `scripts/validate_research_frontmatter.py`, `scripts/dedup.py`, `scripts/_frontmatter.py`.

**Net new in D2:** one skill (2 files) + one script + one test file. No D1 file is modified.

---

## 4. The skill

### 4.1 Trigger `description` (make-or-break, eagerly matched)

The `description` frontmatter is the always-resident matcher. It must (a) fire when stuck or missing current data, (b) not over-fire on routine work, (c) convey "starts cheap, escalates" so Claude invokes it freely. The auto-trigger matching mechanism is undocumented (keyword / embedding / model-judged / hybrid); the text is written to read well under all of them and is verified empirically (§7), not assumed reliable.

> *Use when you're stuck or missing current information mid-task — the same command/API/approach failed twice, an error looks like a changed or deprecated API, or you need the current version of something, a fact from after your training cutoff, or to verify something you cannot confirm from the code in context. Starts with a cheap inline lookup and only escalates to a full research sweep if that fails. Do not use for routine pre-emptive checks before ordinary library work — for deliberate research, use `/qdev:research`.*

### 4.2 Entry routing (the lean decision tree in `SKILL.md`)

| Entry condition | Path |
| --- | --- |
| **Category A** — demonstrably stuck (same call failed ×2, ≥2 approaches failed, fix-then-same-failure, about to retry something already tried) | **medium directly** — dispatch `qdev-researcher` at `depth=quick` |
| **Category C** — context gap (needs latest version / post-cutoff fact / unverifiable claim / current ecosystem state) | **light path**, escalate on failure |
| **Category B** — proactive pre-search | **not handled** — one-line "use `/qdev:research` instead"; never auto-fire |

The full detection-signal catalog for A/C and the B exclusion note live in `references/detection-and-egress.md` (D2-4), not in the eagerly-invoked body.

### 4.3 Light path (inline — no subagent, no report)

For one-off, low-stakes lookups: a current version, an API signature, "is library X still maintained?"

1. **Sanitize first (mandatory).** Run `sanitize_query.py` (§5) on every outbound query *before* any MCP/Context7 call. If it returns `requires_human_approval: true`, **pause and surface `safe_query` + `dropped_fields` to the user** (D2-2); send only on approval. Otherwise send `safe_query`, preferring the lowest-risk allowed provider per `provider_allowed`.
2. **Docs-or-web gate.** If the lookup is *how to use* a named library/framework/SDK/API/CLI (syntax, config, version behavior) → **Context7 first** (resolve with candidate scoring — never the first match; score by exact-name · official-vs-community · reputation · snippet-count · benchmark · version-match · task-fit). **Bypass straight to the web stack** for latest-release / changelog / CVE / issue / PR / maintainer-status / roadmap / pricing / incident lookups, or when the library is missing / low-reputation / low-snippet / ambiguous.
3. **Web stack:** `brave_web_search` primary (D2-6) → `serper` only for Google-specific operators (`site:`, `filetype:`; always `gl: us, hl: en`) → `tavily_extract` only to read one specific page in full. Route news/finance angles to Brave (`tavily_search` `topic` is `general`-only in the MCP schema).
4. **Minimum search:** **≥2 of {brave, serper}** for any fact that will be acted on (never single-source); prefer the freshest result; include the current year for version/changelog queries.
5. **Output cap (context economy):** `max_results` 3–5, snippets over raw pages, no raw-content / crawl / base64-images by default. A lookup projected to exceed ~8k tokens of MCP output or need >1 extraction is an **escalation signal**, not light work.
6. **Rounds:** round 1 = the initial sweep meeting the minimum; round 2 = one refined retry (reworded/expanded queries, an added server, or a single `tavily_extract` on the best page). **After 2 unsuccessful rounds → escalate.** "Unsuccessful" = results thin / empty / conflicting, OR applied but the question/blocker persists. Escalate early (before round 2) if scope turns substantial or a blocker is confirmed.

### 4.4 Medium path (escalated, or Category-A direct)

- Dispatch **`qdev:qdev-researcher`** (qualified name — repo convention PLUGIN-001; a bare name no-ops) via the `Agent` tool at `depth=quick`: 3–4 queries, skip the follow-up pass (or cap deep-reads at ~2); thin angles become Open Questions. "Medium" is search *breadth*, not skipping the report.
- Hand over what light found: queries tried, best links, why it stalled — so the subagent does not restart cold. This handoff is already sanitized (the light path sanitized every query before sending), so the medium path inherits clean input plus `qdev-researcher`'s own prose guardrail (defense in depth — D2-3).
- Runs D1's **full reporting cycle** (frontmatter + `## Sources` + dedup + index regen) — reused unchanged.
- **Announce before firing:** e.g. `Auto-research: <topic> (escalated after 2 light rounds)`. Return a compact result and hand control back.

---

## 5. The `sanitize_query.py` contract

A pure, deterministic PEP 723 script — `# requires-python = ">=3.11"`, `dependencies = []` (runs standalone via `uv run`; the empty list is mandatory per uv's PEP 723 rules — D1 CR-NEW-001). It exposes one testable function the way D1's `dedup.py` exposes `decide()`. It **never** makes network calls and **never** decides routing; the skill owns the send/skip/approval judgment.

### 5.1 Pipeline (ordered — resolution-2 §2.3–2.4)

1. **Drop secrets** — token/key/credential patterns: `sk-…`, `ghp_…`/`gho_…`, AWS access keys (`AKIA…`), bearer tokens, `password=`/`api_key=` assignments, PEM blocks.
2. **Strip private identifiers** — internal hostnames, Tailscale CGNAT IPs (`100.64.0.0/10`), absolute home/repo paths (`/home/<user>/…`), customer/email identifiers.
3. **Collapse stack traces** → public package · error-type · version terms only (drop file paths, line numbers, local frames).

### 5.2 Output (JSON — consumed like the dedup helper)

```json
{
  "safe_query": "<sanitized, generic task description>",
  "dropped_fields": ["secret:bearer-token", "path:/home/<user>/...", "host:internal"],
  "provider_allowed": {"brave": true, "context7": true, "tavily": true, "serper": true},
  "requires_human_approval": false
}
```

- `provider_allowed` ranks the *sanitized-but-still-external* query against the per-provider risk verdicts (Brave lowest — and only with enterprise ZDR; Context7 medium; Tavily/Serper high), letting the skill prefer the lowest-risk provider for a borderline query.
- `requires_human_approval` is set `true` when secrets, regulated/customer data, or more than a tiny proprietary excerpt are detected → triggers the surface-to-user pause (D2-2). For ordinary private-identifier stripping (paths, hostnames) it stays `false` — those are dropped silently and the safe query proceeds.

### 5.3 CLI

```text
uv run sanitize_query.py --query "<raw text>"        # prints the JSON above
```

---

## 6. Component reuse summary

| Component | Origin | D2 action |
| --- | --- | --- |
| `qdev-researcher` agent | D1 | reuse unchanged (medium engine) |
| Reporting cycle (`build_research_index`, `validate_research_frontmatter`, `dedup`, `_frontmatter`) | D1 | reuse unchanged (medium path runs it) |
| `sanitize_query.py` | D2 | new — light-path-only |
| `research-grounding` skill | D2 | new — the only auto-trigger in the system |

---

## 7. Verification

| Layer | What | How |
| --- | --- | --- |
| **Deterministic** | `sanitize_query.py` | pytest — one test per pipeline branch (secret drop, identifier strip, stack-trace collapse), both `requires_human_approval` branches (set / not-set), `provider_allowed` ranking, plus a CLI smoke (`uv run sanitize_query.py …`) since the suite imports the function directly. Mirrors D1's `test_dedup.py` + CR-NEW-001 pattern. |
| **Trigger (manual)** | Fires on A/C, not on B | A documented **trigger matrix** in `references/`: ~5 Category-A prompts, ~5 Category-C, ~5 Category-B negatives; run in a plugin-loaded session, record fire/no-fire. Auto-trigger matching is undocumented and not unit-testable outside a live session — this is honestly manual, not fake-automated. |
| **End-to-end (manual)** | Escalation + medium report | Light path writes nothing, uses ≥2 services, escalates after 2 rounds; a Category-A entry skips light and produces a `qdev-researcher` report via the D1 cycle; a query containing a secret pauses for approval. |

**Testing philosophy (from D1):** deterministic logic gets pytest; judgment gets a documented manual matrix. We deliberately do **not** fake-automate the trigger with a `description`-substring assertion — that would test the wrong layer (the static text, not the runtime matcher) and produce a green check that proves nothing.

---

## 8. Out of scope (deferred — carried from D1 §12)

- **`qdev doctor` preflight command** — the light path's fail-soft fallback (Context7 → Brave → Serper, degrade with a one-line notice) covers essential degrade behavior; a standalone doctor is optional.
- **`brave_llm_context` as the light-path primary** — pending the resolution-2 §3.6 paired-workflow token benchmark (D2-6 ships the conservative default).
- **The empirical benchmark harness** (backlog topics 4–7) — a measurement task that would replace research-informed thresholds (p95 < 5 s, footprint < 3,000 tokens, precision@5 > 0.60, stale < 20%) with measured ones; not a build blocker.
- **Retrofitting `sanitize_query.py` into `qdev-researcher`** — D2-3 keeps it light-path-only; a later cycle may unify enforcement.
- **Retrofitting `docs/research/qdev/` meta-docs** with frontmatter — build research about qdev, not the runtime KB.

---

## 9. Repo-doc touchpoints (for the plan)

- `plugins/qdev/README.md` — add the grounding skill (light/medium escalation) + the sanitizer to the feature list.
- `plugins/qdev/CHANGELOG.md` — `[Unreleased]` Added entries (skill + sanitizer).
- `docs/conventions.md` TEST-001 — bump qdev's pytest count to include `test_sanitize_query.py`.
- `docs/architecture.md` — qdev now ships a skill + a second script family.
- **No global `~/.claude/CLAUDE.md` change** — D1 already reconciled the per-path routing guidance (D1 Task 8).
- `docs/specs-plans.md` — index this design + (later) its plan.

---

## 10. Open questions (non-blocking)

- **Secret/identifier pattern set** — the §5.1 list is representative; the plan should pin the exact regex set and cite a source (e.g. common detect-secrets / gitleaks rule families) so it is reviewable and testable, not ad hoc.
- **Skill directory name** — `research-grounding` is provisional; confirm against any qdev skill-naming convention at plan time.
- **Trigger `description` final wording** — §4.1 is the proposed text; it is the make-or-break field and may be tuned during the manual trigger-matrix pass.
