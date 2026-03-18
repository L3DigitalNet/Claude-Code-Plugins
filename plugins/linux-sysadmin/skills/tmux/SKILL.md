---
name: tmux
description: >
  tmux terminal multiplexer: session creation and attachment, window and pane
  management, detach/reattach, copy mode, synchronized panes, and configuration
  via ~/.tmux.conf.
  MUST consult when setting up or scripting tmux sessions.
triggerPhrases:
  - "tmux"
  - "terminal multiplexer"
  - "persistent session"
  - "detach session"
  - "screen"
  - "split terminal"
  - "window pane"
  - "ssh session"
  - "remote session"
globs:
  - "**/.tmux.conf"
  - "**/tmux.conf"
last_verified: "unverified"
---

## Identity

| Property | Value |
|----------|-------|
| **Binary** | `tmux` |
| **Config** | `~/.tmux.conf` or `/etc/tmux.conf` |
| **Logs** | No persistent logs — output to terminal |
| **Type** | CLI tool |
| **Install** | `apt install tmux` / `dnf install tmux` |

## Quick Start

```bash
sudo apt install tmux
tmux new-session -s work
# inside tmux: Ctrl+b d to detach
tmux attach-session -t work
tmux list-sessions
```

## Key Operations

| Task | Command |
|------|---------|
| New named session | `tmux new-session -s mysession` |
| Attach to named session | `tmux attach-session -t mysession` |
| Attach or create if absent | `tmux new-session -A -s mysession` |
| List all sessions | `tmux list-sessions` |
| Detach from session | prefix + `d` |
| New window | prefix + `c` |
| Next / previous window | prefix + `n` / `p` |
| Switch to window by number | prefix + `0`-`9` |
| Split pane horizontal (side by side) | prefix + `%` |
| Split pane vertical (top/bottom) | prefix + `"` |
| Navigate between panes | prefix + arrow keys |
| Resize pane | prefix + Ctrl+arrow (hold Ctrl, tap arrow) |
| Kill current pane | prefix + `x` |
| Kill current window | prefix + `&` |
| Kill a session | `tmux kill-session -t mysession` |
| Enter copy mode | prefix + `[` |
| Rename current window | prefix + `,` |
| Rename current session | prefix + `$` |
| Send same command to all panes | `tmux set-option -g synchronize-panes on` |
| Run command in a new detached session | `tmux new-session -d -s work 'top'` |

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `tmux attach` says "no sessions" | No running sessions | Start one: `tmux new-session -s main` |
| Ctrl+b conflicts with readline | Default prefix is Ctrl+b, same as readline "back char" | Remap in `~/.tmux.conf`: `set -g prefix C-a` + `bind C-a send-prefix` |
| Copy doesn't reach system clipboard | tmux copy mode uses internal buffer, not X clipboard | Install `xclip` and add: `bind -T copy-mode-vi y send -X copy-pipe 'xclip -sel clip'` |
| Mouse mode not working | Not enabled by default | Add to `~/.tmux.conf`: `set -g mouse on` |
| Nested tmux: inner prefix swallowed | Outer tmux intercepts the prefix | Send prefix to inner: press prefix twice (`Ctrl+b Ctrl+b`) |
| Colours look wrong in tmux | Terminal `TERM` not set to 256color | Add to `~/.tmux.conf`: `set -g default-terminal "screen-256color"` |
| Session not persisting after SSH disconnect | Session was foreground process, not tmux | Always start work in a named tmux session before running long jobs |

## Pain Points

- **Default prefix Ctrl+b conflicts with readline**: Readline uses Ctrl+b to move the cursor back one character. Most users remap the tmux prefix to Ctrl+a (matching GNU screen's default) in `~/.tmux.conf`.
- **Copy-paste requires extra configuration**: tmux copy mode fills an internal buffer. Getting content into the system clipboard requires `xclip`, `xsel`, or OSC 52 passthrough, plus config to wire them together. This is not set up by default.
- **Nested tmux needs double-prefix**: When ssh-ing into a remote host that also runs tmux, the local tmux intercepts the prefix. Send a prefix to the inner session with two prefix presses: `C-b C-b` for the inner window, `C-b C-b C-b` to send a literal `C-b`.
- **`tmux new` vs `tmux new-session`**: Both work interactively, but scripts should use `new-session` for clarity. `tmux new -A -s name` is the idiomatic "attach if exists, create if not" pattern.
- **Mouse mode must be enabled explicitly**: `set -g mouse on` enables click-to-focus, scrolling, and pane resizing via mouse. Without it, the mouse has no effect and scrolling uses the terminal emulator's scroll buffer instead of tmux's.

## See Also

- **btop** — Terminal-based resource monitor; often run inside tmux sessions
- **htop** — Interactive process viewer; commonly paired with tmux for monitoring

## References
See `references/` for:
- `cheatsheet.md` — task-organized command reference
- `docs.md` — official documentation links
