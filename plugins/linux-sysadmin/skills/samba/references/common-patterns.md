# Samba Common Patterns

Each block below is copy-paste-ready. Validate any smb.conf change with `testparm`
before reloading. Reload with `sudo smbcontrol smbd reload-config` (no restart needed
for share changes); restart is required after changing [global] protocol or security settings.

---

## 1. Basic Setup: User Share for Windows/macOS Access

A minimal working share for one user or a small group. Creates a private directory
accessible by authenticated users only.

```bash
# Create the directory and set ownership
sudo mkdir -p /srv/samba/shared
sudo chown root:users /srv/samba/shared
sudo chmod 2775 /srv/samba/shared    # setgid bit: new files inherit group
```

```ini
# /etc/samba/smb.conf — [global] minimum required settings
[global]
    workgroup = WORKGROUP
    server string = My File Server
    netbios name = FILESERVER
    security = user
    passdb backend = tdbsam
    min protocol = SMB2
    map to guest = Never
    log file = /var/log/samba/log.%m
    max log size = 50000

[shared]
    comment = Shared Files
    path = /srv/samba/shared
    valid users = @users
    read only = no
    browseable = yes
    create mask = 0664
    directory mask = 0775
    force group = users
```

```bash
# Validate, then enable and start
testparm
sudo systemctl enable --now smbd nmbd
```

---

## 2. Add and Manage Samba Users

Samba users must exist as Linux users first. The Samba password is stored separately
in `/var/lib/samba/private/passdb.tdb` and is independent of the Linux password.

```bash
# Create the Linux user (if not already present)
sudo useradd -M -s /sbin/nologin alice    # -M: no home dir, -s: no shell login

# Add the Linux user to Samba's password database and set their Samba password
sudo smbpasswd -a alice    # prompts for new password twice

# Enable a previously disabled account
sudo smbpasswd -e alice

# Disable without removing (user can't log in but account is preserved)
sudo smbpasswd -d alice

# Change an existing Samba password
sudo smbpasswd alice

# Remove from Samba DB entirely (Linux user is unaffected)
sudo smbpasswd -x alice

# List all Samba users
sudo pdbedit -L

# Verbose list (shows account flags, last login, etc.)
sudo pdbedit -Lv
```

---

## 3. Group-Based Access Control

Use Linux groups to control who can read vs. write. Both `valid users` and file
system permissions must allow — check both when troubleshooting.

```bash
# Create a group
sudo groupadd projectteam

# Add users to the group
sudo usermod -aG projectteam alice
sudo usermod -aG projectteam bob

# Create the share directory with group ownership
sudo mkdir -p /srv/samba/project
sudo chown root:projectteam /srv/samba/project
sudo chmod 2775 /srv/samba/project    # setgid ensures new files inherit group
```

```ini
[project]
    comment = Project Team Share
    path = /srv/samba/project
    # @groupname syntax: all members of the Linux group
    valid users = @projectteam
    # Only leads can write; other team members read
    write list = alice
    read only = yes
    browseable = yes
    create mask = 0664
    directory mask = 0775
    force group = projectteam
```

```bash
# Verify group membership resolves correctly (run as the user, not root)
id alice
# Should show projectteam in the groups list

# Test access directly
smbclient //localhost/project -U alice -c ls
```

---

## 4. Time Machine Target (macOS Backup over SMB)

Requires the `fruit` VFS module (part of `samba-vfs-modules` on Debian/Ubuntu;
included in the main `samba` package on RHEL/Fedora).

```bash
# Create per-user Time Machine directories
sudo mkdir -p /srv/samba/timemachine
sudo chown root:root /srv/samba/timemachine
sudo chmod 755 /srv/samba/timemachine

# macOS will create a subdirectory per user automatically
# (the %U variable expands at connect time)
```

