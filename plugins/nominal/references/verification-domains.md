# Verification Domain Checks

This file defines what each of the 12 verification domains checks during a Nominal run. These are verification specifications, not scripts. Claude determines the exact commands based on the environment. What is prescribed is what must be verified and how to classify the result.

All domains except Domain 0 run during `/postflight`. Domain 0 runs during `/preflight` only. All 11 postflight domains run every time; the trigger type label does not gate which domains execute.

**Terminology:** The design uses "domain" internally. User-facing output uses "system" (e.g. "System 4"). These are synonyms. Use "System" in all terminal output.

## How to read each domain

- **Reads from** — `environment.json` profile fields that drive the checks. Null fields cause dependent checks to be skipped (not failed).
- **Checks** — verification intents, not prescribed commands.
- **Nominal** — check passed; system operating within expected parameters.
- **Anomaly** — blocking failure requiring action. Appears in final verdict.
- **Minor anomaly** — worth noting but non-blocking. Logged but does not block nominal verdict.
- **Evidence** — what to show the user alongside the result. Every check, pass or fail, must show evidence.
- **Cascade halt** — whether failure should stop the entire systems check.

---

## Pre-domain gate: Preparing for re-entry

**Runs during:** `/postflight`, before any domain checks begin.
**Reads from:** Full environment profile and live system state.

Before domain checks run, re-read the environment profile and compare against the live system. Detect unexpected structural changes before domains use the profile as source of truth.

The profile re-read is expected to show intentional changes from the session. A new service appearing in a port scan after you deployed it is correct. Watch for unexpected structural change outside the declared scope.

**What it checks:**
- Re-read profile, confirm active environment matches the one selected at `/preflight`.
- Perform a lightweight live scan and compare against the profile.
- Identify structural discrepancies: services missing or newly detected, tooling changes, network topology changes.
- Classify each discrepancy as intentional (consistent with declared work) or unexpected.

**No discrepancies:** Brief confirmation, proceed to domain checks.

**Intentional changes:** Note them and proceed. Profile may need updating (Domain 11 will flag).

**Unexpected changes:** Present via AskUserQuestion before proceeding:
- **Investigate first** — pause
- **Update profile and continue** — update environment.json, proceed
- **Continue anyway** — proceed with current profile (discrepancies may cause false results)
- **Call /abort** — exit and rollback

**Cascade halt:** Yes — if the active environment is unreachable or the profile cannot be read.

**UX output:** Template 2b (Re-entry Scan) from the ux-templates reference.

---

## Domain 0 — Rollback readiness

**Runs during:** `/preflight` only.
**Reads from:** `abort.json` (methods, steps, applicable_environments).

A change should not begin without a confirmed rollback path. Based on ITIL remediation planning and ISO 20000 back-out requirements.

**Checks:**
- `abort.json` exists and is valid JSON with at least one named rollback method.
- If multiple methods exist, user selects via AskUserQuestion.
- If a single method exists, present for quick confirmation.
- The selected method's steps are presented with enough detail to understand what will happen during an abort.
- If `abort.json` does not exist, walk user through creating a rollback method and save it.

**Nominal:** A rollback method is confirmed and ready.
**Anomaly:** Not applicable — Domain 0 always resolves before `/preflight` completes. If no rollback path can be established, `/preflight` produces a HOLD signal.
**Evidence:** Confirmed method name, description, and step count.

---

## Domain 1 — Operational scripts & automation

**Runs during:** `/postflight`.
**Reads from:** services inventory (name, dependencies), backup (backup_tool, targets, pre_dump_scripts), monitoring (metrics_tool, uptime_tool).

When a service is added or modified, surrounding operational infrastructure must be updated. Lifecycle scripts, backup hooks, uptime monitors, and monitoring collectors are the connective tissue that keeps the environment operational.

**Checks:**
- For each service, verify backup include paths or pre-dump scripts exist if the service manages persistent data. Stateless proxies may have no backup entry — use judgment.
- If uptime monitoring is configured, verify each service with a health endpoint has a corresponding uptime monitor.
- If metrics collection is configured, verify each service is being collected by the platform.
- Verify new services have systemd unit files (or equivalent) with appropriate `After=` and `Requires=` directives for declared dependencies.

