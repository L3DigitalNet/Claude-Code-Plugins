---
name: falco
description: >
  Falco cloud-native runtime security: kernel module and eBPF driver selection,
  rule authoring (condition/output/priority), output channels, Falcosidekick
  alert forwarding, Kubernetes DaemonSet deployment, container runtime detection,
  and troubleshooting.
  MUST consult when installing, configuring, or troubleshooting falco.
triggerPhrases:
  - "falco"
  - "Falco"
  - "falco rules"
  - "falco driver"
  - "modern_ebpf"
  - "runtime security"
  - "syscall monitoring"
  - "falcosidekick"
  - "falco kubernetes"
  - "container runtime detection"
  - "falco alerts"
  - "falco.yaml"
  - "falco_rules"
globs:
  - "**/falco.yaml"
  - "**/falco_rules.yaml"
  - "**/falco_rules.local.yaml"
  - "**/falco_rules*.yaml"
  - "**/rules.d/*.yaml"
last_verified: "2026-03"
---

## Identity
- **Unit**: `falco-modern-bpf.service` (default), `falco-bpf.service` (legacy eBPF), `falco-kmod.service` (kernel module)
- **Config**: `/etc/falco/falco.yaml` (main), `/etc/falco/config.d/` (drop-in overrides)
- **Default rules**: `/etc/falco/falco_rules.yaml`
- **Custom rules**: `/etc/falco/falco_rules.local.yaml`, `/etc/falco/rules.d/`
- **Log**: `journalctl -u falco-modern-bpf`
- **Binary**: `/usr/bin/falco`
- **Install**: DEB/RPM repos (`https://falco.org/repo/`), Helm chart (`falcosecurity/falco`), container image (`falcosecurity/falco`)
- **Project**: CNCF Graduated, v0.43.0 current as of 2026-01

## Quick Start

```bash
# Add repo and GPG key (Debian/Ubuntu)
curl -fsSL https://falco.org/repo/falcosecurity-packages.asc | \
  sudo gpg --dearmor -o /usr/share/keyrings/falco-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/falco-archive-keyring.gpg] https://download.falco.org/packages/deb stable main" | \
  sudo tee /etc/apt/sources.list.d/falcosecurity.list

sudo apt-get update -y
sudo apt-get install -y dialog falco

# The installer prompts for driver type; select "Modern eBPF" (default)
sudo systemctl enable --now falco-modern-bpf.service

# Verify
sudo systemctl status falco-modern-bpf.service

# Trigger a test alert
sudo cat /etc/shadow > /dev/null
sudo journalctl _COMM=falco -p warning --no-pager -n 5
```

For RPM-based systems, replace the repo setup with:

```bash
sudo rpm --import https://falco.org/repo/falcosecurity-packages.asc
sudo curl -o /etc/yum.repos.d/falcosecurity.repo https://falco.org/repo/falcosecurity-rpm.repo
sudo yum install -y falco
```

## Drivers

Falco intercepts kernel syscalls using one of three drivers. The modern eBPF probe is the default since v0.38.0.

| Driver | Service Unit | Kernel Req | Privileges | Notes |
|--------|-------------|------------|------------|-------|
| Modern eBPF (default) | `falco-modern-bpf.service` | >= 5.8 (x86_64/aarch64) | CAP_SYS_BPF, CAP_SYS_PERFMON, CAP_SYS_RESOURCE, CAP_SYS_PTRACE | Bundled in binary (CO-RE), no external download needed |
| Legacy eBPF | `falco-bpf.service` | >= 4.14 (x86_64), >= 4.17 (aarch64) | CAP_SYS_ADMIN, CAP_SYS_RESOURCE, CAP_SYS_PTRACE | Deprecated in v0.43.0; requires probe download per kernel version |
| Kernel module | `falco-kmod.service` | >= 3.10 | Full root | Requires DKMS and kernel headers; slightly faster but can panic the kernel on bugs |

Set the driver in `/etc/falco/falco.yaml`:

```yaml
engine:
  kind: modern_ebpf    # or: ebpf, kmod
  modern_ebpf:
    cpus_for_each_buffer: 2
    buf_size_preset: 4
```

## Key Operations

| Task | Command |
|------|---------|
| Check service status | `systemctl status falco-modern-bpf` |
| View live alerts | `sudo journalctl -u falco-modern-bpf -f` |
| View warnings and above | `sudo journalctl _COMM=falco -p warning` |
| Run Falco in foreground | `sudo falco` |
| Run with specific config | `sudo falco -c /path/to/falco.yaml` |
| Run with specific rules file | `sudo falco -r /path/to/rules.yaml` |
| Validate rules without running | `sudo falco -V /etc/falco/rules.d/custom.yaml` |
| Override config option at CLI | `sudo falco -o json_output=true` |
| List loaded rules at startup | `sudo falco --list` |
| Print supported fields | `sudo falco --list-fields` |
| Print supported syscalls | `sudo falco --list-events` |
| Hot-reload rules (no restart) | Automatic when `watch_config_files: true` (default) |
| Install/update rules via falcoctl | `sudo falcoctl artifact install falco-rules` |
| Check Falco version | `falco --version` |

