# UX & Output Templates

This file defines all output templates and UX behavior for Nominal. Templates are the contract between the plugin logic and the user.

Guiding principle: be transparent, be specific, be actionable. The user should never have to guess what Nominal is doing, what it found, or what to do next.

The aerospace/space theme runs consistently through all output.

## Design principles

- **Show work, not just results.** Every check shows evidence — the command run and what it returned. A pass without evidence is just a promise.
- **Fail loudly, pass quietly.** Anomalies get full treatment. Clean passes get a single line.
- **Never block silently.** If a check cannot complete, say why and what the user can do about it.
- **Consistent visual grammar.** Fixed symbols used throughout for scanning at a glance.
- **The final verdict is unambiguous.** Either the system is nominal or it is not. No hedging.
- **Decisions use AskUserQuestion.** All decision points use interactive options. Plain text for progress reporting. These two modes never mix.

## Visual grammar

| Symbol | Meaning |
|--------|---------|
| ✅ | System nominal — check passed |
| ❌ | Anomaly detected — action required |
| ⚠️ | Minor anomaly — non-blocking, review recommended |
| ⏭️ | Skipped — reason stated |
| ⏳ | Queued — not yet run |
| 🔄 | In progress |
| 🟢 | Final verdict: all systems nominal |
| 🟡 | Final verdict: nominal with minor anomalies |
| 🔴 | Final verdict: abort criteria met / restoration incomplete |
| ⬛ | Final verdict: mission aborted, environment restored |
| 🛸 | Postflight systems check header and cascade halt |
| 🚀 | Preflight / mission brief / mission survey |
| 🛑 | Abort in progress |
| ❗ | Unexpected structural change (re-entry scan) |
| ℹ️ | Informational — expected change or new discovery (non-blocking) |

## Terminology

| Concept | Nominal term |
|---------|-------------|
| Pre-work validation pass | Go/No-go poll |
| Environment validated, proceed | Go for launch |
| Environment blocked, do not proceed | HOLD |
| First-run environment discovery | Mission survey |
| Environment profile file | Mission parameters |
| Domain check pass | Nominal |
| Domain check fail | Anomaly detected |
| Warning (non-blocking) | Minor anomaly |
| All domains passed | All systems nominal |
| One or more domains failed | Abort criteria met |
| Run log (runs.jsonl) | Flight log |
| Rollback initiated | Abort called |
| Rollback complete | Mission aborted — environment restored |
| Session brief output | Mission brief |

---

## Template 1 — `/preflight` Mission Brief

**When:** After `/preflight` completes all checks.

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🚀  NOMINAL — MISSION BRIEF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Environment  {environment name}
Parameters   {first seen / last validated date}
Timestamp    {ISO timestamp}

GO/NO-GO POLL
  ✅  Core hosts reachable          ({count} checked)
  ✅  Primary services running      ({count} spot-checked)
  ✅  Reverse proxy responding
  ✅  Monitoring platform active
  ✅  Backup tooling present        (last run: {relative time})
  ✅  Firewall active
  ⚠️  {description of any minor anomaly noted}

ABORT READY
  ✅  Abort procedure confirmed (from abort.json)
  ✅  {snapshot / config backup / schema version} confirmed
  Abort path: {one-line description of the rollback procedure}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🟢  GO FOR LAUNCH
    Run /postflight when your changes are complete.
    Run /abort at any time to abort and restore.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### HOLD variant

When a structural anomaly blocks the go/no-go poll:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🚀  NOMINAL — HOLD
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

