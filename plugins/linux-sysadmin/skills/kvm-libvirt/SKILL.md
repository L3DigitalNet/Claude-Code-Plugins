---
name: kvm-libvirt
description: >
  KVM/libvirt virtualization — virtual machine creation and management with virsh,
  virt-install, and virt-manager. Covers CPU/memory/disk configuration, networking
  (bridge, NAT, macvtap), storage pools, snapshots, live migration, and
  troubleshooting.
  MUST consult when installing, configuring, or troubleshooting KVM/libvirt virtualization.
triggerPhrases:
  - "KVM"
  - "libvirt"
  - "virsh"
  - "virt-install"
  - "virt-manager"
  - "QEMU"
  - "virtual machine"
  - "VM"
  - "libvirtd"
  - "qcow2"
  - "live migration"
  - "virbr0"
  - "virt-clone"
  - "virtual network"
globs:
  - "**/libvirt/**/*.xml"
  - "**/qemu/*.xml"
last_verified: "2026-03"
---

## Identity
- **Unit**: `libvirtd.service` (monolithic) or `virtqemud.service` + `virtnetworkd.service` + `virtstoraged.service` (modular daemons, preferred since libvirt 9.0+)
- **Config**: `/etc/libvirt/libvirtd.conf` (daemon), `/etc/libvirt/qemu.conf` (QEMU driver), `/etc/libvirt/qemu/*.xml` (per-VM domain definitions)
- **Logs**: `journalctl -u libvirtd`, per-VM logs in `/var/log/libvirt/qemu/<vmname>.log`
- **Storage default**: `/var/lib/libvirt/images/` (default directory pool)
- **Network default**: `virbr0` bridge, `192.168.122.0/24`, DHCP `192.168.122.100-254` via dnsmasq
- **Install**: `apt install qemu-kvm libvirt-daemon-system virtinst virt-manager` (Debian/Ubuntu) or `dnf install @virtualization` (Fedora/RHEL)

## Quick Start
```bash
# 1. Install packages (Debian/Ubuntu).
sudo apt install qemu-kvm libvirt-daemon-system virtinst virt-manager

# 2. Add your user to the libvirt group (log out/in after).
sudo usermod -aG libvirt $USER

# 3. Verify KVM support — output should be > 0.
egrep -c '(vmx|svm)' /proc/cpuinfo

# 4. Confirm libvirtd is running.
sudo systemctl enable --now libvirtd
virsh list --all

# 5. Create a VM from an ISO.
virt-install \
  --name debian12 \
  --memory 2048 \
  --vcpus 2 \
  --disk size=20,format=qcow2 \
  --cdrom /var/lib/libvirt/images/debian-12.iso \
  --osinfo debian12 \
  --network network=default \
  --graphics vnc

# 6. Connect to the VM console.
virsh console debian12
```

## Key Operations

| Task | Command |
|------|---------|
| List VMs | `virsh list --all` |
| Start VM | `virsh start <name>` |
| Graceful shutdown | `virsh shutdown <name>` |
| Force power off | `virsh destroy <name>` |
| Reboot | `virsh reboot <name>` |
| Serial console | `virsh console <name>` |
| VM info | `virsh dominfo <name>` |
| Dump XML config | `virsh dumpxml <name>` |
| Create VM (from ISO) | `virt-install --name <n> --memory <MiB> --vcpus <N> --disk size=<GiB> --cdrom <iso> --osinfo <os>` |
| Import existing disk | `virt-install --import --name <n> --memory <MiB> --disk <path> --osinfo <os>` |
| Clone VM | `virt-clone --original <name> --name <newname> --auto-clone` |
| Create snapshot | `virsh snapshot-create-as <name> <snapname> --description "..."` |
| List snapshots | `virsh snapshot-list <name>` |
| Revert snapshot | `virsh snapshot-revert <name> <snapname>` |
| Delete snapshot | `virsh snapshot-delete <name> <snapname>` |
| List networks | `virsh net-list --all` |
| Start network | `virsh net-start <netname>` |
| List storage pools | `virsh pool-list --all` |
| Create storage pool | `virsh pool-define-as <poolname> dir --target /path && virsh pool-start <poolname> && virsh pool-autostart <poolname>` |
| Create volume | `virsh vol-create-as <pool> <vol>.qcow2 <size>G --format qcow2` |
| Live migrate | `virsh migrate --live --p2p <name> qemu+ssh://<desthost>/system` |
| Set memory (live) | `virsh setmem <name> <KiB> --live` |
| Set vCPUs (live) | `virsh setvcpus <name> <N> --live` |
| Autostart VM | `virsh autostart <name>` |
| Delete VM | `virsh undefine <name> --remove-all-storage` |