## Rule Syntax

Rules live in YAML files loaded via `rules_files` in `falco.yaml`. Default load order:

```yaml
rules_files:
  - /etc/falco/falco_rules.yaml        # upstream defaults (do not edit)
  - /etc/falco/falco_rules.local.yaml   # local overrides
  - /etc/falco/rules.d                  # directory for additional rule files
```

### Rule structure

Every rule requires five fields: `rule`, `desc`, `condition`, `output`, `priority`.

```yaml
- rule: shell_in_container
  desc: Detect shell execution inside a container
  condition: >
    spawned_process and container and
    proc.name in (shell_binaries)
  output: >
    Shell spawned in container
    (user=%user.name container=%container.name
    shell=%proc.name parent=%proc.pname
    cmdline=%proc.cmdline image=%container.image.repository)
  priority: WARNING
  tags: [container, shell, mitre_execution]
```

### Macros and lists

Macros are reusable condition fragments; lists are named value arrays.

```yaml
- list: shell_binaries
  items: [bash, csh, ksh, sh, tcsh, zsh, dash]

- macro: spawned_process
  condition: (evt.type in (execve, execveat))

- macro: container
  condition: (container.id != host)
```

### Priority levels (highest to lowest)

EMERGENCY, ALERT, CRITICAL, ERROR, WARNING, NOTICE, INFORMATIONAL, DEBUG

Guidelines: ERROR for unauthorized writes, WARNING for unauthorized reads, NOTICE for unexpected behavior, INFORMATIONAL for policy violations.

### Common output fields

`%user.name`, `%proc.name`, `%proc.pname`, `%proc.cmdline`, `%fd.name`, `%container.id`, `%container.name`, `%container.image.repository`, `%evt.time`, `%evt.type`

## Output Channels

Configure in `/etc/falco/falco.yaml`:

```yaml
# Enable structured JSON for all outputs
json_output: true

stdout_output:
  enabled: true

syslog_output:
  enabled: true

file_output:
  enabled: false
  keep_alive: false
  filename: /var/log/falco/events.txt

program_output:
  enabled: false
  keep_alive: false
  program: "jq '{text: .output}' | curl -d @- -X POST https://hooks.slack.com/..."

http_output:
  enabled: false
  url: http://localhost:2801    # Falcosidekick default port
```

For more than five outputs, use Falcosidekick (see below).

## Falcosidekick

Falcosidekick is a proxy forwarder that accepts Falco's HTTP output and routes alerts to 60+ integrations: Slack, Teams, PagerDuty, Elasticsearch, Loki, Kafka, AWS S3, and more.

**Standalone (Docker):**

```bash
docker run -d -p 2801:2801 \
  -e SLACK_WEBHOOKURL=https://hooks.slack.com/services/XXX \
  -e SLACK_MINIMUMPRIORITY=warning \
  falcosecurity/falcosidekick
```

Then point Falco at it:

```yaml
json_output: true
http_output:
  enabled: true
  url: http://localhost:2801
```

**Kubernetes (Helm):**

```bash
helm install falco falcosecurity/falco -n falco --create-namespace \
  --set tty=true \
  --set falcosidekick.enabled=true \
  --set falcosidekick.config.slack.webhookurl=https://hooks.slack.com/services/XXX \
  --set falcosidekick.config.slack.minimumpriority=notice
```

**Falcosidekick UI** provides a web dashboard for browsing alerts:

```bash
helm upgrade falco falcosecurity/falco -n falco \
  --set falcosidekick.enabled=true \
  --set falcosidekick.webui.enabled=true
kubectl port-forward svc/falco-falcosidekick-ui -n falco 2802:2802
# Default credentials: admin / admin
```

## Kubernetes Deployment

Falco deploys as a privileged DaemonSet so every node runs an instance.

```bash
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update
helm install falco falcosecurity/falco \
  --namespace falco --create-namespace \
  --set tty=true

# Verify
kubectl get pods -n falco
kubectl logs -l app.kubernetes.io/name=falco -n falco
```

Custom rules via Helm `values.yaml`:

```yaml
customRules:
  custom-rules.yaml: |-
    - rule: Unauthorized process
      desc: Detect unauthorized process in production namespace
      condition: >
        spawned_process and container and
        k8s.ns.name = "production" and
        not proc.name in (allowed_procs)
      output: >
        Unauthorized process in production
        (proc=%proc.name ns=%k8s.ns.name pod=%k8s.pod.name)
      priority: ERROR
```

## Container Runtime Detection

Falco enriches syscall events with container metadata by connecting to the container runtime socket. Supported runtimes: Docker, containerd, CRI-O, Podman, LXC, libvirt-lxc.

