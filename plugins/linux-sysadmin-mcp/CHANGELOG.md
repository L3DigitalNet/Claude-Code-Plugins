# Changelog

All notable changes to the linux-sysadmin-mcp plugin are documented here.

## [1.0.3] — 2026-02-19

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
- **Docs — C-009: tool count consistency** — README header updated from "~100 tools" to "~107
  tools" to match the module table total.
- **Docs — C-010: design doc installation block** — `claude install linux-sysadmin-commands`
  line marked as `[Planned]` with a comment noting it is not yet implemented.

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
