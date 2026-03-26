# Rollback Procedures Reference

This file contains everything needed to manage `abort.json`: the persistent rollback configuration that survives session interruptions. It is loaded by `/nominal:preflight` (for setup and confirmation) and `/nominal:abort` (for execution).

## File location

`.claude/nominal/abort.json` in the user's repository.

## Why a separate file

Rollback procedures are deliberately stored separately from the environment profile. The separation ensures:
- Rollback procedures survive session interruptions (a profile update cannot accidentally overwrite them).
- Clean separation of concerns: what exists (profile) vs. what to do if things go wrong (abort).
- The abort command can read its procedure even if the profile is corrupted.

---

## Top-level structure

```json
{
  "_schema_version": "1.0.0",
  "methods": {
    "{method_name}": { /* rollback method object */ }
  }
}
```

| Field | Type | Purpose |
|-------|------|---------|
| `_schema_version` | string | Nominal plugin version. |
| `methods` | object | Dictionary of named rollback methods. Key is a short human-readable name (e.g. `"zfs_plus_restic"`, `"git_revert_only"`, `"proxmox_snapshot"`). |

---

## Rollback method object

| Field | Type | Purpose |
|-------|------|---------|
| `description` | string | Human-readable description (e.g. `"Restore ZFS snapshot, then verify with restic backup comparison"`). |
| `applicable_environments` | string array or null | Environment names this method applies to. Null means all environments. Names must match top-level keys in `environment.json`. |
| `steps` | array of step objects | Ordered rollback steps. Executed in sequence; halts on step failure. |
| `created` | timestamp | When this method was first established. |
| `last_confirmed` | timestamp | When a user last confirmed this method during `/preflight`. |

---

## Rollback step object

| Field | Type | Purpose |
|-------|------|---------|
| `order` | integer | Step sequence number (1-based). |
| `description` | string | Human-readable description of what this step does. |
| `action_hint` | string or null | Prose hint for Claude about how to execute (e.g. `"run zfs rollback on the dataset"`, `"restore the nginx config from the backup path"`). Not a literal command — Claude determines exact execution. |
| `irreversible` | boolean | Whether this step cannot be undone. If true, Nominal requires additional explicit user confirmation before executing. |
| `verification_hint` | string or null | How to verify the step succeeded (e.g. `"confirm the dataset shows the previous snapshot"`, `"check that nginx -t passes"`). |

---

## Example abort.json

```json
{
  "_schema_version": "1.0.0",
  "methods": {
    "zfs_plus_restic": {
      "description": "Restore ZFS snapshot to pre-session state, then verify integrity against most recent restic backup",
      "applicable_environments": ["atlas"],
      "steps": [
        {
          "order": 1,
          "description": "Roll back ZFS dataset to pre-session snapshot",
          "action_hint": "Identify the most recent pre-session ZFS snapshot and run zfs rollback",
          "irreversible": true,
          "verification_hint": "Confirm zfs list -t snapshot shows the rollback completed"
        },
        {
          "order": 2,
          "description": "Verify rolled-back state matches restic backup",
          "action_hint": "Run restic diff between the latest snapshot and the current filesystem state",
          "irreversible": false,
          "verification_hint": "restic diff should show minimal or no changes"
        },
        {
          "order": 3,
          "description": "Restart affected services",
          "action_hint": "Restart any services that were modified during the session",
          "irreversible": false,
          "verification_hint": "All services should be running and responding to health checks"
        }
      ],
      "created": "2026-03-25T14:00:00Z",
      "last_confirmed": "2026-03-25T14:00:00Z"
    }
  }
}
```

---

## Creating a new rollback method

When `abort.json` does not exist or the user needs a new method, walk through these steps:

1. Ask the user to describe their rollback strategy in plain language. What tools do they use? What would they restore from?

2. Based on the environment profile, suggest a method structure. Common patterns:
   - **ZFS snapshot rollback** — for environments with ZFS datasets
   - **Restic restore** — for environments using restic backup
   - **Proxmox snapshot revert** — for Proxmox LXC/VM environments
   - **Git revert** — for config-only changes tracked in git
   - **Manual service restart** — minimal rollback for low-risk changes

3. Break the strategy into ordered steps. For each step, determine:
   - A clear description
   - An action hint (how Claude should execute it)
   - Whether it is irreversible
   - How to verify it succeeded

4. Present the complete method for confirmation via AskUserQuestion before writing to `abort.json`.

5. Write `abort.json` with `_schema_version` set to the current Nominal version.

---

## Presenting existing methods at `/preflight`

When `abort.json` exists and contains methods:

**Single method:** Present the method name, description, and step summary for quick confirmation. AskUserQuestion:
- **Confirmed — proceed with this abort path**
- **Update the rollback method** — walk through re-establishing
- **View full details** — show all steps with action hints

**Multiple methods:** If the profile has multiple environments and methods are scoped via `applicable_environments`, filter to methods applicable to the active environment. If multiple still apply, present them for selection via AskUserQuestion.

**Method with `applicable_environments` that does not match the active environment:** Warn the user that no rollback method is configured for this environment. Offer to create one or select a generic method.

After confirmation, update `last_confirmed` on the selected method.

---

## Executing rollback at `/abort`

1. Read the confirmed rollback method from session context. If no preflight ran this session, read `abort.json` directly as a fallback.

2. Present the full procedure via AskUserQuestion (Template 5 in ux-templates reference) for final confirmation before executing anything.

3. Execute steps in order:
   - Before each irreversible step, require additional explicit confirmation via AskUserQuestion.
   - After each step, run the verification hint to confirm success.
   - If a step fails, halt immediately. Do not continue to the next step.

4. After all steps complete, run a post-abort go/no-go poll (same spot-check as `/preflight` validation).

5. Record the abort event in `runs.jsonl` (see flight-log reference).

6. Terminate the session contract. A fresh `/preflight` is required before any further work.

---

## Edge cases

**No `abort.json` and no preflight ran:** Ask the user to provide rollback steps manually. Execute what is given, noting that completeness cannot be guaranteed. Record the abort with `rollback_method: null`.

**`abort.json` exists but is invalid JSON:** Warn the user. Offer to recreate it or proceed with manual steps.

**Method references an environment that no longer exists in the profile:** The method can still be used; the `applicable_environments` field is advisory, not enforced.
