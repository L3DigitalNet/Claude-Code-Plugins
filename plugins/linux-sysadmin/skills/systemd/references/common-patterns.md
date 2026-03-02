# systemd Common Patterns

Each block is complete and copy-paste-ready. Place service units in
`/etc/systemd/system/<name>.service`. After creating or editing any unit file:

```bash
sudo systemctl daemon-reload
```

---

## 1. Simple Service for a Custom Script or Binary

Wraps `/usr/local/bin/myapp` as a system service. The binary runs in the foreground
and writes to the journal automatically.

```ini
# /etc/systemd/system/myapp.service
[Unit]
Description=My Application
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/myapp --port 8080
Restart=on-failure
RestartSec=5s
User=myapp
Group=myapp

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now myapp
systemctl status myapp
```

---

## 2. Service with Environment File

Keeps secrets and runtime config out of the unit file. The environment file is a
plain `KEY=VALUE` file, one entry per line. Comments (`# ...`) are supported.

```ini
# /etc/myapp/environment
DATABASE_URL=postgres://user:secret@localhost/myapp
APP_SECRET_KEY=changeme
LOG_LEVEL=info
```

```ini
# /etc/systemd/system/myapp.service
[Unit]
Description=My Application
After=network.target postgresql.service
Wants=postgresql.service

[Service]
Type=simple
EnvironmentFile=/etc/myapp/environment
ExecStart=/usr/local/bin/myapp
Restart=on-failure
User=myapp
Group=myapp

[Install]
WantedBy=multi-user.target
```

The `-` prefix makes the file optional — service starts even if the file is missing:
```ini
EnvironmentFile=-/etc/myapp/environment
```

---

## 3. Service with Automatic Restart on Failure

`Restart=on-failure` restarts on non-zero exit, crash, or timeout — but not on a
clean exit (code 0). `StartLimitBurst` prevents runaway restart loops.

```ini
# /etc/systemd/system/myapp.service
[Unit]
Description=My Application (auto-restart)
After=network-online.target
Wants=network-online.target
# Stop retrying after 5 starts in 60 seconds.
StartLimitIntervalSec=60s
StartLimitBurst=5

[Service]
Type=simple
ExecStart=/usr/local/bin/myapp
Restart=on-failure
RestartSec=10s
User=myapp

[Install]
WantedBy=multi-user.target
```

Check restart history: `systemctl status myapp` shows restart count and last exit code.

---

## 4. Oneshot Service (Runs Once, Not a Daemon)

Suitable for initialization scripts, database migrations, or any task that exits
when finished. `RemainAfterExit=yes` keeps the unit in the `active` state after
the process exits, so downstream units with `After=myapp-init.service` can depend on it.

```ini
# /etc/systemd/system/myapp-migrate.service
[Unit]
Description=Run myapp database migrations
After=postgresql.service
Requires=postgresql.service
# Only run if not already done — use ConditionPathExists to gate on a sentinel file.
ConditionPathExists=!/var/lib/myapp/.migrations-done

[Service]
Type=oneshot
RemainAfterExit=yes
User=myapp
ExecStart=/usr/local/bin/myapp migrate
ExecStartPost=/bin/touch /var/lib/myapp/.migrations-done

[Install]
WantedBy=multi-user.target
```

Run once manually: `sudo systemctl start myapp-migrate`
Status: `systemctl status myapp-migrate` shows `active (exited)` on success.

---

## 5. Timer (Replace a Cron Job)

Two files with the same base name: the `.timer` activates the `.service`.
The service does the actual work; the timer handles scheduling.

```ini
# /etc/systemd/system/myapp-backup.service
[Unit]
Description=myapp backup task
After=network.target

[Service]
Type=oneshot
User=myapp
ExecStart=/usr/local/bin/myapp backup --dest /var/backups/myapp
```

```ini
# /etc/systemd/system/myapp-backup.timer
[Unit]
Description=Daily myapp backup at 02:00
Requires=myapp-backup.service

[Timer]
# Every day at 02:00. Validate: systemd-analyze calendar '02:00'
OnCalendar=*-*-* 02:00:00
# Run immediately if the last run was missed (e.g., system was off).
Persistent=true
# Spread up to 15 minutes of random delay — avoids thundering herd on many hosts.
RandomizedDelaySec=15min

[Install]
WantedBy=timers.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now myapp-backup.timer
# Check timer status and next run:
systemctl list-timers myapp-backup.timer
```

---

## 6. Drop-in Override Without Editing the Original Unit

`systemctl edit` creates a drop-in at `/etc/systemd/system/<unit>.d/override.conf`.
Drop-ins survive package upgrades; editing the original `/lib/systemd/system/` file does not.

Common use: override environment, increase limits, add pre/post commands.

```bash
sudo systemctl edit nginx.service
```

This opens an editor. Add only the directives you want to override:

