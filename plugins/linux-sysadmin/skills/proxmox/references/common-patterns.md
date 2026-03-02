# Proxmox VE Common Patterns

Commands below target the Proxmox CLI. Most operations have an equivalent in the web UI
at `https://<host>:8006`. VMID and CTID are the numeric IDs assigned at creation.

---

## 1. Create and Configure a New VM

```bash
# Create a VM shell. Adjust memory (MiB), cores, and machine type as needed.
qm create 100 \
  --name myvm \
  --memory 2048 \
  --cores 2 \
  --net0 virtio,bridge=vmbr0 \
  --ostype l26 \
  --machine q35

# Attach an ISO for installation (must already be in an ISO-capable storage pool).
qm set 100 --ide2 local:iso/debian-12.iso,media=cdrom

# Create a 32 GiB virtio disk on local-lvm storage.
qm set 100 --virtio0 local-lvm:32

# Set boot order: boot from cdrom first, then the virtio disk.
qm set 100 --boot order="ide2;virtio0"

# Start the VM, then open the web console (Proxmox UI > Console) or use noVNC.
qm start 100
```

After installation, remove the CD-ROM and update boot order:

```bash
qm set 100 --delete ide2
qm set 100 --boot order="virtio0"
```

---

## 2. Create an LXC Container from Template

```bash
# Download a container template (run on the Proxmox node).
pveam update
pveam available --section system        # list available templates
pveam download local debian-12-standard_12.7-1_amd64.tar.zst

# Create the container. Adjust storage, memory, and rootfs size as needed.
pct create 200 \
  local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst \
  --hostname mycontainer \
  --memory 512 \
  --swap 512 \
  --rootfs local-lvm:8 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp \
  --unprivileged 1 \
  --start 1

# Enter a shell inside the running container.
pct enter 200
```

For Docker inside LXC, add feature flags before starting:

```bash
pct set 200 --features nesting=1,keyctl=1
pct start 200
```

---

## 3. Clone a VM for Rapid Deployment

Full clone creates an independent copy; linked clone shares the base disk (faster, but
requires the source VM to persist).

```bash
# Full clone — completely independent VM.
qm clone 100 101 --name myvm-clone --full

# Linked clone — shares base disk with source VM (faster, uses less space).
# Source VM must have at least one snapshot for linked clones.
qm snapshot 100 base-snap
qm clone 100 102 --name myvm-linked --snapname base-snap

# Start the clone.
qm start 101
```

---

## 4. Snapshot and Rollback

VM snapshots capture RAM state (if `--vmstate 1`) and disk at a point in time. LXC
snapshots capture the container filesystem. Both are stored in the same storage pool as
the VM/CT disk.

```bash
# VM: take a snapshot before a risky change.
qm snapshot 100 before-upgrade --description "pre-apt-upgrade snapshot"

# VM: roll back to a snapshot (VM must be stopped first unless snapshot includes RAM state).
qm stop 100
qm rollback 100 before-upgrade

# VM: list snapshots.
qm listsnapshot 100

# VM: delete a snapshot.
qm delsnapshot 100 before-upgrade

# LXC: same operations with pct.
pct snapshot 200 before-config
pct rollback 200 before-config
pct listsnapshot 200
pct delsnapshot 200 before-config
```

---

## 5. Backup with vzdump and Restore

vzdump backs up VMs and containers to a storage pool that has the `Backup` content type.

```bash
# Backup a VM to the 'backup' storage pool using snapshot mode (no downtime).
vzdump 100 --storage backup --mode snapshot --compress zstd

# Backup all VMs and containers on this node.
vzdump --all --storage backup --mode snapshot --compress zstd

# List backup files in a storage pool.
pvesm list backup

# Restore a VM from backup (assigns new VMID 110).
qmrestore /var/lib/vz/dump/vzdump-qemu-100-2024_01_01-00_00_00.vma.zst 110

# Restore an LXC container from backup (assigns new CTID 210).
pct restore 210 /var/lib/vz/dump/vzdump-lxc-200-2024_01_01-00_00_00.tar.zst \
  --storage local-lvm
```

Scheduled backups are configured in the web UI: Datacenter > Backup > Add.

---

## 6. Storage Management

```bash
# List all storage pools and their status.
pvesm status

# List contents of a storage pool.
pvesm list local
pvesm list local-lvm

# Add NFS storage.
pvesm add nfs nfs-backups \
  --server 192.168.1.100 \
  --export /mnt/backups \
  --content backup,iso

# Add CIFS/SMB storage.
pvesm add cifs smb-share \
  --server 192.168.1.101 \
  --share backups \
  --username proxmox \
  --password 'secret' \
  --content backup

# Add a directory-based storage (e.g., an already-mounted external disk).
pvesm add dir local-extra \
  --path /mnt/extra \
  --content images,backup,iso

# Remove a storage definition (does not delete data).
pvesm remove nfs-backups
```

