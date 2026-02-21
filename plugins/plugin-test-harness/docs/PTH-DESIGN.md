# Plugin Test Harness (PTH) — Design Document

> **⚠ DESIGN DOCUMENT STATUS: PARTIALLY SUPERSEDED**
> This document describes the original pre-implementation design. Several major architectural elements were revised or removed during implementation:
> - **No container/VM isolation** — PTH runs tests in a git worktree on the host, not Docker/VM environments
> - **19 tools implemented** (not 45 as planned) — dynamic tool registration via `notifications/tools/list_changed` was not implemented
> - **No parallel test execution** — tests are driven by Claude sequentially
> - **No CI export or doc patch generation** — these remain planned features
>
> For the current implementation, see the README and source code. This document is kept for historical context.

**Version:** 1.0
**Date:** February 18, 2026
**Status:** Approved for Implementation (partial — see note above)

---

## 1. Executive Summary

The Plugin Test Harness (PTH) is a Claude Code plugin that orchestrates the live testing, diagnosis, hot-patching, and iterative refinement of other Claude Code plugins. It provisions isolated execution environments (containers or VMs), loads a target plugin into that environment, executes test scenarios against real files and services, captures failures, applies fixes to the target plugin's source, reloads it, and retests — all in a tight iterative loop driven by a human developer working interactively through Claude Code. PTH is activated on demand — its full tool set is only exposed while a session is active, keeping the Claude Code namespace clean during normal development.

PTH is designed to test any MCP-compliant plugin regardless of its domain, complexity, or implementation language. It achieves this by acting as a native MCP client that speaks the same protocol Claude Code uses, discovering the target plugin's capabilities through schema introspection and source analysis, and generating test proposals that the developer can approve, edit, or let Claude run directly.

Beyond iterative bug fixing, PTH produces durable artifacts: a persisted test suite that accumulates across sessions, a structured session report, documentation patches derived from passing tests, and an exportable CI pipeline — so a single PTH session can take a plugin from untested to CI-enabled. Sessions can be resumed after interruption, tests run in parallel for speed, and cross-distro verification ensures fixes work across target platforms.

---

## 2. Design Philosophy

PTH follows a single governing principle:

> **Claude uses its best judgment by default. The system provides tools and information to make good decisions, not rules that constrain them.**

This means:

- There are no mechanical enforcement rules, rigid thresholds, or hard-coded safety gates.
- Claude assesses risk, decides approval workflows, chooses recovery strategies, and manages safety contextually.
- The system is built to give Claude maximum information (source analysis, build output, test results, environment state) so it can make informed decisions.
- The human developer is always available for guidance through the interactive Claude Code session, and Claude decides when to ask versus when to act.

This philosophy reflects the nature of the tool: PTH tests a wildly varying range of plugins with different domains, risk profiles, and environment needs. Rigid rules would either be too restrictive for some plugins or too permissive for others. Claude's contextual judgment adapts to each situation.

---

## 3. Architecture Overview

### 3.1 Physical Architecture

PTH runs on the host machine as a standard MCP server within the developer's Claude Code session. It reaches into test environments (containers or VMs) via `docker exec`, `virsh`, or SSH. The target plugin runs inside the test environment, and PTH communicates with it using the MCP protocol — the same way Claude Code itself would.

```
┌─────────────────────────────────────────────────────────────┐
│                       HOST MACHINE                          │
│                                                             │
│  ┌────────────────────────────────────────────────────┐     │
│  │              Claude Code Session                    │     │
│  │                                                     │     │
│  │  ┌──────────────────┐  ┌──────────────────────┐    │     │
│  │  │  Plugin Test      │  │  Superpowers          │    │     │
│  │  │  Harness (PTH)    │  │  (if installed)       │    │     │
│  │  │  MCP Server       │  │                       │    │     │
│  │  └────────┬─────────┘  └──────────────────────┘    │     │
│  │           │                                         │     │
│  └───────────┼─────────────────────────────────────────┘     │
│              │                                               │
│              │  docker exec / virsh / SSH                     │
│              │                                               │
│  ┌───────────▼──────────────────────────────────────┐       │
│  │            Test Environment                       │       │
│  │         (Container or VM)                         │       │
│  │                                                   │       │
│  │  ┌─────────────────────────────────────────────┐ │       │
│  │  │  Target Plugin (MCP Server)                  │ │       │
│  │  │  Started via docker exec, communicates       │ │       │
│  │  │  over stdin/stdout (stdio) or HTTP           │ │       │
│  │  └─────────────────────────────────────────────┘ │       │
│  │                                                   │       │
│  │  ┌──────────────────────────────────────────┐    │       │
│  │  │ Plugin Source                             │    │       │
│  │  │ (bind-mounted or shared from PTH worktree)│    │       │
│  │  └──────────────────────────────────────────┘    │       │
│  │                                                   │       │
│  │  ┌──────────────────────────────────────────┐    │       │
│  │  │ Test Fixtures, Services, Seed Data        │    │       │
│  │  └──────────────────────────────────────────┘    │       │
│  └───────────────────────────────────────────────────┘       │
│                                                              │
│  PTH Worktree: /tmp/pth-worktree-xxxxx/                      │
│  (session branch, mounted into test environment above)       │
│                                                              │
│  Developer's Checkout: /home/dev/plugin-repo/                │
│  (untouched, developer continues working here)               │
└──────────────────────────────────────────────────────────────┘
```

### 3.2 Source Management

When a PTH session begins, it creates a new git branch in the target plugin's repository (e.g., `pth/session-2026-02-18-a1b2c3`) and checks it out into a separate working tree using `git worktree add`. This keeps the developer's checkout completely untouched — they can continue working on their branch in the original directory while PTH operates on a parallel worktree. The worktree is created in a temporary location (e.g., `/tmp/pth-worktree-a1b2c3/`).

This gives Claude full git capabilities throughout the session:

- **Fix tracking**: Each fix is committed individually with a descriptive message linking the change to its diagnosis. This provides a complete, reviewable history of every modification.
- **Incremental diffing**: `git diff` against the branch point shows cumulative changes at any time.
- **Fix reversal**: `git revert` cleanly undoes a specific fix without affecting other changes, even if subsequent fixes were applied on top.
- **Bisection**: If a regression is introduced, Claude can use `git bisect` against the fix commits to identify exactly which change caused it.
- **Session safety**: The developer's branch and working tree are untouched. If the session goes badly, the developer simply deletes the PTH branch and worktree.

The PTH worktree is what gets mounted into the test environment. When Claude applies a fix, it edits the file in the worktree, commits, and the change is immediately visible inside the environment.

At session end, PTH removes the worktree (`git worktree remove`) but the branch remains in the repository for the developer to review, merge, cherry-pick, or delete at their convenience.

**Source sharing by environment type:**
- **Containers (Tier 1/2):** The PTH worktree is bind-mounted into the container. Changes are visible instantly.
- **VMs (Tier 3):** The PTH worktree is shared via virtiofs (preferred) or 9p. If neither shared filesystem is available, PTH falls back to rsync-on-edit as a degraded mode with slightly delayed visibility.

### 3.3 Communication with the Target Plugin

PTH includes a lightweight MCP client that connects to the target plugin's MCP server using the same protocol Claude Code uses:

- **stdio transport** (most Claude Code plugins): PTH runs `docker exec -i <container> <start-command>` and communicates over the exec'd stdin/stdout using JSON-RPC. The start command is resolved per-plugin during loading (see §5.2) — for example, `node /path/to/plugin/dist/index.js` for a TypeScript plugin, `python /path/to/plugin/main.py` for Python, or a compiled binary path for Rust/Go. The server process is kept alive across tool calls or restarted per test — Claude decides based on whether the plugin is stateful and whether tests need isolation.

- **HTTP transport**: PTH forwards a port from the container and connects as a standard HTTP client.

This approach means PTH can test any MCP-compliant plugin without modification. The target plugin doesn't need a CLI, a test harness hook, or any awareness of PTH.

**Connection Pooling for Parallel Execution:**

By default, PTH maintains a single MCP client connection to one plugin server instance. When parallel test execution is enabled (see §5.3), PTH manages a *pool* of connections, each to a separate MCP server instance running inside the environment:

- **stdio**: Each pool member is a separate exec'd process with its own stdin/stdout pair. PTH tracks the process handles independently.
- **HTTP**: Each pool member is a server instance on a different port. PTH allocates ports from a configurable range starting above the primary instance's port.

Pool size equals the configured concurrency level. Claude decides the concurrency level based on the plugin's apparent statefulness and the environment's available resources. Stateful plugins (those that hold in-memory caches, write to shared files, or maintain cross-call context) should use concurrency 1 to avoid divergent state across instances. Stateless plugins can safely fan out across multiple instances.

All pool instances share the same bind-mounted source directory. Since parallel execution is limited to Tier 1 tests (single tool calls with no shared state), filesystem contention is unlikely but PTH monitors for it via environment health checks.

### 3.4 Activation Model

PTH operates in two states: **dormant** and **active**. When installed but not in use, PTH exposes only a minimal set of activation tools — enough to start or resume a session. The full tool set (environment management, testing, diagnosis, fixes, iteration control, performance) is registered only after the developer explicitly initiates a PTH session. When the session ends, PTH withdraws all session tools and returns to dormant state.

**Dormant State** (default when PTH is installed):

| Tool | Description |
|---|---|
| `pth_start_session` | Initialize a new PTH session — the single entry point |
| `pth_resume_session` | Resume an interrupted session from an existing PTH branch |
| `pth_preflight` | Pre-session validation (optional — also runs automatically during start) |

These three tools are the only PTH tools visible in the Claude Code session during normal development. The `pth_` prefix appears in tool listings only for these activation tools.

**Active State** (after `pth_start_session` or `pth_resume_session` succeeds):

PTH sends a `notifications/tools/list_changed` notification to Claude Code, which triggers a re-read of PTH's tool list. All 45 session tools become available. Claude can now use environment management, testing, diagnosis, fix, iteration, and performance tools freely.

**Deactivation** (after `pth_end_session`):

PTH withdraws all session tools and sends another `notifications/tools/list_changed` notification. Only the three dormant-state tools remain. This ensures the tool namespace stays clean between sessions.

**Practical Effect:** A developer who has PTH installed but isn't actively testing sees only 3 tools from PTH in their Claude Code session. When they say "test my plugin," Claude calls `pth_start_session` and the full tool set becomes available for the duration of the session. When they say "wrap up," the tools disappear again.

**Session Crash Recovery:** If PTH's MCP server process crashes during an active session, the tools disappear with it. When the MCP server restarts (automatically by Claude Code, or manually), PTH initializes in dormant state. The developer uses `pth_resume_session` to reactivate the full tool set and pick up where they left off.

---

## 4. Environment Tiering

PTH uses a tiered environment strategy to balance realism against provisioning speed. PTH performs a quick static analysis of the target plugin's source (looking for syscalls, systemd references, kernel module operations, raw socket access, etc.) and recommends a tier. The human confirms or overrides.

