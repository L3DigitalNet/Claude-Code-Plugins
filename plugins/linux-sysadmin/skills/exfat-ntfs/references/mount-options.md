# exFAT and NTFS Mount Options

## exFAT Mount Options (`-t exfat`, via `exfatprogs`)

| Option | Effect |
|--------|--------|
| `uid=N` | Owner UID for all files (default: 0 / root) |
| `gid=N` | Owner GID for all files (default: 0 / root) |
| `umask=NNN` | Apply this umask to both files and directories |
| `fmask=NNN` | Umask for files only (overrides `umask` for files) |
| `dmask=NNN` | Umask for directories only (overrides `umask` for dirs) |
| `iocharset=utf8` | Character encoding for filenames (default: utf8) |

Common combination for a single user at UID 1000:
```
-o uid=1000,gid=1000,umask=022
```

## NTFS-3g Mount Options (`-t ntfs-3g`)

| Option | Effect |
|--------|--------|
| `uid=N` | Owner UID for all files |
| `gid=N` | Owner GID for all files |
| `umask=NNN` | Umask for both files and directories |
| `fmask=NNN` | Umask for files only |
| `dmask=NNN` | Umask for directories only |
| `windows_names` | Reject filenames that are illegal on Windows (safe cross-platform writing) |
| `streams_interface=windows` | Expose NTFS alternate data streams as Windows does |
| `locale=en_US.UTF-8` | Locale for filename character conversion |
| `remove_hiberfile` | Remove Windows hibernation file on mount (allows read-write; use with caution — discards Windows session) |
| `no_def_opts` | Disable ntfs-3g's default options (rarely needed) |

## Kernel NTFS3 Mount Options (`-t ntfs3`, Linux 5.15+)

| Option | Effect |
|--------|--------|
| `uid=N` | Owner UID for all files |
| `gid=N` | Owner GID for all files |
| `umask=NNN` | Umask applied to all files and directories |
| `iocharset=utf8` | Filename encoding |
| `prealloc` | Preallocate disk space for files (reduces fragmentation) |
| `nohidden` | Hide files with the Windows hidden attribute |
| `sys_immutable` | Mark Windows system files as immutable |

NTFS3 does not support `remove_hiberfile`. If the volume is dirty (Windows hibernation), NTFS3 will also refuse to mount read-write. Run `ntfsfix /dev/sdX1` first (using ntfs-3g's tool), then mount with NTFS3.

---

## fstab Examples

Identify the UUID first: `sudo blkid /dev/sdX1`

**exFAT, auto-mount at boot, owned by UID 1000:**
```
UUID=XXXX-XXXX  /mnt/usb  exfat  uid=1000,gid=1000,umask=022,nofail  0  0
```

**NTFS (kernel NTFS3), auto-mount at boot, owned by UID 1000:**
```
UUID=XXXXXXXXXXXXXXXX  /mnt/usb  ntfs3  uid=1000,gid=1000,umask=022,nofail  0  0
```

**NTFS (ntfs-3g), auto-mount at boot:**
```
UUID=XXXXXXXXXXXXXXXX  /mnt/usb  ntfs-3g  uid=1000,gid=1000,umask=022,nofail  0  0
```

The `nofail` option prevents the system from halting boot if the drive is absent (critical for removable media). The final `0  0` skips fsck on boot (correct for NTFS and exFAT — they have their own repair tools).

---

## udev Rule for Automatic User-Mountable Drives

Create `/etc/udev/rules.d/99-usb-automount.rules`:

```
# Auto-mount external drives to /media/<label> when inserted
ACTION=="add", KERNEL=="sd[b-z][0-9]", TAG+="systemd", ENV{SYSTEMD_WANTS}="media-automount@%k.service"
```

Alternatively, use `udisks2` (already active on most desktop systems) — it handles auto-mount without custom udev rules. Users in the `plugdev` group (Debian) or `disk` group (Fedora) can mount without `sudo`.

To add a user to `plugdev`: `sudo usermod -aG plugdev $USER`

---

## udisksctl vs mount for Desktop Systems

`udisksctl` is the recommended tool for removable media on desktop/interactive systems. It:
- Mounts to `/run/media/$USER/<label>` automatically
- Applies correct permissions for the calling user without manual `uid`/`gid` options
- Powers down the drive after unmount (important for USB drives)
- Integrates with the desktop session (file manager notifications, etc.)

```bash
# Mount a drive
udisksctl mount -b /dev/sdX1

# Unmount and power off
udisksctl unmount -b /dev/sdX1
udisksctl power-off -b /dev/sdX

# Mount with specific filesystem type
udisksctl mount -b /dev/sdX1 --options ro
```

Use raw `mount`/`umount` only in scripts, server contexts, or when you need full control over mount options. For interactive desktop use, prefer `udisksctl`.