**Nominal:** All services have appropriate operational coverage.
**Anomaly:** A service with persistent data has no backup coverage. A service has no monitoring collector when monitoring is configured.
**Minor anomaly:** Uptime monitor missing for a non-user-facing service with a health endpoint. New service unit file has a less-than-ideal restart policy.
**Evidence:** List each service and its operational coverage status. For failures, show what is missing and where to configure it.
**Cascade halt:** No.

---

## Domain 2 — Backup integrity

**Runs during:** `/postflight`.
**Reads from:** backup (backup_tool, targets, last_run_check, pre_dump_scripts).

Backup must be confirmed as actually running and capturing the right data. Configuration alone is not sufficient. Based on ITIL PIR practices.

**Checks:**
- Backup tool is installed and its service or scheduled task is active.
- Most recent backup completed within the expected retention window. Use `last_run_check` from the profile.
- Backup tool reports success for the most recent run (not just "ran" but "succeeded").
- At least one backup file or snapshot exists and is non-zero at the configured target(s).
- If `pre_dump_scripts` are defined, verify they are executable and their output artifacts exist with recent timestamps.

**Nominal:** Backup is running, recent, successful, and producing real data.
**Anomaly:** Last backup older than retention window. Tool reports failure. No backup files at target. Pre-dump scripts not executable.
**Minor anomaly:** Backup exists and is recent but exit status not definitively confirmed. Secondary target unreachable but primary is healthy.
**Evidence:** Backup tool name, last run timestamp, status, file count/size at target. For pre-dump scripts, last-modified timestamps.
**Cascade halt:** No.

---

## Domain 3 — Credential & secrets hygiene

**Runs during:** `/postflight`.
**Reads from:** secrets (approach, canonical_location), VCS (tool, config_tracked_paths), services inventory.

Secrets must be in the canonical store, not visible in process lists or logs, not committed to git. Based on HashiCorp 18-point checklist and OWASP Secrets Management Cheat Sheet.

**Checks:**
- Canonical secrets location exists and has appropriate file permissions (not world-readable). For env files, check readable only by service user and root.
- Scan running process lists for exposed secrets (passwords, tokens, API keys visible as command-line arguments). Focus on services in the inventory.
- Check recent git history (last few commits) for accidentally committed secrets (file names like `.env`, `credentials`, `secrets`, or content patterns).
- Verify canonical secrets location is not inside a git-tracked directory without a `.gitignore` exclusion.
- For new services, verify secrets are sourced from the canonical location rather than hardcoded.

**Nominal:** Secrets in canonical store, not exposed in processes/logs/git, appropriate permissions.
**Anomaly:** Secrets visible in process arguments. Secrets committed to git. Canonical file world-readable. New service with secrets outside canonical location.
**Minor anomaly:** Canonical file has broader permissions than ideal but not world-readable. `.gitignore` rule uses a broad pattern rather than explicit path.
**Evidence:** Canonical location, permissions, process scan results (redact actual values — show only that a pattern was found and which process), git scan results.
**Cascade halt:** No.

---

## Domain 4 — Reachability & access tier correctness

**Runs during:** `/postflight`.
**Reads from:** services inventory (name, host_address, ports, access_tier, health_endpoint), ingress (reverse_proxy_tool, access_model).

Every service must be reachable from exactly the right channels and unreachable from everything else.

**Checks:**
- For each service, verify it responds on its declared host address and port(s). Use health endpoint if available; fall back to TCP connection check.
- For `"public"` services, verify reachable through the reverse proxy on expected public URL.
- For `"auth_gated"` services, verify unauthenticated requests are challenged (401, 403, or redirect to auth provider).
- For `"vpn_only"` services, verify not reachable from outside the VPN (only meaningful if VPN is configured).
- Verify each service's dependencies are also reachable.

**Nominal:** Every service reachable from declared channels and responds appropriately.
**Anomaly:** Service unreachable on declared address:port. Public service not responding through proxy. Auth-gated service serving without challenge. VPN-only service publicly reachable.
**Minor anomaly:** Service responds with unexpected HTTP status (e.g. 503 instead of 200). Health endpoint not defined, only TCP check performed.
**Evidence:** For each service: address:port, access tier, method used, result. For failures: expected vs. actual.
**Cascade halt:** Yes — if the host itself is unreachable (not a single service, the entire host). Fires only when fundamental connectivity is broken.