```ini
[global]
    # fruit module must be loaded globally to initialize the protocol extensions
    vfs objects = fruit streams_xattr
    fruit:metadata = stream
    fruit:model = MacSamba
    fruit:posix_rename = yes
    fruit:veto_appledouble = no
    fruit:nfs_aces = no
    fruit:wipe_intentionally_left_blank_rfork = yes
    fruit:delete_empty_adfiles = yes
    # Advertise SMB2+ to macOS clients
    min protocol = SMB2

[TimeMachine]
    comment = Time Machine Backup
    path = /srv/samba/timemachine/%U
    valid users = %U
    read only = no
    browseable = yes
    # These two lines tell macOS this share is a Time Machine target
    fruit:time machine = yes
    # Optional: cap backup size per user (prevents filling the disk)
    fruit:time machine max size = 500G
    create mask = 0600
    directory mask = 0700
```

```bash
# On macOS: System Settings > General > Time Machine > Add Backup Disk
# Select the server share; macOS will prompt for credentials.
testparm    # verify no errors before connecting macOS
```

---

## 5. Guest/Public Share (No Authentication)

Requires `map to guest = Bad User` in [global] so unauthenticated connections
are mapped to the guest account (typically `nobody`).

```bash
sudo mkdir -p /srv/samba/public
sudo chown nobody:nogroup /srv/samba/public
sudo chmod 755 /srv/samba/public
```

```ini
[global]
    # Without this, guest ok = yes in the share has no effect
    map to guest = Bad User
    guest account = nobody

[public]
    comment = Public Read-Only Share
    path = /srv/samba/public
    guest ok = yes
    read only = yes
    browseable = yes
```

