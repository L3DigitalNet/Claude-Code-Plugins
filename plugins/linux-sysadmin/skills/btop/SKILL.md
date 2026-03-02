---
name: btop
description: >
  btop is an interactive terminal resource monitor displaying CPU, memory, disk, network,
  and process stats in a rich TUI. It replaces htop for users who want graph-based views
  and mouse support without leaving the terminal.
  Triggers on: "btop", "process monitor", "resource monitor", "system monitor TUI",
  "cpu usage tui", "htop alternative", "bpytop", "bashtop".
globs: []
---

## Identity

| Property | Value |
|----------|-------|
| **Binary** | `btop` |
| **Config** | `~/.config/btop/btop.conf` (auto-created on first run) |
| **Logs** | No persistent logs — output to terminal |
| **Type** | Interactive terminal UI |
| **Install** | `apt install btop` (Debian/Ubuntu 22.04+) / `dnf install btop` (RHEL/Fedora) |

## Key Operations

| Task | Command |
|------|---------|
| Launch | `btop` |
| Quit | `q` or `Ctrl+C` |
| Help overlay | `?` |
| Toggle process tree | `e` |
| Kill signal menu | `k` (opens signal selector for selected process) |
| Filter processes | `f` then type filter string; `Esc` to clear |
| Sort columns | Click column header (mouse) or `left`/`right` arrows |
| Change graph type | `t` cycles through graph styles |
| Network stats | Always visible in net box; `n` toggles net box focus |
| Disk I/O | Always visible in disk box; `d` toggles disk box |
| Per-core CPU view | `1` toggles single-core vs aggregate CPU view |
| Toggle mouse support | `m` |
| Open options menu | `o` |
| Jump to next box | `Tab` |

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `btop: command not found` | Not installed or not in PATH | `apt install btop` or `dnf install btop`; snap installs land in `/snap/bin/` |
| Mouse clicks not registering | Terminal emulator or SSH session doesn't forward mouse events | Press `m` to confirm mouse mode is on; try a different terminal or `btop --utf-force` |
| Colors look wrong / monochrome | Terminal doesn't support 256 colors | Set `TERM=xterm-256color` before launching; check `echo $COLORTERM` |
| Snap-installed btop can't find config | Config location differs under snap confinement | Config is at `~/snap/btop/current/.config/btop/btop.conf` instead of `~/.config/btop/` |
| Kill confirmation doesn't respond | Mouse mode disabled; keyboard required | Use arrow keys to select signal, `Enter` to confirm, `Esc` to cancel |
| Battery widget missing | No battery present (desktop/server) | This is expected — the battery box only appears on systems that report a battery |
| High CPU from btop itself | Refresh interval too low | Press `o` → increase `update_ms` (default 2000 ms is fine; 500 ms causes noticeable load) |

## Pain Points

- **Mouse support not available in all terminals**: some terminal emulators or SSH multiplexers (screen, older tmux configs) don't pass mouse events. Toggle with `m` to verify; fall back to keyboard nav.
- **256-color requirement**: btop's default theme needs a 256-color terminal. On minimal servers, `TERM` may be set to `xterm` (8 colors) — set `TERM=xterm-256color` to fix rendering.
- **Snap config path diverges**: when installed via snap, btop runs in a confined namespace and writes config to `~/snap/btop/current/.config/btop/btop.conf`. Editing `~/.config/btop/btop.conf` has no effect on the snap build.
- **Kill requires confirmation dialog**: unlike htop's direct `F9` → signal flow, btop opens a modal dialog. This is intentional but slower under keyboard-only navigation.
- **Battery widget only appears on laptops**: the battery section is entirely absent on desktops and servers — this is not a bug or config issue.
- **No regex in process filter**: the `f` filter does substring matching only. For pattern-based filtering, pipe `ps` or `pgrep` output externally instead.

## References

See `references/` for:
- `cheatsheet.md` — 10 task-organized patterns
- `docs.md` — official documentation links