Configure in `falco.yaml`:

```yaml
container_engines:
  docker:
    enabled: true
  cri:
    enabled: true
    sockets:
      - /run/containerd/containerd.sock
      - /run/crio/crio.sock
      - /run/k3s/containerd/containerd.sock
  podman:
    enabled: true
  lxc:
    enabled: true
```

When properly configured, rules can reference `container.id`, `container.name`, `container.image.repository`, and Kubernetes fields (`k8s.pod.name`, `k8s.ns.name`).

## Expected Ports

- **8765/tcp** -- Webserver / health endpoint. Listens on all interfaces by default. Serves `/healthz` for Kubernetes liveness probes.
- **2801/tcp** -- Falcosidekick (if deployed). Receives Falco HTTP output.
- **2802/tcp** -- Falcosidekick UI (if deployed). Web dashboard.

Webserver configuration:

```yaml
webserver:
  enabled: true
  listen_port: 8765
  k8s_healthz_endpoint: /healthz
  ssl_enabled: false
```

## Health Checks

1. `systemctl is-active falco-modern-bpf` -- service running
2. `curl -s localhost:8765/healthz` -- returns `{"status":"ok"}` when webserver is enabled
3. `sudo journalctl -u falco-modern-bpf --no-pager -n 20` -- no driver load errors
4. `sudo cat /etc/shadow > /dev/null && sudo journalctl _COMM=falco -p warning -n 1` -- test rule fires
5. `falco --version` -- binary present and reports version

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| "Unable to load the driver. Exiting." | Driver not available for this kernel; missing headers or DKMS | Switch to `modern_ebpf` (kernel >= 5.8) or install `linux-headers-$(uname -r)` and DKMS for kmod |
| "Permission denied" on eBPF syscall | SELinux blocking BPF, or missing capabilities | Set SELinux to permissive for testing; ensure CAP_SYS_BPF and CAP_SYS_PERFMON for modern eBPF |
| "Syscall event drop" warnings | Buffer too small for event volume | Increase `buf_size_preset` (0-9) in `engine.modern_ebpf`; reduce monitored syscalls with `base_syscalls` |
| No alerts generated | Rules not matching, or rules file not loaded | Check `rules_files` in `falco.yaml`; validate with `falco -V /path/to/rules.yaml`; test with `sudo cat /etc/shadow` |
| Container fields empty (`<NA>`) | Container runtime socket not mounted or not configured | Verify `container_engines` config; mount the socket into the Falco pod/container |
| Service fails on reboot | Wrong service unit enabled for the selected driver | Enable the correct unit: `falco-modern-bpf`, `falco-bpf`, or `falco-kmod` |
| Rules hot-reload not working | `watch_config_files: false` in config | Set `watch_config_files: true` or restart the service after rule changes |
| High CPU usage | Too many rules evaluating against high-frequency syscalls | Use `base_syscalls` to limit monitored calls; disable DEBUG-priority rules in production |

## Pain Points

- **Driver selection confusion**: Three drivers exist, each with a different systemd service name. The installer prompts interactively; for automation, set `FALCO_FRONTEND=noninteractive` and configure `engine.kind` in `falco.yaml`. When in doubt, use `modern_ebpf` on kernel >= 5.8.

- **Default rules are verbose**: The upstream `falco_rules.yaml` fires on common admin operations (reading `/etc/shadow`, running `sudo`). Override noisy rules in `falco_rules.local.yaml` or `rules.d/` rather than editing the default file, which gets overwritten on upgrade.

- **gRPC is deprecated**: The embedded gRPC server and `grpc_output` were deprecated in v0.43.0. Use `http_output` with Falcosidekick instead of building gRPC clients.

- **Rule ordering matters**: More specific rules should appear before general ones. Lists and macros must be defined before any rule that references them. Files load in `rules_files` order.

- **Kubernetes field availability**: Fields like `k8s.pod.name` require a working container runtime socket connection. If the CRI socket path is wrong or unmounted, all Kubernetes metadata resolves to `<NA>`.

- **Falcosidekick is almost always needed**: Native Falco supports only stdout, syslog, file, program, and HTTP output. For Slack, PagerDuty, Elasticsearch, or any other destination, deploy Falcosidekick alongside Falco.

## See Also

- **auditd** -- Linux kernel audit framework; lower-level syscall auditing without container awareness
- **crowdsec** -- collaborative intrusion prevention with community blocklists and active response bouncers
- **kubernetes** -- Falco's primary deployment target; runs as a DaemonSet for cluster-wide runtime detection
- **trivy** — static vulnerability scanning that complements Falco's runtime detection

## References
See `references/` for:
- `docs.md` -- official documentation, GitHub repos, and community resources
- `common-patterns.md` -- copy-paste rule examples for common detection scenarios
- `falco.yaml.annotated` -- annotated config covering rules, plugins, output channels, logging, event drop handling, webserver, gRPC (deprecated), and engine settings
