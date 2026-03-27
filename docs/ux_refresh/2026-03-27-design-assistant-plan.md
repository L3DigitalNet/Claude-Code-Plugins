# design-assistant References Architecture — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract shared infrastructure and output templates from two massive commands (2,636 lines combined) into `references/`, cutting each command roughly in half while preserving identical behavior.

**Architecture:** Extract shared sections (interaction conventions, state model, pause/resume, operational commands, handoff, interview rules) and all formatted output blocks into reference files. Commands keep phase procedures but replace inline content with `Read ${CLAUDE_PLUGIN_ROOT}/references/...` pointers.

**Tech Stack:** Markdown, bash (validation scripts)

**Spec:** `docs/ux_refresh/2026-03-27-design-assistant-design.md`

---

### Task 1: Create references directory

**Files:**
- Create: `plugins/design-assistant/references/` (directory)

- [ ] **Step 1: Create directory**

```bash
mkdir -p plugins/design-assistant/references
```

---

### Task 2: Extract shared references from both commands

**Files:**
- Create: `plugins/design-assistant/references/interaction-conventions.md`
- Create: `plugins/design-assistant/references/operational-commands.md`
- Create: `plugins/design-assistant/references/interview-rules.md`
- Create: `plugins/design-assistant/references/handoff-contract.md`
- Source: `plugins/design-assistant/commands/design-draft.md` (lines 17-41, 1477-1498, 1502-1538, 1190-1261)
- Source: `plugins/design-assistant/commands/design-review.md` (lines 15-41, 1057-1099)

These are the simpler extractions — self-contained sections that can be cut directly.

- [ ] **Step 1: Create `references/interaction-conventions.md`**

