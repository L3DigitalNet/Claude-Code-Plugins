# Remaining Fixes Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix 4 quality issues identified during PTH testing of linux-sysadmin-mcp: structured disk I/O output, disk_usage_top performance, cron next-run calculation, and show_sudoers_reference implementation.

**Architecture:** All changes are isolated to individual tool handler functions in `src/tools/`. No shared infrastructure changes. Each fix is independent.

**Tech Stack:** TypeScript, Node.js, `src/tools/{performance,storage,cron,session}/index.ts`

**Build:** `cd plugins/linux-sysadmin-mcp && npm run build`

**Build verification:** `ls -la dist/server.bundle.cjs` — file should be present and recently modified.

---

## Task 1: Fix `perf_disk_io` — Parse `/proc/diskstats` into structured JSON

**Files:**
- Modify: `plugins/linux-sysadmin-mcp/src/tools/performance/index.ts:100-109`

**Context:** `/proc/diskstats` has 20 fixed columns per line (kernel 4.18+). The tool currently returns raw text. `perf_network_io` already parses `/proc/net/dev` into named fields — `perf_disk_io` should match that pattern.

**Diskstats column layout (per kernel docs):**
```
major minor name reads_completed reads_merged sectors_read ms_reading
writes_completed writes_merged sectors_written ms_writing
ios_in_progress ms_doing_io ms_weighted_io
discards_completed discards_merged sectors_discarded ms_discarding
flush_requests ms_flushing
```
Only the first 14 are universally available; columns 15+ (discards, flushes) require kernel ≥ 4.18.

**Step 1: Replace the tool handler**

Edit `performance/index.ts` lines 100–109. Replace the entire block with:

```typescript
  // ── perf_disk_io ────────────────────────────────────────────────
  registerTool(ctx, {
    name: "perf_disk_io", description: "Disk I/O statistics per device.",
    module: "performance", riskLevel: "read-only", duration: "quick",
    inputSchema: z.object({}), annotations: { readOnlyHint: true },
  }, async () => {
    const r = await executeBash(ctx, "cat /proc/diskstats", "quick");
    // /proc/diskstats: fixed-width space-separated; columns 1-3 are major/minor/name,
    // 4-14 are the standard I/O counters (reads, merges, sectors, ms per operation class).
    // Columns 15+ (discards, flushes) only present on kernel ≥ 4.18 — include when available.
    const devices = r.stdout.trim().split("\n").filter(Boolean).map((line) => {
      const p = line.trim().split(/\s+/);
      const d: Record<string, unknown> = {
        name: p[2],
        reads_completed: Number(p[3]),
        reads_merged: Number(p[4]),
        sectors_read: Number(p[5]),
        ms_reading: Number(p[6]),
        writes_completed: Number(p[7]),
        writes_merged: Number(p[8]),
        sectors_written: Number(p[9]),
        ms_writing: Number(p[10]),
        ios_in_progress: Number(p[11]),
        ms_doing_io: Number(p[12]),
        ms_weighted_io: Number(p[13]),
      };
      // Discard stats (kernel ≥ 4.18)
      if (p.length >= 18) {
        d.discards_completed = Number(p[14]);
        d.discards_merged = Number(p[15]);
        d.sectors_discarded = Number(p[16]);
        d.ms_discarding = Number(p[17]);
      }
      return d;
    });
    return success("perf_disk_io", ctx.targetHost, r.durationMs, "cat /proc/diskstats", { devices, count: devices.length });
  });
```

**Step 2: Build**

```bash
cd /home/chris/projects/Claude-Code-Plugins/plugins/linux-sysadmin-mcp && npm run build
```
Expected: exits 0, `dist/server.bundle.cjs` updated.

**Step 3: Commit**

```bash
cd /home/chris/projects/Claude-Code-Plugins && git add plugins/linux-sysadmin-mcp/src/tools/performance/index.ts && git commit -m "fix: parse /proc/diskstats into structured JSON in perf_disk_io"
```

---

## Task 2: Fix `disk_usage_top` — Prevent cross-mount traversal

**Files:**
- Modify: `plugins/linux-sysadmin-mcp/src/tools/storage/index.ts:19-27`

**Context:** `du` without `--one-file-system` traverses NFS, pCloud, and pseudo-filesystems (/proc, /sys), causing 30-second wall times and empty results when all traversable paths fail with permission errors.

**Step 1: Add `--one-file-system` and a timeout guard**

Replace the `disk_usage_top` handler body (line 20) with:

```typescript
  registerTool(ctx, { name: "disk_usage_top", description: "Find largest directories under a path.", module: "storage", riskLevel: "read-only", duration: "normal", inputSchema: z.object({ path: z.string().optional().default("/"), limit: z.number().int().min(1).max(50).optional().default(20), depth: z.number().int().min(1).max(5).optional().default(1) }), annotations: { readOnlyHint: true } }, async (args) => {
    // --one-file-system prevents du from crossing mount boundaries (NFS, pCloud, /proc, /sys).
    // Without it, a scan of "/" can block for 30+ seconds on network mounts.
    const cmd = `sudo -n du -h --one-file-system --max-depth=${(args.depth as number) ?? 1} '${(args.path as string) ?? "/"}' 2>/dev/null | sort -rh | head -n ${(args.limit as number) ?? 20}`;
    const r = await executeBash(ctx, cmd, "normal");
    // Parse "size\tpath" du output into structured records (tab-separated by du).
    const entries = r.stdout.trim().split("\n").filter(Boolean).map((line) => {
      const tab = line.indexOf("\t");
      return tab !== -1 ? { size: line.slice(0, tab).trim(), path: line.slice(tab + 1).trim() } : { size: line.trim(), path: "" };
    });
    return success("disk_usage_top", ctx.targetHost, r.durationMs, "du + sort", { entries });
  });
```

**Step 2: Build**

```bash
cd /home/chris/projects/Claude-Code-Plugins/plugins/linux-sysadmin-mcp && npm run build
```

**Step 3: Commit**

```bash
cd /home/chris/projects/Claude-Code-Plugins && git add plugins/linux-sysadmin-mcp/src/tools/storage/index.ts && git commit -m "fix: add --one-file-system to disk_usage_top to prevent cross-mount hang"
```

---

## Task 3: Fix `cron_next_runs` — Pure-JS cron expression calculator

**Files:**
- Modify: `plugins/linux-sysadmin-mcp/src/tools/cron/index.ts:72-77`

**Context:** `systemd-analyze calendar` uses OnCalendar syntax (e.g. `*-*-* 00:00:00`), not standard cron syntax (e.g. `0 * * * *`). It always outputs the fallback message. We need a pure-JS calculator.

**Algorithm:** Starting from "now + 1 minute", step forward minute-by-minute checking if the timestamp matches all 5 cron fields. For performance, step by hour when minute field is a fixed number and current minute doesn't match.

**Cron field order:** `minute hour day-of-month month day-of-week`

**Step 1: Replace `cron_next_runs` tool handler**

Replace lines 72-77 with:

```typescript
  registerTool(ctx, { name: "cron_next_runs", description: "Show next N scheduled execution times for a cron expression.", module: "cron", riskLevel: "read-only", duration: "instant", inputSchema: z.object({ expression: z.string().min(9), count: z.number().int().min(1).max(20).optional().default(5) }), annotations: { readOnlyHint: true } }, async (args) => {
    const count = (args.count as number) ?? 5;
    const expr = (args.expression as string).trim();
    const parts = expr.split(/\s+/);
    if (parts.length < 5) {
      return success("cron_next_runs", ctx.targetHost, 0, null, { error: `Invalid expression: expected 5 fields, got ${parts.length}`, next_runs: [] });
    }
    const [minF, hourF, domF, monF, dowF] = parts;

    // Match a single cron field value against a Date component value.
    // Handles: * (wildcard), */N (step), N (literal), N-M (range), N-M/S (stepped range), N,M,... (list).
    function matchField(field: string, value: number, min: number, max: number): boolean {
      if (field === "*" || field === "?") return true;
      for (const part of field.split(",")) {
        const [rangeStep, stepStr] = part.split("/");
        const step = stepStr ? parseInt(stepStr, 10) : 1;
        if (rangeStep === "*") {
          // */N — every Nth value starting from min
          if ((value - min) % step === 0) return true;
        } else if (rangeStep.includes("-")) {
          const [lo, hi] = rangeStep.split("-").map(Number);
          if (value >= lo && value <= hi && (value - lo) % step === 0) return true;
        } else {
          const n = parseInt(rangeStep, 10);
          if (value === n) return true;
        }
      }
      return false;
    }

    const results: string[] = [];
    // Start at next minute boundary
    const start = new Date();
    start.setSeconds(0, 0);
    start.setMinutes(start.getMinutes() + 1);

    const cur = new Date(start.getTime());
    let iterations = 0;
    const maxIterations = 527040; // 1 year in minutes

    while (results.length < count && iterations < maxIterations) {
      const min = cur.getMinutes();
      const hour = cur.getHours();
      const dom = cur.getDate();
      const mon = cur.getMonth() + 1; // 1-12
      const dow = cur.getDay(); // 0=Sun, 6=Sat; cron also accepts 7=Sun

      const dowVal = dow === 0 ? [0, 7] : [dow];
      const dowMatch = dowVal.some(d => matchField(dowF, d, 0, 7));

      if (matchField(monF, mon, 1, 12) && matchField(domF, dom, 1, 31) && dowMatch &&
          matchField(hourF, hour, 0, 23) && matchField(minF, min, 0, 59)) {
        results.push(cur.toISOString().replace("T", " ").slice(0, 16) + " UTC");
      }

      cur.setMinutes(cur.getMinutes() + 1);
      iterations++;
    }

    return success("cron_next_runs", ctx.targetHost, 0, null, {
      expression: expr,
      next_runs: results,
      searched_minutes: iterations,
    });
  });
```

