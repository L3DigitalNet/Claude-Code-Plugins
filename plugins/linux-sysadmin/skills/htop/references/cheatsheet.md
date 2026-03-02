# htop Cheatsheet

## 1. Launch with targeted scope

```bash
htop                    # all processes, current user's view
htop -u deploy          # show only processes owned by "deploy"
htop -p 1234,5678       # watch specific PIDs only
htop -d 10              # set refresh delay to 1.0 seconds (unit = 10ths of a second)
htop --no-color         # plain ASCII, no color (useful for logging or narrow terminals)
```

---

## 2. Searching for a process

Press `F3` or `/` to open the search bar. Type part of the process name.
htop highlights the first match and jumps to it. Press `F3` again to find the next match.

This is case-sensitive substring search — not a regex.

---

## 3. Filtering the process list

Press `\` (backslash) to open the filter bar. The process list narrows to matching entries in real time.
Press `Esc` to clear the filter.

Difference from search: filter hides non-matching rows; search highlights and scrolls.

---

## 4. Killing a process

1. Navigate to the process (arrow keys or search).
2. Press `F9` to open the signal selector.
3. Arrow keys move through signals. Common targets:
   - `15` SIGTERM — ask the process to stop gracefully (default)
   - `9` SIGKILL — force kill immediately (no cleanup)
   - `1` SIGHUP — reload config (for daemons that support it)
4. Press `Enter` to send the signal.

---

## 5. Renicing a process

Navigate to the process, then:
- `F7` — decrease nice value (increase priority; requires root for values below 0)
- `F8` — increase nice value (lower priority; any user can raise their own processes' nice)

Nice range: -20 (highest priority) to +19 (lowest). Default is 0.

---

## 6. Process tree view

Press `F5` or `t` to toggle tree mode. Processes indent under their parent.

```
├─ sshd (1234)
│   └─ bash (5678)
│       └─ htop (9012)
```

Press `Space` on a tree node to collapse/expand that branch.
Press `H` to hide userland threads (reduces noise for multi-threaded apps).
Press `K` to hide kernel threads.

---

## 7. Sorting by a column

Press `F6` to open the sort column menu. Arrow to the column name, press `Enter`.

Common sorts:
- `CPU%` — find CPU hogs
- `MEM%` — find memory consumers
- `TIME+` — cumulative CPU time (long-running processes)
- `PID` — restore chronological order

Press `I` to invert the sort order.

---

## 8. Customizing columns and meters (F2 Setup)

Press `F2` to open Setup. Three panels:
- **Meters** (top section): add/remove/reorder CPU bars, memory bars, clock, hostname
- **Display options**: tree view default, hide threads, highlight changes, etc.
- **Colors**: built-in color schemes (Default, Black Night, etc.)

Changes are written to `~/.config/htop/htoprc` when you quit htop.

---

## 9. Following a process as it moves

Navigate to a process and press `F` to enter "follow" mode. The cursor tracks that process
even as it changes position in the sorted list (e.g., as its CPU% fluctuates).

Press any arrow key to exit follow mode.

---

## 10. Quick strace without leaving htop (htop 3.x)

In htop 3.x, select a process and press `s` to attach strace to it.
htop opens a pane showing live syscall output.

If `s` is unresponsive, strace is not installed:
```bash
apt install strace   # Debian/Ubuntu
dnf install strace   # RHEL/Fedora
```

Alternatively run directly: `strace -p <pid> -e trace=network,file`
