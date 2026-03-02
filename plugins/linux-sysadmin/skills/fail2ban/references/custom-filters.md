# Writing Custom fail2ban Filters

Custom filters go in `/etc/fail2ban/filter.d/<name>.conf`. The jail references them by name (without `.conf`).

---

## 1. Filter File Structure

```ini
# /etc/fail2ban/filter.d/myapp.conf

[INCLUDES]
# Optional: inherit definitions from another filter file.
# Useful for inheriting common datepatterns without copy-pasting.
before = common.conf

[Definition]
# _daemon: Matches the syslog/journald identifier for this service.
# Used when logs pass through syslog and include a daemon prefix.
# _daemon = myapp

# failregex: One or more Python regex patterns. An IP matching any
# pattern during the findtime window counts as one failure.
# <HOST> is a required placeholder — fail2ban substitutes it with
# the regex for an IPv4 or IPv6 address.
failregex = ^<HOST> .* Failed login attempt$
            ^Authentication failure from <HOST>: .*$

# ignoreregex: Patterns that cancel a failregex match on the same line.
# Use to exclude known-safe log lines that would otherwise trigger.
ignoreregex = ^<HOST> .* health-check.*$

# datepattern: Override how fail2ban parses timestamps in log lines.
# Only needed when the default patterns don't recognize the format.
# See section 4 below.
# datepattern = %%Y-%%m-%%dT%%H:%%M:%%S
```

---

## 2. failregex Syntax

`<HOST>` is the only required placeholder. It expands to a pattern that matches IPv4 and IPv6 addresses. Everything else is standard Python `re` syntax.

**Anchoring:** `^` anchors to the start of the log line after the timestamp is stripped. Do not anchor to `$` unless you are certain of exact line endings.

**Character classes and quantifiers** work as in Python regex: `\d+`, `\w+`, `.*`, `.+`, `[a-z]+`.

**Named groups** are supported but not required. fail2ban extracts `<HOST>` automatically.

**Multiple patterns:** Each line in `failregex` is a separate pattern. A match on any one of them counts as a failure. Blank lines and comment lines are ignored.

```ini
# Matches: "2024-01-15 10:23:45 Failed login from 203.0.113.42"
failregex = ^Failed login from <HOST>$

# Matches: "[ERROR] 203.0.113.42 - invalid credentials"
failregex = ^\[ERROR\] <HOST> - invalid credentials$

# Both in one filter:
failregex = ^Failed login from <HOST>$
            ^\[ERROR\] <HOST> - invalid credentials$
```

---

## 3. Testing with fail2ban-regex

Always test before deploying. `fail2ban-regex` reads a log file (or stdin) and reports how many lines match.

```bash
# Basic test: filter against a log file
sudo fail2ban-regex /var/log/myapp/app.log /etc/fail2ban/filter.d/myapp.conf

# Test against journald output (pipe directly)
sudo journalctl -u myapp --no-pager | sudo fail2ban-regex stdin /etc/fail2ban/filter.d/myapp.conf

# Verbose output: shows each matched line and which failregex matched
sudo fail2ban-regex --print-all-matched /var/log/myapp/app.log /etc/fail2ban/filter.d/myapp.conf

# Debug a datepattern: shows how timestamps are parsed
sudo fail2ban-regex --print-all-missed /var/log/myapp/app.log /etc/fail2ban/filter.d/myapp.conf
```

A result of `0 matches` means either the regex is wrong or the timestamps aren't being parsed. Use `--print-all-missed` to see lines that were skipped due to timestamp failures — that points to a `datepattern` problem rather than a `failregex` problem.

---

## 4. datepattern

fail2ban tries several timestamp formats automatically. When logs use an unusual format, add `datepattern` to the `[Definition]` section.

The pattern uses Python `strftime` codes, **doubled** (`%%Y` not `%Y`) because fail2ban's config parser processes one level of `%`-substitution itself.

```ini
[Definition]
# ISO 8601 with T separator: 2024-01-15T10:23:45
datepattern = %%Y-%%m-%%dT%%H:%%M:%%S

# Unix timestamp (seconds since epoch): 1705315425
datepattern = {EPOCH}

# Custom: "Jan 15 10:23:45"
datepattern = %%b %%d %%H:%%M:%%S

# Multiple patterns (tried in order, first match wins):
datepattern = %%Y-%%m-%%dT%%H:%%M:%%S
              %%Y/%%m/%%d %%H:%%M:%%S
```

Run `fail2ban-regex --print-all-missed` to confirm timestamps are being parsed before debugging `failregex`.

