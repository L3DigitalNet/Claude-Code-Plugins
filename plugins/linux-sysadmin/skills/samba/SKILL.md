---
name: samba
description: >
  Samba file server administration: smb.conf configuration, user management,
  share access, Windows/macOS interoperability, SELinux/AppArmor integration,
  and troubleshooting. Triggers on: samba, SMB, CIFS, samba share, smb.conf,
  Windows file sharing, smbclient, NAS samba, smbpasswd, smbstatus, testparm,
  winbind, nmbd, smbd.
globs:
  - "**/smb.conf"
  - "**/samba/**/*.conf"
  - "**/samba/smb.conf"
---

## Identity
- **Daemons**: `smbd.service` (file/print sharing), `nmbd.service` (NetBIOS name service), `winbindd.service` (AD/domain integration)
- **Config**: `/etc/samba/smb.conf`
- **Samba password DB**: `/var/lib/samba/private/passdb.tdb`
- **Logs**: `journalctl -u smbd`, `/var/log/samba/log.smbd`, `/var/log/samba/log.nmbd`
- **Distro install**: `apt install samba` / `dnf install samba`

## Key Operations

| Task | Command |
|------|---------|
| Status: smbd | `systemctl status smbd` |
| Status: nmbd | `systemctl status nmbd` |
| Test config syntax | `testparm` |
| Test config (quiet, show effective values) | `testparm -s` |
| List shares on local server | `smbclient -L localhost -U%` |
| List shares on remote server | `smbclient -L //server -U username` |
| Add Samba user (must be an existing Linux user) | `sudo smbpasswd -a username` |
| Change Samba password for user | `sudo smbpasswd username` |
| Enable Samba user | `sudo smbpasswd -e username` |
| Disable Samba user | `sudo smbpasswd -d username` |
| Delete Samba user from DB | `sudo smbpasswd -x username` |
| List all Samba users | `sudo pdbedit -L` |
| List Samba users (verbose) | `sudo pdbedit -Lv` |
| Browse/connect to a share as user | `smbclient //server/share -U username` |
| Show connected users and open files | `smbstatus` |
| Show connected users only | `smbstatus -p` |
| Show open shares only | `smbstatus -S` |
| Reload config without restart | `sudo smbcontrol smbd reload-config` |
| net: list local groups | `net groupmap list` |
| net: join workgroup (AD) | `net ads join -U Administrator` |
| Check user's Linux group membership | `id username` |
| Check effective share permissions | `smbclient //localhost/sharename -U username -c ls` |

## Expected Ports

- **445/tcp** — SMB2/SMB3 (modern, primary; no NetBIOS required)
- **139/tcp** — SMB over NetBIOS (legacy; needed for very old Windows clients)
- **137/udp** — NetBIOS Name Service (nmbd; legacy browsing)
- **138/udp** — NetBIOS Datagram Service (nmbd; legacy browsing)

Verify: `ss -tlnup | grep -E 'smbd|nmbd'`

Firewall (firewalld): `sudo firewall-cmd --add-service=samba --permanent && sudo firewall-cmd --reload`

Firewall (ufw): `sudo ufw allow samba`

## Health Checks

1. `systemctl is-active smbd nmbd` → both `active`
2. `testparm 2>&1 | tail -3` → `Loaded services file OK.` (no `ERROR:` lines)
3. `smbclient -L localhost -U%` → lists shares without `NT_STATUS` error
4. `smbclient //localhost/sharename -U testuser -c ls` → directory listing (not `NT_STATUS_ACCESS_DENIED`)

## Common Failures

