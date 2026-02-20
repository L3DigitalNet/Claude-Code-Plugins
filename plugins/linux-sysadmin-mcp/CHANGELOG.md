# Changelog

All notable changes to the linux-sysadmin-mcp plugin are documented here.

## [1.0.4] — 2026-02-20

### Changed
- **UX — P2-1: `svc_logs` structured output** — `journal_logs` field changed from a raw string
  blob to an array of log line strings, with `log_line_count` and `truncated` fields so callers
  can detect when the line limit was reached and more entries may exist.
- **UX — P2-2: `log_query` parsed entries** — response changed from `{ lines: string[], count }`
  to `{ entries: [{timestamp, unit, pid, message}], count, unparsed_count? }`. Journal lines are
  parsed from the default "short" format; non-matching lines (e.g., `-- Boot ID --` dividers)
  contribute to `unparsed_count` and are excluded from `entries`.
- **UX — P2-3: `log_disk_usage` two-field output** — replaced single `output` blob with
  `journal_usage` (journalctl's human-readable disk-usage string) and `varlog_usage` (du size
  of `/var/log/`).
- **Docs — P2-4: `sudoers_list/modify` marked [Planned]** — Section 6.2 now correctly marks
  these two tools as planned-but-not-implemented, preventing false expectations.
- **Docs — P2-5: `timer_create/modify` marked [Planned]** — Section 6.3 similarly corrected;
  only `timer_list` is currently implemented.
- **Docs — P2-6: `sysadmin_session_info` description corrected** — Removed "detected MCP
  servers, routing guidance" from the tool's description and response schema documentation. The
  plugin has no runtime MCP server discovery mechanism; `integration_mode` is a behavioral hint
  only, not a live enumeration. Added an explicit note in Section 6.0 explaining why.
- **Docs — P2-7: SELF_TEST_RESULTS.md version caveat updated** — caveat now references v1.0.3
  as the current version and enumerates the behavioral categories affected by v1.0.x changes,
  clarifying which Layer 3 assertions would differ in a re-run.
- **UX — P3-1: `log_disk_usage.journal_usage` normalized** — previously returned the full prose
  sentence from `journalctl --disk-usage` (e.g., `"Archived and active journals take up 1.2 G in
  the file system."`); now returns the bare size token (e.g., `"1.2G"`), consistent with
  `varlog_usage`. Falls back to the full sentence if the regex parse fails.
- **UX — P3-2: `log_query.unparsed_count` always emitted** — field is now always present in the
  response (value `0` on the clean path) so callers can distinguish "all lines parsed" from
  "field not present". Previously omitted when zero.
- **UX — P3-3: `log_search.journal` intentional raw strings documented** — added an inline
  comment explaining why journal results in `log_search` remain as `string[]` (multi-source grep
  tool; not all result lines follow journalctl short format). `log_query` is the right tool for
  structured parsed entries.
- **Fix — P3-4: `factory.ts` silent Debian fallback now warns** — unrecognized distro families
  now emit a `logger.warn` before falling back to Debian commands, so operators can identify
  misconfigured environments in server logs rather than seeing silent tool failures.
- **C1 — P3-5: Architectural role headers added** — `factory.ts` and `helpers.ts` now have
  role headers explaining their purpose, callers, and cross-file contracts. Decorative `// ──`
  section separator comments removed from `helpers.ts` and `server.ts` phase labels.
- **Docs — P3-6: Design doc Section 9.1 corrected** — Step 5 of the first-run sequence no
  longer claims the plugin "Detects other MCP servers." Rewritten to accurately describe the
  `complementary` integration mode as a behavioral hint. Removed `detected_mcp_servers: []` from
  the startup JSON example (field never existed in the actual response schema).
- **Docs — P3-7: Design doc version header updated to 1.0.4**
- **Docs — P3-8: Design doc decisions table testing strategy updated** — Row at end of document
  now reads "Container-based (Podman)" instead of the stale "VMs per distro via Vagrant".
- **Docs — P3-9: `log_tail` ghost entry removed** — Section 6.5 tool table no longer lists
  `log_tail` (never implemented; 4 log tools are implemented: `log_query`, `log_search`,
  `log_summary`, `log_disk_usage`). SELF_TEST_RESULTS.md log module tool count corrected to 4.