---

## Domain 5 — Security posture

**Runs during:** `/postflight`.
**Reads from:** network (firewall_tool), security_tooling (fim_tool, fim_baseline_update_method, ips_tool, ips_status_check), services inventory (ports).

Firewall rules intact, no unintended ports open, FIM baseline updated after intentional changes, IPS running. Based on CIS Controls v8 drift detection model.

**Checks:**
- Verify firewall is active. Check rule set has not changed unexpectedly — no new ALLOW rules beyond planned work.
- Scan listening ports and compare against services inventory. Flag undeclared ports.
- If FIM is configured, check whether baseline needs updating after session changes.
- If IPS is configured, verify running and protecting. Use `ips_status_check`.
- Verify new config files have appropriate ownership and permissions.

**Nominal:** Firewall active with expected rules, no unexpected ports, FIM baseline current, IPS running, permissions correct.
**Anomaly:** Firewall inactive or has unexpected ALLOW rules. Undeclared port listening and accepting connections. IPS not running.
**Minor anomaly:** FIM baseline not updated after intentional changes (reminder, not failure). Config file has broader permissions but not world-writable.
**Evidence:** Firewall status and rule changes. Port scan with expected vs. actual. FIM and IPS status. New file ownership/permissions.
**Cascade halt:** No.

---

## Domain 6 — Performance & resource baselines

**Runs during:** `/postflight`.
**Reads from:** host (virtualization_type), services inventory (name, host_address).

A new service can silently starve neighbors. Based on SRE Four Golden Signals and Brendan Gregg's USE Method.

**Checks:**
- CPU utilization on the host. Flag sustained utilization above ~90%.
- Memory utilization. Flag critically low available memory.
- Disk/storage on all mounted filesystems. Flag any above 90%. Check ZFS pool health if applicable.
- OOM killer events in system logs since session began.
- Container resource allocation (Proxmox LXC, Docker, Kubernetes) — verify not hitting limits.

**Nominal:** Utilization within normal bounds, no OOM events, adequate storage headroom.
**Anomaly:** Filesystem above 95%. OOM events during session. Container hitting resource limits.
**Minor anomaly:** CPU/memory 80-90%. Filesystem 90-95%. ZFS scrub overdue.
**Evidence:** CPU, memory, disk utilization as percentages. OOM events with process name and timestamp. Container limits vs. current usage.
**Cascade halt:** No.

---

## Domain 7 — Service lifecycle & boot ordering

**Runs during:** `/postflight`.
**Reads from:** services inventory (name, dependencies), host (virtualization_type).

A service healthy now can fail silently after the next reboot.

**Checks:**
- For each service, verify autostart configuration (systemd `enabled`, Proxmox autostart, Kubernetes replica count).
- For services with declared dependencies, verify both `After=` and `Requires=` directives (or equivalent). `After=` alone does not start the dependency. `Requires=` alone does not control ordering. Both are needed.
- Verify restart policies are appropriate (critical services: `Restart=on-failure` or `Restart=always`, not `Restart=no`).
- For new or modified unit files, run `systemd-analyze verify` to catch configuration errors.
- For Proxmox LXC/VM, verify autostart flag and boot order.

**Nominal:** All services have autostart, dependency ordering correct, restart policies appropriate, unit files valid.
**Anomaly:** Service has no autostart. Service depends on another but has no `Requires=`. New unit file fails validation.
**Minor anomaly:** Service has `Restart=no` but is not critical. `After=` without `Requires=` for a soft dependency.
**Evidence:** Per-service autostart status, dependency directives, restart policy. New unit file validation results.
**Cascade halt:** No.

---

## Domain 8 — Observability completeness

**Runs during:** `/postflight`.
**Reads from:** monitoring (metrics_tool, metrics_status_check, uptime_tool, uptime_status_check, log_aggregation_tool, log_status_check), services inventory (name, monitoring_collector, health_endpoint).

Monitoring must be actively collecting data, not just configured. Based on Google SRE PRR observability gate.

