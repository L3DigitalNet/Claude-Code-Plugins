---
name: systemd
description: >
  systemd init system and service manager: unit files, service lifecycle,
  timers (cron replacement), socket activation, targets, dependency ordering,
  security sandboxing, journald log integration, and troubleshooting.
  Triggers on: systemd, systemctl, service unit, systemd service, systemd timer,
  .service file, unit file, systemd target, daemon-reload, journalctl, systemd-analyze,
  ExecStart, WantedBy, After=, Requires=, EnvironmentFile, drop-in, oneshot service,
  socket activation.
globs:
  - "/etc/systemd/system/*.service"
  - "/etc/systemd/system/*.timer"
  - "/etc/systemd/system/*.socket"
  - "/etc/systemd/system/*.target"
  - "/etc/systemd/system/*.path"
  - "/etc/systemd/system/**/*.service"
  - "/etc/systemd/system/**/*.timer"
---

## Identity

- **PID**: 1 — systemd is the first process started by the kernel; all other processes are its descendants
- **System unit dirs**: `/etc/systemd/system/` (admin-created, highest priority), `/lib/systemd/system/` (package-installed, do not edit), `/run/systemd/system/` (runtime, ephemeral)
- **User unit dir**: `~/.config/systemd/user/` (no root needed; started at login via `--user` instance)
- **Drop-in dir**: `/etc/systemd/system/<unit>.d/*.conf` — fragments merged on top of the base unit
- **Logs**: `journalctl -u <unit>` (system), `journalctl --user -u <unit>` (user instance)

## Key Operations

| Operation | Command |
|-----------|---------|
| Show status + recent log | `systemctl status <unit>` |
| Start | `sudo systemctl start <unit>` |
| Stop | `sudo systemctl stop <unit>` |
| Restart (stop + start) | `sudo systemctl restart <unit>` |
| Reload (SIGHUP, no downtime) | `sudo systemctl reload <unit>` |
| Enable at boot | `sudo systemctl enable <unit>` |
| Enable and start now | `sudo systemctl enable --now <unit>` |
| Disable at boot | `sudo systemctl disable <unit>` |
| Mask (prevent start by any means) | `sudo systemctl mask <unit>` |
| Unmask | `sudo systemctl unmask <unit>` |
| Reload unit definitions (MANDATORY after editing) | `sudo systemctl daemon-reload` |
| List all loaded units | `systemctl list-units` |
| List failed units | `systemctl list-units --state=failed` |
| List units by type | `systemctl list-units --type=service` |
| List all installed unit files | `systemctl list-unit-files` |
| Show unit's effective config | `systemctl show <unit>` |
| Print the unit file | `systemctl cat <unit>` |
| Open drop-in editor | `sudo systemctl edit <unit>` |
| Edit the full unit file | `sudo systemctl edit --full <unit>` |
| Follow logs in real time | `journalctl -fu <unit>` |
| Show logs since last boot | `journalctl -u <unit> -b` |
| Show boot time summary | `systemd-analyze` |
| Show per-unit startup times | `systemd-analyze blame` |
| Show dependency tree | `systemctl list-dependencies <unit>` |
| List all active timers | `systemctl list-timers` |
| Check if unit is enabled | `systemctl is-enabled <unit>` |
| Check if unit is active | `systemctl is-active <unit>` |
| Check overall system health | `systemctl is-system-running` |

## Expected State

- PID 1 is `systemd`: `ps -p 1 -o comm=` → `systemd`
- System is fully booted: `systemctl is-system-running` → `running` (or `degraded` if any unit failed)
- All required targets reached: `systemctl list-units --type=target --state=active`
- No unexpected failed units: `systemctl list-units --state=failed` → empty

## Health Checks

1. `systemctl is-system-running` → `running` (degraded means at least one unit failed)
2. `systemctl list-units --state=failed` → identify failed units; run `systemctl status <unit>` on each
3. `systemd-analyze blame` → surface services taking longest to start
4. `journalctl -p err -b` → all error-level log entries since last boot

## Common Failures

| Symptom | Likely cause | Check/Fix |
|---------|-------------|-----------|
| `Unit <name>.service not found` | Unit file missing or wrong name | `systemctl list-unit-files \| grep <name>`; check `/etc/systemd/system/` |
| `Failed to connect to bus: No such file or directory` | Running as non-root without `--user` | Add `sudo` for system units; use `systemctl --user` for user instance |
| Service fails, won't restart | `Restart=` not set or set to `no` | Set `Restart=on-failure` in `[Service]`; then `daemon-reload` |
| `ExecStart= references a path that cannot be found` | Wrong binary path or missing shebang | Verify path with `which <cmd>`; use absolute path in `ExecStart=` |
| `EnvironmentFile not found` | Env file path wrong or not created | Check path; create the file; `daemon-reload` + `restart` |
| Unit is masked | `systemctl mask` was called | `sudo systemctl unmask <unit>` |
| Timer not firing | Timer not enabled, or `OnCalendar=` syntax wrong | `systemctl list-timers`; validate syntax with `systemd-analyze calendar '<expr>'` |
| `Permission denied` in ExecStart | Service user lacks access to file/socket | Check `User=`/`Group=` in unit; fix ownership with `chown`/`chmod` |
| Changes not taking effect after edit | `daemon-reload` not run | Always run `sudo systemctl daemon-reload` after any unit file change |
| `Start request repeated too quickly` | Service crashes immediately; systemd stops retrying | `journalctl -u <unit> -n 50` to find crash reason; fix the underlying error |

## Pain Points

- **`daemon-reload` is mandatory** after every unit file edit — systemd reads unit files at load time, not at start time. Skipping this is the single most common mistake.
- **Drop-ins survive package upgrades**; editing the original `/lib/systemd/system/` file does not. Always use `systemctl edit <unit>` to create a drop-in in `/etc/systemd/system/<unit>.d/override.conf`.
- **`After=` is ordering, not dependency**: `After=network.target` means "start after network.target if both are activated" — it does not cause network.target to start. Add `Wants=` or `Requires=` to express actual dependency.
- **`Requires=` is hard dependency**: if the required unit stops or fails, this unit stops too. Prefer `Wants=` (soft dependency) unless the hard stop behavior is intentional.
- **`Type=` determines when systemd considers startup complete**: `simple` (default, ExecStart is the main process), `forking` (parent exits, child continues — requires `PIDFile=`), `notify` (service sends `sd_notify` ready signal — most reliable), `oneshot` (process exits when done; unit remains active until stop), `dbus` (registers a bus name when ready).
- **`WantedBy=multi-user.target`** is what `systemctl enable` acts on — it creates a symlink in `multi-user.target.wants/`. Without `[Install]` section, `enable` is a no-op.
- **User instance vs system instance**: `systemctl --user` manages per-user services; they start at login (not boot unless `loginctl enable-linger <user>` is set). Environment, paths, and journal are separate.
- **`systemctl reload`** sends SIGHUP — only works if the service handles it. For services that don't, use `restart`. Check with `ExecReload=` presence in the unit.

## References

See `references/` for:
- `service-unit.annotated` — complete service unit with every directive explained; includes timer and socket examples
- `common-patterns.md` — task-organized patterns: custom script service, env file, restart on failure, oneshot, timer, drop-in, non-root user, socket activation, security hardening, user instance
- `docs.md` — official documentation links