## Expected Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 16509 | TCP | libvirtd listen (disabled by default; enable in `/etc/libvirt/libvirtd.conf` with `listen_tcp = 1`) |
| 16514 | TCP | libvirtd TLS (when `listen_tls = 1`) |
| 5900+ | TCP | VNC display per VM (5900 + display number) |
| 5900+ | TCP | SPICE display per VM (when configured instead of VNC) |
| 49152-49215 | TCP | Live migration data channel (QEMU default range) |

## Health Checks
1. `virsh nodeinfo` -- shows CPU model, memory, active CPUs
2. `virsh list --all` -- lists all domains and their state
3. `systemctl is-active libvirtd` -- returns `active`
4. `virsh net-list --all` -- default network shows `active` and `autostart`
5. `virt-host-validate qemu` -- checks KVM, IOMMU, device assignment capabilities

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `KVM kernel module is not loaded` or `/dev/kvm` missing | VT-x/AMD-V disabled in BIOS or kvm module not loaded | Enable virtualization in BIOS/UEFI; `modprobe kvm_intel` or `modprobe kvm_amd` |
| `permission denied` on `/dev/kvm` | User lacks kvm group membership | `sudo usermod -aG kvm $USER`, log out/in |
| `network 'default' is not active` | Default NAT network stopped | `virsh net-start default && virsh net-autostart default` |
| `Cannot access storage file ... Permission denied` | libvirt-qemu user cannot read the disk image | `chown libvirt-qemu:kvm <image>` or set `security_driver = "none"` in qemu.conf (testing only) |
| `Disk image is already in use by another VM` | Domain lock on qcow2 file | Stop the conflicting VM, or if stale: `virsh domblklist` all domains to find the lock holder |
| Migration fails: `unable to connect to destination` | libvirtd not listening on destination or firewall blocking | Enable TCP/TLS listen on dest; open ports 16509, 49152-49215 |
| Migration fails: `disk image cannot be found` | Disk path differs between hosts or storage not shared | Ensure shared storage (NFS/GlusterFS/Ceph) mounted at identical paths on both hosts |
| VM unresponsive, `virsh destroy` hangs | QEMU process stuck | `kill -9 $(virsh qemu-monitor-command <name> --hmp info cpus 2>/dev/null)` or find PID with `ps aux \| grep qemu` and kill directly |
| `unsupported configuration: host doesn't support nested HVM` | Nested virtualization not enabled | `echo "options kvm_intel nested=1" > /etc/modprobe.d/kvm.conf` and reload module |

## Pain Points
- **Bridge networking setup**: Linux bridge (`br0`) requires reconfiguring the host's primary interface, which can drop your SSH session. Use `nmcli` to create the bridge atomically, or configure via `/etc/netplan/` or `/etc/network/interfaces` and apply carefully. Wireless interfaces cannot be bridged; use macvtap or NAT instead.
- **virbr0 NAT limitations**: The default NAT network lets VMs reach the outside, but external hosts cannot reach the VMs without port-forwarding iptables rules. For production VMs that need inbound access, use bridged networking.
- **qcow2 vs raw performance**: qcow2 supports snapshots, thin provisioning, and backing files but adds an I/O overhead of roughly 5-15% compared to raw. Use raw for I/O-intensive workloads; qcow2 for flexibility. Preallocation (`qemu-img create -f qcow2 -o preallocation=full`) closes most of the gap.
- **Nested virtualization**: Running KVM inside a KVM guest requires `nested=1` on the host's kvm_intel/kvm_amd module. Performance degrades noticeably; suitable for testing and CI, not production.
- **CPU passthrough**: `--cpu host-passthrough` gives the VM the host's exact CPU features, enabling maximum performance and nested virt, but blocks live migration between hosts with different CPUs. Use `--cpu host-model` for a migration-compatible compromise.
- **Memory ballooning**: The virtio-balloon device allows the host to reclaim unused guest memory, but guests may become unresponsive if the balloon shrinks too aggressively. Set a minimum memory floor in the domain XML (`<currentMemory>`) and monitor `virsh dommemstat`.
- **macvtap guest-to-host communication**: macvtap in bridge mode gives VMs direct physical network access without a Linux bridge, but the host and VM cannot communicate with each other. Work around this with a second interface or the NAT network.

## See Also
- **proxmox** -- web-managed KVM/LXC hypervisor that wraps libvirt and QEMU with a full cluster stack
- **lxc-lxd** -- OS-level container virtualization (lighter weight than full VMs)
- **docker** -- application containers; complementary to KVM for different isolation needs
- **podman** -- daemonless container runtime; rootless alternative to Docker

## References
See `references/` for:
- `docs.md` -- official documentation links for libvirt, QEMU, and related tools
- `cheatsheet.md` -- virsh command reference organized by category (domain, network, storage, snapshot)
- `common-patterns.md` -- virt-install examples, bridge networking setup, storage pools, snapshot workflows, live migration, GPU passthrough