---

## 5. Example: Custom nginx App Filter (JSON Access Logs)

nginx can log in JSON format. The default nginx filters don't handle JSON. This filter matches a JSON access log line where the remote IP appears as a field value.

Log line example:
```
{"time": "2024-01-15T10:23:45+00:00", "remote_addr": "203.0.113.42", "status": "401", "request": "POST /login HTTP/1.1"}
```

Filter (`/etc/fail2ban/filter.d/nginx-json-auth.conf`):

```ini
[Definition]
failregex = ^{"time": "[^"]+", "remote_addr": "<HOST>", "status": "401",.*$

ignoreregex =

datepattern = {^LN-BEG}%%Y-%%m-%%dT%%H:%%M:%%S
```

`{^LN-BEG}` tells fail2ban not to anchor date parsing to the start of the line — needed when the timestamp is embedded inside a JSON object rather than at the very beginning.

Jail entry:

```ini
[nginx-json-401]
enabled = true
port = http,https
filter = nginx-json-auth
logpath = /var/log/nginx/access.log
maxretry = 5
bantime = 1h
findtime = 10m
```

---

## 6. Example: Custom Application Filter (Generic Pattern)

Application logs "Failed login from X.X.X.X" to its own file.

Log lines:
```
2024-01-15 10:23:45 INFO  Failed login from 203.0.113.42 (user: admin)
2024-01-15 10:24:01 WARN  Failed login from 198.51.100.7 (user: root)
```

Filter (`/etc/fail2ban/filter.d/myapp.conf`):

```ini
[Definition]
failregex = ^ \w+\s+Failed login from <HOST> .*$

ignoreregex =

datepattern = %%Y-%%m-%%d %%H:%%M:%%S
```

The leading space before `\w+` accounts for the timestamp being stripped, leaving the log level (`INFO`, `WARN`) at the start of the remaining line. Adjust to match the actual format — use `--print-all-matched` to verify.

---

## 7. Multiline Filters

Some services log a failure across multiple lines. fail2ban supports this via `[Definition]` options `prefregex`, `maxlines`, and `journalmatch`.

```ini
[Definition]
# maxlines: How many consecutive log lines to combine before matching.
# Default: 1. Raising this has a performance cost — use sparingly.
maxlines = 2

# prefregex: A pre-filter applied to candidate lines before failregex.
# Lines not matching prefregex are ignored entirely — improves performance
# when the log is high-volume.
prefregex = ^.*(Failed|Invalid).*$

# failregex now matches against the combined block of maxlines lines.
# \n separates lines within the block.
failregex = ^.*Failed password for .* from <HOST>.*\n.*Invalid user.*$
```

Multiline matching is expensive. Only use it when the service genuinely requires it — prefer restructuring the log source or using `prefregex` to narrow the candidate set first.

---

## 8. backend = systemd (journald Logs)

When a service logs exclusively to journald (no file in `/var/log/`), set `backend = systemd` in the jail and use `journalmatch` instead of `logpath`. The filter's `failregex` matches against the `MESSAGE` field of journal entries.

```ini
# In jail.local or jail.d/myapp.conf:
[myapp]
enabled = true
port = 8080
filter = myapp
backend = systemd
journalmatch = _SYSTEMD_UNIT=myapp.service
maxretry = 5
bantime = 1h
findtime = 10m
```

`journalmatch` accepts systemd journal field expressions:

```
# Match a specific unit:
journalmatch = _SYSTEMD_UNIT=myapp.service

# Match by comm (process name):
journalmatch = _COMM=myapp

# Combine with + (logical AND across different fields):
journalmatch = _SYSTEMD_UNIT=myapp.service + PRIORITY=3

# Multiple values for the same field (logical OR, separate entries on same line):
journalmatch = _SYSTEMD_UNIT=myapp.service _SYSTEMD_UNIT=myapp-worker.service
```

The filter's `failregex` matches against the raw `MESSAGE` content — no timestamp prefix, since journald stores timestamps separately. Remove any timestamp anchoring from the pattern:

```ini
[Definition]
# For file-based logs (timestamp at line start):
# failregex = ^2024-\d\d-\d\d .* Failed login from <HOST>.*$

# For systemd backend (MESSAGE field only, no timestamp prefix):
failregex = ^.*Failed login from <HOST>.*$
```

Test against journald output before deploying:

```bash
sudo journalctl -u myapp --no-pager | sudo fail2ban-regex stdin /etc/fail2ban/filter.d/myapp.conf
```
