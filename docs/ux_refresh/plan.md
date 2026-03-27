# UX Refresh: Nominal-Style References Architecture

Converting plugins from skill-heavy designs to the pattern established by the `nominal` plugin: commands as thin orchestrators, domain knowledge in `references/`, zero idle context footprint.

## The Pattern

The nominal plugin demonstrates three properties that reduce context waste and skill menu pollution:

1. **Commands as thin orchestrators.** Define the procedure (steps, decision points, critical rules) but contain no domain knowledge inline. ~80-120 lines each.
2. **`references/` for on-demand knowledge.** Domain specs, schemas, checklists, and UX templates live in `references/` and are loaded via `Read ${CLAUDE_PLUGIN_ROOT}/references/...` only when a command needs them.
3. **No skills.** Nothing auto-loaded into context, nothing in the skill menu. The command is the sole entry point.

Supporting elements: UX templates in references ensure consistent, polished output across invocations.

## Conversion Queue

### 1. design-assistant

**Current state:** 2 commands (design-draft: 1,537 lines, design-review: 1,099 lines), 2 stub skills (21 + 18 lines)

**Problem:** Commands embed all criteria, output templates, and frameworks inline. Every invocation loads the full 1,500+ line command even when only one phase is needed.

**Plan:**
- [x] Extract shared infrastructure into 7 reference files
- [x] Extract output templates into `references/ux-templates.md` (37 templates)
- [x] Rewrite design-draft.md (1,538 → 990 lines)
- [x] Rewrite design-review.md (1,099 → 686 lines)
- [x] Delete the 2 stub skills
- [x] Update README.md
- [x] Bump version

---

### 2. github-repo-manager

**Current state:** 1 command, 15 skills (3,336 lines total), templates, helper CLI

**Problem:** 15 skills in the skill menu that are only relevant when `/repo-manager` is active. The command already reads one skill on demand; the pattern is half-adopted.

**Plan:**
- [x] Convert all 15 skills to files in `references/`
- [x] Update command to read the appropriate reference per user selection/module
- [x] Preserve the helper CLI and templates (no change)
- [x] Delete the `skills/` directory
- [x] Update README.md
- [x] Bump version

---

### 3. qt-suite

**Current state:** 6 commands, 16 skills (2,548 lines), 6 agents, 1 template

**Problem:** 16 domain skills (qt-threading, qt-packaging, etc.) occupy the skill menu. Commands could load matching references directly.

**Plan:**
- [ ] Convert 16 skills to `references/` files
- [ ] Update each command to read the relevant reference(s)
- [ ] Keep agents (they load independently)
- [ ] Delete the `skills/` directory
- [ ] Update README.md
- [ ] Bump version

---

### 4. test-driver

**Current state:** 2 commands, 10 skills (1,518 lines) including 5 stack profiles

**Problem:** Stack profiles are pure reference data. Workflow skills (gap-analysis, convergence-loop) are only used by commands.

**Plan:**
- [ ] Move 5 stack profiles to `references/profiles/`
- [ ] Move gap-analysis, convergence-loop, test-design, test-status to `references/`
- [ ] Keep `testing-mindset` as the sole skill (68 lines, always-on by design)
- [ ] Update commands to read references
- [ ] Delete converted skills
- [ ] Update README.md
- [ ] Bump version

---

### 5. home-assistant-dev (partial)

**Current state:** 2 commands, 27 skills (4,167 lines), 3 agents, templates, MCP server

**Problem:** Many skills are pure reference material (API docs, device classes, quality checklists) that don't benefit from contextual auto-loading.

**Plan:**
- [ ] Identify which skills genuinely benefit from contextual loading (~10 core ones)
- [ ] Move remaining ~17 reference-heavy skills to `references/`
- [ ] Skills already containing `reference/` subdirs get consolidated
- [ ] Update commands to read references where applicable
- [ ] Update README.md
- [ ] Bump version

---

### 6. python-dev (minimal)

**Current state:** 1 command, 11 skills (5,288 lines)

**Problem:** Skills are designed as always-on contextual knowledge and work well as-is. Only the `/python-code-review` command could benefit.

**Plan:**
- [ ] Keep all 11 skills (they serve contextual auto-loading correctly)
- [ ] Extract review checklists from the command into `references/review-domains.md`
- [ ] Update README.md
- [ ] Bump version

---

## Not Converting

| Plugin | Reason |
|--------|--------|
| nominal | Reference implementation of this pattern |
| release-pipeline | Already dispatches to `templates/mode-*.md` |
| linux-sysadmin | Already uses `guides/*/references/` |
| repo-hygiene | 1 self-contained command, no skills |
| opus-context | 1 always-on behavioral skill (correct design) |
| docs-manager | Tiny skills (13-15 lines), low conversion value |
| plugin-test-harness | TypeScript MCP tool, no skills/commands |

## Session Log

| Date | Plugin | Status | Notes |
|------|--------|--------|-------|
| 2026-03-27 | — | Planning | Initial analysis and plan created |
| 2026-03-27 | github-repo-manager | Complete | 15 skills → 14 references, self-test deleted, command rewritten as thin orchestrator, v0.4.0 |
| 2026-03-27 | design-assistant | Complete | 7 shared references + 37 UX templates extracted, both commands slimmed ~36%, stubs deleted, v0.4.0 |