| Symptom | Likely cause | Check/Fix |
|---------|-------------|-----------|
| `NT_STATUS_LOGON_FAILURE` | Samba password not set or differs from what client is using | `sudo smbpasswd -a username` — Samba has its own password DB separate from `/etc/shadow` |
| `NT_STATUS_ACCESS_DENIED` | File system permissions deny access, or `valid users`/`write list` excludes the user | Check `ls -la /path/to/share` and `valid users` in smb.conf; both must allow |
| `NT_STATUS_BAD_NETWORK_NAME` | Share name in client doesn't match `[section]` in smb.conf | `testparm -s` to list active share names; check typos and case |
| `NT_STATUS_OBJECT_NAME_NOT_FOUND` | Path in share definition doesn't exist | `ls -la /path/from/smb.conf` and create/fix it |
| SELinux blocking access | SELinux policy denies smbd access to the path | `ausearch -m avc -ts recent | grep samba`; see SELinux section below |
| AppArmor denial | AppArmor profile blocks smbd | `journalctl -t kernel | grep apparmor | grep smbd`; add profile exception or set complain mode |
| `testparm` shows `WARNING: The security=share option is deprecated` | Old `security = share` in [global] | Replace with `security = user` and `map to guest = Bad User` for public shares |
| Windows can't see Linux shares (browsing) | Firewall blocking 445 or workgroup mismatch | Check firewall with `ss -tlnp \| grep 445`; verify `workgroup` matches Windows network |
| macOS "connection failed" | SMB1 disabled; min protocol too low or missing | Set `min protocol = SMB2` in [global]; macOS 12+ requires SMB2 minimum |
| Linux user not in Samba DB | User was created after Samba install; never added | `sudo pdbedit -L | grep username`; add with `smbpasswd -a` if missing |
| Write fails, read works | Share is `read only = yes` (default) or wrong `create mask` | Set `read only = no` or `writable = yes`; check `create mask` and `directory mask` |
| `tdb_fetch_uint32` or passdb errors at startup | Corrupted passdb.tdb | `sudo tdbbackup /var/lib/samba/private/passdb.tdb` then investigate or rebuild |

## Pain Points

- **Samba has a separate password database.** Adding a Linux user with `useradd` does not add them to Samba. You must explicitly run `smbpasswd -a username` afterward. The Samba password is independent of the Linux password — changing one does not change the other.
- **SELinux requires explicit booleans for Samba.** Even if file permissions are correct, SELinux will silently deny access unless the appropriate booleans are set (`samba_enable_home_dirs`, `samba_export_all_rw`, etc.) and the file context is labeled `samba_share_t`. Use `ausearch -m avc` to catch denials that aren't in Samba's own logs.
- **macOS requires `min protocol = SMB2`.** macOS 10.15+ defaults to SMB2/3 and will refuse or show errors with SMB1. Additionally, for Time Machine support, `vfs objects = fruit streams_xattr` must be loaded and `fruit:time machine = yes` set on the target share.
- **`workgroup` must match the Windows/macOS network workgroup.** The default in Windows is `WORKGROUP`; mismatches cause browsing failures even when direct UNC path access works.
- **`valid users` and file system permissions are independent gates.** Both must allow access. A user in `valid users` with correct Samba credentials will still be denied if the underlying directory mode/ownership blocks them — and vice versa. Always check both layers.
- **`nmbd` is needed only for legacy NetBIOS browsing.** Modern SMB2/3 clients use DNS to find servers. If you only need file sharing with current Windows 10/11 or macOS clients, `nmbd` is optional. Disable it to reduce attack surface if browsing is not required.
- **`read only = yes` is the default for new shares.** Every share is read-only unless you explicitly set `read only = no` or `writable = yes`. This catches many admins who see directories but can't write.
- **`force group` changes GID for all new files.** Useful for shared project directories, but understand the consequence: all files are group-owned by the forced group regardless of which user created them. Pair with `create mask = 0660` and `directory mask = 0770`.

## References
See `references/` for:
- `smb.conf.annotated` — full annotated config with every directive explained
- `common-patterns.md` — user shares, group access, Time Machine, guest shares, SELinux, fstab mounts
- `docs.md` — official documentation links
