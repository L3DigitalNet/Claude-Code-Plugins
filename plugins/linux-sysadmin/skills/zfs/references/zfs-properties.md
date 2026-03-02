# ZFS Property Reference

Properties are set with `zfs set <prop>=<value> <dataset>` or `zpool set <prop>=<value> <pool>`.
Retrieved with `zfs get <prop> <dataset>` or `zfs get all <dataset>` for the full list.
The "Source" column shows whether a value is `local` (explicitly set), `inherited` (from parent dataset),
`default`, or `none`.

---

## Pool Properties (`zpool get` / `zpool set`)

| Property | Type | Default | Writable | Purpose |
|----------|------|---------|----------|---------|
| `size` | number | — | no | Total raw size of all top-level vdevs |
| `free` | number | — | no | Unallocated space in the pool |
| `allocated` | number | — | no | Space currently in use (used + metadata) |
| `capacity` | percent | — | no | `allocated / size`; fragmentation increases above 80% |
| `health` | string | — | no | ONLINE, DEGRADED, FAULTED, OFFLINE, UNAVAIL, REMOVED |
| `version` | number | current | yes | Legacy pool version (deprecated; use feature flags) |
| `dedupratio` | number | — | no | Effective deduplication ratio across the pool |
| `fragmentation` | percent | — | no | Estimate of free-space fragmentation; high values hurt large sequential writes |
| `autoexpand` | bool | off | yes | Automatically expand pool after underlying device is resized |
| `autoreplace` | bool | off | yes | Automatically replace a failed disk with a hot spare by device path |
| `autotrim` | bool | off | yes | Periodically issue TRIM/discard to SSDs; safe to enable on SSDs |
| `listsnapshots` | bool | off | yes | `zfs list` shows snapshots by default when on |
| `ashift` | number | auto-detect | at creation | Sector size hint as power of 2 (e.g. 12 = 4K sectors); set at pool creation — cannot change later |
| `bootfs` | string | none | yes | Dataset to boot from (used by some bootloaders) |
| `comment` | string | — | yes | Free-form comment stored in the pool label |
| `failmode` | string | wait | yes | Behavior on I/O failure: `wait`, `continue`, `panic` |
| `feature@async_destroy` | enum | enabled | at upgrade | Allows background dataset destruction without blocking |
| `feature@encryption` | enum | enabled | at upgrade | Required to create encrypted datasets |
| `feature@lz4_compress` | enum | active | at upgrade | Required for `compression=lz4` |
| `feature@zstd_compress` | enum | enabled | at upgrade | Required for `compression=zstd` |
| `feature@bookmark_v2` | enum | enabled | at upgrade | Enhanced bookmarks for send/receive |
| `feature@device_removal` | enum | enabled | at upgrade | Allows removing a mirror or single-disk vdev from a pool |

---

## Dataset Properties (`zfs get` / `zfs set`)

### Space Accounting (read-only)

| Property | Type | Purpose |
|----------|------|---------|
| `type` | string | `filesystem`, `volume`, `snapshot`, or `bookmark` |
| `used` | number | Total space consumed by dataset and all descendants |
| `available` | number | Space available to dataset (accounting for quotas and reservations) |
| `referenced` | number | Space used by this dataset alone (not shared with snapshots) |
| `written` | number | Space written since last snapshot (snapshot-only) |
| `usedbydataset` | number | Space consumed by the dataset's own data |
| `usedbysnapshots` | number | Space consumed by snapshots that cannot be freed until they are destroyed |
| `usedbychildren` | number | Space consumed by child datasets |
| `usedbyrefreservation` | number | Space consumed by `refreservation` |
| `compressratio` | number | Achieved compression ratio (e.g. 2.50x) |
| `clones` | list | Datasets cloned from this snapshot |
| `defer_destroy` | bool | Snapshot marked for deferred destruction |

### I/O and Data Integrity

| Property | Type | Default | Inherit | Purpose |
|----------|------|---------|---------|---------|
| `checksum` | string | on (sha256) | yes | Block checksum algorithm: `on` (sha256), `sha512`, `skein`, `edonr`, `fletcher4`, `off` (dangerous) |
| `compression` | string | off | yes | Compression algorithm: `lz4` (fast, recommended default), `zstd` (better ratio), `gzip`, `gzip-N` (1–9), `off` |
| `copies` | number | 1 | yes | Number of redundant copies of each block (1–3); independent of RAID redundancy |
| `sync` | string | standard | yes | Write synchronization: `standard` (honor fsync), `always` (force sync), `disabled` (ignore fsync — dangerous) |
| `primarycache` | string | all | yes | What to cache in ARC: `all`, `metadata`, `none` |
| `secondarycache` | string | all | yes | What to cache in L2ARC: `all`, `metadata`, `none` |
| `dedup` | string | off | yes | Enable deduplication: `on` (sha256), `verify`, `sha256`, `sha512`, `skein`; memory-expensive — see pain points |
| `special_small_blocks` | number | 0 | yes | Blocks smaller than this size go to special vdev (if configured) |