GO/NO-GO POLL — ANOMALY DETECTED
  ❌  {description of what doesn't match}
      Parameters say:  {what the profile recorded}
      Found:           {what the live system shows}

This is a structural anomaly. Launch is on hold.
```

AskUserQuestion options:
- **Update parameters** — update environment.json and re-run poll
- **Investigate first** — exit; user will re-run `/preflight` when ready
- **Override** — proceed with a warning logged

### First-run variant

When no mission parameters exist:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🚀  NOMINAL — MISSION SURVEY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

No mission parameters found.
Initiating environment survey — this will take a few minutes.

Surveying:
  🔄  Host OS and virtualization layer...
  🔄  Running services and roles...
  🔄  Reverse proxy and ingress...
  🔄  Monitoring platform...
  🔄  Backup tooling...
  🔄  Secrets management approach...
  🔄  Network topology and access model...
  🔄  Security tooling...
  🔄  VCS and config repository...
```

Transitions to Template 0 (Post-Discovery Confirmation) in the environment-profile reference when complete.

---

## Template 2 — `/postflight` Systems Check Header

**When:** Immediately when `/postflight` begins.

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🛸  NOMINAL — SYSTEMS CHECK INITIATING
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Mission type  {inferred trigger type}  (label only — all 11 postflight systems run)
Environment   {environment name}
```

AskUserQuestion — confirm mission type label:
- **Confirmed — {inferred type}**
- **New service deployment**
- **Reverse proxy / ingress change**
- **Shared datastore change**
- **Auth / SSO change**
- **Network / firewall change**
- **General / no specific change type**

```
SYSTEMS QUEUED — FULL SUITE
  ⏳  System 1    Operational scripts & automation
  ⏳  System 2    Backup integrity
  ⏳  System 3    Credential & secrets hygiene
  ⏳  System 4    Reachability & access correctness
  ⏳  System 5    Security posture
  ⏳  System 6    Performance & resource baselines
  ⏳  System 7    Service lifecycle & boot ordering
  ⏳  System 8    Observability completeness
  ⏳  System 9    DNS & certificate lifecycle
  ⏳  System 10   Network routing correctness
  ⏳  System 11   Documentation & state
  ──  System 0    Rollback readiness (verified in /preflight)

Initiating full systems check...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Template 2b — Re-entry Scan

**When:** After Template 2, before domain checks.

**No discrepancies:**
```
🛸  Preparing for re-entry...

  ✅  Environment profile confirmed     {environment name}
  ✅  Live system matches parameters    {count} categories checked
  ✅  Services inventory consistent     {count} services verified

Proceeding to full systems check.
```

**Intentional changes:**
```
🛸  Preparing for re-entry...

  ✅  Environment profile confirmed     {environment name}
  ✅  Live system consistent with session work

  EXPECTED CHANGES (consistent with session work)
    ℹ️  {description, e.g. "New service detected: Gitea on port 3000"}
    ℹ️  {description}

  Profile update recommended after systems check (System 11 will flag).

Proceeding to full systems check.
```

**Unexpected changes:**
```
🛸  Preparing for re-entry...

  ✅  Environment profile confirmed     {environment name}
  ⚠️  Structural discrepancy detected

  UNEXPECTED CHANGES
    ❗  {description, e.g. "Service 'Uptime Kuma' present in profile but not running"}
    ❗  {description, e.g. "Port 9090 listening — not declared in services inventory"}

  These changes do not appear related to the declared session work.
```

AskUserQuestion options:
- **Investigate first** — pause
- **Update profile and continue** — update environment.json, proceed
- **Continue anyway** — proceed with current profile
- **Call /abort** — exit and rollback

---

## Template 3 — Individual System Result

**When:** After each system check completes (printed immediately, real-time).

**Nominal:**
```
✅  System {N} — {System Name}
    {count} checks nominal  ·  {elapsed time}
```

**Nominal with minor anomaly:**
```
✅  System {N} — {System Name}
    {count} checks nominal  ·  {elapsed time}

    ⚠️  Minor anomaly: {description}
        {Specific detail — what was found, what was expected}
        Classification: non-blocking — logged to flight log
```

**Anomaly detected:**
```
❌  System {N} — {System Name}
    {pass count} nominal, {fail count} ANOMALY DETECTED  ·  {elapsed time}

    ANOMALY: {Check description}
    ────────────────────────────────────────
    Command:   {command that was run}
    Expected:  {what a nominal result looks like}
    Found:     {what was actually returned}

    Diagnosis: {Assessment of likely cause}
```

AskUserQuestion options:
- **Fix forward: {specific suggested step}** — attempt remediation and re-check
- **Acknowledge and continue** — logged as unresolved; check continues
- **Call /abort** — exit and rollback

```
⚠️  Systems check continues — final verdict will
    reflect this anomaly.
```

**Skipped:**
```
⏭️  System {N} — {System Name}
    Skipped — {reason}
```

---

## Template 4 — `/postflight` Final Verdict

**When:** After all systems complete.

**All systems nominal:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🟢  ALL SYSTEMS NOMINAL
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Mission type  {trigger label}
Systems       11/11 nominal
Anomalies     {count}  (see details above)
Duration      {total elapsed time}
Timestamp     {ISO timestamp}

SYSTEMS REPORT
  ✅  System 1    Operational scripts & automation
  ✅  System 2    Backup integrity
  ✅  System 3    Credential & secrets hygiene
  ✅  System 4    Reachability & access correctness
  ✅  System 5    Security posture
  ✅  System 6    Performance & resource baselines
  ✅  System 7    Service lifecycle & boot ordering
  ✅  System 8    Observability completeness
  ✅  System 9    DNS & certificate lifecycle
  ✅  System 10   Network routing correctness
  ✅  System 11   Documentation & state

Flight log updated: .claude/nominal/runs.jsonl
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Abort criteria met:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔴  ABORT CRITERIA MET — NOT NOMINAL
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Mission type  {trigger label}
Systems       {pass count}/11 nominal  ·  {fail count} ANOMALY
Anomalies     {count}
Duration      {total elapsed time}
Timestamp     {ISO timestamp}

SYSTEMS REPORT
  ✅  System 1    Operational scripts & automation
  ❌  System 2    Backup integrity
  ...

ANOMALIES REQUIRING ACTION
  ❌  System 2 — Backup integrity
      {Brief restatement of anomaly and diagnosis}
      Fix forward: {one-line remediation}

  ❌  System 4 — Reachability & access correctness
      {Brief restatement}
      Fix forward: {one-line remediation}

ABORT AVAILABLE
  To abort and restore the pre-session state:
  → run /abort
  Abort path: {rollback procedure from abort.json}

Flight log updated: .claude/nominal/runs.jsonl
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Nominal with minor anomalies:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🟡  NOMINAL — MINOR ANOMALIES LOGGED
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Mission type  {trigger label}
Systems       11/11 nominal
Anomalies     {count}  (non-blocking — review at your discretion)
Duration      {total elapsed time}
Timestamp     {ISO timestamp}

{Systems report with ✅ and ⚠️ markers}

MINOR ANOMALIES
  ⚠️  System {N} — {description}
      {Detail and recommended follow-up}

Flight log updated: .claude/nominal/runs.jsonl
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Template 4b — Regression Sweep

**When:** After Domain 11, before final verdict. Only if fix-forwards occurred.

**Clean sweep:**
```
🛸  Regression sweep — verifying fix-forward side effects...

  ✅  System 1    Operational scripts & automation   — still nominal
  ✅  System 2    Backup integrity                   — still nominal
  ✅  System 3    Credential & secrets hygiene        — still nominal
  ✅  System 4    Reachability & access correctness   — still nominal

  No regressions detected. Fix-forward actions contained.

Proceeding to final verdict.
```

**Regression found:**
```
🛸  Regression sweep — verifying fix-forward side effects...

  ✅  System 1    Operational scripts & automation   — still nominal
  ✅  System 2    Backup integrity                   — still nominal
  ✅  System 3    Credential & secrets hygiene        — still nominal
  ❌  System 4    Reachability & access correctness   — REGRESSION

  REGRESSION DETECTED
    System 4 was nominal during initial check.
    After fix-forward in System 5 ({brief description}),
    System 4 now fails: {brief description}

  This regression will appear in the final verdict.

Proceeding to final verdict.
```

No fix-forward options during the sweep. Regressions surface in Template 4 as anomalies with clear attribution.

---

## Template 5 — `/abort` Execution

**When:** After user runs `/abort`.

**Confirmation prompt:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🛑  NOMINAL — ABORT CALLED
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

This will abort the current mission and execute the
rollback procedure from abort.json (confirmed during /preflight).

Abort path:
  {Full rollback procedure}

The following will be reversed:
  {List of changes to be undone}

This action may be irreversible for some steps.
```

AskUserQuestion:
- **Confirm — execute abort** — proceed with rollback
- **Cancel** — return to session without changes

**Execution output:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🛑  NOMINAL — ABORT IN PROGRESS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Executing rollback procedure...

  🔄  Step 1: {description}
  ✅  Step 1: {description} — complete
      Evidence: {command run / output observed}

  🔄  Step 2: {description}
  ✅  Step 2: {description} — complete
      Evidence: {command run / output observed}

Rollback steps complete. Verifying restoration...

GO/NO-GO POLL (post-abort)
  ✅  Core hosts reachable
  ✅  Primary services running
  ✅  Reverse proxy responding
  ✅  Monitoring platform active
  ✅  Firewall active

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⬛  MISSION ABORTED — ENVIRONMENT RESTORED
    Duration   {elapsed time}
    Timestamp  {ISO timestamp}

Flight log updated: .claude/nominal/runs.jsonl
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Step failure variant:**
```
  🔄  Step 2: {description}
  ❌  Step 2: {description} — FAILED
      Command:  {command run}
      Expected: {expected result}
      Found:    {actual result}

ABORT HALTED — manual intervention required.

The rollback procedure could not complete automatically.
Current state is partially restored. Steps completed: {N}/{total}.

Remaining steps:
  {list of steps not yet executed}

Resolve manually, then verify the environment is restored
before continuing any work.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔴  MISSION ABORTED — RESTORATION INCOMPLETE
    Manual intervention required.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Template 6 — Cascade Halt

**When:** During `/postflight` when a foundational failure makes continuing meaningless.

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🛸  NOMINAL — SYSTEMS CHECK HALTED
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

HALT REASON
  ❌  {Foundational failure description}
      Command:  {command run}
      Found:    {what was returned}

Continuing would produce unreliable results for
remaining systems. Check halted.

COMPLETED BEFORE HALT
  ✅  System 1    Operational scripts & automation
  ✅  System 2    Backup integrity
  ❌  System 3    {name} — HALT TRIGGERED HERE
  ──  Systems 4–11  Not run

Partial results recorded in flight log.

ABORT AVAILABLE
  If this failure is related to your changes:
  → run /abort
  Abort path: {rollback procedure from abort.json}

Flight log updated: .claude/nominal/runs.jsonl
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## UX behavior notes

**Progressive output.** Print each system result as it completes. If a check takes more than a few seconds, show `🔄 System N — {name} — checking...` as a live indicator.

**All decision points use AskUserQuestion.** Decisions are never buried in narration.

**All 11 postflight systems always run.** No scoped or targeted check mode. The trigger type label is for context and record-keeping only.

**Anomaly detected does not stop the check.** Failed systems are recorded and surfaced in the final verdict. Exception: cascade halt (Template 6).

**Evidence always accompanies a result.** Every check shows what was run and what was observed. "System nominal" with no evidence is not acceptable.

**Abort path is visible at failure time.** Any time an anomaly is reported or the verdict is not nominal, the abort procedure is restated inline.

**`/postflight` or `/abort` without `/preflight`.** Print a soft warning via AskUserQuestion — no preflight record exists. For `/postflight`: offer to run a validation pass now or proceed with checks only. For `/abort`: check if `abort.json` exists as fallback; if not, ask for manual rollback steps.

**After a completed `/abort`, fresh `/preflight` is required.** Session contract terminated. Do not accept `/postflight` after an abort.

**Multi-environment selection.** When `environment.json` has multiple named environments, `/preflight` presents them via AskUserQuestion. Chosen label flows through all output and flight log.