- **Docs — P3-10: `bak_schedule` cross-reference corrected** — Section 6.14 description no
  longer references `timer_create` as the backing mechanism. `bak_schedule` uses cron directly;
  the description now accurately reflects this and notes that systemd timer support is planned.
- **Docs — P3-11: Duration category table `log_tail` reference replaced** — Section 10.2's
  `quick` timeout row referenced `log_tail` (never implemented); replaced with `log_disk_usage`
  which is actually a `quick`-category tool.
- **Docs — P3-12: Startup sequence Mermaid diagram corrected** — Line in the Section 9.2
  sequence diagram read "Check for active MCP servers"; updated to accurately describe the
  static `integration_mode` config application (no runtime MCP enumeration).

---

## [1.0.3] — 2026-02-20

### Changed
- **UX — B-005: `fw_add_rule` error categorization** — errors from the firewall backend are now
  routed through `buildCategorizedResponse()` rather than passed as raw stderr, giving categorized
  error codes and actionable remediation hints.
- **UX — B-009: `sec_check_suid` truncation signal** — response now includes `truncated: true`
  when results hit the `limit` cap, so callers know additional SUID files may exist beyond the
  returned set.
- **UX — A-002/B-006: `documentation_action` now emitted** — `svc_start`, `svc_stop`,
  `svc_restart`, and `fw_add_rule` include a `documentation_action` hint in their success
  response when a documentation repo is configured, guiding Claude to suggest relevant doc tools
  (e.g. `doc_generate_service`, `doc_backup_config`) after a state change.
- **UX — N-001: `ctr_compose_down` `volumes` parameter description** — moved the destructive-
  action warning ("permanently deletes all volume data") from the `dry_run` field into the
  `volumes` field's own `.describe()` so it is visible to callers regardless of which parameter
  they read first.
- **Fix — N-002: `package.json` `bin`/`main` entry point** — corrected from `dist/server.js`
  (unbundled tsc output) to `dist/server.bundle.cjs` (esbuild bundle). Users who install globally
  and invoke the binary directly now get the correct bundled entry point.
- **Docs — C-009: tool count consistency** — plugin.json, marketplace.json, and README updated
  from "~100 tools" to "~107 tools" to match the actual module table total.
- **Docs — C-010: design doc installation block** — updated from global binary invocation to the
  correct `node dist/server.bundle.cjs` form matching `.mcp.json`.
- **Fix — QW2: `noRepo` error tool-name scope bug** — `docs/index.ts` was returning `tool:"doc"`
  for all 8 documentation tools when no repo is configured. Each handler now passes its own tool
  name to `noRepo()`, so the error envelope's `tool` field matches the actual invocation.
- **Fix — QW3: `duration_ms` type** — `ResponseBase` now types `duration_ms` as `number | null`.
  The safety gate confirmation response and all dry-run / validation-only responses (no command
  executed) now emit `null` instead of `0`.
- **UX — SC1/SC2: improved error categorization** — `svc_enable`, `svc_disable`, and the MCP
  server catch block now route errors through `buildCategorizedResponse()` for categorized error
  codes and actionable remediation.
- **UX — SC3: dry-run `preview_command`** — renamed `would_run` → `preview_command` across all
  dry-run success responses (services, packages, users, security) for a consistent response shape.
- **UX — SC4: `pkg_update` structured output** — response now includes `packages_updated_count`
  (parsed from apt/dnf output), `raw_output`, and a `summary` string instead of raw stdout only.
- **UX — SC5: `sec_audit` full severity scale** — severity now uses `critical` (>5 failed
  services), `high` (>2), `warning` (any), `info` (none) rather than the previous 3-level scale.
- **UX — DR2: `documentation_action` extended to users module** — `user_create` and `user_delete`
  now emit `documentation_action` hints (or `documentation_tip` if no repo configured) on success.
- **UX — DR3: structured output for perf/security/network tools** — `perf_overview`, `perf_memory`,
  `perf_network_io`, `sec_audit`, and `sec_check_listening` now return parsed structured fields
  (`memory`, `disk`, `interfaces`, `listening_ports`) instead of raw command output strings.
- **UX — DR4: `doc_restore_guide` structured output** — response now returns `{ host_summary,
  services: [{name, restore_steps, readme_available}], restore_sequence, services_documented,
  generated_at, full_guide_markdown }` instead of a single opaque guide string.
