---
name: glances
description: >
  glances is an all-in-one system monitor covering CPU, memory, disk, network, processes,
  containers, and sensors in a single terminal view. It supports a built-in web server for
  browser-based monitoring and a client/server mode for watching remote hosts.
  Triggers on: "glances", "system overview", "all-in-one monitor", "glances web",
  "remote monitoring", "glances docker", "glances containers", "glances influxdb",
  "glances client server".
globs: []
---

## Identity

| Property | Value |
|----------|-------|
| **Binary** | `glances` |
| **Config** | `/etc/glances/glances.conf` (system-wide) or `~/.config/glances/glances.conf` (user) |
| **Logs** | No persistent logs — output to terminal (web mode logs to stdout) |
| **Type** | Interactive terminal UI / web server / client-server daemon |
| **Install** | `apt install glances` (Debian/Ubuntu) / `dnf install glances` (RHEL/Fedora) / `pip install glances` (latest features) |

## Key Operations

| Task | Command |
|------|---------|
| Launch (terminal) | `glances` |
| Web server mode | `glances -w` (serves on http://0.0.0.0:61208) |
| Web server, custom port | `glances -w --port 9001` |
| Connect to remote glances server | `glances -c <host>` |
| Run as server (no TUI) | `glances -s` |
| Export to InfluxDB | `glances --export influxdb` |
| Export to CSV | `glances --export csv --export-csv-file /tmp/glances.csv` |
| Toggle a plugin on/off | Keyboard shortcut per plugin (e.g., `d` disk, `n` network, `p` processes) |
| Show container stats | `c` — requires Docker or Podman running |
| Show GPU stats | Requires `nvidia-ml-py` installed; GPU section appears automatically |
| Sort processes | `a` auto, `c` CPU%, `m` MEM%, `i` I/O, `p` PID, `u` user |
| Alert history | `l` — opens the alert log overlay |
| Quit | `q` or `Esc` |

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `glances: command not found` | Not installed | `apt install glances` or `pip install glances` |
| Sensors section missing | `py-sensors` / `lm-sensors` not installed | `apt install python3-sensors lm-sensors && sensors-detect` |
| Container section absent | Docker/Podman not running or socket not accessible | Ensure `dockerd` is running; glances user needs access to `/var/run/docker.sock` |
| GPU section missing | `nvidia-ml-py` not installed or non-NVIDIA GPU | `pip install nvidia-ml-py`; AMD GPU support requires separate backend |
| Web mode accessible but blank | Browser blocking HTTP (HTTPS expected) or wrong port | Connect to `http://` explicitly; check `--port` value; check firewall |
| Client can't connect to server | Version mismatch between client and server | Install the same glances version on both ends; `pip install glances==<version>` |
| Export to InfluxDB fails | Missing `influxdb` Python package | `pip install 'glances[influxdb]'` or `pip install influxdb` |
| Config file ignored | Wrong path or wrong install method (pip vs package) | Pip installs read `~/.config/glances/glances.conf`; check with `glances --config /path/to/glances.conf` |

## Pain Points

- **Web mode requires a browser, not just a terminal**: `glances -w` starts an HTTP server — useful for remote access, but it's a different interface from the terminal TUI and requires a browser or API client rather than SSH.
- **Many plugins disabled until dependencies are installed**: sensor temps (`py-sensors`), GPU stats (`nvidia-ml-py`), InfluxDB export (`influxdb` package), and RAID stats all need separate Python packages. The section simply doesn't appear without them rather than showing an error.
- **Remote client requires the same version on both ends**: glances uses its own XML-RPC protocol. A version mismatch between client and server causes connection failures or garbled output. Pin versions explicitly when deploying.
- **GPU support is NVIDIA-first**: `nvidia-ml-py` covers NVIDIA cards via NVML. AMD GPU support exists but requires a different backend and is less reliable. Intel GPU stats are not supported.
- **Config file path varies by install method**: pip installs use `~/.config/glances/glances.conf`; distro packages may use `/etc/glances/glances.conf`. Run `glances --help` and look for `--config` to verify which path is active.
- **Keyboard shortcuts are plugin-specific and not all documented in-TUI**: press `h` inside glances to see the help overlay, which lists the active shortcuts. The full list is longer than what fits on screen.

## References

See `references/` for:
- `cheatsheet.md` — 10 task-organized patterns
- `docs.md` — official documentation links