### Tier 1 — Container

**When:** Plugin only does file I/O, network API calls, text processing, data transformation.

**Runtime:** Docker.

**Characteristics:** Fast provisioning (2-5 seconds), lightweight, no real init system.

**Limitations:** No systemd, no real kernel, no hardware interfaces.

### Tier 2 — Privileged Container

**When:** Plugin manages services, cron jobs, users/groups, or needs a real init system but doesn't require kernel-level access.

**Runtime:** Docker with `--privileged` and systemd as the container's init process.

**Characteristics:** Moderate provisioning time, has systemd as init, can manage services. More resource-intensive than Tier 1 but faster than a full VM.

**Limitations:** Shares host kernel, may not perfectly replicate a standalone OS environment.

### Tier 3 — Full VM

**When:** Plugin touches kernel parameters, hardware interfaces, networking stack, firewall rules, or needs a specific distro with full OS-level realism.

**Runtime:** QEMU/KVM via libvirt.

**Characteristics:** Full OS-level realism. Slower provisioning but provides the most accurate test environment. Uses qcow2 backing files for copy-on-write overlays, making snapshot/rollback fast once the base image exists.

**Limitations:** Heavier resource usage, slower iteration cycle.

### Base Images

PTH maintains golden base images for each supported distro:

| Base Image | Distro | Primary Use | Formats |
|---|---|---|---|
| `pth-base-ubuntu2404` | Ubuntu 24.04 LTS | General purpose, Debian-family testing | Container (Dockerfile) + VM (qcow2) |
| `pth-base-fedora` | Fedora (latest) | RHEL-family testing, cutting-edge packages | Container (Dockerfile) + VM (qcow2) |

Each base image includes the OS, Node.js 20+, Python 3.11+, git, and common build tools. Both images are available as containers (for Tier 1/2) and as VM disk images (for Tier 3).

**Image Lifecycle:** PTH builds base images on demand. Claude assesses whether an existing image is fresh enough for the current task based on the plugin being tested, known recent changes to dependencies, and how long ago the image was built. A manual rebuild tool (`pth_rebuild_base_images`) is available for explicit refresh.

**Layering Model:**
- **Base layer** (rebuilt occasionally): OS + runtimes (Node.js, Python) + git + build tools
- **Plugin layer** (applied at session start): `npm install`, plugin build, dependency setup — typically 10-30 seconds
- **Session layer** (ephemeral): Test fixtures, environment variables, seed data — created and destroyed with each test environment

---

## 5. Core Components

### 5.1 Environment Manager

Provisions, manages, and tears down test environments. Abstracts the differences between Docker and QEMU/KVM behind a common interface.

**Responsibilities:**
- Detect available container runtimes on the host
- Build or verify base images (on-demand with Claude-assessed staleness)
- Provision environments at the appropriate tier
- Manage bind mounts (containers) or shared directories (VMs) for plugin source
- Execute commands inside the environment
- Copy files in and out
- Snapshot and rollback environment state
- Destroy environments at session end
- Load dependent plugins as infrastructure (see below)
- Monitor environment health between iterations
- Detect environment drift from provisioned state

**Dependent Plugin Loading:**

Some plugins depend on other MCP plugins being available in the environment. `EnvConfig` supports a `dependencyPlugins` array listing plugins to install and start alongside the target. PTH installs, builds, and starts these dependency plugins but does not test or modify them — they are treated as infrastructure. The target plugin's tests can exercise workflows that assume the dependency plugin's tools are available.

*Start ordering:* Dependency plugins are installed, built, and started before the target plugin, in the order listed in `dependencyPlugins`. Each dependency's MCP server is verified healthy via `tools/list` before proceeding to the next. The target plugin is started only after all dependencies are confirmed healthy.

*Health verification:* After starting each dependency plugin, PTH calls `tools/list` on its MCP server to confirm it is responsive and has registered its expected tools. If a dependency fails this check after retries, PTH reports the failure (build output, server stderr) and blocks the session — the target cannot be tested meaningfully without its dependencies.

*Communication model:* Dependency plugins are primarily useful for the background services they provide to the environment — databases, API servers, file watchers, or other infrastructure that the target plugin depends on at the system level. MCP servers do not call other MCP servers directly; inter-plugin communication happens through shared environment state (files, network services, databases), not MCP tool calls. PTH's tests invoke the *target* plugin's tools via the MCP client; if those tools internally rely on services that a dependency plugin manages, the dependency's role is to ensure those services are running.

**Health Monitoring:**

Between iterations, PTH samples basic environment health: disk usage, memory pressure, zombie processes, and whether key services (Tier 2/3) are still running. If the environment has degraded — a runaway process from a previous test, an OOM kill, disk exhaustion — PTH surfaces this before Claude wastes iterations diagnosing phantom failures. This is lightweight: a few `exec` calls between iterations, not continuous monitoring.

**Drift Detection:**

At provision time, PTH takes an environment fingerprint: installed packages, running services, system config file checksums, filesystem baseline outside the plugin source directory. `pth_check_environment_drift` compares the current state against this fingerprint. Significant drift (packages installed by fixes, services left running by tests, config files modified by side effects) may cause tests to pass in the dirty environment but fail on a clean provision. Claude can run drift detection before the final validation pass, and if drift is significant, reprovision a clean environment to verify fixes are self-contained.

**Resource Management:**

PTH manages resources at three levels:

- **Session exclusivity:** At session start, PTH writes a lock file (`.pth/active-session.lock`) to the plugin repository containing the session branch name, PID, and timestamp. Preflight and session start check for this lock and warn if another session appears active. This prevents accidental concurrent sessions from the same plugin repo (Decision #29). The lock is removed at session end or on resume if the owning process is no longer running.

- **Environment resource reporting:** After provisioning, PTH queries the environment's available resources (CPU count, memory, disk) and reports them as part of the provision result. This data is available to Claude when deciding parallel test concurrency — e.g., "this VM has 4 CPUs and 8GB RAM" informs a concurrency-4 decision. The `pth_inspect_environment` tool includes this resource summary.

- **Host resource limits:** PTH does not manage total host capacity. The `EnvConfig.resources` constraints are passed to Docker (`--cpus`, `--memory`) or libvirt (vCPU/memory allocation) to cap the environment's resource usage, but the developer is responsible for ensuring their host machine has sufficient headroom for PTH overhead, parallel MCP server instances, and the environment itself. PTH surfaces host resource pressure via health monitoring if the environment begins to degrade.

**Runtime Abstraction:**

```typescript
interface EnvironmentRuntime {
  name: "docker" | "qemu-kvm";

  // Lifecycle
  provision(config: EnvConfig): Promise<EnvironmentHandle>;
  destroy(handle: EnvironmentHandle): Promise<void>;

  // Snapshot & rollback
  snapshot(handle: EnvironmentHandle, tag: string): Promise<SnapshotId>;
  rollback(handle: EnvironmentHandle, snapshot: SnapshotId): Promise<void>;

  // Execution & file transfer
  exec(handle: EnvironmentHandle, command: string[], opts?: ExecOpts): Promise<ExecResult>;
  copyIn(handle: EnvironmentHandle, hostPath: string, envPath: string): Promise<void>;
  copyOut(handle: EnvironmentHandle, envPath: string, hostPath: string): Promise<void>;

  // Source sharing
  mountSource(handle: EnvironmentHandle, hostPath: string, envPath: string): Promise<MountInfo>;
  // Docker: bind mount. QEMU: virtiofs (preferred), 9p, or rsync-on-edit fallback.
  // Returns MountInfo describing the method used and any latency characteristics.

  // Port forwarding (for HTTP transport and parallel pool instances)
  forwardPort(handle: EnvironmentHandle, envPort: number, hostPort?: number): Promise<number>;
  // Returns the allocated host port. If hostPort is omitted, auto-allocates.

  // Health & drift
  healthCheck(handle: EnvironmentHandle): Promise<HealthReport>;
  // Samples disk, memory, zombie processes, key services. Lightweight.
  fingerprint(handle: EnvironmentHandle): Promise<EnvironmentFingerprint>;
  // Captures installed packages, running services, config checksums, filesystem baseline.
  detectDrift(handle: EnvironmentHandle, baseline: EnvironmentFingerprint): Promise<DriftReport>;

  // Observability
  logs(handle: EnvironmentHandle, opts?: LogOpts): Promise<string>;
  inspect(handle: EnvironmentHandle): Promise<EnvState>;
}
```

**Environment Configuration:**

```typescript
interface EnvConfig {
  runtime: "docker" | "qemu-kvm" | "auto";
  tier: 1 | 2 | 3;
  baseImage: string;
  targetPlugin: {
    sourcePath: string;          // Host path to PTH worktree
    buildCommand?: string;       // Override if convention detection fails
    configValues?: Record<string, string>;  // Resolved config/secrets
  };
  dependencyPlugins?: {           // Other plugins loaded as infrastructure
    sourcePath: string;           // Host path to dependency plugin
    configValues?: Record<string, string>;
  }[];
  fixtures?: {
    files?: FileFixture[];       // Files to seed into the environment
    setupScripts?: string[];     // Scripts to run after provisioning
    services?: ServiceDef[];     // Companion services to provision
  };
  resources?: {
    cpus?: number;
    memoryMB?: number;
    diskGB?: number;
  };
}
```

### 5.2 Plugin Loader

Handles installation, configuration, build, and hot-reload of the target plugin within the test environment.

**Responsibilities:**
- Discover the build system via convention (package.json → npm, setup.py → pip, Makefile → make, etc.); ask the human if detection fails
- Install dependencies inside the environment
- Build the plugin
- Read the plugin's config schema and resolve values — Claude provides defaults where possible, prompts the human only for values it can't determine (secrets, environment-specific paths)
- Start the MCP server process
- Hot-reload after fixes: rebuild, restart the MCP server, verify with `tools/list`
- Track tool schema changes across reloads (new tools, removed tools, changed signatures)

**Hot-Reload Sequence:**

```
1. Signal the MCP server process to shut down (close stdin / SIGTERM)
2. Wait for graceful shutdown (timeout determined by Claude)
3. Rebuild plugin source (detected build command)
4. Restart MCP server process via the runtime's exec interface
5. Call tools/list to verify the server is healthy
6. Report tool delta to the conversation if schemas changed
```

**Build System Detection Priority:**

| File Detected | Build Command | Install Command |
|---|---|---|
| `package.json` with `build` script | `npm run build` | `npm install` |
| `package.json` without `build` script | (none) | `npm install` |
| `tsconfig.json` | `npx tsc` | `npm install` |
| `setup.py` or `pyproject.toml` | `pip install -e .` | (included in build) |
| `Makefile` | `make` | `make install` (if target exists) |
| `Cargo.toml` | `cargo build` | (included in build) |

If none of these are found, PTH asks the human how to build the plugin.

**On-demand toolchains:** The base images include Node.js, Python, and common build tools. Non-standard toolchains (Rust, Go, Java, etc.) are installed on-demand into the environment when detected during plugin loading. This keeps base images lean while supporting any plugin language.

### 5.3 Test Engine

Generates, manages, and executes tests across three tiers.

**Test Generation Inputs:**

PTH combines every available signal to generate test proposals:

1. **Tool schemas** — Introspect the MCP server's `tools/list` response to understand every tool's name, description, input schema, and output schema. Generate Tier 1 tests for each tool with valid inputs, edge cases, and invalid inputs.

2. **Source code analysis** — Parse the plugin's source to understand control flow, error handling patterns, dependencies, and side effects. Identify tools that modify state, tools that depend on other tools' output, and tools with complex validation logic.

3. **README and documentation** — If the plugin has documentation, extract usage examples, expected behaviors, and described workflows. Generate Tier 2 scenario tests from documented workflows.

4. **Config schema** — Understand what the plugin is configured to do and test accordingly.

Claude decides whether each generated test should run immediately or be presented to the human for review. Routine schema-derived tool tests typically run directly; novel scenarios or tests with potentially destructive operations are surfaced for approval.

**Generation Source Tracking:**

Every generated test is tagged with a `generated_from` metadata field indicating its origin: `schema`, `source_analysis`, `documentation`, or `config`. Human-created or human-edited tests are tagged `manual`. This metadata helps Claude during diagnosis: a `documentation`-sourced test that contradicts `schema`-sourced expectations is more likely a stale doc problem than a plugin bug. The `pth_list_tests` tool can filter by generation source.

**Flakiness Detection:**

When a test fails, PTH can optionally re-run it 2–3 times before triggering diagnosis. If results are inconsistent, PTH flags the test as flaky rather than failed. Flaky tests get a different diagnostic path — Claude investigates timing, race conditions, or external dependencies rather than code logic. The test result history tracks flakiness rates per test over time. Claude decides when to use flakiness detection — typically skipped for Tier 1 schema tests but valuable for Tier 2/3 scenarios involving services or network calls.

**Parallel Test Execution:**

Tier 1 tests are independent by design (single tool call, no shared state) and can run in parallel. PTH supports a configurable concurrency level: it starts multiple MCP server instances inside the environment and fans out independent tests across them. Tier 2/3 tests remain sequential due to ordering dependencies and shared state. Claude chooses the concurrency level based on the environment's resources and whether the plugin appears to be stateless. This is particularly important for large test suites and when matrix verification (cross-distro) adds additional test passes.

**Test Impact Analysis:**

During test execution, PTH builds a lightweight dependency map between source files and tests. When a tool handler in `user-management.ts` is invoked by tests X, Y, and Z, PTH records that association. After a fix touches a source file, PTH can report which tests directly exercise code in the changed file, plus any scenario tests that call those tools as part of a workflow. Claude still decides what to re-run, but the impact map provides concrete data rather than requiring first-principles reasoning each time.

**Code Coverage Instrumentation:**

PTH can enable code coverage instrumentation during test runs (Istanbul/nyc for TypeScript, coverage.py for Python). After a test suite run, PTH reports which source files and functions have low coverage. Claude uses this to generate targeted additional tests for uncovered code paths — a second generation pass after the initial schema/docs/source pass. This doesn't gate progress; it's information for Claude. "Tool X has 3 tests but its error handling branch at line 47 is never exercised" is a concrete signal for generating better tests.

### 5.4 Diagnostic Engine

Analyzes test failures and produces structured diagnosis.

When a test fails, the diagnostic engine collects:
- The raw error (exception, stderr, non-zero exit code, assertion failure)
- The tool call that triggered it (input, expected output, actual output)
- The MCP server's stderr/stdout at the time of failure
- Relevant source code (the tool's handler, imports, shared utilities)
- Environment state (filesystem, running services, resource usage)

Claude synthesizes this into a diagnosis: what went wrong, which source files are involved, and what kind of fix is likely needed. The diagnosis feeds directly into fix generation.

**Failure Categories** (informational, not rigidly enforced):

- **Build failures** — Compilation errors, missing dependencies, syntax errors, import resolution failures
- **Runtime exceptions** — Uncaught errors in tool handlers
- **Schema violations** — Input or output doesn't match the declared schema
- **Wrong output** — Tool runs but returns incorrect results
- **Missing side effects** — Expected state changes didn't happen
- **Unexpected side effects** — Unintended modifications to the environment
- **Timeouts** — Tool calls exceeding reasonable time
- **MCP protocol errors** — Malformed JSON-RPC, missing required fields
- **Dependency errors** — Missing system packages, unavailable services

### 5.5 Fix Applicator

Applies code changes to the target plugin's source on the session branch, commits each fix individually, and triggers reload.

**Fix Types:**

- **Line edits** — Modify specific lines in specific files (the common case for bug fixes)
- **File operations** — Create, delete, or rename files (for structural changes)
- **Multi-file edits** — Coordinated changes across multiple files (for refactoring)
- **Configuration changes** — Modify environment variables, config files, or runtime flags
- **Dependency changes** — Add, remove, or update package dependencies

**Snapshot-Gated Application:**

For risky fixes that alter environment state beyond source code — package installs, service configuration changes, firewall modifications, system config edits — PTH takes an environment snapshot before applying the fix. If the fix causes a regression or the environment enters a bad state, PTH performs a coordinated rollback: environment snapshot restore *and* `git revert` in one operation. This is more reliable than git revert alone, since a fix that installs a package or modifies `/etc/` leaves environment state that code revert won't undo. Claude decides which fixes warrant snapshot gating based on the fix type and the operations involved. The snapshot is discarded after the retest passes.

**Fix Tracking:**

Every fix is committed as an individual git commit on the PTH session branch. Commit messages follow a structured convention with machine-readable git trailers:

```
fix: handle missing group in user creation

Fixed undefined reference to groupAdd utility when creating users
with non-existent groups. Added existence check before calling.

PTH-Test: create_user_nonexistent_group
PTH-Category: runtime-exception
PTH-Files: src/tools/user-management.ts
PTH-Iteration: 3
```

The trailers make the git history queryable without parsing prose:
- `git log --format='%(trailers:key=PTH-Test)'` finds all fixes for a specific test
- `git log --format='%(trailers:key=PTH-Category)'` filters by failure category
- `git log --format='%(trailers:key=PTH-Iteration)'` reconstructs per-iteration activity

This gives Claude a rich, structured history to work with:

- `git log` shows the full sequence of fixes applied
- `git diff <branch-point>..HEAD` shows cumulative changes at any point
- `git show <commit>` reveals the exact change for any specific fix
- `git revert <commit>` cleanly undoes a specific fix
- `git bisect` can identify which fix introduced a regression

Claude uses this git history to avoid repeating failed fixes, detect oscillating patterns, and understand how the codebase has evolved across iterations.

**Superpowers Integration:**

When the Superpowers plugin is detected in the Claude Code session, Claude can choose to delegate complex changes through Superpowers' planning and implementation workflow. This is particularly valuable for:
- Architectural restructuring (splitting modules, moving functions between files)
- Changes that affect many files simultaneously
- Changes where a brainstorm→plan→implement→review cycle would produce a better result

Claude decides when a change is complex enough to warrant Superpowers versus direct implementation. PTH does not depend on Superpowers and is fully functional without it.

**Detection:** At session start, PTH checks for Superpowers by looking for its skill files in the Claude Code plugin cache (typically `~/.claude/plugins/cache/Superpowers/`). If found, PTH notes the available skills (brainstorming, TDD, code review, etc.) and Claude factors them into its decision-making for complex changes.

**Anti-Regression Awareness:**

The git commit history gives Claude full visibility into what has been tried. Claude can review:
- Previous fix commits that addressed the same test failure
- Fixes that were later reverted due to regressions
- Patterns of fixes oscillating (fix A breaks test B, fix B breaks test A)
- Files with many fix commits, suggesting a deeper architectural issue
- The relationship between changes via `git blame`

This information is available to Claude for decision-making but is not enforced mechanically.

### 5.6 Iteration Controller

Orchestrates the test → diagnose → fix → reload → retest loop.

**Loop Flow:**

```
SESSION START
  │
  ├─ Create session branch and worktree
  ├─ Activate full tool set (notifications/tools/list_changed)
  ├─ Provision environment (tier selected by Claude, confirmed by human)
  ├─ Install and build plugin
  ├─ Start MCP server, introspect tools
  ├─ Generate test proposals
  │
  ▼
ITERATION LOOP
  │
  ├─ Execute tests
  │   └─ Claude decides which tests to run (all, failing only,
  │      or targeted based on recent changes)
  │
  ├─ If all tests pass → exit loop
  │
  ├─ Diagnose failures
  │   └─ Collect error context, identify root cause, suggest fix
  │
  ├─ Apply fix
  │   ├─ Claude assesses risk and decides: apply directly or ask human
  │   ├─ If complex: optionally delegate to Superpowers
  │   └─ Commit fix to session branch with diagnostic context
  │
  ├─ Reload plugin
  │   └─ Claude decides scope: MCP server restart vs. environment restart
  │
  ├─ Update test suite if needed
  │   └─ Generate new tests for added/changed tools (§5.2), coverage
  │      gaps (§5.3), or human-requested capabilities
  │
  ├─ Check environment health
  │   └─ PTH samples disk, memory, processes, services between iterations
  │
  └─ Loop back to test execution
      └─ Claude decides which tests to re-run based on change extent

ITERATION EXIT (all tests pass OR Claude/human decides to stop)
  │
  ▼
VERIFICATION PHASE (if targeting multiple distros)
  │
  ├─ For each additional base image:
  │   ├─ Reprovision, re-run full suite
  │   └─ Fix distro-specific failures (PTH-Distro trailer)
  ├─ Re-verify on primary distro (confirm no regressions)
  └─ Complete when primary distro passes final re-verification

DRIFT CHECK (optional, recommended before final validation)
  │
  ├─ Compare environment state against provision-time fingerprint
  └─ If significant drift: reprovision clean, re-run full suite

PERFORMANCE PHASE (if warranted)
  │
  ├─ Re-run full test suite with performance instrumentation
  ├─ Claude provides qualitative performance assessment
  └─ Human reviews and decides on further optimization

SESSION END
  │
  ├─ Session branch remains in repo with full fix history
  ├─ Persist test suite to .pth/tests/ on session branch
  ├─ Generate session report to .pth/SESSION-REPORT.md
  ├─ Optionally generate documentation patches
  ├─ Remove PTH worktree
  ├─ Destroy test environment
  ├─ Deactivate session tools (return to dormant state)
  └─ Claude summarizes: branch name, total commits, files changed
```

**Cross-Distro Verification Phase:**

When the developer is targeting multiple distros, PTH supports a verification phase between the functional iteration loop and the performance phase. The primary iteration loop runs on one distro (the developer's primary target). After all tests pass, PTH reprovisions the environment with each additional base image and re-runs the full test suite. Failures that are distro-specific get a focused fix pass with Claude noting which fixes are universal versus distro-conditional. The convergence tracker shows per-distro pass rates. This keeps the fast inner loop on one distro while adding cross-platform validation before declaring victory.

**Distro-Conditional Fix Tracking:** Fixes applied during the verification phase that are specific to a distro include a `PTH-Distro: <distro>` commit trailer alongside the standard trailers. This distinguishes universal fixes (no `PTH-Distro` trailer) from distro-conditional code paths. The session report groups fixes by distro scope.

**Re-Verification on Primary Distro:** After all verification distros pass, PTH reprovisions the primary distro and re-runs the full test suite one final time. This confirms that distro-specific fixes (which may add conditional logic, new dependencies, or alternative code paths) did not regress the primary distro. The session is not complete until the primary distro passes this final re-verification.

**Three or More Distros:** When targeting more than two distros, PTH verifies each sequentially. Fixes applied for distro B are retested on distro C (since they share the same branch), and so on. After the last verification distro passes, the final re-verification pass runs on the primary distro. Claude can reorder the verification sequence if it determines that certain distros are more likely to share characteristics (e.g., verifying two RHEL-family distros back-to-back).

**Test Persistence:**

At session end, PTH exports the final test suite to a `.pth/tests/` directory committed to the session branch. On future sessions, `pth_start_session` checks for an existing `.pth/tests/` directory and loads those tests as a baseline, then generates additional tests for any new or changed tools. This creates a flywheel: each PTH session builds on the previous session's test suite. Human-edited tests and hand-crafted scenarios survive across sessions.

**Session Report:**

`pth_end_session` generates a markdown session report committed to the session branch as `.pth/SESSION-REPORT.md`. It includes: session parameters (plugin, distro, tier), test suite summary (total generated, pass/fail progression by iteration), a categorized fix log (each fix with its diagnosis, affected files, and test it resolved — derived from commit trailers), any performance findings, cross-distro verification results if applicable, and the final state (all passing, or which tests remain failing and why). The iteration-by-iteration convergence curve is captured as a text table. This gives the developer a reviewable artifact alongside the code diff.

**Documentation Patches:**

At session end (or on request), PTH can generate documentation patches for the plugin's README: updated tool descriptions reflecting actual behavior, corrected usage examples based on passing Tier 2 tests, and new entries for tools added during the session. This is committed as a separate `docs: update README from PTH session` commit on the session branch. PTH has everything needed for accurate docs: every tool's schema, passing test examples showing real inputs and outputs, and the ability to compare existing README content against observed behavior.

**Human Alteration:**

At any point during the iteration loop, the human can describe a desired behavioral change in natural language. PTH interprets this as an alteration request (distinct from a bug fix) and implements the change, then continues the iteration loop with the altered plugin. This supports the use case where the developer realizes mid-testing that the plugin's design should change, not just its bugs.

**Convergence Awareness:**

Claude tracks progress across iterations:
- How many tests are passing vs. failing over time
- Whether the same failures keep recurring despite different fixes
- Whether fixes are causing as many regressions as they resolve
- Whether the fix complexity is escalating (suggesting architectural issues)

**Test Result History:** The iteration controller maintains a per-iteration record of test results (pass/fail status for each test, failure categories, which fixes were applied). This history drives the convergence summaries shown in §8 and enables Claude to detect patterns like plateaus, oscillations, and regressions across the full session timeline.

Claude uses this awareness to decide when to escalate to the human (e.g., "I've attempted 3 different approaches to this failure and none have worked — I think this needs a design discussion") or when to suggest shifting strategy.

**Session Resume:**

If a PTH session is interrupted — Claude Code crashes, context window fills up, the developer closes their laptop — the git commits, persisted tests, and session state survive. At the end of each iteration, PTH writes a lightweight `.pth/session-state.json` to the session branch containing: the current iteration number, per-test pass/fail status from the most recent run, the convergence trend (improving, plateaued, oscillating), active diagnosis summaries for still-failing tests, and PTH operation timings. This file is overwritten each iteration (not accumulated) and committed as a standalone checkpoint commit with a `PTH-Type: state-checkpoint` trailer, separate from fix commits. This ensures state is always persisted even in iterations that produce no fixes, and checkpoint commits are easily filtered out of the fix history by trailer type.

`pth_resume_session` picks up an existing PTH session branch: it creates a new worktree for the branch, reads `.pth/session-state.json` to reconstruct exactly where the session left off, reads the commit history (via structured trailers) for the full fix narrative, reprovisions a matching environment, rebuilds the plugin from the branch's current state, and reloads persisted tests from `.pth/tests/`. Claude reviews the session state and git log to understand where things left off and resumes the iteration loop with full context — not just what was done, but how the session was progressing at the time of interruption.

**Session Lifecycle Edge Cases:**

*Branch naming:* Session branch names always include a random suffix (e.g., `pth/linux-admin-mcp-2026-02-18-a1b2c3`). Before creating a branch, `pth_start_session` checks for name existence and generates a new suffix if a collision occurs. Stale PTH branches from previous sessions are left for the developer to manage — PTH never deletes branches it didn't create in the current session.

*Stale worktree cleanup:* If a previous PTH session crashed without running `pth_end_session`, orphaned worktrees may remain registered in git and on disk. Both `pth_preflight` and `pth_start_session` scan for PTH worktrees (matching the `<PTH_WORKTREE_DIR>/pth-worktree-*` pattern, where `PTH_WORKTREE_DIR` defaults to `/tmp` — see §13) and check whether they are still associated with a running session (via the lock file). Orphaned worktrees are surfaced to Claude, who offers to clean them up or prompt the human.

*Corrupted resume state:* If `.pth/session-state.json` is unreadable or missing on resume (power loss mid-write, partial commit), `pth_resume_session` falls back gracefully: it reconstructs what it can from git commit history and trailers (iteration count, fixes applied, files changed) and reloads persisted tests from `.pth/tests/`. The per-test pass/fail history and convergence trend are lost, but the session can still continue. Claude notes the degraded context to the human.

*Test persistence across merges:* When the developer merges a PTH branch to main, `.pth/tests/` becomes part of the mainline. Future PTH sessions that branch from main will inherit this test suite automatically — `pth_start_session` detects existing tests and loads them as the baseline. Merge conflicts in `.pth/tests/` are unlikely (YAML files are typically added, not edited in parallel), but if they occur, they are standard git conflicts for the developer to resolve before starting a new session.

### 5.7 Error Handling & Recovery

PTH's own infrastructure can fail independently of the plugin under test. When this happens, PTH surfaces the failure with full context to Claude, who selects from the available recovery options. The table below catalogs major failure categories, what PTH reports, and what recovery paths exist.

**Environment Failures:**

| Failure | What PTH Surfaces | Recovery Options |
|---|---|---|
| Docker daemon unreachable | Connection error, last known daemon state | Retry after delay; prompt human to check Docker; abort session |
| VM fails to boot | libvirt error output, boot log if available | Retry provision; try different base image; fall back to Tier 2 if appropriate; abort |
| Container/VM dies mid-session | Exit code, last logs, resource state before death | Reprovision from snapshot if available; reprovision fresh and rebuild plugin; abort |
| Disk full (host) | Disk usage, list of PTH artifacts consuming space | Prompt human to free space; destroy snapshots; prune old base images; abort |
| Snapshot/rollback fails | Runtime error, snapshot metadata, disk state | Reprovision clean and rebuild from git branch state; skip snapshot-gating for this fix |
| Network unavailable inside environment | Failed connectivity test output | Check Docker network config; reprovision; prompt human for network troubleshooting |

**Plugin Failures (not test failures):**

| Failure | What PTH Surfaces | Recovery Options |
|---|---|---|
| Build fails irrecoverably | Full build output, detected build system, dependency tree | Prompt human to fix build manually; try alternative build command; abort session |
| MCP server process crashes | Exit code, stderr, last successful tool call, core dump path if available | Restart server; rebuild and restart; reprovision environment if crash corrupted state |
| MCP server hangs (no response) | Time since last response, process state (via `ps`), resource usage | Kill and restart; increase timeout; reprovision if environment is degraded |
| Plugin config resolution fails | Missing keys, schema vs. provided values diff | Prompt human for missing values; try with defaults; skip optional config |
| Dependency plugin fails to start | Dependency build output, server stderr, tools/list failure | Fix dependency manually; remove from dependencyPlugins if not essential; abort session |

**Git & Source Failures:**

| Failure | What PTH Surfaces | Recovery Options |
|---|---|---|
| Worktree creation fails | git error output, existing worktree list, path state | Clean stale worktrees; use alternative temp path; prompt human |
| Commit fails | git error, disk state, index state | Retry; check disk space; prompt human |
| Revert produces merge conflict | Conflict markers, files affected, commit being reverted | Prompt human to resolve; skip revert and apply a new forward fix instead |
| Branch already exists | Existing branch name, its commit history | Resume existing session; create with alternate name; prompt human to delete stale branch |

**General Principles:**

- PTH always surfaces the raw error output alongside its own interpretation. Claude sees both the infrastructure error and the human-readable context (which component, what was being attempted, what state the session is in).
- For transient failures (network blips, brief resource pressure), PTH retries with exponential backoff before escalating. Claude decides the retry budget.
- For destructive failures (corrupted environment, disk full), PTH prioritizes preserving the session branch and persisted tests. The git history and `.pth/tests/` directory are the session's durable assets — if those survive, the session can be resumed even after a catastrophic environment failure.
- PTH never silently swallows errors. Every caught exception is reported to Claude with enough context to decide the next step.

---

## 6. Test Format Specification

All tests are defined in YAML. Three tiers vary in assertion style while sharing a common container format.

### Tier 1 — Tool Unit Tests

Direct tool calls with explicit input/output assertions. Generated primarily from schema introspection.

```yaml
name: "restart_service - valid service"
tier: 1
requires_tier: 2
tool: sysadmin_restart_service
input:
  service: "nginx"
expect:
  success: true
  output_contains: "restarted"
verify:
  - exec: "systemctl is-active nginx"
    expect_stdout: "active"
```

```yaml
name: "restart_service - nonexistent service"
tier: 1
tool: sysadmin_restart_service
input:
  service: "nonexistent-service-12345"
expect:
  success: false
  error_contains: "not found"
```

### Tier 2 — Scenario Tests

Multi-step workflows where later steps depend on earlier results. Steps can capture values from tool output and inject them into subsequent steps using `capture` and `$variable` interpolation.

```yaml
name: "Create user then verify group membership"
tier: 2
steps:
  - tool: sysadmin_create_user
    input:
      username: "testuser"
      groups: ["wheel"]
    expect:
      success: true
    capture:
      created_uid: "$.output.uid"

  - tool: sysadmin_get_user_info
    input:
      uid: "$created_uid"
    expect:
      success: true
      output_contains: "wheel"

  - tool: sysadmin_delete_user
    input:
      username: "testuser"
    expect:
      success: true
```

**Variable interpolation:** `capture` extracts values from a step's tool response using JSONPath expressions. Captured variables are available in subsequent steps' `input` fields via `$variable_name` syntax. Variables are scoped to the test — they don't persist across tests.

### Tier 3 — Agent-Driven Tests (Simulated)

PTH simulates agent behavior — either by interpreting a natural language prompt to determine tool calls at runtime, or by following a scripted tool sequence. Both modes are evaluated against a natural language checklist and optional verification commands.

**Prompt-driven mode** — Claude (via PTH) reads the prompt, decides which tools to call and in what order, and executes them. This tests whether the plugin's tool set is sufficient and coherent for real agent workflows:

```yaml
name: "Basic server hardening"
tier: 3
description: |
  Simulate an agent using the sysadmin plugin to apply
  basic security hardening to a fresh server.
prompt: |
  Harden this server: disable SSH root login, enable the firewall
  with default-deny and SSH allowed, and configure automatic updates.
checklist:
  - "SSH root login is disabled"
  - "Firewall is active with default-deny policy"
  - "Automatic updates are configured"
verify:
  - exec: "sshd -T | grep permitrootlogin"
    expect_stdout_contains: "no"
  - exec: "firewall-cmd --get-default-zone || ufw status"
    expect_stdout_contains: "active"
timeout_seconds: 120
```

**Scripted mode** — The tool sequence is specified explicitly. Useful when testing a known workflow where the exact call order matters, or when prompt-driven results need to be reproducible:

```yaml
name: "Basic server hardening (scripted)"
tier: 3
description: |
  Scripted variant — verifies these specific tools work together
  in sequence for server hardening.
tool_sequence:
  - tool: sysadmin_configure_ssh
    input: { permit_root_login: false, password_authentication: false }
  - tool: sysadmin_enable_firewall
    input: { default_policy: "deny", allow: ["ssh"] }
  - tool: sysadmin_configure_auto_updates
    input: { enabled: true }
checklist:
  - "SSH root login is disabled"
  - "Firewall is active with default-deny policy"
  - "Automatic updates are configured"
verify:
  - exec: "sshd -T | grep permitrootlogin"
    expect_stdout_contains: "no"
  - exec: "firewall-cmd --get-default-zone || ufw status"
    expect_stdout_contains: "active"
timeout_seconds: 120
```

A Tier 3 test must have either a `prompt` field or a `tool_sequence` field (not both). Both modes share the same `checklist` and `verify` evaluation.

### Common Fields

All tiers support these optional fields:

```yaml
setup:                    # Commands to run before the test
  - exec: "mkdir -p /test/workspace"
  - file:
      path: "/test/workspace/config.yaml"
      content: "key: value"

teardown:                 # Commands to run after the test
  - exec: "rm -rf /test/workspace"

tags: ["smoke", "ssh"]    # For filtering and organization
requires_tier: 2          # Minimum environment tier needed
generated_from: schema    # Origin: schema | source_analysis | documentation | config | manual
timeout_seconds: 30       # Max wall-clock time for the entire test
```

**`timeout_seconds`** applies to the entire test execution: for Tier 1, the single tool call plus any `verify` commands; for Tier 2, all steps combined; for Tier 3, the full prompt-driven or scripted sequence plus checklist evaluation. If omitted, Claude assigns a default based on the plugin, tier, and test complexity — typically 10s for Tier 1, 30s for Tier 2, and 120s for Tier 3. A test that exceeds its timeout is reported as a "Timeout" failure category (see §5.4).

### Assertion Reference

**Tool response assertions** (used in `expect` blocks):

| Assertion | Type | Description |
|---|---|---|
| `success` | boolean | Whether the tool call should succeed or fail |
| `output_contains` | string | Tool response text includes this substring |
| `output_equals` | string | Tool response text matches exactly |
| `output_matches` | string (regex) | Tool response text matches this regular expression |
| `error_contains` | string | Error message includes this substring |
| `output_json` | object | Tool response, parsed as JSON, deeply equals this structure |
| `output_json_contains` | object | Tool response, parsed as JSON, contains these keys/values (partial match) |

**Environment verification assertions** (used in `verify` blocks):

| Assertion | Type | Description |
|---|---|---|
| `expect_stdout` | string | Command stdout matches exactly |
| `expect_stdout_contains` | string | Command stdout includes this substring |
| `expect_stdout_matches` | string (regex) | Command stdout matches this regular expression |
| `expect_exit_code` | integer | Command exits with this code (default: 0) |

All string comparisons are case-sensitive unless suffixed with `_i` (e.g., `output_contains_i`).

---

## 7. Performance Testing

Performance testing is a distinct phase that runs after the functional iteration loop is complete — after features, functionality, and bugs have been addressed.

### Measured Dimensions

| Dimension | What It Measures | How PTH Collects It |
|---|---|---|
| **Response Time** | Duration of each tool call from invocation to result | Timestamps around MCP JSON-RPC calls |
| **Resource Consumption** | CPU, memory, and disk usage during tool execution | `docker stats` / `virsh domstats` sampled during test runs |
| **Throughput** | Behavior under rapid sequential tool calls | Fire multiple calls in quick succession, measure queuing and latency |
| **Side-Effect Efficiency** | Whether state modifications are done efficiently | Compare expected minimal I/O against actual (e.g., file write counts) |
| **Context Cost** | Token budget consumed by tool descriptions and responses | Measure byte size of `tools/list` output and typical tool responses |

### Assessment Model

PTH does not enforce hard performance thresholds. Instead:

1. PTH re-runs the full functional test suite with performance instrumentation enabled.
2. Claude analyzes the collected metrics and provides a qualitative assessment based on what would be reasonable for a plugin of this type and complexity.
3. Claude identifies outliers — tools that are disproportionately slow, responses that are unusually large, resource consumption that seems excessive.
4. The human reviews Claude's assessment and decides which performance issues are worth addressing.
5. If the human requests performance improvements, PTH enters another iteration loop focused specifically on performance optimization.

### Regression Check

The primary purpose of the performance phase is to verify that the accumulated fixes from the functional iteration didn't introduce performance problems. Claude assesses each tool's performance against its expectations for a plugin of this type and complexity, flagging any tools whose response times, resource usage, or output sizes seem unreasonable. Since no pre-fix performance data is collected (performance testing only runs at the end), this is a qualitative assessment rather than a before/after comparison.

### Operational Characteristics (PTH Itself)

The following are design targets for PTH's own operational performance — not hard thresholds, but expectations that guide implementation tradeoffs. These help implementers make architecture decisions and help users understand PTH's operational envelope.

**Provisioning Time:**

| Tier | Expected Range | Notes |
|---|---|---|
| Tier 1 (Container) | 2–5 seconds | Docker run + bind mount. Dominated by image pull if not cached. |
| Tier 2 (Privileged Container) | 5–15 seconds | Docker run + systemd boot. systemd startup adds latency. |
| Tier 3 (VM) | 30–90 seconds | QEMU boot from qcow2 overlay + virtiofs setup. First boot slower; subsequent boots from snapshots faster. |

Plugin layer setup (npm install, build) adds 10–30 seconds on top of provisioning, depending on dependency count and build complexity.

**Iteration Cycle Time:** A single iteration (run tests → diagnose → apply fix → rebuild → reload → retest) is designed to complete in under 60 seconds for a typical plugin with 50–100 tests on Tier 1/2, assuming incremental rebuilds. The dominant factors are rebuild time (TypeScript: 1–5s, Rust: 10–60s) and test execution time (parallel Tier 1 tests at concurrency 4: ~1s per 20 tests). Tier 3 iterations are slower due to VM overhead.

**Memory Footprint:** PTH's in-memory state includes test definitions, test results (per-iteration history), MCP exchange captures, dependency maps, and convergence tracking. Designed to support sessions with up to 500 tests and 50 iterations within 200–500 MB of PTH process memory. Plugins with significantly larger test suites may benefit from aggressive MCP exchange capture pruning (keeping only the most recent iteration's captures in memory).

**Scalability Bounds:** PTH is designed to support plugins with up to 200 tools and test suites of up to 1,000 tests per session. Git operations remain fast through ~500 commits on a session branch. Beyond these ranges, PTH remains functional but iteration cycle time may degrade. These are not hard limits — they are the design envelope within which PTH is expected to perform well interactively.

---

## 8. Observability

### In-Conversation Reporting

During the iteration loop, PTH reports to the Claude Code conversation at a summary level:

**Per-Iteration Report:**
```
── Iteration 5 ────────────────────────────
Phase: Testing
Tests: 14/18 passing (↑3 from iteration 4)
Failing: create_user (runtime exception), enable_firewall (wrong output),
         get_disk_usage (timeout), configure_ssh (schema violation)
```

```
── Iteration 5 ────────────────────────────
Phase: Fix Applied
File: src/tools/user-management.ts
Change: Fixed undefined reference to `groupAdd` utility function
Risk: Low — single file, 4 lines changed
```

```
── Iteration 5 ────────────────────────────
Phase: Reload
Plugin rebuilt successfully (1.2s)
MCP server restarted — 106 tools detected (no schema changes)
```

**Convergence Summary (periodic):**
```
── Convergence ─────────────────────────────
Iterations: 5
Progress: 8/18 → 11 → 11 → 14 → 14
Status: Possible plateau — same 4 tests failing for 2 iterations
Suggestion: The firewall and SSH failures may share a root cause
            in the privilege handling module.
```

### Detail on Request

At any point, the developer can ask for deeper detail:
- Full stderr/stdout from a specific test
- Complete diff of a specific fix
- Raw MCP JSON-RPC exchange for a specific tool call
- Environment resource usage breakdown
- Build output from the last compilation

### PTH Internal Observability

PTH is itself a complex system that needs debugging and performance monitoring during development and maintenance.

**Debug Log Channel:** PTH supports a debug logging mode enabled via the `PTH_DEBUG` environment variable. When enabled, PTH writes structured logs to stderr (or a file path specified by `PTH_LOG_FILE`) covering its internal operations: Docker/libvirt API calls, git commands with arguments and exit codes, build invocations, MCP client connection lifecycle, and environment provisioning steps. Debug logs are never written to the Claude Code conversation — they are a separate channel for PTH developers. Log levels follow standard conventions (error, warn, info, debug, trace). The default level when `PTH_DEBUG` is set is `debug`; `PTH_DEBUG=trace` includes full MCP JSON-RPC payloads.

**MCP Exchange Capture:** PTH captures the full JSON-RPC request and response for every tool call made to the target plugin. These are stored in memory, indexed by test name and call sequence number. They are available to Claude via the "detail on request" mechanism described above, and are discarded at session end. At trace log level, they are also written to the debug log channel.

**Operation Timing:** PTH tracks wall-clock duration for its own key operations: environment provisioning, base image builds, plugin installs, plugin builds, MCP server startup, hot-reload cycles (rebuild + restart), individual test execution, full test suite runs, and snapshot/rollback operations. These timings are included in the session report (`.pth/SESSION-REPORT.md`) and available via `pth_get_iteration_status`. They help PTH developers identify bottlenecks in the harness itself, separately from performance testing of the target plugin.

PTH does not write permanent log files. Diagnostic detail (test output, build logs, MCP exchanges) exists in memory for the session duration and is discarded at session end. Fix history is preserved in the git commit log on the session branch and survives session end. A structured session report (`.pth/SESSION-REPORT.md`) is generated and committed at session end, providing a complete, human-readable record of the session's progression and outcomes.

---

## 9. Security Considerations

PTH tests plugins that the developer wrote or owns. It is not a sandbox for running untrusted third-party code. The security model reflects this: PTH prioritizes test fidelity and developer productivity over adversarial isolation.

**Host Isolation by Tier:**

| Tier | Isolation Level | Host Exposure |
|---|---|---|
| Tier 1 (Container) | Standard Docker isolation | Bind-mounted worktree only. No privileged access. |
| Tier 2 (Privileged Container) | Reduced — `--privileged` flag grants near-full device access | Bind-mounted worktree. Container shares host kernel and can access host devices. Suitable only for trusted code on a development machine. |
| Tier 3 (VM) | Strong — hardware-level isolation via KVM | Shared filesystem (virtiofs/9p) exposes worktree only. VM has its own kernel. Strongest isolation tier. |

**Bind Mount Scope:** Only the PTH worktree directory is mounted into the test environment. The developer's original checkout, home directory, and other host paths are not exposed. The worktree is a temporary copy on a session branch — damage to it does not affect the developer's working tree.

**Secrets Handling:** Plugin configuration values (including secrets like API keys) are passed via `EnvConfig.configValues` and injected as environment variables inside the test environment. They are:
- Never committed to the session branch or included in git history
- Redacted from session reports (`.pth/SESSION-REPORT.md` replaces values matching known secret keys with `[REDACTED]`)
- Not included in test YAML definitions — tests reference environment variables, not literal secret values
- Held in PTH process memory for the session duration only

Claude prompts the human for secret values interactively rather than reading them from files, unless the human explicitly provides a secrets file path.

**Privileged Container Advisory:** Tier 2 environments use Docker's `--privileged` flag, which significantly weakens container isolation. This is necessary for systemd, service management, and user/group operations. Developers should be aware that bugs in Tier 2 plugin tests can affect the host system. For plugins that need both service management and strong isolation, Tier 3 (VM) is the appropriate choice. Claude factors this tradeoff into its tier recommendation.

---

## 10. MCP Tool Inventory

PTH uses a two-state activation model (see §3.4). Tool names use the `pth_` prefix per MCP naming conventions.

### Dormant State Tools (always available when PTH is installed)

| Tool | Description |
|---|---|
| `pth_start_session` | Initialize a PTH session (create worktree + branch, detect build system, analyze source, recommend environment tier). On success, activates all session tools. |
| `pth_resume_session` | Resume an interrupted session from an existing PTH branch (recreate worktree, reprovision, reload tests). On success, activates all session tools. |
| `pth_preflight` | Pre-session validation: check plugin path, git repo, build system, runtimes, base images, disk space, existing active session lock |

### Session Tools (available only during an active session)

The following tools are registered dynamically after `pth_start_session` or `pth_resume_session` succeeds, and withdrawn after `pth_end_session`.

#### Environment Management

| Tool | Description |
|---|---|
| `pth_provision_environment` | Create a new test environment at the specified tier |
| `pth_inspect_environment` | Get detailed state of the active environment |
| `pth_snapshot_environment` | Save current environment state for rollback |
| `pth_rollback_environment` | Restore environment to a named snapshot |
| `pth_destroy_environment` | Tear down the active environment |
| `pth_reprovision_environment` | Destroy and recreate at a different tier (preserves session branch and worktree) |
| `pth_exec_in_environment` | Run an arbitrary command inside the environment |
| `pth_copy_to_environment` | Copy files from host into the environment |
| `pth_copy_from_environment` | Copy files from the environment to the host |
| `pth_get_environment_logs` | Retrieve recent container/VM logs |
| `pth_rebuild_base_images` | Force rebuild of one or all base images |
| `pth_check_environment_health` | Sample disk, memory, processes, and services between iterations |
| `pth_check_environment_drift` | Compare current environment state against provision-time fingerprint |

#### Plugin Management

| Tool | Description |
|---|---|
| `pth_load_plugin` | Install, build, configure, and start the target plugin |
| `pth_reload_plugin` | Rebuild and restart the target plugin after changes |
| `pth_get_plugin_status` | Check plugin health (loaded, building, errored) |
| `pth_list_plugin_tools` | List all tools exposed by the target plugin |
| `pth_call_plugin_tool` | Invoke a specific tool on the target plugin |
| `pth_get_plugin_config` | View the plugin's resolved configuration |
| `pth_update_plugin_docs` | Generate documentation patches from passing tests and current tool schemas |

#### Testing

| Tool | Description |
|---|---|
| `pth_generate_tests` | Generate test proposals from schema/source/docs analysis |
| `pth_list_tests` | List tests with optional filtering by tag, tier, pass/fail status, or generation source |
| `pth_run_test` | Execute a single test case |
| `pth_run_test_suite` | Execute a collection of tests (supports parallel execution for Tier 1) |
| `pth_get_test_results` | Retrieve results from the most recent test run |
| `pth_get_test_impact` | Show which tests exercise code in specified source files (dependency map) |
| `pth_get_coverage_report` | Report code coverage from the most recent instrumented test run |
| `pth_create_test` | Define a new test case (YAML) |
| `pth_edit_test` | Modify an existing test case |
| `pth_export_ci` | Generate a standalone test runner and CI config (GitHub Actions) from the current test suite |

#### Diagnosis & Fixes

| Tool | Description |
|---|---|
| `pth_diagnose_failure` | Analyze a specific test failure in depth |
| `pth_apply_fix` | Apply a code change and commit to the session branch |
| `pth_get_fix_history` | View git log of all fix commits on the session branch |
| `pth_revert_fix` | Undo a specific fix via git revert |
| `pth_diff_session` | Show cumulative diff between session branch and its origin |

#### Iteration Control

| Tool | Description |
|---|---|
| `pth_run_iteration` | Execute one full cycle: run tests, diagnose all failures, group by root cause, apply fixes (each as a separate commit), reload, and retest |
| `pth_run_iteration_loop` | Run iterations until all tests pass or Claude decides to stop |
| `pth_get_iteration_status` | Current iteration number, pass rates, convergence |
| `pth_verify_cross_distro` | Run the passing test suite against additional base images as a verification phase |
| `pth_end_session` | Persist tests, generate session report, remove worktree, destroy environment, report branch summary |

#### Performance

| Tool | Description |
|---|---|
| `pth_run_performance_suite` | Re-run tests with performance instrumentation |
| `pth_get_performance_report` | Retrieve performance metrics from the instrumented run |

**Total: 45 tools (3 dormant + 42 session) across 7 categories**

---

## 11. Project Structure

```
plugin-test-harness/
├── package.json
├── tsconfig.json
├── README.md
├── DESIGN.md
├── .github/
│   └── workflows/
│       └── ci.yml                      # Lint, typecheck, unit, integration pipeline
│
├── src/
│   ├── index.ts                        # MCP server entry point
│   ├── server.ts                       # Tool registration and dispatch
│   ├── tool-registry.ts                # Dynamic tool activation/deactivation (dormant ↔ active)
│   │
│   ├── environment/
│   │   ├── manager.ts                  # Environment lifecycle orchestration
│   │   ├── types.ts                    # EnvironmentRuntime interface, EnvConfig
│   │   ├── runtime-detect.ts           # Auto-detection of available runtimes
│   │   ├── runtime-docker.ts           # Docker implementation
│   │   ├── runtime-qemu.ts            # QEMU/KVM via libvirt implementation
│   │   ├── base-image-manager.ts       # Base image build, caching, staleness
│   │   ├── health-monitor.ts           # Between-iteration health sampling
│   │   ├── drift-detector.ts           # Provision-time fingerprint and drift comparison
│   │   ├── preflight.ts                # Pre-session validation checks
│   │   └── base-images/
│   │       ├── Dockerfile.ubuntu2404   # Ubuntu 24.04 base
│   │       ├── Dockerfile.fedora       # Fedora base
│   │       ├── vm-ubuntu2404.pkr.hcl   # Packer template for Ubuntu VM
│   │       ├── vm-fedora.pkr.hcl       # Packer template for Fedora VM
│   │       └── provision.sh            # Common provisioning (Node, Python, git, build tools)
│   │
│   ├── plugin/
│   │   ├── loader.ts                   # Plugin install, build, configure
│   │   ├── hot-reload.ts              # Rebuild + restart MCP server
│   │   ├── build-detect.ts            # Convention-based build system detection
│   │   ├── config-resolver.ts         # Read config schema, resolve values
│   │   ├── doc-updater.ts             # Generate documentation patches from test results
│   │   ├── mcp-client.ts             # Lightweight MCP client for tool invocation
│   │   ├── mcp-client-stdio.ts       # stdio transport adapter
│   │   ├── mcp-client-http.ts        # HTTP transport adapter
│   │   └── types.ts                   # Plugin state, tool schemas
│   │
│   ├── testing/
│   │   ├── engine.ts                  # Test orchestration
│   │   ├── generator.ts              # Test proposal generation from schemas/source/docs
│   │   ├── parser.ts                 # YAML test definition parser
│   │   ├── runner.ts                 # Execute individual tests (supports parallel Tier 1)
│   │   ├── assertions.ts            # Assertion evaluation (contains, matches, etc.)
│   │   ├── impact-analyzer.ts       # Source file → test dependency mapping
│   │   ├── coverage.ts              # Coverage instrumentation and reporting
│   │   ├── flakiness.ts             # Flaky test detection via re-runs
│   │   ├── ci-exporter.ts           # Export test suite as standalone CI pipeline
│   │   └── types.ts                  # Test tiers, results, assertions
│   │
│   ├── diagnosis/
│   │   ├── engine.ts                 # Failure analysis and reporting
│   │   ├── context-collector.ts     # Gather error context from environment
│   │   └── types.ts                  # Diagnosis report, failure categories
│   │
│   ├── fix/
│   │   ├── applicator.ts            # Apply code changes and commit to session branch
│   │   ├── tracker.ts               # Query git history for fix patterns and regressions
│   │   └── types.ts                  # Fix record, change types
│   │
│   ├── iteration/
│   │   ├── controller.ts            # Main loop orchestration
│   │   ├── convergence.ts           # Progress tracking and stuck detection
│   │   └── types.ts                  # Iteration state
│   │
│   ├── performance/
│   │   ├── instrumenter.ts          # Wrap tool calls with timing/resource measurement
│   │   ├── metrics.ts               # Metric collection and aggregation
│   │   └── types.ts                  # Performance dimensions, metric types
│   │
│   ├── session/
│   │   ├── manager.ts               # Session lifecycle (start, resume, end, worktree management)
│   │   ├── git-integration.ts       # Worktree, branch, commit, revert, diff operations
│   │   ├── report-generator.ts      # Session report generation (.pth/SESSION-REPORT.md)
│   │   ├── test-persister.ts        # Save/load test suites to/from .pth/tests/
│   │   ├── state-persister.ts       # Write/read .pth/session-state.json each iteration
│   │   └── types.ts                  # Session state
│   │
│   ├── integrations/
│   │   └── superpowers.ts           # Detect and optionally leverage Superpowers
│   │
│   └── shared/
│       ├── errors.ts                # Error types and helpers
│       ├── logger.ts                # Dual-channel: conversation-level reporting + debug log
│       ├── exec.ts                  # Shell execution utilities
│       └── source-analyzer.ts       # Static analysis of plugin source
│
├── test/
│   ├── unit/                        # Unit tests for each module
│   ├── integration/                 # Integration tests against real containers
│   └── fixtures/
│       ├── sample-plugin/           # Minimal MCP plugin for testing PTH itself
│       ├── broken-plugin/           # Intentionally broken plugin for diagnosis tests
│       └── test-scenarios/          # Sample YAML test definitions
│
├── templates/
│   ├── test-tier1.yaml              # Template for Tier 1 test definitions
│   ├── test-tier2.yaml              # Template for Tier 2 test definitions
│   └── test-tier3.yaml              # Template for Tier 3 test definitions
│
└── scripts/
    └── validate-install.sh          # Verify PTH and dependencies are properly installed
```

---

## 12. External Dependencies

### Required on Host

| Dependency | Purpose | Required |
|---|---|---|
| Node.js 20+ | Run PTH MCP server | Yes |
| Docker | Tier 1 and Tier 2 environments | Yes |
| libvirt + QEMU/KVM | Tier 3 VM environments | Only if Tier 3 needed |
| git | Branch management, fix tracking, revert, diff | Yes |

### NPM Dependencies (PTH itself)

| Package | Purpose |
|---|---|
| `@modelcontextprotocol/sdk` | MCP server implementation |
| `zod` | Input schema validation for PTH tools |
| `yaml` | Parse YAML test definitions |
| `execa` | Subprocess management (docker exec, virsh, etc.) |
| `tree-sitter` (optional) | Source code analysis for test generation |
| `nyc` / `c8` (optional) | Code coverage instrumentation for TypeScript plugins |

### Inside Base Images

| Package | Purpose |
|---|---|
| Node.js 20+ | Run TypeScript MCP plugins |
| Python 3.11+ | Run Python MCP plugins |
| git | Common build dependency; may be needed by plugin installs and builds |
| Common build tools | gcc, make, etc. for native dependencies |

---

## 13. Installation & Configuration

### Plugin Registration

PTH is a standard Claude Code plugin distributed as an npm package. Installation follows the standard Claude Code plugin workflow:

```
cd /path/to/plugin-test-harness
npm install
npm run build
claude plugin add /path/to/plugin-test-harness
```

This registers PTH's MCP server with Claude Code. The plugin manifest is defined in `package.json` via the standard `claude` field, which declares the MCP server entry point, supported transports (stdio), and the `pth_` tool namespace.

Alternatively, PTH can be installed from a registry if published:

```
claude plugin add plugin-test-harness
```

After registration, PTH's 3 dormant-state tools (`pth_start_session`, `pth_resume_session`, `pth_preflight`) are available in the Claude Code session. The remaining 42 session tools are registered dynamically when a PTH session is activated (see §3.4).

### Prerequisites

Before first use, verify prerequisites with the included validation script:

```
./scripts/validate-install.sh
```

This checks: Node.js version (20+), Docker availability and daemon status, git version, and optionally libvirt/QEMU for Tier 3 support. It reports pass/fail for each prerequisite with actionable instructions for any failures.

`pth_preflight` performs the same checks programmatically at the start of each session, so manual validation is only needed for initial setup troubleshooting.

### Configuration

PTH has minimal configuration. It does not require a config file for standard operation. Optional settings are controlled via environment variables:

| Variable | Default | Purpose |
|---|---|---|
| `PTH_DEBUG` | unset | Enable debug logging. Values: `debug`, `trace` (includes MCP payloads) |
| `PTH_LOG_FILE` | stderr | File path for debug log output |
| `PTH_WORKTREE_DIR` | `/tmp` | Parent directory for PTH worktrees |
| `PTH_BASE_IMAGE_DIR` | `~/.pth/images` | Storage location for cached base images |

All other configuration is per-session and resolved interactively: environment tier, base image selection, plugin config values, and test generation scope are all determined by Claude in conversation with the developer during `pth_start_session`.

### Updates

PTH follows standard npm update conventions. For local installations, `git pull && npm install && npm run build` followed by restarting Claude Code picks up new versions. For registry installations, `claude plugin update plugin-test-harness` or the equivalent npm update workflow applies. PTH does not auto-update or check for new versions.

---

## 14. Testing PTH

PTH is a complex system that manages containers, VMs, git operations, MCP connections, and multi-phase iteration loops. Its own test suite must verify these subsystems work correctly both in isolation and in combination.

### Unit Tests

One test file per source module, located in `test/unit/` mirroring the `src/` directory structure. Unit tests cover each module's public API, error handling paths, and edge cases. External dependencies (Docker, git, MCP servers) are mocked at module boundaries.

Key unit test areas:
- **YAML test parser** — Validates all three tier formats, variable interpolation, assertion types, common fields including `timeout_seconds` and `generated_from`
- **Assertion evaluator** — Every assertion type (contains, equals, matches, json, exit code) with passing, failing, and edge cases
- **Build system detection** — Correct detection for each file convention, fallback behavior when no convention matches
- **Config resolver** — Schema reading, default generation, secret prompting
- **Git integration** — Branch creation, commit with trailers, revert, worktree lifecycle, trailer parsing
- **Session state persister** — Write/read cycle, graceful handling of corrupted files
- **Impact analyzer** — Dependency map construction and query
- **CI exporter** — Generated runner script validity

### Integration Tests

Integration tests run against real Docker containers using the test fixtures. Located in `test/integration/`.

**Test Fixtures:**

`sample-plugin/` — A minimal but complete MCP plugin with 5–10 tools covering common patterns: stateless tools (echo, transform), stateful tools (counter, key-value store), tools with side effects (file creation, service management), and a tool that returns errors on specific inputs. Written in TypeScript with a standard `package.json` build. Provides a predictable, well-understood target for PTH's test generation, execution, diagnosis, and fix workflows.

`broken-plugin/` — A deliberately flawed variant of sample-plugin with known bugs: a tool that throws unhandled exceptions, a tool with a schema mismatch (declared output doesn't match actual), a missing dependency import, and a tool that times out. Used to verify PTH's diagnostic engine correctly categorizes each failure type and that the fix applicator can resolve them.

**Integration Test Scope:**

- **Environment lifecycle** — Provision Tier 1 container, execute commands, copy files, snapshot, rollback, destroy
- **Plugin loading** — Install, build, start, introspect, hot-reload against sample-plugin
- **Test generation and execution** — Generate tests from sample-plugin schemas, run them, verify results
- **Diagnosis and fix cycle** — Load broken-plugin, run tests, verify diagnosis categories match expected failures
- **Session lifecycle** — Start session, apply fixes, persist tests, end session, resume session, verify state continuity
- **Parallel execution** — Run Tier 1 tests with concurrency > 1 against sample-plugin

Tier 2 integration tests (privileged containers with systemd) run when Docker supports `--privileged` in the CI environment. Tier 3 integration tests (VMs) are skipped in CI by default — they require KVM and are run manually or in a dedicated environment with nested virtualization.

### CI Pipeline

PTH uses GitHub Actions. The CI workflow runs on every push and PR:

```
├── Lint (ESLint)
├── Type Check (tsc --noEmit, strict mode)
├── Unit Tests (all, no Docker required)
├── Integration Tests — Tier 1 (Docker required, provided by GitHub Actions runner)
├── Integration Tests — Tier 2 (Docker --privileged, conditional on runner support)
└── Integration Tests — Tier 3 (skipped in CI, requires KVM)
```

A `.github/workflows/ci.yml` file is included in the project structure. PRs are blocked on lint, type check, and unit test passes. Integration test failures on Tier 1 also block PRs. Tier 2 failures are advisory.

### Quality Gates

- **TypeScript strict mode** — `tsconfig.json` has `strict: true`; no `any` types without explicit justification
- **ESLint** — Enforced on all source files; no warnings permitted in CI
- **Test coverage** — Unit test coverage reported but not gated; integration test pass rate is the primary quality signal
- **No test regressions** — PR CI fails if any previously passing test starts failing

---

## 15. Key Workflows

### 15.1 Starting a Session

```
Developer: "Test my linux-admin-mcp plugin at /home/dev/linux-admin-mcp"

PTH:
  1. pth_start_session({ pluginPath: "/home/dev/linux-admin-mcp" })
     - Creates session branch and worktree at /tmp/pth-worktree-a1b2c3/
     - Detects build system: package.json found → npm
     - Reads config schema: no required secrets found
     - Analyzes source: systemd, firewall, kernel refs detected
     - Recommends: Tier 3 (full VM) on Ubuntu 24.04
     - Activates full tool set (42 session tools now available)

  2. Claude presents the recommendation:
     Claude: "This plugin references kernel parameters and firewall
              rules. I recommend a Tier 3 VM environment on Ubuntu 24.04.
              Does that work?"

  3. Developer confirms

  4. pth_provision_environment({ tier: 3, baseImage: "pth-base-ubuntu2404" })
     - Checks base image: built 3 days ago, Claude judges it fresh enough
     - Provisions VM with qcow2 overlay
     - Shares PTH worktree via virtiofs

  5. pth_load_plugin()
     - npm install (12s)
     - npm run build (3s)
     - Starts MCP server
     - Introspects: 106 tools detected

  6. pth_generate_tests()
     - Generates 45 Tier 1 tests from tool schemas
     - Generates 8 Tier 2 scenarios from README examples
     - Generates 3 Tier 3 simulated agent workflows
     - Claude runs Tier 1 tests directly, presents Tier 2/3 for review
```

### 15.2 Iteration Loop

```
Iteration 1:
  - 31/45 Tier 1 tests pass, 14 fail
  - Claude diagnoses: 6 failures share a root cause (incorrect path
    handling on the distro), 4 are missing error handling, 4 are
    schema mismatches
  - Claude applies 3 fixes (path handling, two error handlers)
  - Reloads plugin (rebuild 3s, restart 1s)

Iteration 2:
  - 38/45 passing (↑7)
  - Claude applies 4 more fixes
  - Reloads

Iteration 3:
  - 43/45 passing (↑5)
  - Remaining 2 failures are in firewall management tools
  - Claude diagnoses: these tools assume iptables but the test VM has nftables
  - Claude: "These failures require adding nftables support alongside iptables.
    This is an architectural change affecting 3 files. I'll use Superpowers
    to plan and implement this."
  - [Superpowers brainstorm → plan → implement cycle]
  - Reloads

Iteration 4:
  - 45/45 passing
  - Claude: "All Tier 1 tests passing. Running Tier 2 scenarios now."

... (Tier 2 and 3 testing continues similarly)

Cross-Distro Verification (if targeting multiple distros):
  - All tests passing on Ubuntu 24.04
  - pth_verify_cross_distro({ baseImages: ["pth-base-fedora"] })
  - Reprovisions on Fedora, re-runs full suite
  - 54/56 passing — 2 failures are Fedora-specific (different
    default firewall backend)
  - Claude applies 1 distro-conditional fix (PTH-Distro: fedora)
  - 56/56 passing on Fedora
  - Re-verification: reprovisions on Ubuntu 24.04, re-runs full suite
  - 56/56 passing — Fedora fix did not regress Ubuntu
  - Claude: "All tests passing on both Ubuntu 24.04 and Fedora."
```

### 15.3 Human Alteration Mid-Session

```
Developer: "Actually, I want the firewall tools to also support
            reporting which rules are active, not just setting them."

PTH:
  - Interprets this as a feature addition, not a bug fix
  - Adds new tool handler in the plugin source
  - Updates the MCP tool registration
  - Generates new Tier 1 tests for the new capability
  - Reloads and tests
```

### 15.4 Session End

```
Developer: "That looks good, let's wrap up."

PTH:
  1. pth_end_session()
     - Session branch: pth/linux-admin-mcp-2026-02-18-f7e3a9
     - 23 fix commits, 14 files changed, +312 lines, -87 lines
     - Persists 56 tests to .pth/tests/
     - Generates .pth/SESSION-REPORT.md
     - Updates README with corrected tool descriptions
     - Removes PTH worktree
     - Destroys VM
     - Deactivates session tools (returns to dormant state — 3 tools only)
     - Claude: "Session complete. All changes are on branch
       pth/linux-admin-mcp-2026-02-18-f7e3a9 with 23 commits across
       12 iterations. Test suite saved for future sessions.
       You can review the session report, commit history, merge,
       cherry-pick individual fixes, or delete the branch."
```

### 15.5 Resuming an Interrupted Session

```
Developer: "Resume PTH session on branch pth/linux-admin-mcp-2026-02-18-f7e3a9"

PTH:
  1. pth_resume_session({ branch: "pth/linux-admin-mcp-2026-02-18-f7e3a9" })
     - Creates new worktree for existing branch
     - Reads .pth/session-state.json:
       Last iteration: #8, 39/42 passing, trend: improving
     - Reads commit history via git trailers:
       17 fix commits across 8 iterations
     - Loads 42 persisted tests from .pth/tests/
     - Detects 3 new tools added since tests were generated
     - Activates full tool set (42 session tools now available)

  2. Claude presents session context:
     Claude: "Resuming session from iteration 8. Last run: 39/42 passing,
              trend was improving. 3 tests were still failing (firewall
              rule enumeration). I also see 3 new tools that don't have
              tests yet. I'll reprovision a Tier 3 VM and pick up where
              we left off."

  3. pth_provision_environment({ tier: 3, baseImage: "pth-base-ubuntu2404" })
     - Provisions fresh VM
     - Shares PTH worktree via virtiofs

  4. pth_load_plugin()
     - Rebuilds from current branch state
     - Starts MCP server — 109 tools detected (3 new)

  5. pth_generate_tests()
     - Generates 6 new Tier 1 tests for the 3 new tools
     - Resumes iteration loop from iteration 9
```

---

## 16. Decision Log

Design decisions from the collaborative design process and document drafting, for future reference.

| # | Decision | Choice | Rationale |
|---|---|---|---|
| 1 | Primary consumer | Human developer using Claude Code | Interactive workflow, human judgment available |
| 2 | Environment realism | Full OS-level | Plugins may need kernel, hardware, real init |
| 3 | Alteration scope | Source + config + runtime + architectural | Maximum flexibility for iterative refinement |
| 4 | Environment strategy | Tiered (container → privileged → VM) | Balance speed vs. realism per plugin needs |
| 5 | VM technology | QEMU/KVM via libvirt | Standard, well-supported, good snapshot support |
| 6 | Base image model | Base + overlay with golden images | Fast provisioning, manageable maintenance |
| 7 | Initial distros | Ubuntu 24.04 LTS, Fedora latest | Cover Debian and RHEL families |
| 8 | Base image rebuild | On-demand, Claude-assessed staleness | Zero-maintenance, no arbitrary thresholds |
| 9 | Test generation input | All signals (schemas, source, docs, config) | Maximum test coverage from available information |
| 10 | Test approval | Claude decides when to ask vs. run directly | Flexible, avoids unnecessary gates |
| 11 | Test format | Three-tier YAML hybrid | Right expressiveness at each complexity level |
| 12 | Fix approval | Claude judges risk contextually | No rigid rules, adapts to each situation |
| 13 | Fix presentation | Summary + diff on request | Clean conversation, detail available |
| 14 | Safety model | Claude's judgment, no mechanical enforcement | Flexibility across diverse plugin types |
| 15 | PTH location | Host machine, exec into containers | Simple, safe, direct access to source files |
| 16 | Source management | Git worktree on session branch, mounted into environment | Full version control, developer's checkout untouched |
| 17 | Session end | Branch remains with full artifact set for developer review | Clean handoff: fix history, persisted tests, session report, documentation patches |
| 18 | Tool invocation | Native MCP client with transport adapters | Protocol-correct, works with any MCP plugin |
| 19 | MCP server lifecycle | Claude decides per-plugin | Stateful plugins need isolation, stateless don't |
| 20 | Reload scope | Claude decides per-fix | Match reload cost to change impact |
| 21 | Test re-run scope | Claude decides per-fix | Targeted re-runs for small fixes, full suite for big ones |
| 22 | Build system discovery | Convention-based, human fallback | Works for most plugins, graceful degradation |
| 23 | Plugin configuration | Schema-read + Claude defaults + human for secrets | Minimal human burden, accurate config |
| 24 | Service dependencies | Source analysis + auto-provision | Reduces manual setup |
| 25 | Architectural changes | Superpowers if available, Claude judgment otherwise | Best tool for complex restructuring |
| 26 | Human alteration UX | Natural language description → PTH implements | Low friction, leverages Claude's interpretation |
| 27 | Observability | Summary in chat, detail on request | Clean conversation without log noise |
| 28 | Implementation language | TypeScript with MCP SDK | Consistent with existing plugin ecosystem |
| 29 | Session scope | One plugin, one environment at a time | Simple, focused. Reprovisioning available if tier needs to change |
| 30 | Session persistence | Ephemeral (raw diagnostic detail), persistent (fix history, test suite, session state, session report, doc patches — all on branch) | Clean starts, but complete session artifacts survive for review and resume |
| 31 | Error recovery | Claude chooses appropriate response | Severity-matched recovery |
| 32 | Performance dimensions | Response time, resources, throughput, side-effect efficiency, context cost | Comprehensive but practical coverage |
| 33 | Performance thresholds | Claude's qualitative assessment | No arbitrary numbers, context-appropriate |
| 34 | Performance timing | Final validation pass after functional iteration | Don't optimize what isn't working yet |
| 35 | Privileged operations | Claude's judgment | Flexibility for plugins that legitimately need elevation |
| 36 | Design philosophy | Claude's judgment by default, no mechanical enforcement | Consistent principle across all decisions |
| 37 | Cross-distro testing | Verification phase after primary iteration loop | Fast inner loop, cross-platform validation before completion |
| 38 | Test persistence | Export to .pth/tests/ on session branch | Flywheel: each session builds on previous test suites |
| 39 | Session resume | Reconstruct from session-state.json, git history, and persisted tests | Full context on resume: convergence trend, per-test status, and fix narrative |
| 40 | Snapshot-gated fixes | Environment snapshot before risky fixes | Coordinated rollback of code and environment state |
| 41 | Test impact analysis | Source-to-test dependency map | Targeted re-runs instead of full suite after each fix |
| 42 | Session report | .pth/SESSION-REPORT.md auto-generated | Reviewable artifact for PRs and team discussions |
| 43 | Dependent plugins | Loaded as untested infrastructure | Support plugin-to-plugin dependencies without testing both |
| 44 | Preflight validation | pth_preflight before session start | Catch blocking issues before provisioning |
| 45 | Code coverage | Istanbul/coverage.py instrumentation | Guide test generation toward uncovered code paths |
| 46 | Structured commits | Git trailers in fix commit messages | Machine-readable history for querying, reporting, and resume |
| 47 | Environment health | Between-iteration health sampling | Prevent phantom failures from environment degradation |
| 48 | Flakiness detection | Automatic re-runs before diagnosis | Distinguish real bugs from timing/concurrency issues |
| 49 | CI export | Standalone test runner and GitHub Actions config | Plugin goes from untested to CI-enabled in one session |
| 50 | Parallel testing | Multiple MCP server instances for Tier 1 | Faster iteration cycles for large test suites |
| 51 | Test source tracking | generated_from metadata on every test | Smarter diagnosis based on test origin trust level |
| 52 | Documentation patches | Auto-update README from passing tests | Provably correct docs as a session side-effect |
| 53 | Environment drift | Fingerprint comparison against provision state | Catch false-pass scenarios from accumulated state |
| 54 | Security model | Trust-based with per-tier isolation guidance and secrets redaction | PTH tests developer-owned code; security prioritizes fidelity over adversarial isolation |
| 55 | Error handling | Catalog of failure modes with recovery menus; Claude selects recovery path | Enumerates infrastructure failures without prescribing rigid responses; consistent with P1 |
| 56 | Installation | Standard Claude Code plugin registration; env vars for optional config | Minimal configuration, standard workflow, no PTH-specific setup ceremony |
| 57 | PTH testing strategy | Unit + integration tiers; sample-plugin and broken-plugin fixtures; GitHub Actions CI | PTH is complex enough to need its own structured test suite; Tier 3 integration excluded from CI due to KVM requirement |
| 58 | Operational characteristics | Design targets for provisioning, iteration cycle, memory, scalability — not hard thresholds | Guides implementation tradeoffs and sets user expectations without violating P1 |
| 59 | Activation model | Two-state dormant/active; 3 tools when idle, 42 tools during session; dynamic via notifications/tools/list_changed | Keeps tool namespace clean during normal development; requires explicit opt-in to initiate PTH |