```ini
# /etc/systemd/system/nginx.service.d/override.conf
[Service]
# Clear and replace the existing LimitNOFILE.
# Setting a directive to empty first clears any previous value before setting the new one.
LimitNOFILE=
LimitNOFILE=65536

# Add an extra environment variable without replacing the base unit's environment.
Environment=MY_CUSTOM_VAR=true
```

```bash
sudo systemctl daemon-reload
sudo systemctl restart nginx
# Verify the merged config:
systemctl cat nginx.service
```

---

## 7. Run a Service as a Non-Root User

The user and group must exist before starting the service. Create them with
`useradd --system --no-create-home myapp` for a system account without a login shell.

```ini
# /etc/systemd/system/myapp.service
[Unit]
Description=My Application (non-root)
After=network.target

[Service]
Type=simple
User=myapp
Group=myapp
WorkingDirectory=/var/lib/myapp
ExecStart=/usr/local/bin/myapp
# Allow writes to the app's data dir and runtime dir only.
ReadWritePaths=/var/lib/myapp /run/myapp
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes
NoNewPrivileges=yes

[Install]
WantedBy=multi-user.target
```

```bash
# Create the system user:
sudo useradd --system --no-create-home --shell /usr/sbin/nologin myapp
# Create directories with correct ownership:
sudo mkdir -p /var/lib/myapp /run/myapp
sudo chown myapp:myapp /var/lib/myapp /run/myapp
sudo systemctl daemon-reload && sudo systemctl enable --now myapp
```

---

## 8. Socket Activation

systemd holds the socket open; the service starts on the first connection and
inherits the file descriptor. The service must use `sd_listen_fds()` or the
`LISTEN_FDS` environment variable to receive the socket.

```ini
# /etc/systemd/system/myapp.socket
[Unit]
Description=myapp socket

[Socket]
ListenStream=8080
# For UNIX domain sockets:
# ListenStream=/run/myapp/myapp.sock
# SocketMode=0660
# SocketUser=myapp
# SocketGroup=myapp

[Install]
WantedBy=sockets.target
```

```ini
# /etc/systemd/system/myapp.service
[Unit]
Description=My Application (socket-activated)
Requires=myapp.socket

[Service]
Type=simple
User=myapp
ExecStart=/usr/local/bin/myapp
# Service exits after idle; systemd will restart on next connection.
```

```bash
sudo systemctl daemon-reload
# Enable the socket, not the service — systemd starts the service automatically.
sudo systemctl enable --now myapp.socket
systemctl status myapp.socket
```

---

## 9. Security Hardening (Sandbox Directives)

A layered set of `[Service]` directives that restrict what the process can access.
Apply in order of least to most restrictive; test with `systemctl status` after each.

```ini
[Service]
# Isolate /tmp and /var/tmp from the rest of the system.
PrivateTmp=yes

# Mount /usr, /boot, /efi read-only. Service cannot modify system files.
ProtectSystem=strict

# Prevent access to /home, /root, /run/user.
ProtectHome=yes

# Block privilege escalation via setuid/setgid or file capabilities.
NoNewPrivileges=yes

# Give the service its own network namespace (no network access at all).
# Remove if the service needs network.
# PrivateNetwork=yes

# Restrict which address families the service can use.
# RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX

# List of syscall groups the service is allowed to make. Everything else is blocked.
# SystemCallFilter=@system-service

# Make /proc entries for other PIDs invisible.
ProtectProc=invisible

# Hide kernel tunables in /proc/sys from the service.
ProtectKernelTunables=yes

# Prevent loading kernel modules.
ProtectKernelModules=yes

# Prevent writing to the kernel message ring.
ProtectKernelLogs=yes

# Restrict what capabilities the service can use (empty = none).
# CapabilityBoundingSet=CAP_NET_BIND_SERVICE

# Paths the service is explicitly allowed to write.
ReadWritePaths=/var/lib/myapp

# Everything else is read-only (requires ProtectSystem=strict).
ReadOnlyPaths=/etc/myapp
```

Audit what a service actually needs: `systemd-analyze security myapp.service`
This prints an exposure score (0 = most secure) and highlights missing directives.

---

## 10. User Systemd Instance (No Root Required)

User units run under your login session. Useful for personal services, development
servers, or any process that shouldn't require sudo.

```ini
# ~/.config/systemd/user/myapp.service
[Unit]
Description=My Personal Application
After=network.target

[Service]
Type=simple
ExecStart=%h/.local/bin/myapp --port 8080
# %h expands to the home directory.
WorkingDirectory=%h/myapp
Restart=on-failure
# Environment variables from the user session are inherited automatically.

[Install]
WantedBy=default.target
```

```bash
# No sudo needed:
systemctl --user daemon-reload
systemctl --user enable --now myapp
systemctl --user status myapp
journalctl --user -u myapp -f

# Keep running after logout (requires root to set once per user):
sudo loginctl enable-linger $USER
```

User units stop when the user logs out unless `loginctl enable-linger` is set.