### Layout and Performance

| Property | Type | Default | Inherit | Purpose |
|----------|------|---------|---------|---------|
| `recordsize` | number | 128K | yes | Maximum block size for files; lower values help random-access workloads (databases); higher for sequential |
| `volblocksize` | number | 8K | at creation | Block size for zvols; cannot change after creation |
| `logbias` | string | latency | yes | I/O scheduling hint: `latency` (default) or `throughput` (large sequential writes) |
| `objset_size` | number | — | no | Internal object set size |

### Space Management

| Property | Type | Default | Inherit | Purpose |
|----------|------|---------|---------|---------|
| `quota` | number | none | no | Hard upper bound on space used by dataset and descendants; does not reserve space in pool |
| `refquota` | number | none | no | Hard upper bound on space used by dataset alone (excludes descendants) |
| `reservation` | number | none | no | Minimum space guaranteed to dataset and descendants; reserved in pool |
| `refreservation` | number | none | no | Minimum space guaranteed to dataset alone (excludes descendants); commonly used on zvols to pre-reserve space |

### Mount and Access

| Property | Type | Default | Inherit | Purpose |
|----------|------|---------|---------|---------|
| `mountpoint` | string | `/<pool>/<name>` | yes | Filesystem mount path; set to `none` to prevent mounting, `legacy` to use `/etc/fstab` |
| `canmount` | string | on | yes | `on` (auto-mount), `off` (never mount), `noauto` (mount only on explicit `zfs mount`) |
| `atime` | bool | on | yes | Update access time on reads; set `off` to reduce write amplification |
| `relatime` | bool | off | yes | Update atime only if mtime is newer; middle ground between `atime=on` and `atime=off` |
| `readonly` | bool | off | yes | Prevent all writes to dataset |
| `setuid` | bool | on | yes | Allow setuid/setgid bits to take effect |
| `exec` | bool | on | yes | Allow execution of binaries |
| `devices` | bool | on | yes | Allow device files |
| `snapdir` | string | hidden | yes | Visibility of `.zfs/snapshot` directory: `hidden` or `visible` |

### Naming and Access Control

| Property | Type | Default | Inherit | Purpose |
|----------|------|---------|---------|---------|
| `casesensitivity` | string | sensitive | at creation | Case handling: `sensitive`, `insensitive`, `mixed`; cannot change after creation |
| `normalization` | string | none | at creation | Unicode normalization form for filenames; cannot change after creation |
| `utf8only` | bool | off | at creation | Reject non-UTF-8 filenames; cannot change after creation |
| `aclinherit` | string | restricted | yes | ACL inheritance behavior: `discard`, `noallow`, `restricted`, `passthrough`, `passthrough-x` |
| `acltype` | string | off | yes | ACL type: `off`, `posix` (Linux POSIX ACLs), `nfsv4` |
| `xattr` | string | on | yes | Extended attribute storage: `on` (directory-based), `sa` (store in inode — faster), `off` |

### Encryption

| Property | Type | Default | Inherit | Purpose |
|----------|------|---------|---------|---------|
| `encryption` | string | off | at creation | Cipher: `off`, `on` (aes-256-gcm), `aes-128-ccm`, `aes-192-ccm`, `aes-256-ccm`, `aes-128-gcm`, `aes-192-gcm`, `aes-256-gcm`; cannot change after creation |
| `keylocation` | string | none | no | Where to find the encryption key: `prompt`, `file:///path/to/keyfile`, `https://...` |
| `keyformat` | string | none | at creation | Key format: `raw`, `hex`, `passphrase` |
| `pbkdf2iters` | number | 350000 | at creation | PBKDF2 iteration count for passphrase keys; higher is slower to brute-force |
| `keystatus` | string | — | no | `available` (key loaded) or `unavailable` (key not loaded, dataset locked) |

### User Properties

Any property in the form `namespace:key` is a user-defined property. These are stored in the dataset
metadata and returned by `zfs get all`. Useful for tagging datasets with application metadata,
backup status, or owner information:

```
zfs set backup:last_run="2025-01-15T02:00:00Z" tank/data
zfs get backup:last_run tank/data
```