For a writable public share (anonymous drop box), set `read only = no` and
`chmod 1777 /srv/samba/public` (sticky bit prevents users deleting each other's files).

---

## 6. SELinux Configuration for Samba

On RHEL, Fedora, and CentOS, SELinux denies Samba access by default even when
file permissions are correct. Denials appear in the audit log, not in Samba logs.

```bash
# Check for recent SELinux denials related to Samba
sudo ausearch -m avc -ts recent | grep samba
# Or use audit2why for a human-readable explanation:
sudo ausearch -m avc -ts recent | audit2why

# Allow smbd to share home directories
sudo setsebool -P samba_enable_home_dirs on

# Allow smbd to share any directory (use when path isn't under /home or /srv)
sudo setsebool -P samba_export_all_rw on    # read-write
# sudo setsebool -P samba_export_all_ro on  # read-only variant

# Label a custom path with the correct SELinux context
# samba_share_t is the required type for Samba-accessible directories
sudo semanage fcontext -a -t samba_share_t "/srv/samba(/.*)?"
sudo restorecon -Rv /srv/samba

# Verify the context was applied
ls -lZ /srv/samba/

# List all Samba-related SELinux booleans
getsebool -a | grep samba
```

---

## 7. Mount SMB Share on Linux Client (fstab with Credentials File)

Avoid putting passwords in `/etc/fstab` directly. Use a credentials file instead.

```bash
# Install the cifs-utils package (provides mount.cifs)
sudo apt install cifs-utils    # Debian/Ubuntu
sudo dnf install cifs-utils    # RHEL/Fedora

# Create a credentials file readable only by root
sudo install -m 600 /dev/null /etc/samba/credentials-myserver
# Write credentials into it:
cat | sudo tee /etc/samba/credentials-myserver <<'EOF'
username=alice
password=secretpassword
domain=WORKGROUP
EOF

# Create the local mount point
sudo mkdir -p /mnt/myshare
```

```
# /etc/fstab entry:
//server/sharename  /mnt/myshare  cifs  credentials=/etc/samba/credentials-myserver,uid=1000,gid=1000,iocharset=utf8,vers=3.0,_netdev  0  0
```

```bash
# Test the fstab entry without rebooting
sudo mount /mnt/myshare

# Verify
df -h /mnt/myshare
```

Key mount options:
- `credentials=` — path to the credentials file (never put username= and password= inline in fstab)
- `uid=` / `gid=` — local user/group that owns mounted files (use numeric IDs for reliability)
- `vers=3.0` — force SMB3; omit to auto-negotiate
- `_netdev` — tells systemd to wait for network before mounting

---

## 8. Connect from macOS Finder and Windows Explorer

**macOS Finder:**
- Finder > Go > Connect to Server (`Cmd+K`)
- Enter: `smb://server/sharename` or `smb://server` to browse all shares
- Credentials dialog appears; enter your Samba username and password

**macOS Terminal:**
```bash
# Mount via command line (requires your user to have sudo/mount rights)
mount_smbfs //alice@server/sharename /Volumes/myshare
# Or with explicit password (avoid in scripts — use a credentials mechanism)
mount_smbfs //alice:password@server/sharename /Volumes/myshare
```

**Windows Explorer:**
- Address bar: `\\server\sharename` or just `\\server` to browse
- Map Network Drive: Right-click "This PC" > "Map network drive"
  - Drive letter: choose one (e.g., Z:)
  - Folder: `\\server\sharename`
  - Check "Reconnect at sign-in" for persistence
  - Check "Connect using different credentials" if your Windows username differs

**Windows Command Prompt:**
```cmd
:: Map a drive
net use Z: \\server\sharename /user:alice /persistent:yes

:: List mapped drives
net use

:: Disconnect
net use Z: /delete
```

---

## 9. Samba as Active Directory Member (winbind)

A brief reference for joining an existing AD domain. This is more complex than
standalone Samba — consult your AD administrator for domain-specific values.

```bash
sudo apt install samba winbind libnss-winbind libpam-winbind    # Debian/Ubuntu
```

```ini
[global]
    workgroup = CORP           # AD domain short name (not FQDN)
    realm = CORP.EXAMPLE.COM   # AD domain FQDN (Kerberos realm)
    security = ads
    kerberos method = secrets and keytab
    winbind use default domain = yes
    winbind offline logon = yes
    idmap config * : backend = tdb
    idmap config * : range = 10000-19999
    idmap config CORP : backend = rid
    idmap config CORP : range = 20000-999999
```

```bash
# Join the domain (requires DNS pointing to a DC)
sudo net ads join -U Administrator

# Start winbind
sudo systemctl enable --now winbind

# Test winbind can see domain users
wbinfo -u    # list domain users
wbinfo -g    # list domain groups

# Test authentication
wbinfo -a CORP\\alice%password
```

---

## 10. Performance Tuning

Defaults work for most deployments. These options matter for high-throughput
scenarios (large files, many simultaneous clients, gigabit+ networks).

```ini
[global]
    # Use sendfile(2) to bypass userspace copy when serving files from local disk.
    # Default: no  |  Recommended: yes for local disk; do NOT use with NFS-backed paths.
    use sendfile = yes

    # Allow reading ahead in the kernel's page cache.
    # Default: yes  |  Recommended: yes.
    read raw = yes

    # Allow writing directly without intermediate buffering.
    # Default: yes  |  Recommended: yes.
    write raw = yes

    # TCP socket options — tuned for LAN file transfer throughput.
    # IPTOS_LOWDELAY: prioritize latency for interactive use.
    # TCP_NODELAY: disable Nagle's algorithm (reduces latency for small writes).
    # IPTOS_THROUGHPUT: set on high-volume transfers.
    # SO_RCVBUF / SO_SNDBUF: kernel socket buffer sizes (bytes).
    # Tune these based on your network; do not blindly copy large values.
    socket options = TCP_NODELAY IPTOS_LOWDELAY SO_RCVBUF=131072 SO_SNDBUF=131072

    # Maximum size (bytes) of a single SMB read/write request.
    # Default: 65536  |  Recommended: 131072 for gigabit LAN, 16777216 for 10GbE.
    max xmit = 65536

    # Number of outstanding async SMB requests per connection.
    # Default: 100  |  Increase for high-concurrency multi-client workloads.
    aio read size = 16384
    aio write size = 16384
```

For 10GbE or NVMe-backed storage, also consider:
```ini
    # Disable oplocks if clients frequently hold locks and you see contention.
    # Default: yes  |  Disable only if you observe stale lock problems.
    # oplocks = no
    # kernel oplocks = no
```
