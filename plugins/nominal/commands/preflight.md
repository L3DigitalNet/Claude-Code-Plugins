---
name: preflight
argument-hint: "[refresh]"
description: "Pre-session environment validation: discovers or validates the environment profile, confirms rollback readiness, and produces a Go/No-go Mission Brief."
---

# Preflight — Go/No-go Poll

You are running the Nominal preflight sequence. Your job is to validate the environment, confirm rollback readiness, and produce a clear Go for Launch or HOLD signal.

## Critical rules

1. **Never make changes during preflight.** Preflight is observational. The only write operations are creating/updating `environment.json` and `abort.json`.
2. **All decisions use AskUserQuestion.** Never bury a decision in narration.
3. **Minimize questions.** Make intelligent decisions; ask only at the structured confirmation points defined below.
4. **Record timing.** Note the start time when this command begins. You will need `duration_ms` if this is a refresh that writes to the flight log.

## Procedure

### Step 1 — Locate or initialize the environment profile

Check if `.claude/nominal/environment.json` exists.

**If it does NOT exist:** This is a first run. Print the Mission Survey header from the ux-templates reference (Template 1, first-run variant). Then read `${CLAUDE_PLUGIN_ROOT}/references/environment-profile.md` for the full discovery instructions and schema. Execute the full discovery pass described there. When discovery completes, present the Post-Discovery Confirmation (Template 0 from the environment-profile reference) via AskUserQuestion. Write the profile only after user confirmation.

**If it DOES exist:** Read the profile. Check `_schema_version` against the current plugin version (1.0.0). If they differ, apply migrations as described in the environment-profile reference.

### Step 2 — Handle the `refresh` argument

If the user invoked `/nominal:preflight refresh`:

Read `${CLAUDE_PLUGIN_ROOT}/references/environment-profile.md` for the discovery instructions. Execute a full re-discovery pass on the active environment. When complete, present the Refresh Confirmation (Template 0b from the environment-profile reference) showing a diff of what changed vs. the existing profile. Write the updated profile only after confirmation.

If the refresh is confirmed, record a `preflight_refresh` entry in the flight log. Read `${CLAUDE_PLUGIN_ROOT}/references/flight-log.md` for the schema.

After the refresh completes, continue to Step 3 as normal.

### Step 3 — Select the active environment

If the profile contains multiple named environments, present them via AskUserQuestion and let the user select which one to activate for this session. The chosen environment label flows through all subsequent output and flight log records.

If only one environment exists, activate it automatically.

### Step 4 — Establish rollback readiness (Domain 0)

Read `${CLAUDE_PLUGIN_ROOT}/references/rollback-procedures.md` for the full `abort.json` management instructions.

**If `.claude/nominal/abort.json` exists:** Read it. Filter methods by `applicable_environments` for the active environment. Present the applicable method(s) for confirmation as described in the rollback-procedures reference. Update `last_confirmed` on the selected method.

**If `abort.json` does NOT exist:** Walk the user through creating a rollback method as described in the rollback-procedures reference. Write `abort.json` after confirmation.

Domain 0 always resolves before preflight completes. If no rollback path can be established, produce a HOLD signal instead of Go for Launch.

### Step 5 — Run the go/no-go poll

Perform a streamlined spot-check validation of the active environment:

- Core hosts reachable (ping or equivalent)
- Primary services running (check a sample from the services inventory)
- Reverse proxy responding (if configured in profile)
- Monitoring platform active (if configured)
- Backup tooling present and last run within expected window (if configured)
- Firewall active (if configured)

This is not a full systems check. It is a quick validation that the environment is in the expected state before work begins.

**If all checks pass:** Proceed to produce the Mission Brief.

**If a structural anomaly is detected:** Produce a HOLD signal. Read `${CLAUDE_PLUGIN_ROOT}/references/ux-templates.md` for the HOLD variant of Template 1. Present options via AskUserQuestion: update parameters, investigate first, or override.

### Step 6 — Produce the Mission Brief

Read `${CLAUDE_PLUGIN_ROOT}/references/ux-templates.md` for Template 1 (Mission Brief).

Print the Mission Brief with:
- Environment name and profile timestamps
- Go/no-go poll results with evidence
- Confirmed abort procedure summary
- The Go for Launch signal and next-step guidance

The mission brief is the final output of `/preflight`. The session contract is now active.
