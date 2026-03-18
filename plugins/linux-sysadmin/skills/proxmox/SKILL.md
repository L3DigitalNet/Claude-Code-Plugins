---
name: proxmox
description: >
  Proxmox VE hypervisor administration: VM and LXC container lifecycle,
  storage pools, cluster management, backup and restore, network bridge
  and VLAN configuration, and troubleshooting.
  MUST consult when installing, configuring, or troubleshooting proxmox.
triggerPhrases:
  - "proxmox"
  - "Proxmox VE"
  - "PVE"
  - "qemu KVM proxmox"
  - "LXC proxmox"
  - "proxmox cluster"
  - "proxmox backup server"
  - "qm"
  - "pct"
  - "pvesh"
  - "pvecm"
  - "vzdump"
  - "pveupdate"
  - "/etc/pve"
  - "/var/lib/vz"
globs: []
last_verified: "unverified"
---

## Identity

| Property | Value |
|----------|-------|
| **Web UI** | `https://<host>:8006` (HTTPS only; self-signed cert by default) |
| **CLI tools** | `qm` (VMs), `pct` (LXC), `pvesh` (REST API), `pvecm` (cluster), `vzdump` (backup) |
| **Config root** | `/etc/pve/` (cluster-synced FUSE filesystem; do not edit directly unless documented) |
| **Storage root** | `/var/lib/vz/` (images, templates, backups for local storage) |
| **Logs** | `journalctl -u pvedaemon`, `journalctl -u pveproxy`, `/var/log/pve/` |
| **Install** | Bare-metal ISO installer from `pve.proxmox.com/wiki/Downloads` |

## Quick Start
```bash
# After bare-metal ISO install:
apt update && apt full-upgrade -y
pvesm status                                       # verify storage pools
qm list                                            # list VMs (empty on fresh install)
curl -sk https://localhost:8006/api2/json/version   # API responds = PVE running
```

## Key Operations

| Task | Command |
|------|---------|
| List all VMs | `qm list` |
| Start VM | `qm start <vmid>` |
| Stop VM (graceful) | `qm shutdown <vmid>` |
| Stop VM (force) | `qm stop <vmid>` |
| Reset VM (hard reboot) | `qm reset <vmid>` |
| VM status | `qm status <vmid>` |
| VM config | `qm config <vmid>` |
| Serial/terminal console | `qm terminal <vmid>` |
| Monitor console (QEMU) | `qm monitor <vmid>` |
| List LXC containers | `pct list` |
| Start container | `pct start <ctid>` |
| Stop container | `pct stop <ctid>` |
| Container shell | `pct enter <ctid>` |
| Container config | `pct config <ctid>` |
| Clone VM | `qm clone <vmid> <newid> --name <name> [--full]` |
| VM snapshot | `qm snapshot <vmid> <snapname>` |
| Rollback VM snapshot | `qm rollback <vmid> <snapname>` |
| Container snapshot | `pct snapshot <ctid> <snapname>` |
| Backup VM/CT | `vzdump <vmid> --storage <storage> --mode snapshot` |
| Restore VM | `qmrestore <file> <newid>` |
| Restore CT | `pct restore <newid> <file>` |
| Storage status | `pvesm status` |
| List storage content | `pvesm list <storage>` |
| Node status | `pvesh get /nodes/<node>/status` |
| Cluster status | `pvecm status` |
| Cluster node list | `pvecm nodes` |
| Update packages | `pveupdate && pveupgrade` |
| View task log | `journalctl -u pvedaemon -f` |
| Migrate VM to node | `qm migrate <vmid> <target-node> [--online]` |
| Migrate CT to node | `pct migrate <ctid> <target-node>` |
| API call (REST shell) | `pvesh get /cluster/resources` |

## Expected State

- Web UI accessible at `https://<host>:8006`
- Services running: `pvedaemon`, `pveproxy`, `pve-cluster`, `corosync` (cluster nodes)
- Cluster filesystem mounted: `pveceph status` or `df -h /etc/pve` shows pmxcfs
- Storage pools listed and active: `pvesm status` shows all storage as `active`

## Health Checks