Read design-draft.md lines 17-41 (## INTERACTION CONVENTIONS). This section is nearly identical in design-review.md lines 15-41. Write the content to `references/interaction-conventions.md` with a `# Interaction Conventions` heading.

- [ ] **Step 2: Create `references/operational-commands.md`**

Read design-draft.md lines 1477-1498 (## OPERATIONAL COMMANDS) and design-review.md lines 1057-1099 (## OPERATIONAL COMMANDS). Combine into a single file with two sections: "## design-draft Commands" and "## design-review Commands". Shared commands (pause, continue, finalize, back, skip) go in a "## Shared Commands" section at the top to avoid duplication.

- [ ] **Step 3: Create `references/interview-rules.md`**

Read design-draft.md lines 1502-1538 (## INTERVIEW CONDUCT RULES). Write to `references/interview-rules.md`. This is design-draft specific but extracted to reduce command size.

- [ ] **Step 4: Create `references/handoff-contract.md`**

Read design-draft.md lines 1190-1279 (### /design-draft → /design-review Handoff Contract, through the handoff announcement). Write to `references/handoff-contract.md`.

- [ ] **Step 5: Commit**

```bash
git add plugins/design-assistant/references/interaction-conventions.md \
       plugins/design-assistant/references/operational-commands.md \
       plugins/design-assistant/references/interview-rules.md \
       plugins/design-assistant/references/handoff-contract.md
git commit -m "refactor(design-assistant): extract shared references from commands"
```

---

### Task 3: Extract session state models

**Files:**
- Create: `plugins/design-assistant/references/session-state.md`
- Source: `plugins/design-assistant/commands/design-draft.md` (lines 166-371, ## SESSION STATE MODEL)
- Source: `plugins/design-assistant/commands/design-review.md` (lines 80-310, ## SESSION STATE MODEL)

- [ ] **Step 1: Create `references/session-state.md`**

Read both state model sections. Write to `references/session-state.md` organized as:

```markdown
# Session State Models

## design-draft State Model
[content from design-draft lines 166-371]

## design-review State Model
[content from design-review lines 80-310]
```

Keep both models complete and separate within the file. Each command reads its own section.

- [ ] **Step 2: Commit**

```bash
git add plugins/design-assistant/references/session-state.md
git commit -m "refactor(design-assistant): extract session state models to reference"
```

---

### Task 4: Extract pause/resume and early exit protocols

**Files:**
- Create: `plugins/design-assistant/references/pause-resume.md`
- Source: `plugins/design-assistant/commands/design-draft.md` (lines 1283-1473: EARLY EXIT PROTOCOL + PAUSE STATE SNAPSHOT)
- Source: `plugins/design-assistant/commands/design-review.md` (lines 908-1015: PAUSE STATE SNAPSHOT + EARLY EXIT PROTOCOL)

- [ ] **Step 1: Create `references/pause-resume.md`**

Read both pause/resume/early-exit sections. Write to `references/pause-resume.md` organized as:

```markdown
# Pause, Resume & Early Exit

## Shared Behavior
[Common patterns: pause emits snapshot, continue restores, finalize triggers early exit]

## design-draft Pause Snapshot
[Snapshot format from design-draft lines 1375-1473]

## design-draft Early Exit Protocol
[Early exit from design-draft lines 1283-1371]

## design-review Pause Snapshot
[Snapshot format from design-review lines 908-995]

## design-review Early Exit Protocol
[Early exit from design-review lines 997-1015]
```

- [ ] **Step 2: Commit**

```bash
git add plugins/design-assistant/references/pause-resume.md
git commit -m "refactor(design-assistant): extract pause/resume protocols to reference"
```

---

### Task 5: Create UX templates

**Files:**
- Create: `plugins/design-assistant/references/ux-templates.md`
- Source: All formatted output blocks from both commands

- [ ] **Step 1: Create `references/ux-templates.md`**

Extract every formatted output block (code-fenced template blocks) from both commands into a numbered template file. Follow the same pattern as github-repo-manager's ux-templates.md: design principles, visual grammar, then numbered templates.

**From design-draft, extract these templates:**

| Template # | Name | Source lines (approx) |
|---|---|---|
| 1 | Entry Point Confirmation | lines 62-70 |
| 2 | Entry Point Error — File Not Found | lines 76-89 |
| 3 | Entry Point Error — Unexpected File Type | lines 95-106 |
| 4 | Entry Point — Argument Ambiguous | lines 113-123 |
| 5 | Entry Point — Possible Wrong Command | lines 131-147 |
| 6 | Orientation Questions (Q1-Q2) | lines 386-397 |
| 7 | Orientation Summary | lines 415-426 |
| 8 | Context Deep Dive — Round 1 | lines 438-458 |
| 9 | Tension Detected (Phase 1) | lines 467-474 |
| 10 | Context Deep Dive — Round 2 | lines 481-501 |
| 11 | Context Deep Dive — Round 3 (Quality) | lines 512-538 |
| 12 | Context Synthesis | lines 562-578 |
| 13 | Candidate Principles Summary (compact) | lines 604-624 |
| 14 | Candidate Principles (full details) | lines 638-651 |
| 15 | Stress Test Questions | lines 662-690 |
| 16 | Stress Test Verdict | lines 695-718 |
| 17 | Tension Resolution Scenario | lines 771-799 |
| 18 | Tension Resolution Log | lines 808-814 |
| 19 | Registry Lock (compact) | lines 826-847 |
| 20 | Registry Lock (full details) | lines 853-889 |
| 21 | Phase 3 — Section Structure | lines 905-930 |
| 22 | Phase 4 — Content Questions | lines 953-967 |
| 23 | Phase 4 — Coverage Sweep | lines 1001-1011 |
| 24 | Draft Complete Summary | lines 1132-1172 |
| 25 | Partial Draft Declaration | lines 1319-1371 |
| 26 | Phase Completion Assessment | lines 1290-1313 |
| 27 | Pause State Snapshot (draft) | lines 1379-1440 |
| 28 | Resume Confirmation | lines 1462-1473 |

**From design-review, extract these templates:**

| Template # | Name | Source section |
|---|---|---|
| 29 | Section Status Table | ## SECTION STATUS TABLE |
| 30 | End of Pass Summary | ## END OF PASS SUMMARY |
| 31 | Finding Format (per track) | ## FINDING TYPE TAXONOMY |
| 32 | Diff Format | ## DIFF FORMAT |
| 33 | Change Volume + Trend Tracking | ## CHANGE VOLUME + TREND TRACKING |
| 34 | Deferred Log | ## DEFERRED LOG |
| 35 | Completion Declaration | ## COMPLETION DECLARATION |
| 36 | Session Log Export | ## SESSION LOG EXPORT |
| 37 | Pause State Snapshot (review) | ## PAUSE STATE SNAPSHOT (review variant) |

Each template includes the full code-fenced block and any immediately surrounding rules/notes that explain when and how to use it.

- [ ] **Step 2: Commit**

```bash
git add plugins/design-assistant/references/ux-templates.md
git commit -m "refactor(design-assistant): create ux-templates.md with all output templates"
```

---

### Task 6: Rewrite design-draft.md

**Files:**
- Modify: `plugins/design-assistant/commands/design-draft.md`

- [ ] **Step 1: Replace extracted sections with Read pointers**

The command keeps its frontmatter and all phase procedures (Phases 0-5). Replace extracted sections as follows:

1. **Lines 17-41 (INTERACTION CONVENTIONS):** Replace with:
   ```
   Read `${CLAUDE_PLUGIN_ROOT}/references/interaction-conventions.md` for AskUserQuestion conversion rules.
   ```

2. **Lines 166-371 (SESSION STATE MODEL):** Replace with:
   ```
   Read `${CLAUDE_PLUGIN_ROOT}/references/session-state.md` for the design-draft state model and invariants.
   ```

3. **All formatted output blocks throughout Phases 0-5:** Replace each code-fenced template block with a pointer like:
   ```
   Read `${CLAUDE_PLUGIN_ROOT}/references/ux-templates.md` for Template N (Template Name).
   ```
   Keep the surrounding procedural text (when to use it, what to do after).

4. **Lines 1190-1279 (HANDOFF CONTRACT):** Replace with:
   ```
   Read `${CLAUDE_PLUGIN_ROOT}/references/handoff-contract.md` for the warm handoff protocol.
   ```

5. **Lines 1283-1473 (EARLY EXIT + PAUSE):** Replace with:
   ```
   Read `${CLAUDE_PLUGIN_ROOT}/references/pause-resume.md` for design-draft pause, resume, and early exit protocols.
   ```

6. **Lines 1477-1498 (OPERATIONAL COMMANDS):** Replace with:
   ```
   Read `${CLAUDE_PLUGIN_ROOT}/references/operational-commands.md` for available session commands.
   ```

7. **Lines 1502-1538 (INTERVIEW RULES):** Replace with:
   ```
   Read `${CLAUDE_PLUGIN_ROOT}/references/interview-rules.md` for interview conduct rules.
   ```

Target: ~500 lines remaining (phase procedures + Read pointers).

- [ ] **Step 2: Verify the rewritten command**

Read back the file. Confirm: frontmatter intact, all phases present (0-5), every former inline template replaced with a Read pointer, no orphaned references to removed content.

- [ ] **Step 3: Commit**

```bash
git add plugins/design-assistant/commands/design-draft.md
git commit -m "refactor(design-assistant): slim design-draft command with reference pointers"
```

---

### Task 7: Rewrite design-review.md

**Files:**
- Modify: `plugins/design-assistant/commands/design-review.md`

- [ ] **Step 1: Replace extracted sections with Read pointers**

Same approach as Task 6. Replace:

1. **INTERACTION CONVENTIONS** → Read pointer to `interaction-conventions.md`
2. **SESSION STATE MODEL** → Read pointer to `session-state.md` (design-review section)
3. **All formatted output blocks** (section status, pass summary, finding format, diff format, change tracking, deferred log, completion declaration, session log) → Template pointers
4. **PAUSE STATE SNAPSHOT + EARLY EXIT** → Read pointer to `pause-resume.md`
5. **OPERATIONAL COMMANDS** → Read pointer to `operational-commands.md`

Target: ~500 lines remaining.

- [ ] **Step 2: Verify the rewritten command**

Read back the file. Confirm: frontmatter intact, all core sections present (initialization, review loop, tracks, finding types, auto-fix, resolution modes), every former inline template replaced.

- [ ] **Step 3: Commit**

```bash
git add plugins/design-assistant/commands/design-review.md
git commit -m "refactor(design-assistant): slim design-review command with reference pointers"
```

---

### Task 8: Delete skills directory

**Files:**
- Delete: `plugins/design-assistant/skills/` (2 stub skills)

- [ ] **Step 1: Delete**

```bash
rm -rf plugins/design-assistant/skills
```

- [ ] **Step 2: Commit**

```bash
git add plugins/design-assistant/skills/
git commit -m "refactor(design-assistant): delete stub skills (commands are the entry points)"
```

---

### Task 9: Update README

**Files:**
- Modify: `plugins/design-assistant/README.md`

- [ ] **Step 1: Replace Skills table with References section**

Remove the Skills table. Replace with a References table listing all 7 reference files and their purposes (same format as github-repo-manager).

- [ ] **Step 2: Commit**

```bash
git add plugins/design-assistant/README.md
git commit -m "docs(design-assistant): update README for references architecture"
```

---

### Task 10: CHANGELOG, version bump, validate

**Files:**
- Modify: `plugins/design-assistant/CHANGELOG.md`
- Modify: `plugins/design-assistant/.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`

- [ ] **Step 1: Add changelog entry**

Add `## [0.4.0] - 2026-03-27` with Changed (extracted shared content, rewrote commands, created ux-templates) and Removed (deleted stub skills) sections.

- [ ] **Step 2: Bump version to 0.4.0**

Update both `plugin.json` and `marketplace.json`.

- [ ] **Step 3: Validate**

```bash
./scripts/validate-marketplace.sh
```

- [ ] **Step 4: Commit**

```bash
git add plugins/design-assistant/CHANGELOG.md \
       plugins/design-assistant/.claude-plugin/plugin.json \
       .claude-plugin/marketplace.json
git commit -m "chore(design-assistant): bump to 0.4.0 for references architecture"
```

---

### Task 11: Update UX refresh tracking

**Files:**
- Modify: `docs/ux_refresh/plan.md`

- [ ] **Step 1: Check off design-assistant and update session log**

Check all boxes under `### 1. design-assistant`. Add session log row:

```markdown
| 2026-03-27 | design-assistant | Complete | Shared content + templates extracted to 7 references, both commands slimmed, stubs deleted |
```

- [ ] **Step 2: Commit**

```bash
git add docs/ux_refresh/plan.md
git commit -m "docs: mark design-assistant complete in UX refresh plan"
```