For LVM-thin (used by `local-lvm` on default installs) and ZFS pools, configuration
is usually done during installation or via the web UI (Node > Disks > LVM-Thin / ZFS).

---

## 7. Network Bridge and VLAN Configuration

Proxmox uses Linux bridges. Configuration lives in `/etc/network/interfaces`.

```
# Standard bridge — all VMs on this bridge share the same network segment.
auto vmbr0
iface vmbr0 inet static
    address 192.168.1.10/24
    gateway 192.168.1.1
    bridge-ports eno1
    bridge-stp off
    bridge-fd 0
```

VLAN-aware bridge — one bridge, VMs specify their VLAN tag:

```
auto vmbr0
iface vmbr0 inet manual
    bridge-ports eno1
    bridge-stp off
    bridge-fd 0
    bridge-vlan-aware yes
    bridge-vids 2-4094
```

Assign a VLAN tag to a VM's network interface in its config:

```bash
qm set 100 --net0 virtio,bridge=vmbr0,tag=10
```

Apply network changes without a full reboot:

```bash
ifreload -a
```

---

## 8. Post-Install: Disable Subscription Warning and Add Community Repo

The enterprise repo requires a paid subscription. Switch to the free community repo and
optionally patch the subscription warning modal.

```bash
# Disable the enterprise repo.
echo "# disabled" > /etc/apt/sources.list.d/pve-enterprise.list

# Add the no-subscription (community) repo.
echo "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" \
  > /etc/apt/sources.list.d/pve-no-subscription.list

apt update

# Patch the subscription warning modal (re-apply after pve-manager upgrades).
# The sed command removes the "no valid subscription" check from the JS bundle.
sed -i.bak "s/res === null || res === undefined || !res || res/false/g" \
  /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js

# Restart the proxy to pick up the patched JS.
systemctl restart pveproxy
```

---

## 9. GPU Passthrough Basics (PCI Passthrough)

Requires IOMMU enabled in the host firmware and GRUB.

```bash
# 1. Enable IOMMU in GRUB (/etc/default/grub).
#    For Intel:
GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt"
#    For AMD:
GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_iommu=on iommu=pt"

update-grub

# 2. Load required kernel modules (/etc/modules).
echo -e "vfio\nvfio_iommu_type1\nvfio_pci\nvfio_virqfd" >> /etc/modules
update-initramfs -u -k all

# Reboot here, then verify IOMMU groups.
dmesg | grep -e DMAR -e IOMMU | head -20

# 3. Identify the GPU PCI IDs.
lspci -nn | grep -i nvidia    # or amd/intel
# Example output: 01:00.0 VGA compatible controller [0300]: NVIDIA ... [10de:2204]
# Note BOTH the VGA and the Audio device IDs on the same card.

# 4. Blacklist the host driver so vfio-pci claims the device.
echo "blacklist nouveau" >> /etc/modprobe.d/blacklist.conf
echo "options vfio-pci ids=10de:2204,10de:1aef" >> /etc/modprobe.d/vfio.conf
update-initramfs -u -k all

# 5. Add PCI device to a VM (Machine must be q35; BIOS can be OVMF or SeaBIOS).
qm set 100 --hostpci0 01:00,pcie=1,x-vga=1
```

---

## 10. Cluster Setup Overview (pvecm)

Proxmox clusters allow centralized management of multiple nodes. Requires at least 3
nodes (or 2 nodes + 1 QDevice) for reliable quorum.

```bash
# On the FIRST node: create the cluster.
pvecm create my-cluster

# On EACH ADDITIONAL node: join the cluster (run on the new node).
pvecm add <IP-of-first-node>
# You will be prompted for the root password of the first node.

# Verify cluster health (run on any node).
pvecm status
pvecm nodes

# Add a QDevice for 2-node quorum (requires a third minimal machine running corosync-qnetd).
# On the QDevice machine:
apt install corosync-qnetd
# On a Proxmox node:
pvecm qdevice setup <IP-of-qdevice-host>

# Remove a node gracefully (node must be powered off first).
pvecm delnode <nodename>
```

Shared storage must be configured identically on all nodes for live migration and HA to
work. Each node connects independently to the same NFS/Ceph/iSCSI target; Proxmox does
not replicate local storage between nodes automatically.
