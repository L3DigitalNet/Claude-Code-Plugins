# lsof Cheatsheet

Ten task-organized patterns for the most common lsof workflows.

---

## 1. Find what process is using a port

The most frequent use case: diagnose an "address already in use" bind error.

```bash
sudo lsof -i :8080
```

Output shows the process name, PID, and user. For listening ports specifically:

```bash
sudo lsof -i :8080 -sTCP:LISTEN
```

---

## 2. List all listening ports and the processes behind them

A quick alternative to `ss -tlnp` that shows process names directly.

```bash
sudo lsof -i -sTCP:LISTEN -n -P
```

`-n` and `-P` skip DNS and port-name resolution, making this run significantly faster on systems with many sockets.

---

## 3. Find deleted files holding disk space

When `df` shows high disk usage but `du` finds nothing large, a deleted file is held open by a running process.

```bash
sudo lsof +L1
```

The `+L1` flag selects file descriptors with a link count below 1 — i.e., unlinked but still open. The `SIZE` column shows how much space is held. To reclaim without restarting the process:

```bash
# Truncate the file in-place via the process's /proc fd link
sudo truncate -s 0 /proc/<PID>/fd/<FD>
```

---

## 4. Find all files open by a process

Inspect every file descriptor a specific process currently holds.

```bash
sudo lsof -p 1234 -n -P
```

Useful for understanding what config files, sockets, and pipes a daemon has open. To watch for changes:

```bash
sudo lsof -r 2 -p 1234 -n -P
```

---

## 5. Find which process has a specific file open

Diagnose "resource busy" errors when trying to unmount, delete, or modify a file.

```bash
sudo lsof /var/log/syslog
```

Or for a device:

```bash
sudo lsof /dev/sda1
```

---

## 6. Watch connections to a port in real time

Repeat mode (`-r`) polls at a given interval. Useful for watching connections appear and disappear on a service.

```bash
sudo lsof -r 1 -i :443 -n -P
```

Press `Ctrl-C` to stop. Each interval is separated by a `=======` divider.

---

## 7. Find all open files under a directory

Useful before unmounting a filesystem or identifying which processes are writing to a log directory.

```bash
sudo lsof +D /var/log/nginx
```

`+D` is recursive. For a non-recursive check of files directly in a path:

```bash
sudo lsof /var/log/nginx/access.log
```

---

## 8. Show all network connections for a user

Useful when investigating outbound connections from a web app or scheduled job running as a specific user.

```bash
sudo lsof -u www-data -i -n -P
```

Combine with `-a` to AND the filters (without `-a`, multiple filters are OR'd):

```bash
# Files opened by www-data AND involving network (AND semantics)
sudo lsof -a -u www-data -i -n -P
```

---

## 9. Find all TCP connections to a remote host

Useful when tracing which local processes are connecting to a specific backend or database.

```bash
sudo lsof -i @192.168.1.10 -n -P
```

Or for a specific host and port:

```bash
sudo lsof -i @192.168.1.10:5432 -n -P
```

---

## 10. Show file descriptors for a crashed/zombie process

After a process crashes or becomes a zombie, its fd table is still visible briefly. Useful for post-mortem analysis before the PID is reaped.

```bash
sudo lsof -p <zombie-PID>
```

If the PID is already gone, check `/proc/<PID>/fd/` directly:

```bash
ls -la /proc/<PID>/fd/
```

Each symlink points to the original file path (with `(deleted)` appended if the file was removed).