1. `systemctl is-active pvedaemon pveproxy pve-cluster` — all three return `active`
2. `pvecm status` — shows `Quorum information` with `Quorate: Yes` (cluster only)
3. `pvesm status` — all configured storage shows `active`
4. `curl -sk https://localhost:8006/api2/json/version` — returns JSON with `version` field

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| "You do not have a valid subscription" banner | No enterprise subscription (expected on free installs) | Disable via UI hook patch; switch to community repo — see common-patterns.md |
| VM fails to start: `KVM kernel module not loaded` | CPU lacks VT-x/AMD-V or it is disabled in BIOS/UEFI | `egrep -c '(vmx\|svm)' /proc/cpuinfo`; enable virtualization in host firmware |
| VM fails to start: `cannot allocate memory` | Host is overcommitted | `free -h`; reduce VM memory, balloon, or stop other VMs |
| LXC container fails to start: `Permission denied` | AppArmor profile blocking nested operations | Enable `nesting=1` and `apparmor=1` in container Options, or set `lxc.apparmor.profile: unconfined` |
| Storage pool unavailable after reboot | NFS/CIFS mount not re-established or LVM volume not activated | Check `/etc/fstab`, `systemctl status nfs-client.target`, `pvesm activate <storage>` |
| Cluster quorum lost | One or more nodes unreachable; cluster requires majority | `pvecm expected 1` (single-node emergency); do NOT use on multi-node in production |
| Backup job fails: `storage not configured` | Target storage has no `backup` content type enabled | Datacenter > Storage > Edit > tick `Backup` content type |
| Disk passthrough not working | PCI ID changed or IOMMU not enabled | Confirm `intel_iommu=on` / `amd_iommu=on` in GRUB; `dmesg \| grep -e DMAR -e IOMMU` |
| UEFI VM won't boot | OVMF firmware not selected or wrong disk order | Set Machine to `q35`, BIOS to `OVMF`, ensure EFI disk exists; check boot order in Options |

## Pain Points

- **Subscription nag on every login**: Proxmox shows a modal on free installs. The community-supported fix patches `/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js` — it must be re-applied after every `pve-manager` package update.
- **Storage configuration is a prerequisite for almost everything**: Backups, templates, ISOs, and VM disks each require a storage pool with the matching content type enabled. Getting this wrong silently blocks operations.
- **VLAN-aware bridge vs. separate bridges**: Proxmox supports VLAN-aware bridges (one bridge, tag per VM) or separate bridges per VLAN. VLAN-aware is simpler to maintain but requires switch-side trunk port configuration.
- **Nested virtualization in LXC**: Running Docker or other container runtimes inside LXC requires `nesting=1` and sometimes `keyctl=1` in the container's feature flags. Missing this causes cryptic permission errors inside the container.
- **Backup storage must be added before scheduling**: The backup job wizard only shows storage pools that have the `Backup` content type. Add and configure storage first; otherwise the job creation silently has no valid destination.
- **HA cluster requires 3+ nodes for reliable quorum**: A 2-node cluster loses quorum if either node goes down. Use a third node or a QDevice (Corosync quorum device) to achieve quorum with 2 physical hosts.
- **`/etc/pve` is a FUSE filesystem (pmxcfs)**: Files here are cluster-synced. Do not edit them with tools that write via a temp file and rename (e.g., some editors). Use `pvesh` or the API, or edit directly with `echo`/`tee`.
- **Online migration requires shared storage**: Live migrating a VM between nodes only works if its disk is on shared storage (NFS, Ceph, iSCSI). Local storage requires offline migration with the `--offline` flag.

## See Also
- **lxc-lxd** — standalone LXC/LXD container management without the Proxmox hypervisor layer
- **docker** — application-level containerization for microservices, complementary to Proxmox VMs/LXC
- **kvm-libvirt** — raw KVM/QEMU management with virsh; Proxmox uses this under the hood

## References

See `references/` for:
- `common-patterns.md` — VM creation, LXC setup, cloning, snapshots, backups, storage, networking, post-install, GPU passthrough, and cluster setup
- `docs.md` — official documentation and community links
