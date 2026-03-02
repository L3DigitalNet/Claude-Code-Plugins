# glances Cheatsheet

## 1. Basic launch and navigation

```bash
glances               # launch terminal TUI
glances -t 2          # set refresh interval to 2 seconds (default: 3)
glances --hide-kernel-threads   # skip kernel threads in process list
glances -1            # per-CPU mode (show each core separately)
```

Inside glances: `h` for help, `q` / `Esc` to quit.

---

## 2. Web server mode (browser-based)

```bash
glances -w                        # start web server on port 61208
glances -w --port 9001            # custom port
glances -w --bind 127.0.0.1       # listen only on loopback (safer)
glances -w --password             # prompt for a password to protect the UI
```

Access at `http://<host>:61208`. The web UI is a separate interface from the terminal TUI —
it auto-refreshes via the REST API. Useful for headless servers without SSH X forwarding.

---

## 3. Client/server remote monitoring

On the remote server:
```bash
glances -s                    # server mode (no TUI, listens on port 61209)
glances -s --port 61209       # explicit port
```

On the local machine:
```bash
glances -c <remote-host>      # connect to the server TUI
glances -c <remote-host> --port 61209
```

Both ends must run the same glances version. Use pip to pin: `pip install glances==4.x.x`.

---

## 4. Container stats (Docker / Podman)

Press `c` inside glances to toggle the container section, or it appears automatically
when Docker or Podman is running and the socket is accessible.

```bash
# Ensure your user can access the Docker socket
sudo usermod -aG docker $USER   # then re-login

# Or run glances as root for socket access
sudo glances
```

Glances shows per-container CPU, memory, and network I/O in a dedicated section.

---

## 5. Sorting processes

Inside glances, press a sort key to change the process sort order:

| Key | Sort by |
|-----|---------|
| `a` | Auto (most active first) |
| `c` | CPU% |
| `m` | MEM% |
| `i` | I/O read+write |
| `p` | PID |
| `u` | Username |
| `t` | Thread count |

---

## 6. Exporting metrics to InfluxDB

```bash
# Install the influxdb extra
pip install 'glances[influxdb]'

# Configure ~/.config/glances/glances.conf
[influxdb]
host=localhost
port=8086
user=root
password=root
db=glances
prefix=localhost
```

```bash
glances --export influxdb          # start with InfluxDB export enabled
glances --export influxdb -t 5     # export every 5 seconds
```

---

## 7. Exporting metrics to CSV

```bash
glances --export csv --export-csv-file /tmp/glances.csv
```

Each refresh appends a row. Useful for lightweight logging without a time-series database.
The CSV includes all active plugins' stats in wide format (one column per metric).

---

## 8. Using a config file to disable noisy plugins

```ini
# ~/.config/glances/glances.conf

[docker]
disable=True      # hide the container section entirely

[sensors]
disable=False     # ensure sensors are enabled

[processlist]
max_processes=20  # cap process list length for low-power hosts
```

```bash
glances --config ~/.config/glances/glances.conf
```

---

## 9. Alert history

Press `l` inside glances to open the alert log overlay. This shows a time-stamped list of
thresholds that were breached (CPU spike, disk full warning, etc.) during the current session.

Alert thresholds are configured in `glances.conf`:

```ini
[cpu]
careful=50    # yellow warning
warning=70    # orange warning
critical=90   # red alert
```

---

## 10. Installing optional plugin dependencies

Glances silently omits sections when their dependencies are missing.

```bash
# Temperature sensors (lm-sensors)
apt install lm-sensors python3-sensors
sudo sensors-detect    # run once to configure sensor modules

# NVIDIA GPU stats
pip install nvidia-ml-py

# AMD GPU stats
pip install pyAmdSMI   # or amdgpu-py depending on driver version

# InfluxDB export
pip install 'glances[influxdb]'

# All extras at once (pip install)
pip install 'glances[action,browser,cloud,cpuinfo,docker,export,folder,gpu,graph,ip,raid,snmp,web,wifi]'
```