**Step 2: Build**

```bash
cd /home/chris/projects/Claude-Code-Plugins/plugins/linux-sysadmin-mcp && npm run build
```

**Step 3: Commit**

```bash
cd /home/chris/projects/Claude-Code-Plugins && git add plugins/linux-sysadmin-mcp/src/tools/cron/index.ts && git commit -m "fix: implement pure-JS cron next-run calculator in cron_next_runs"
```

---

## Task 4: Fix `show_sudoers_reference` — Read arg and include sudoers fragments

**Files:**
- Modify: `plugins/linux-sysadmin-mcp/src/tools/session/index.ts:16-77`

**Context:** The `show_sudoers_reference` parameter is declared in the schema (line 13) but `args` is never accessed in the handler. When `true`, the response should include per-module sudoers snippet templates.

**Sudoers fragments** are `NOPASSWD` lines for the commands each module needs. Keep them actionable — exact command patterns, not prose.

**Step 1: Add sudoers fragment map and conditional inclusion**

After the `if (!ctx.sudoAvailable)` block (line 70-73) and before the return (line 76), add:

```typescript
    // Conditionally append per-module sudoers fragments when show_sudoers_reference is true.
    // args is typed as unknown in the generic handler signature; cast is safe because schema enforces boolean.
    if ((args as { show_sudoers_reference?: boolean }).show_sudoers_reference) {
      data.sudoers_reference = {
        note: "Add these NOPASSWD lines to /etc/sudoers.d/linux-sysadmin-mcp (use visudo -f)",
        modules: {
          packages: [
            "your_user ALL=(ALL) NOPASSWD: /usr/bin/apt*, /usr/bin/dnf*, /usr/bin/yum*, /usr/bin/zypper*",
          ],
          services: [
            "your_user ALL=(ALL) NOPASSWD: /usr/bin/systemctl *",
            "your_user ALL=(ALL) NOPASSWD: /usr/bin/journalctl *",
          ],
          users: [
            "your_user ALL=(ALL) NOPASSWD: /usr/sbin/useradd, /usr/sbin/usermod, /usr/sbin/userdel",
            "your_user ALL=(ALL) NOPASSWD: /usr/sbin/groupadd, /usr/sbin/groupmod, /usr/sbin/groupdel",
            "your_user ALL=(ALL) NOPASSWD: /usr/bin/passwd",
          ],
          firewall: [
            "your_user ALL=(ALL) NOPASSWD: /usr/sbin/ufw *, /usr/sbin/iptables *",
            "your_user ALL=(ALL) NOPASSWD: /usr/sbin/firewall-cmd *",
          ],
          storage: [
            "your_user ALL=(ALL) NOPASSWD: /usr/bin/du *",
            "your_user ALL=(ALL) NOPASSWD: /usr/sbin/lvdisplay, /usr/sbin/vgdisplay, /usr/sbin/pvdisplay",
            "your_user ALL=(ALL) NOPASSWD: /usr/sbin/lvcreate, /usr/sbin/lvresize, /usr/sbin/lvextend",
          ],
          cron: [
            "your_user ALL=(ALL) NOPASSWD: /usr/bin/crontab *",
          ],
          security: [
            "your_user ALL=(ALL) NOPASSWD: /usr/bin/find / -perm -4000 *",
            "your_user ALL=(ALL) NOPASSWD: /usr/sbin/aa-status, /usr/sbin/semanage *",
          ],
        },
      };
    }
```

**Step 2: Build**

```bash
cd /home/chris/projects/Claude-Code-Plugins/plugins/linux-sysadmin-mcp && npm run build
```

**Step 3: Commit**

```bash
cd /home/chris/projects/Claude-Code-Plugins && git add plugins/linux-sysadmin-mcp/src/tools/session/index.ts && git commit -m "fix: implement show_sudoers_reference in sysadmin_session_info"
```

---

## Task 5: Sync to cache and verify

**Step 1: Sync built artifact to plugin cache**

```bash
cp /home/chris/projects/Claude-Code-Plugins/plugins/linux-sysadmin-mcp/dist/server.bundle.cjs \
   /home/chris/.claude/plugins/cache/l3digitalnet-plugins/linux-sysadmin-mcp/1.1.0/dist/server.bundle.cjs
```

**Step 2: Verify cache updated**

```bash
ls -la /home/chris/.claude/plugins/cache/l3digitalnet-plugins/linux-sysadmin-mcp/1.1.0/dist/server.bundle.cjs
```

Expected: timestamp matches recent build.

**Step 3: Final commit check**

```bash
cd /home/chris/projects/Claude-Code-Plugins && git log --oneline -5
```

Expected: 4 fix commits visible.
