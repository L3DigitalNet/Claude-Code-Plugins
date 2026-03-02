---
name: htop
description: >
  htop is the classic interactive process viewer for Linux, providing real-time CPU, memory,
  and swap usage alongside a sortable, filterable process list with built-in kill and renice.
  It ships on most distros and serves as the go-to process manager when btop isn't available.
  Triggers on: "htop", "top", "process viewer", "kill process", "cpu load",
  "process management", "renice", "strace process", "interactive top".
globs: []
---

## Identity

| Property | Value |
|----------|-------|
| **Binary** | `htop` |
| **Config** | `~/.config/htop/htoprc` (written by htop on exit; also editable via F2 in-session) |
| **Logs** | No persistent logs — output to terminal |
| **Type** | Interactive terminal UI |
| **Install** | `apt install htop` (Debian/Ubuntu) / `dnf install htop` (RHEL/Fedora) |

## Key Operations

| Task | Command |
|------|---------|
| Launch | `htop` |
| Launch for specific user | `htop -u <username>` |
| Quit | `q` or `F10` |
| Help | `?` or `F1` |
| Setup (columns, colors, meters) | `F2` |
| Search process | `F3` or `/` |
| Filter by string | `\` (backslash) |
| Sort by column | `F6` then select column |
| Tree view toggle | `F5` or `t` |
| Kill process | `F9` (opens signal selector) |
| Renice (lower priority) | `F7` (decrease nice — higher priority) |
| Renice (raise priority) | `F8` (increase nice — lower priority) |
| Follow selected process | `F` (cursor tracks the process as it moves) |
| Namespace filter | `N` (toggle showing kernel threads) |
| Collapse/expand tree node | `Space` |

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `htop: command not found` | Not installed (unlike `top`, htop is optional) | `apt install htop` or `dnf install htop`; `top` is always available as fallback |
| htoprc causes strange display on new machine | Config was copied from a different terminal/size | Delete `~/.config/htop/htoprc` and relaunch to regenerate |
| F9 kills with wrong signal | Default is SIGTERM (15); process may need SIGKILL | In the F9 signal menu, navigate to SIGKILL (9) and press Enter |
| Process tree shows many `{process}` threads | Normal for multi-threaded apps (glibc thread names) | Press `H` to hide userland threads, or `K` to hide kernel threads |
| Filter (`\`) doesn't match expected process | Filter is case-sensitive substring, not a regex | Type a shorter substring; for regex use `ps aux | grep` externally |
| `strace` shortcut (F4 in some versions) unavailable | htop version < 3 or strace not installed | Use `strace -p <pid>` from a separate terminal instead |
| Colors absent or broken | Terminal TERM variable wrong | `TERM=xterm-256color htop` or set in shell profile |

## Pain Points

- **`top` is always available; htop may not be**: on minimal installs or containers, `htop` is absent. `top` is POSIX-required. Keep `top` usage in mind for scripts or unfamiliar hosts.
- **htoprc is fragile if edited by hand**: the config format is a mix of key=value and list sections. Hand-editing can corrupt the file silently — htop will just reset to defaults. Use F2 in-session instead.
- **F4 is a filter in htop, not strace**: older documentation and muscle memory from other tools may expect F4 to do something else. In htop, `\` is the recommended filter key; F4 was mapped differently in older versions.
- **F9 defaults to SIGTERM**: killing a frozen process requires navigating to SIGKILL (9) in the signal menu. SIGTERM won't stop an unresponsive process.
- **Process tree mixes threads and processes**: by default, htop shows kernel threads and userland threads alongside processes. Press `H` to hide userland threads and `K` to hide kernel threads for a cleaner view.
- **`-u` flag shows only one user's processes**: useful for multi-tenant systems, but easy to forget you're filtered — the header shows no indication of the active user filter.

## References

See `references/` for:
- `cheatsheet.md` — 10 task-organized patterns
- `docs.md` — official documentation links
