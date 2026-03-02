# tmux Command Reference

Default prefix is `Ctrl+b`. Commands below show the key sequence after the prefix
unless they are standalone shell commands. Many users remap the prefix to `Ctrl+a`
in `~/.tmux.conf`.

---

## 1. Session Management

```bash
# Create a new named session
tmux new-session -s work

# Attach to an existing named session
tmux attach-session -t work

# Attach if exists, create if not
tmux new-session -A -s work

# List all sessions
tmux list-sessions

# Kill a specific session
tmux kill-session -t work

# Kill the server (all sessions)
tmux kill-server
```

After prefix:
- `d` — Detach from current session
- `$` — Rename current session
- `s` — Show session list (interactive picker)

---

## 2. Window Management

```bash
# Create a new session with an initial window name
tmux new-session -s work -n editor

# Run a command in a new detached window
tmux new-window -t work -n logs 'tail -f /var/log/syslog'
```

After prefix:
- `c` — Create a new window
- `n` — Next window
- `p` — Previous window
- `0`-`9` — Switch to window by number
- `,` — Rename current window
- `&` — Kill current window (with confirmation)
- `w` — Show window list (interactive picker)
- `f` — Find window by name

---

## 3. Pane Splitting and Navigation

After prefix:
- `%` — Split horizontally (left/right panes)
- `"` — Split vertically (top/bottom panes)
- Arrow keys — Move focus to pane in that direction
- `o` — Cycle through panes
- `q` — Show pane numbers briefly (then press the number to jump)
- `x` — Kill current pane (with confirmation)
- `!` — Break pane out into its own window
- `z` — Zoom/unzoom current pane (full-screen toggle)

```bash
# Split the current window and run a command in the new pane
tmux split-window -h 'htop'
tmux split-window -v 'tail -f /var/log/syslog'
```

---

## 4. Pane Resizing and Layout

After prefix:
- `Ctrl+arrow` — Resize pane by 1 cell in arrow direction
- `Alt+arrow` — Resize pane by 5 cells (larger steps)
- `Space` — Cycle through preset layouts (even-horizontal, even-vertical, main-horizontal, main-vertical, tiled)

```bash
# Set a specific layout
tmux select-layout even-horizontal
tmux select-layout tiled

# Resize pane to exact dimensions
tmux resize-pane -D 10   # Down 10 lines
tmux resize-pane -R 20   # Right 20 columns
```

---

## 5. Copy Mode and Scrollback

After prefix:
- `[` — Enter copy mode (use arrow keys or vi keys to navigate)
- `]` — Paste from tmux buffer
- `q` — Exit copy mode

In copy mode (vi keys — requires `set-option -g mode-keys vi` in config):
- `/` — Search forward
- `?` — Search backward
- `n` / `N` — Next / previous search result
- `Space` — Start selection
- `Enter` — Copy selection and exit copy mode

```bash
# Show all paste buffers
tmux list-buffers

# Save top buffer to a file
tmux save-buffer /tmp/tmux-paste.txt

# Load a file into the paste buffer
tmux load-buffer /tmp/content.txt
```

---

## 6. Synchronized Panes

```bash
# Enable: send keystrokes to all panes in the current window simultaneously
tmux set-option -g synchronize-panes on

# Disable
tmux set-option -g synchronize-panes off

# Toggle via key binding (add to ~/.tmux.conf)
# bind S set-option -g synchronize-panes \; display-message "sync: #{?synchronize-panes,ON,OFF}"
```

Useful for running the same command on multiple servers simultaneously when each
pane is SSH'd into a different host.

---

## 7. Scripting tmux Sessions

```bash
# Create a session with multiple windows in one command
tmux new-session -d -s dev -n editor
tmux new-window -t dev -n server 'python3 -m http.server 8080'
tmux new-window -t dev -n logs 'tail -f /var/log/syslog'
tmux attach-session -t dev

# Send a command to a specific pane without attaching
tmux send-keys -t dev:editor 'vim .' Enter

# Send a command to all sessions' first windows
tmux list-sessions -F '#S' | xargs -I{} tmux send-keys -t {}:0 'uptime' Enter

# Check if a session exists
tmux has-session -t work 2>/dev/null && echo "exists" || echo "not found"
```

---

## 8. Configuration Basics

```bash
# ~/.tmux.conf — reload without restarting
tmux source-file ~/.tmux.conf
# Or: prefix + : then type "source-file ~/.tmux.conf"
```

Key `~/.tmux.conf` settings:
```conf
# Remap prefix to Ctrl+a (like GNU screen)
unbind C-b
set -g prefix C-a
bind C-a send-prefix

# Enable mouse support
set -g mouse on

# Use vi keys in copy mode
set-option -g mode-keys vi

# Increase scrollback buffer
set -g history-limit 50000

# Start windows and panes at 1 (not 0)
set -g base-index 1
setw -g pane-base-index 1

# 256-color support
set -g default-terminal "screen-256color"

# Faster key repetition
set -sg escape-time 0
```

---

## 9. Plugin Manager (TPM)

```bash
# Install TPM
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

# Add to ~/.tmux.conf
# set -g @plugin 'tmux-plugins/tpm'
# set -g @plugin 'tmux-plugins/tmux-resurrect'   # save/restore sessions
# set -g @plugin 'tmux-plugins/tmux-continuum'   # auto-save sessions
# run '~/.tmux/plugins/tpm/tpm'

# Install plugins: prefix + I
# Update plugins:  prefix + U
```

---

## 10. Practical Session Patterns

```bash
# SSH and immediately start/attach tmux
ssh user@host -t 'tmux new-session -A -s main'

# Long-running job in a detached session (safe to disconnect)
tmux new-session -d -s backup 'rsync -avz /src/ user@nas:/dst/ && echo DONE'

# Watch job progress after reconnecting
tmux attach-session -t backup

# Open a new pane alongside a running process to check it
# (from inside tmux) prefix + " then run: journalctl -f -u myservice

# Kill all sessions except the current one
tmux kill-session -a
```