**Checks:**
- Verify metrics platform is running and receiving data. Use `metrics_status_check`.
- Verify uptime tool is running with recent results. Use `uptime_status_check`.
- If log aggregation is configured, verify running and receiving logs. Use `log_status_check`.
- For each service, verify monitoring platform is collecting data for it.
- Verify uptime monitors exist for services with health endpoints and access tier `"public"` or `"auth_gated"`.

**Nominal:** All monitoring platforms running, data flowing, each service has coverage.
**Anomaly:** Metrics platform not running/receiving. Uptime tool down. User-facing service has no uptime monitor. Service has no metrics collection.
**Minor anomaly:** Log aggregation not configured (some environments omit this). Internal-only service has no uptime monitor.
**Evidence:** Status of each monitoring platform (running/stopped, last data). Per-service monitoring coverage.
**Cascade halt:** No.

---

## Domain 9 — DNS & certificate lifecycle

**Runs during:** `/postflight`.
**Reads from:** ssl (cert_tool, config_path, renewal_mechanism), ingress (reverse_proxy_tool), services inventory (public/auth_gated services).

DNS must resolve, certificates must be valid, auto-renewal must work. CA/Browser Forum's move toward 45-day validity makes automation critical.

**Checks:**
- For each public/auth-gated service, verify DNS resolves to expected address.
- Verify SSL certificate is valid (not expired, not self-signed unless expected, subject matches hostname).
- Check certificate expiry. Flag within 14 days as warning, within 7 days as critical.
- Verify renewal mechanism is active (systemd timer, cron, daemon).
- Run renewal dry-run if supported (e.g. `certbot renew --dry-run`).

**Nominal:** DNS resolves, certs valid with adequate lifetime, renewal active and passes dry-run.
**Anomaly:** DNS fails for public service. Certificate expired. Cert expires within 7 days with no active renewal. Dry-run fails.
**Minor anomaly:** Cert expires within 14-30 days. No dry-run support. DNS resolves to unexpected address (CDN/LB).
**Evidence:** Per domain/service: DNS result, cert subject, issuer, expiry, days remaining. Renewal status and dry-run result.
**Cascade halt:** No.

---

## Domain 10 — Network routing correctness

**Runs during:** `/postflight`.
**Reads from:** network (topology, private_bridge_or_overlay, private_subnet, vpn_tool, firewall_tool), ingress (reverse_proxy_tool), services inventory (host_address, ports, access_tier).

Distinct from Domain 4 (service-level reachability). A service can be reachable through the proxy while its direct inter-node connection path is broken. Based on NIST SP 800-190.

**Checks:**
- If private network exists, verify services can reach each other directly (not through proxy). Test direct connectivity between dependent services.
- Verify no service unintentionally binds to `0.0.0.0` when it should bind only to private address. Binding to all interfaces on a host with a public IP exposes beyond intended tier.
- If VPN is configured, verify VPN interface is up and routing correctly. Check expected peers are connected.
- Verify firewall rules are consistent with intended segmentation.
- For multiple interfaces/bridges, verify services are bound to the correct interface.

**Nominal:** Direct inter-service connectivity works, no unintended `0.0.0.0` binding, VPN routing correct, firewall consistent.
**Anomaly:** Service binds to `0.0.0.0` on a host with public interface when access tier is `"vpn_only"`. Direct connectivity between dependent services fails. VPN interface down.
**Minor anomaly:** Service binds to `0.0.0.0` but protected by firewall. VPN peer temporarily disconnected.
**Evidence:** Binding addresses (from `ss -tlnp` or equivalent). Direct connectivity results. VPN interface and peer status. Relevant firewall rules.
**Cascade halt:** No — but combined failure with Domain 4 is a strong signal of a fundamental problem.

---

## Domain 11 — Documentation & state

**Runs during:** `/postflight`.
**Reads from:** vcs (tool, remote, config_tracked_paths), services inventory.

A change is formally incomplete until documentation reflects reality. Based on ITIL change record closure.

**Checks:**
- Check for uncommitted changes in configuration-tracked paths (new, modified, deleted files).
- Verify changes are staged or committed. Unstaged changes in infra config paths indicate unpersisted work.
- Check if local branch is ahead of remote (committed but not pushed).
- Verify the Nominal profile (`environment.json`) reflects any new services or configuration changes from the session.

