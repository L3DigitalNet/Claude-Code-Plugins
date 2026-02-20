# Changelog

All notable changes to the linux-sysadmin-mcp plugin are documented here.

## [1.0.2] - 2026-02-19

### Changed
- release: 5 plugin releases — design-assistant 0.3.0, linux-sysadmin-mcp 1.0.2, agent-orchestrator 1.0.2, release-pipeline 1.4.0, home-assistant-dev 2.2.0
- add Principles section to all 7 plugin READMEs
- standardise all plugin READMEs with consistent sections

### Fixed
- update hono 4.11.9 → 4.12.0 in mcp-server lockfiles (GHSA-gq3j-xvxp-8hrf)


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
