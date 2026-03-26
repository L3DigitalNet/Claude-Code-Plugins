---
name: postflight
description: "Post-session systems check: runs all 11 verification systems, handles anomalies with fix-forward options, and produces a final nominal/not-nominal verdict with flight log."
---

# Postflight — Full Systems Check

You are running the Nominal postflight sequence. Your job is to run all 11 verification systems, present results in real time, handle anomalies interactively, and produce an unambiguous final verdict.

## Critical rules

1. **The systems check is observational.** Do not make changes to the environment during checks. The only exception is when the user explicitly selects "Fix forward" via AskUserQuestion — this is a user-initiated intervention, not an autonomous action.
2. **All 11 systems run, every time.** The trigger type label does not gate which systems execute.
3. **Every check shows evidence.** A pass without evidence is not acceptable. Show what was run and what was observed.
4. **Print results in real time.** Each system result prints as soon as it completes. Do not buffer.
5. **All decisions use AskUserQuestion.** Never bury a decision in narration.
6. **Record timing.** Note the start time when this command begins. You will need `duration_ms` for the flight log. Also track per-system duration.

## Procedure

### Step 0 — Check for preflight

If no `/nominal:preflight` was run in the current session, present a soft warning via AskUserQuestion:

> No preflight record exists for this session.

Options:
- **Run validation pass first** — run a quick spot-check (like preflight's go/no-go poll) before proceeding
- **Skip validation and proceed** — run the systems check without a baseline
- **Cancel** — exit

### Step 1 — Systems Check header and mission type

Read `${CLAUDE_PLUGIN_ROOT}/references/ux-templates.md` for Template 2 (Systems Check Header).

Infer the mission type from the session context (what work was done since preflight). Present it via AskUserQuestion for confirmation as a label. The label flows into the flight log but does not affect which systems run.

Print the systems queue showing all 11 systems.

### Step 2 — Pre-domain gate (Preparing for re-entry)

Read `${CLAUDE_PLUGIN_ROOT}/references/verification-domains.md` for the Pre-domain gate specification.

Re-read `.claude/nominal/environment.json`. Perform a lightweight live scan and compare against the profile. Classify any discrepancies as intentional or unexpected.

Read `${CLAUDE_PLUGIN_ROOT}/references/ux-templates.md` for Template 2b (Re-entry Scan) and print the appropriate variant.

If unexpected changes are found, present options via AskUserQuestion before proceeding.

**Cascade halt:** If the active environment is unreachable or the profile cannot be read, halt using Template 6 and stop.

### Step 3 — Execute domains 1 through 11

Read `${CLAUDE_PLUGIN_ROOT}/references/verification-domains.md` for the full domain check specifications.

Execute each domain in numerical order (1, 2, 3, ..., 11). For each domain:

1. Read the domain's specification from the verification-domains reference.
2. Execute the checks described, adapting commands to the tools and platform present.
3. Classify results as nominal, anomaly, minor anomaly, or skipped.
4. Print the result immediately using Template 3 from the ux-templates reference.

**On anomaly:** Present three options via AskUserQuestion (Template 3 anomaly format):
- **Fix forward: {specific suggested step}** — attempt the fix, then re-run only the failed check.
  - If re-check passes, the domain continues.
  - If re-check fails, present options again.
  - Track: set `fix_forward_attempted = true` on the result object. Set `fix_forward_resolved` based on the re-check outcome.
- **Acknowledge and continue** — log the anomaly as unresolved, continue to the next check.
- **Call /abort** — exit the systems check and execute the abort procedure.

**On cascade halt condition** (host unreachable, shell connection lost, foundational breakage): Stop immediately. Print Template 6 (Cascade Halt). Record partial results in the flight log and stop.

### Step 4 — Regression sweep (conditional)

If any fix-forwards were executed during Step 3, run a regression sweep after Domain 11 completes.

Read `${CLAUDE_PLUGIN_ROOT}/references/verification-domains.md` for the Regression Sweep specification. Read `${CLAUDE_PLUGIN_ROOT}/references/ux-templates.md` for Template 4b.

- Re-run core pass/fail checks from domains that completed before the first fix-forward.
- Fast mode: lightweight verification, not full evidence gathering.
- No AskUserQuestion prompts. No fix-forward options. Read-only.
- If regressions found, update affected domain outcomes and attribute them to the fix-forward.
- Print Template 4b result.

If no fix-forwards occurred, skip this step entirely.

### Step 5 — Final verdict

Read `${CLAUDE_PLUGIN_ROOT}/references/ux-templates.md` for Template 4 (Final Verdict).

Determine the overall outcome:
- **All systems nominal, no anomalies:** outcome = `"nominal"`, print green verdict.
- **All systems nominal, minor anomalies only:** outcome = `"nominal_with_anomalies"`, print yellow verdict.
- **One or more anomalies (blocking):** outcome = `"not_nominal"`, print red verdict with anomaly summary and abort path.
- **Cascade halt occurred:** outcome = `"halted"`, already printed Template 6.

Print the appropriate Template 4 variant.

### Step 6 — Write flight log

Read `${CLAUDE_PLUGIN_ROOT}/references/flight-log.md` for the `runs.jsonl` schema.

Construct the postflight record with all common and postflight-specific fields. Append it as a single JSON line to `.claude/nominal/runs.jsonl`. Create the file and directory if they do not exist.

Confirm the flight log was written in the final output line.
