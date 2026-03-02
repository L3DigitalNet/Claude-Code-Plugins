# strace Cheatsheet

Ten task-organized patterns for the most common strace workflows.

---

## 1. Find why a binary says "No such file or directory"

Filter to file-related syscalls and write output to a file for easy inspection.

```bash
strace -e trace=file -o /tmp/strace-file.txt ./mybinary 2>&1
grep -E 'ENOENT|EACCES' /tmp/strace-file.txt
```

Every `openat` or `stat` that returns `ENOENT` is a path the binary tried and failed to find. The line shows the exact path argument.

---

## 2. Attach to a running process by PID

Identify the PID first, then attach without restarting the process.

```bash
# Find the PID
pgrep -x myapp

# Attach and filter to file ops
sudo strace -p 1234 -e trace=file -s 200
```

Press `Ctrl-C` to detach cleanly. The process continues running after detach.

---

## 3. Trace a process and all its children/threads

Essential for multi-threaded apps, shell scripts that fork subprocesses, or any process that spawns workers.

```bash
sudo strace -f -p 1234 -o /tmp/trace-all.txt
```

Each line in the output is prefixed with the PID of the thread that made the call. Filter by PID afterward:

```bash
grep '^1234 ' /tmp/trace-all.txt
```

---

## 4. Diagnose a network connection failure

Filter to network-related syscalls to see what address the process tried to connect to and what error it received.

```bash
strace -e trace=network -s 200 curl https://example.com
```

Look for `connect(` lines returning `ECONNREFUSED`, `ETIMEDOUT`, or `ENETUNREACH`.

---

## 5. Summarize syscall usage (count mode)

Get a ranked table of syscall frequency and time without reading thousands of lines. Useful for identifying what a process spends time doing.

```bash
strace -c -f ./mybinary
```

Output at exit:

```
% time     seconds  usecs/call     calls    errors syscall
------ ----------- ----------- --------- --------- ----------------
 62.34    0.001823          12       152        12 openat
 ...
```

---

## 6. Debug a "permission denied" error

A process may fail with EPERM or EACCES on a file, socket, or capability check. Filter to narrow the error source.

```bash
strace -e trace=file,network -s 200 ./mybinary 2>&1 | grep -E 'EPERM|EACCES'
```

The failing syscall shows the exact resource path or address that was denied.

---

## 7. Find what config files a process reads at startup

Watch all file opens during startup to understand the full config search path.

```bash
strace -e trace=openat,open -s 500 -o /tmp/opens.txt ./myapp
grep 'openat\|open(' /tmp/opens.txt | grep -v 'ENOENT'
```

The successfully opened files (no error at end of line) are the ones that were actually read.

---

## 8. Diagnose a hanging process

Attach to a stuck process to see what syscall it is blocked on.

```bash
sudo strace -p 1234
```

If the process is hung, strace will show the in-progress syscall — typically `futex` (lock contention), `read` (waiting for input), `epoll_wait` (event loop idle), or `accept` (waiting for connections). The call has no return value yet.

---

## 9. Trace signal delivery

Watch for signals being sent to or received by a process — useful for diagnosing unexpected exits or restarts.

```bash
strace -e signal=all -p 1234
```

Output shows `--- SIGTERM {si_signo=SIGTERM, si_code=SI_USER, si_pid=999} ---` when a signal arrives, and `+++ killed by SIGKILL +++` on fatal signals.

---

## 10. Write high-volume trace output to file with timestamps

For processes making thousands of syscalls per second, writing to a file avoids terminal rendering becoming the bottleneck. Timestamps allow correlating events with external logs.

```bash
sudo strace -f -t -s 200 -o /tmp/trace-$(date +%Y%m%d-%H%M%S).txt -p 1234
```

Inspect afterward:

```bash
# Find all failed syscalls
grep -E '\-1 E[A-Z]+' /tmp/trace-*.txt | head -50

# Find all file opens with errors
grep 'openat.*ENOENT' /tmp/trace-*.txt
```