**Nominal:** All config changes committed (or staged), branch in sync with remote, profile reflects reality.
**Anomaly:** Config files modified but not staged or committed. Profile does not reflect a deployed service.
**Minor anomaly:** Changes committed but not pushed. Profile current but annotation fields could be updated.
**Evidence:** Git status for tracked config paths. Local-vs-remote status. Profile staleness if applicable.
**Cascade halt:** No.

---

## Cross-domain interactions

- **Domain 1 depends on current services inventory.** If Domain 11 finds the profile is stale, Domain 1 coverage checks will be incomplete. Note this if it occurs.
- **Domains 4 and 10 are complementary.** Domain 4 checks service-level reachability; Domain 10 checks network-level plumbing. A service can pass Domain 4 through the proxy and fail Domain 10 on direct connectivity.
- **Domain 5 should run after Domain 4.** If Domain 4 reveals unexpected reachability, Domain 5's firewall check should be interpreted in that context.
- **Domain 8 builds on Domain 1.** Domain 1 checks monitoring coverage exists (configuration). Domain 8 checks it is actively working (data flowing).

---

## Cascade halt conditions

A halt triggers only when continuing would produce meaningless or misleading results.

**Warrants a halt:**
- Host entirely unreachable (not one service — the host itself).
- SSH/shell connection lost mid-check.
- Foundational infrastructure (container runtime, init system) in a broken state.

**Does NOT warrant a halt:**
- A single service down.
- Monitoring platform unreachable.
- Backup check fails.
- Firewall misconfigured.
- DNS fails for one domain.

The test: would a human SRE continue checking, or stop and focus on the foundational problem? If a reasonable person would continue, Nominal continues.

---

## Execution order

Pre-domain gate, then domains 1 through 11 in numerical order, then regression sweep if any fix-forwards occurred, then final verdict. This follows the DevOps three-layer model: infrastructure (1-3), component (4-8), integration and documentation (9-11).

Each domain result is printed as it completes (real-time). Results are not buffered.

There is no time limit on individual domain checks.

---

## Fix-forward flow

When a domain check detects an anomaly, present three options via AskUserQuestion:
1. **Fix forward: {specific suggested step}** — attempt remediation and re-check
2. **Acknowledge and continue** — log as unresolved, continue
3. **Call /abort** — exit and rollback

**On fix-forward:**
- The systems check pauses.
- Claude attempts the suggested remediation. This is the only point during `/postflight` where Nominal makes changes, and only because the user explicitly requested it.
- Re-run only the specific failed check, not the entire domain.
- If re-check passes, domain continues. Outcome reflects end state.
- If re-check fails, present the same three options again.
- Flight log records `fix_forward_attempted` and `fix_forward_resolved` on the result object.
- One fix at a time. Multiple failures in the same domain are handled individually.

---

## Regression sweep

If any fix-forwards were executed during the systems check, a regression sweep runs after Domain 11 completes and before the final verdict. Skipped entirely on clean runs.

**What it does:**
- Re-runs the core pass/fail checks from every domain that completed before the first fix-forward occurred.
- Fast mode — lightweight verification of key signals, not full evidence gathering.
- No AskUserQuestion prompts. No fix-forward options. Read-only verification.

**If regression found:**
- Affected domain's outcome is updated.
- Regression clearly attributed to the fix-forward that caused it.
- Appears in final verdict alongside other anomalies.

**If clean:** Brief confirmation, proceed to final verdict.

**Flight log:** `regression_sweep` (boolean) and `regressions` array in the postflight record.

---

## Scope of Claude's judgment

These specifications define what must be verified and how to classify results. They do not prescribe:
- Exact commands to run — adapt to tools and platform present.
- Thresholds for resource utilization — use reasonable judgment.
- How to perform reachability checks — `curl`, `wget`, `nc`, health endpoint, service status.
- How to interpret ambiguous results — classify as minor anomaly and surface evidence.

What Claude must NOT do:
- Skip a domain without marking it as skipped with a reason.
- Show a nominal result without evidence.
- Classify a clearly broken check as minor to avoid showing failure.
- Make changes during a check autonomously. The systems check is observational. The only exception is user-initiated fix-forward via AskUserQuestion.
