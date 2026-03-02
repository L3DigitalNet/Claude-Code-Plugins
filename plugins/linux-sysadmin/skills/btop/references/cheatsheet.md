# btop Cheatsheet

## 1. Launch and basic navigation

```bash
btop                    # launch with defaults
btop -p 0              # force CPU preset 0 (no graphs, minimal)
btop --utf-force        # force UTF-8 box-drawing (useful on older terminals)
```

Inside btop: `Tab` moves focus between boxes; arrow keys navigate within a box.

---

## 2. Process filtering

Press `f` to open the filter bar, type a substring (process name, user, or argument), then `Enter`.
Press `Esc` or `f` again to clear.

```
f → nginx        # show only processes matching "nginx"
f → www-data     # show only processes owned by www-data
```

---

## 3. Sending signals to a process

1. Navigate to the process in the process list.
2. Press `k` to open the signal menu.
3. Use arrow keys to select the signal (SIGTERM, SIGKILL, SIGHUP, etc.).
4. Press `Enter` to confirm, `Esc` to cancel.

Common signals: `15` SIGTERM (graceful stop), `9` SIGKILL (force kill), `1` SIGHUP (reload config).

---

## 4. Toggling process tree view

Press `e` to expand/collapse the full process tree (parent → child relationships).
Useful for identifying which parent spawned a runaway child process.

---

## 5. Per-core CPU breakdown

Press `1` to toggle between:
- Aggregate CPU bar (default — single bar for all cores combined)
- Per-core bars (each logical CPU shown separately)

Per-core view is useful for diagnosing single-threaded bottlenecks or IRQ imbalance.

---

## 6. Changing graph styles

Press `t` to cycle through graph styles:
- `Braille` (highest resolution, Unicode braille chars)
- `Block` (█ characters — works on any terminal)
- `Tty` (ASCII-safe, for serial consoles or minimal terminals)

If graphs render as garbage characters, switch to Block or Tty.

---

## 7. Adjusting update interval

Press `o` to open the Options menu, then change `update_ms`:

```
250   ms — very responsive, visible CPU overhead on slow hosts
1000  ms — balanced (1 second)
2000  ms — default, low overhead
5000  ms — quiet monitoring on shared/production hosts
```

Setting persists to `~/.config/btop/btop.conf` as `update_ms = 2000`.

---

## 8. Sorting processes

Click a column header (mouse mode) to sort by that field.
Keyboard: navigate to the process box, then use `left`/`right` to cycle sort column, `i` to invert sort order.

Common sort targets: CPU%, MEM%, PID, USER, Command.

---

## 9. Disabling boxes to reduce clutter

Press `o` → Options → toggle `show_disks`, `show_net`, `show_battery` off for a cleaner view on systems where those boxes add noise (e.g., a diskless container host).

Alternatively, resize boxes by dragging their borders with the mouse.

---

## 10. Editing the config file directly

```bash
# Config is auto-created on first run
"${EDITOR:-nano}" ~/.config/btop/btop.conf

# Key settings
color_theme = "Default"     # theme name from ~/.config/btop/themes/
update_ms = 2000            # refresh interval in milliseconds
proc_tree = False           # start with tree view on
vim_keys = False            # enable hjkl navigation
show_battery = True         # show battery box if present
```

After editing, changes take effect on next btop launch (no reload signal).
