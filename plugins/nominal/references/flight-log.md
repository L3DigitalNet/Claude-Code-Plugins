# Flight Log Reference

This file contains everything needed to read and write `runs.jsonl`. It is loaded by commands when recording postflight, abort, or preflight refresh events.

## File location

`.claude/nominal/runs.jsonl` in the user's repository.

## Format

Append-only JSONL. One JSON object per line. Based on the OpenTelemetry Log Data Model: ISO 8601 timestamps, typed records with a consistent envelope, and structured attributes.

Records are never modified or deleted. No trimming, no rotation. Each record is self-contained.

---

## Common fields (all record types)

These fields appear in every record. They form the consistent envelope, analogous to OTel's named top-level fields.

| Field | Type | Purpose |
|-------|------|---------|
| `timestamp` | ISO 8601 UTC | When the command completed. |
| `type` | string | Record type: `"postflight"`, `"abort"`, or `"preflight_refresh"`. |
| `environment` | string | Active environment name from the profile. |
| `schema_version` | string | Profile schema version at time of run. |
| `outcome` | string | One of: `"nominal"`, `"nominal_with_anomalies"`, `"not_nominal"`, `"aborted"`, `"incomplete"`, or `"halted"`. |
| `duration_ms` | integer | Total execution time in milliseconds. |
| `actor` | object | Who executed this run. |
| `actor.git_user` | string or null | Git user name and email from repo config. |
| `actor.system_user` | string or null | OS-level username. |
| `actor.session_id` | string or null | Claude Code session identifier. |
| `mission_type_label` | string or null | Trigger type label (e.g. `"new_service_deployment"`). Null for abort and preflight_refresh. |

### How to populate actor fields

```bash
# git_user
git config user.name && git config user.email

# system_user
whoami

# session_id
# Use the Claude Code session ID from the current context
```

---

## Postflight-specific fields

These fields appear only when `type` is `"postflight"`.

| Field | Type | Purpose |
|-------|------|---------|
| `systems_checked` | integer array | Always `[1,2,3,4,5,6,7,8,9,10,11]` for a complete run. Partial arrays indicate cascade halt. |
| `results` | array of result objects | One entry per system checked. |
| `anomaly_count` | integer | Total anomaly count across all systems. |
| `halt_at_system` | integer or null | System number where cascade halt occurred. Null if completed. |

### Result object

| Field | Type | Purpose |
|-------|------|---------|
| `system_id` | integer | System number (1-11). |
| `name` | string | System name (e.g. `"Operational scripts & automation"`). |
| `outcome` | string | `"nominal"`, `"nominal_with_anomalies"`, `"anomaly"`, or `"skipped"`. |
| `anomalies` | string array | Human-readable anomaly descriptions. Empty array if nominal. |
| `duration_ms` | integer | Time spent on this system's checks. |

### Fix-forward tracking fields (on result object)

When a fix-forward is attempted, the result object also includes:

| Field | Type | Default | Purpose |
|-------|------|---------|---------|
| `fix_forward_attempted` | boolean | false | True if user selected fix-forward for this system. |
| `fix_forward_resolved` | boolean | false | True if re-check passed after the fix. |

### Regression sweep fields (on postflight record)

| Field | Type | Purpose |
|-------|------|---------|
| `regression_sweep` | boolean | True if the regression sweep ran (because fix-forwards occurred). |
| `regressions` | array of objects | Domains whose outcome changed due to the sweep. Empty if no regressions. |

Each regression object:

| Field | Type | Purpose |
|-------|------|---------|
| `system_id` | integer | Affected system number. |
| `name` | string | System name. |
| `original_outcome` | string | Outcome before regression. |
| `regressed_outcome` | string | Outcome after regression. |
| `caused_by_system` | integer | System whose fix-forward caused the regression. |

---

## Abort-specific fields

These fields appear only when `type` is `"abort"`.

| Field | Type | Purpose |
|-------|------|---------|
| `rollback_method` | string or null | Name of the rollback method used (key from abort.json), or null if manual steps. |
| `steps_executed` | integer | Rollback steps successfully completed. |
| `steps_remaining` | integer | Steps not reached. |
| `restoration_verified` | boolean | Whether post-abort go/no-go poll confirmed restoration. |
| `irreversible_steps_confirmed` | boolean | Whether user confirmed any irreversible steps. |

---

## Preflight refresh-specific fields

These fields appear only when `type` is `"preflight_refresh"`.

| Field | Type | Purpose |
|-------|------|---------|
| `categories_changed` | string array | Profile categories that changed (e.g. `["network", "services"]`). |
| `categories_unchanged` | integer | Count of categories that stayed the same. |
| `new_fields_discovered` | integer | Fields that were null before and now have values. |

---

## Example records

### Postflight — all nominal

```json
{"timestamp":"2026-03-25T15:30:00Z","type":"postflight","environment":"atlas","schema_version":"1.0.0","outcome":"nominal","duration_ms":45200,"actor":{"git_user":"chris <12345+chris@users.noreply.github.com>","system_user":"chris","session_id":"abc123"},"mission_type_label":"new_service_deployment","systems_checked":[1,2,3,4,5,6,7,8,9,10,11],"results":[{"system_id":1,"name":"Operational scripts & automation","outcome":"nominal","anomalies":[],"duration_ms":3200},{"system_id":2,"name":"Backup integrity","outcome":"nominal","anomalies":[],"duration_ms":5100}],"anomaly_count":0,"halt_at_system":null,"regression_sweep":false,"regressions":[]}
```

### Abort

```json
{"timestamp":"2026-03-25T16:00:00Z","type":"abort","environment":"atlas","schema_version":"1.0.0","outcome":"aborted","duration_ms":12000,"actor":{"git_user":"chris <12345+chris@users.noreply.github.com>","system_user":"chris","session_id":"abc123"},"mission_type_label":null,"rollback_method":"zfs_plus_restic","steps_executed":3,"steps_remaining":0,"restoration_verified":true,"irreversible_steps_confirmed":false}
```

---

## Writing policy

- Append only. Never modify or delete existing records.
- One complete JSON object per line. No pretty-printing.
- Create the file if it does not exist. Create `.claude/nominal/` directory if needed.
- Record the event immediately after the command completes, before printing the final output.
