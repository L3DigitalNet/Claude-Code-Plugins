---
name: abort
description: "Mission abort and rollback: presents the confirmed rollback procedure, executes steps with verification, and terminates the session contract."
---

# Abort — Rollback and Terminate

You are running the Nominal abort sequence. Your job is to execute the confirmed rollback procedure safely, verify the environment is restored, and terminate the session contract.

## Critical rules

1. **Claude never initiates abort automatically.** Every abort requires explicit user confirmation via AskUserQuestion.
2. **Halt immediately on step failure.** Do not continue to the next rollback step if the current one fails.
3. **Flag irreversible steps before executing.** Require additional explicit confirmation via AskUserQuestion for any step marked `irreversible: true`.
4. **After a completed abort, the session contract is terminated.** A fresh `/preflight` is required before any further work.
5. **Record timing.** Note the start time. You will need `duration_ms` for the flight log.

## Procedure

### Step 1 — Locate the rollback procedure

Read `${CLAUDE_PLUGIN_ROOT}/references/rollback-procedures.md` for the full `abort.json` management instructions.

**If `/nominal:preflight` was run this session:** Use the rollback method confirmed during preflight from session context.

**If no preflight was run this session:**

First check if `.claude/nominal/abort.json` exists.

- **If it exists:** Read it and present the stored procedure as a fallback. Warn the user via AskUserQuestion that no preflight was run, so the rollback method was not re-confirmed:
  - **Use stored procedure** — proceed with the abort.json method
  - **Provide manual steps** — user provides rollback steps instead
  - **Cancel** — return to session

- **If `abort.json` does not exist:** Warn the user that no rollback procedure is available. Ask for manual rollback steps via AskUserQuestion. Execute what is provided, noting that completeness cannot be guaranteed.

### Step 2 — Present confirmation

Read `${CLAUDE_PLUGIN_ROOT}/references/ux-templates.md` for Template 5 (Abort Execution).

Print the abort confirmation showing:
- The full rollback procedure (method name, description, all steps)
- What will be reversed
- Warning about potentially irreversible steps

Present via AskUserQuestion:
- **Confirm — execute abort** — proceed with rollback
- **Cancel** — return to session without any changes

If the user cancels, exit immediately. The session contract remains active.

### Step 3 — Execute rollback steps

Print the abort-in-progress header (Template 5 execution format).

Execute steps in order. For each step:

1. Print `🔄 Step N: {description}` as an in-progress indicator.

2. **If the step is marked `irreversible: true`:** Present an additional confirmation via AskUserQuestion before executing:
   - **Confirm — this step cannot be undone**
   - **Skip this step** — continue to next step
   - **Cancel abort** — halt the abort procedure entirely

3. Execute the step using the `action_hint` as guidance. Adapt to the actual environment and available tools.

4. Run the `verification_hint` to confirm the step succeeded.

5. **If the step succeeded:** Print `✅ Step N: {description} — complete` with the evidence (command and output).

6. **If the step failed:** Print `❌ Step N: {description} — FAILED` with the command, expected result, and actual result. Then halt immediately. Print the abort-halted message from Template 5 showing:
   - Steps completed vs. total
   - Remaining steps that were not executed
   - Guidance to resolve manually

### Step 4 — Post-abort verification

After all steps complete successfully, run the post-abort go/no-go poll:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/go-nogo-poll.sh .claude/nominal/environment.json
```

This is the same spot-check as preflight's go/no-go poll. Parse the JSON output to verify the environment was restored to a functional state.

### Step 5 — Final output

**If restoration verified:** Print the mission-aborted-environment-restored footer (Template 5) with duration and timestamp.

**If restoration could not be verified** (post-abort poll failed): Print the restoration-incomplete footer. Note what failed in the post-abort poll.

### Step 6 — Write flight log

Read `${CLAUDE_PLUGIN_ROOT}/references/flight-log.md` for the `runs.jsonl` schema.

Construct the abort record:
- `type`: `"abort"`
- `outcome`: `"aborted"` (successful) or `"incomplete"` (step failure or unverified restoration)
- `rollback_method`: method name from abort.json, or null if manual steps
- `steps_executed`: count of steps completed
- `steps_remaining`: count of steps not reached
- `restoration_verified`: boolean from the post-abort poll
- `irreversible_steps_confirmed`: boolean, true if any irreversible steps were confirmed

Pipe the constructed JSON to the flight log script:

```bash
echo '<constructed-json>' | bash ${CLAUDE_PLUGIN_ROOT}/scripts/flight-log.sh append
```

### Step 7 — Terminate session contract

The session contract is now terminated. Print a clear statement that a fresh `/nominal:preflight` is required before any further infrastructure work.

If the user attempts to run `/nominal:postflight` after this abort, remind them the session contract was terminated and they must run `/nominal:preflight` first.