- **Safety — DR1: default `confirmation_threshold` changed to `high`** — the previous default
  (`moderate`) caused routine operations (package installs, user creates) to gate by default,
  contradicting P1 (Act on Intent). High-risk and critical tools still require confirmation.
  Existing user configs with `confirmation_threshold: moderate` are unaffected.
- **Docs — SC6: design doc Section 5.3 profiles table** — corrected to list only the 8 implemented
  profiles; moved the 24 planned profiles to a "Planned Profiles" subsection.
- **Docs — SC7: design doc Section 11 rewritten** — replaced the Vagrant/VM testing description
  with the actual container-based approach (Podman, systemd-enabled containers) used in practice.
- **Docs — QW6: design doc version bump** — version header updated 1.0.2 → 1.0.3.

---

## [1.0.2] — 2026-02-19

### Changed
- **UX — M2: Risk level missing from tool descriptions** — added "Moderate risk." suffix to
  `pkg_update`, `user_modify`, `svc_enable`, and `svc_disable` descriptions so that risk is
  visible to calling LLMs without requiring them to inspect the `riskLevel` field separately.
- **UX — M3: `pkg_update` implicit all-system-upgrade** — clarified that omitting `packages`
  upgrades ALL installed packages (not just a subset), preventing accidental full-system upgrades.
- **UX — L1: `sec_check_suid` limit parameter** — added `limit` param (default 100, max 500)
  replacing the hardcoded `head -100` cut-off. Callers can now request more results on busy systems.
- **UX — L2: `affected_services` now populated in confirmation responses** — safety gate wires
  `serviceName` through to `preview.affected_services`, fulfilling the type contract that was
  already declared but never filled.
- **UX — L3: `net_test` test parameter description** — added `.describe()` explaining all four
  options including "all" (runs ping + traceroute + dig together).

---

## [1.0.1] — 2026-02-19

### Changed
- **UX — H1: `confirmed` / `dry_run` parameter descriptions** — added `.describe()` annotations
  to `confirmed` and `dry_run` on all ~30 state-changing tools across 9 modules (packages,
  services, firewall, users, storage, networking, security, backup, containers, cron).
  The annotations tell calling LLMs exactly when and why to set each flag, improving invocation
  correctness without any runtime behaviour change.
- **UX — H2: Missing parameter descriptions on operation-critical fields** — added `.describe()`
  to fields that lacked guidance: `packages` array (pkg_remove, pkg_purge), `package`/`version`
  (pkg_rollback), `service` (all svc_* tools), `lines` (svc_logs), all 7 fields in the firewall
  `ruleSchema` (action, direction, port, protocol, source, destination, comment), `name`/`vg`/`size`
  (lvm_create_lv), `lv_path`/`size` (lvm_resize), `destination`/`gateway`/`interface`
  (net_routes_modify), `shell`/`home`/`groups`/`system`/`comment` (user_create), `mode`/`owner`
  (perms_set), `actions` (sec_harden_ssh).
- **UX — M1: Added `dry_run` preview mode to 7 tools that had `confirmed` but no preview path** —
  fw_remove_rule, svc_enable, svc_disable, user_modify, group_create, group_delete, mount_remove.
  Each now returns `{ would_run: "..." }` without executing when `dry_run: true`.

---

## [1.0.0] - 2026-02-17

### Added
- 5-layer self-testing framework with 1343 assertions across all 106 tools
  - Layer 1: Structural validation (92 pytest tests)
  - Layer 2: MCP server startup validation (14 tests)
  - Layer 3: Tool execution via MCP protocol (1188 assertions, 106 tools)
  - Layer 4: Safety gate unit + E2E tests (26 tests)
  - Layer 5: Knowledge base unit tests (23 tests)
- Disposable Fedora 43 test container with systemd (Dockerfile, docker-compose.yml, setup-fixtures.sh)
- Test runner orchestrator (`tests/run_tests.sh`) with `--unit-only`, `--container-only`, `--skip-container`, `--fresh` modes
- Self-test protocol and results documentation
- `.gitignore` for build artifacts

### Changed
- MCP config updated to use bundled CJS output
- Design document refined with implementation details

## [0.1.0] - 2026-02-17

### Added
- Initial release with 106 MCP tools across 15 modules
- Safety gate with risk classification and confirmation flow
- Knowledge base with 8 YAML profiles (crowdsec, docker, fail2ban, nginx, pihole, sshd, ufw, unbound)
- Distro detection for RHEL/Debian/Arch families
- esbuild CJS bundle for distribution
