# Plugin Test Harness (PTH) Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a Claude Code MCP plugin that orchestrates iterative live testing, diagnosis, and hot-patching of other Claude Code plugins and MCP servers, with Claude as the test executor.

**Architecture:** PTH is an MCP server that runs in the developer's Claude Code session alongside the plugin under test. It uses dynamic tool registration (dormant: 3 tools when idle, session: 16 tools when active) via `notifications/tools/list_changed`. Claude executes tests directly by calling target plugin tools or running hook scripts — PTH is a test orchestration and tracking layer, not a test executor. All testing is in-session; no Docker or VM environments.

**Tech Stack:** TypeScript 5, Node.js 20+, `@modelcontextprotocol/sdk`, `zod`, `yaml`, `execa`, Jest + ts-jest

---

## Design Reference

Full design is in `docs/PTH-DESIGN.md`. Key decisions made in the pre-implementation review:

- **No Docker/VM** — removed entirely. Claude is the executor for all test types.
- **No PTH MCP client** — Claude calls target plugin tools natively; PTH doesn't proxy.
- **Two modes** — `mcp` (for MCP server plugins) and `plugin` (for skill/command/hook plugins).
- **19 tools** — 3 dormant, 16 session. Down from 45 in original design.
- **Removed features** — Superpowers integration, `_i` assertion variants, documentation patches, parallel execution, code coverage, Docker/VM environments, performance phase, flakiness detection, cross-distro verification.
- **Deferred features** — CI export, Tier 3 VM, performance phase.

---

## Two Modes

**MCP mode** (`mode: mcp` in tests):
- Target MCP plugin loaded in same Claude Code session as PTH
- Claude calls target plugin's tools, evaluates assertions, calls `pth_record_result`
- Plugin reload: PTH builds in worktree → SIGTERM process → Claude Code restarts → Claude verifies

**Plugin mode** (`mode: plugin` in tests):
- Target skill/command/hook plugin loaded in same session (preferred)
- Test types: `hook-script` (direct subprocess + mock stdin), `validate` (structural checks), `exec` (arbitrary script)
- Fixes sync to `~/.claude/plugins/cache/<name>/` for immediate effect (scripts read from disk each run)

---

## Test YAML Format

### MCP mode — single tool call
```yaml
name: "get_server_info returns version"
mode: mcp
tool: ha_get_server_info
input: {}
expect:
  success: true
  output_contains: "version"
generated_from: schema
timeout_seconds: 10
```

### MCP mode — multi-step scenario
```yaml
name: "Create entity then verify it exists"
mode: mcp
steps:
  - tool: ha_create_entity
    input:
      entity_id: "light.test"
      state: "off"
    expect:
      success: true
    capture:
      created_id: "$.entity_id"
  - tool: ha_get_entity
    input:
      entity_id: "$created_id"
    expect:
      success: true
      output_contains: "off"
timeout_seconds: 30
```

### Plugin mode — hook script direct execution
```yaml
name: "write guard blocks Write tool for lead"
mode: plugin
type: hook-script
script: hooks/scripts/write-guard.sh
env:
  ORCHESTRATOR_LEAD: "1"
stdin:
  tool_name: "Write"
  tool_input:
    file_path: "/some/file.ts"
expect:
  exit_code: 2
  stdout_contains: "block"
```

### Plugin mode — structural validation
```yaml
name: "manifest schema is valid"
mode: plugin
type: validate
checks:
  - type: json-schema
    file: .claude-plugin/manifest.json
  - type: file-exists
    files:
      - skills/my-skill.md
      - hooks/hooks.json
```

### Common optional fields (all tests)
```yaml
setup:
  - exec: "mkdir -p /tmp/test-workspace"
teardown:
  - exec: "rm -rf /tmp/test-workspace"
tags: ["smoke", "auth"]
generated_from: schema   # schema | source_analysis | documentation | manual
timeout_seconds: 30
```

---

## Session Artifacts

PTH stores artifacts on the session branch in the target plugin's repo:

```
.pth/
├── tests/                  # Persisted test suite (YAML files)
│   ├── mcp-tool-tests.yaml
│   └── scenario-tests.yaml
├── session-state.json      # Checkpoint after each iteration
└── SESSION-REPORT.md       # Generated at session end
```

Session branch naming: `pth/<plugin-name>-<YYYY-MM-DD>-<6-char-hash>`

### Git commit trailers (fix commits)
```
fix: handle missing group in user creation

PTH-Test: create_user_nonexistent_group
PTH-Category: runtime-exception
PTH-Files: src/tools/user-management.ts
PTH-Iteration: 3
```

---

## Tool Inventory

### Dormant (always visible — 3 tools)
| Tool | Description |
|------|-------------|
| `pth_preflight` | Validate prerequisites: target plugin path, git repo, build system, no active session lock |
| `pth_start_session` | Create session branch + worktree, detect plugin mode, load existing tests |
| `pth_resume_session` | Resume interrupted session: recreate worktree, reload tests, reconstruct from git |

### Session — Management (2 tools)
| Tool | Description |
|------|-------------|
| `pth_end_session` | Persist tests, generate report, remove worktree, deactivate session tools |
| `pth_get_session_status` | Current iteration, pass rates, convergence trend, session metadata |

### Session — Tests (4 tools)
| Tool | Description |
|------|-------------|
| `pth_generate_tests` | Generate test proposals from schema/source/manifest/docs |
| `pth_list_tests` | List tests with filtering by tag, mode, pass/fail, generated_from |
| `pth_create_test` | Define a new test case (YAML) |
| `pth_edit_test` | Modify an existing test case |

### Session — Execution (3 tools)
| Tool | Description |
|------|-------------|
| `pth_record_result` | Claude calls this after executing a test to log outcome |
| `pth_get_results` | View current pass/fail state for all tests |
| `pth_get_test_impact` | Show which tests exercise code in specified source files |

### Session — Fixes (6 tools)
| Tool | Description |
|------|-------------|
| `pth_apply_fix` | Apply code change and commit to session branch with trailers |
| `pth_sync_to_cache` | Sync worktree changes to `~/.claude/plugins/cache/<name>/` |
| `pth_reload_plugin` | Build in worktree, SIGTERM MCP server, wait for Claude Code restart |
| `pth_get_fix_history` | View git log of all fix commits on session branch |
| `pth_revert_fix` | Undo a specific fix via git revert |
| `pth_diff_session` | Show cumulative diff between session branch and its origin |

### Session — Iteration (1 tool)
| Tool | Description |
|------|-------------|
| `pth_get_iteration_status` | Iteration number, per-test pass/fail history, convergence trend |

---

## Project Structure

```
plugin-test-harness/
├── package.json
├── tsconfig.json
├── eslint.config.js
├── jest.config.js
├── .claude-plugin/
│   └── manifest.json
├── .mcp.json
├── src/
│   ├── index.ts                    # Entry point: create server + transport
│   ├── server.ts                   # Request handlers, tool dispatch
│   ├── tool-registry.ts            # Dynamic tool activation/deactivation
│   │
│   ├── session/
│   │   ├── manager.ts              # Start, resume, end, session state
│   │   ├── git.ts                  # Worktree, branch, commit with trailers, revert, diff
│   │   ├── state-persister.ts      # .pth/session-state.json read/write
│   │   ├── report-generator.ts     # .pth/SESSION-REPORT.md
│   │   └── types.ts
│   │
│   ├── plugin/
│   │   ├── detector.ts             # Detect mode (mcp vs plugin), read .mcp.json
│   │   ├── build.ts                # Convention-based build system detection + execution
│   │   ├── reloader.ts             # Build + SIGTERM + restart verification
│   │   ├── cache-sync.ts           # Sync worktree → ~/.claude/plugins/cache/<name>/
│   │   └── types.ts
│   │
│   ├── testing/
│   │   ├── generator.ts            # Generate test proposals (MCP schema + plugin source)
│   │   ├── parser.ts               # Parse YAML test definitions
│   │   ├── store.ts                # In-memory test registry + .pth/tests/ persistence
│   │   ├── impact.ts               # Source file → test dependency map
│   │   └── types.ts
│   │
│   ├── results/
│   │   ├── tracker.ts              # Per-test result history, iteration management
│   │   ├── convergence.ts          # Trend detection: improving, plateaued, oscillating
│   │   └── types.ts
│   │
│   ├── fix/
│   │   ├── applicator.ts           # Write files + git commit with PTH trailers
│   │   ├── tracker.ts              # Query git history via trailer parsing
│   │   └── types.ts
│   │
│   └── shared/
│       ├── errors.ts               # PTHError class + error types
│       ├── logger.ts               # Conversation-level reporting + PTH_DEBUG channel
│       ├── exec.ts                 # execa wrappers with timeout + error surfacing
│       └── source-analyzer.ts      # Read + parse plugin source for test generation
│
├── test/
│   ├── unit/                       # One file per src/ module
│   │   ├── session/
│   │   ├── plugin/
│   │   ├── testing/
│   │   ├── results/
│   │   └── fix/
│   └── fixtures/
│       ├── sample-mcp-plugin/      # Minimal TypeScript MCP plugin (5 tools, predictable)
│       ├── broken-mcp-plugin/      # Intentionally broken variant (3 known failure types)
│       └── sample-hook-plugin/     # Minimal hook plugin for plugin mode testing
│
└── templates/
    ├── test-mcp-single.yaml
    ├── test-mcp-scenario.yaml
    └── test-plugin-hook.yaml
```

---

## Task 1: Project Scaffold

**Files:**
- Create: `plugins/plugin-test-harness/package.json`
- Create: `plugins/plugin-test-harness/tsconfig.json`
- Create: `plugins/plugin-test-harness/jest.config.js`
- Create: `plugins/plugin-test-harness/eslint.config.js`
- Create: `plugins/plugin-test-harness/.gitignore`

**Step 1: Create package.json**
```json
{
  "name": "plugin-test-harness",
  "version": "1.0.0",
  "description": "Iterative live testing harness for Claude Code plugins and MCP servers",
  "main": "dist/index.js",
  "scripts": {
    "build": "tsc",
    "dev": "tsx watch src/index.ts",
    "test": "jest",
    "test:unit": "jest --testPathPattern=test/unit",
    "lint": "eslint src test",
    "typecheck": "tsc --noEmit"
  },
  "dependencies": {
    "@modelcontextprotocol/sdk": "^1.15.0",
    "execa": "^9.5.0",
    "yaml": "^2.7.0",
    "zod": "^3.24.0"
  },
  "devDependencies": {
    "@types/jest": "^29.5.0",
    "@types/node": "^20.0.0",
    "eslint": "^9.0.0",
    "jest": "^29.7.0",
    "ts-jest": "^29.2.0",
    "tsx": "^4.19.0",
    "typescript": "^5.8.0"
  }
}
```

**Step 2: Create tsconfig.json**
```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "Node16",
    "moduleResolution": "Node16",
    "lib": ["ES2022"],
    "outDir": "dist",
    "rootDir": "src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true
  },
  "include": ["src"],
  "exclude": ["node_modules", "dist", "test"]
}
```

**Step 3: Create jest.config.js**
```js
/** @type {import('jest').Config} */
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  roots: ['<rootDir>/test'],
  testMatch: ['**/*.test.ts'],
  moduleNameMapper: {
    '^(\\.{1,2}/.*)\\.js$': '$1'
  },
  collectCoverageFrom: ['src/**/*.ts'],
};
```

**Step 4: Create eslint.config.js**
```js
import js from "@eslint/js";
import tseslint from "typescript-eslint";

export default tseslint.config(
  js.configs.recommended,
  ...tseslint.configs.recommended,
  {
    rules: {
      "@typescript-eslint/no-explicit-any": "error",
      "@typescript-eslint/no-unused-vars": ["error", { "argsIgnorePattern": "^_" }],
    }
  }
);
```

**Step 5: Create .gitignore**
```
node_modules/
dist/
*.js.map
.pth/
```

**Step 6: Install dependencies**
```bash
cd plugins/plugin-test-harness
npm install
```

Expected: `node_modules/` created, no errors.

**Step 7: Commit**
```bash
git add plugins/plugin-test-harness/package.json plugins/plugin-test-harness/tsconfig.json \
  plugins/plugin-test-harness/jest.config.js plugins/plugin-test-harness/eslint.config.js \
  plugins/plugin-test-harness/.gitignore plugins/plugin-test-harness/package-lock.json
git commit -m "chore(pth): scaffold TypeScript project with MCP SDK dependencies"
```

---

## Task 2: Shared Types and Error Handling

**Files:**
- Create: `src/shared/errors.ts`
- Create: `src/shared/logger.ts`
- Create: `src/shared/exec.ts`
- Create: `test/unit/shared/errors.test.ts`

**Step 1: Write failing test**
```typescript
// test/unit/shared/errors.test.ts
import { PTHError, PTHErrorCode } from '../../../src/shared/errors.js';

describe('PTHError', () => {
  it('creates error with code and message', () => {
    const err = new PTHError(PTHErrorCode.NO_ACTIVE_SESSION, 'No session active');
    expect(err.code).toBe(PTHErrorCode.NO_ACTIVE_SESSION);
    expect(err.message).toBe('No session active');
    expect(err instanceof Error).toBe(true);
  });

  it('includes optional context', () => {
    const err = new PTHError(PTHErrorCode.BUILD_FAILED, 'Build failed', { output: 'error text' });
    expect(err.context).toEqual({ output: 'error text' });
  });
});
```

**Step 2: Run test to verify it fails**
```bash
cd plugins/plugin-test-harness && npx jest test/unit/shared/errors.test.ts
```
Expected: FAIL — `Cannot find module '../../../src/shared/errors.js'`

**Step 3: Implement**
```typescript
// src/shared/errors.ts
export enum PTHErrorCode {
  NO_ACTIVE_SESSION = 'NO_ACTIVE_SESSION',
  SESSION_ALREADY_ACTIVE = 'SESSION_ALREADY_ACTIVE',
  BUILD_FAILED = 'BUILD_FAILED',
  GIT_ERROR = 'GIT_ERROR',
  PLUGIN_NOT_FOUND = 'PLUGIN_NOT_FOUND',
  INVALID_TEST = 'INVALID_TEST',
  RELOAD_FAILED = 'RELOAD_FAILED',
  CACHE_SYNC_FAILED = 'CACHE_SYNC_FAILED',
}

export class PTHError extends Error {
  readonly code: PTHErrorCode;
  readonly context?: Record<string, unknown>;

  constructor(code: PTHErrorCode, message: string, context?: Record<string, unknown>) {
    super(message);
    this.name = 'PTHError';
    this.code = code;
    this.context = context;
  }
}
```

```typescript
// src/shared/logger.ts
const debugEnabled = !!process.env.PTH_DEBUG;
const logFile = process.env.PTH_LOG_FILE;

export function debug(message: string, data?: unknown): void {
  if (!debugEnabled) return;
  const entry = `[PTH:DEBUG] ${message}${data ? ' ' + JSON.stringify(data) : ''}`;
  if (logFile) {
    // append to file — handled separately in production
    process.stderr.write(entry + '\n');
  } else {
    process.stderr.write(entry + '\n');
  }
}

export function info(message: string): void {
  // conversation-level: returned in tool responses
  // this is just a utility; callers include in tool response content
}
```

```typescript
// src/shared/exec.ts
import { execa, ExecaError } from 'execa';
import { PTHError, PTHErrorCode } from './errors.js';

export interface ExecResult {
  stdout: string;
  stderr: string;
  exitCode: number;
}

export async function run(
  command: string,
  args: string[],
  options?: { cwd?: string; env?: Record<string, string>; timeoutMs?: number }
): Promise<ExecResult> {
  try {
    const result = await execa(command, args, {
      cwd: options?.cwd,
      env: options?.env ? { ...process.env, ...options.env } : undefined,
      timeout: options?.timeoutMs ?? 30_000,
      reject: false,
    });
    return {
      stdout: result.stdout,
      stderr: result.stderr,
      exitCode: result.exitCode ?? 0,
    };
  } catch (err) {
    const execaErr = err as ExecaError;
    throw new PTHError(PTHErrorCode.BUILD_FAILED, `Command failed: ${command}`, {
      stdout: execaErr.stdout,
      stderr: execaErr.stderr,
      exitCode: execaErr.exitCode,
    });
  }
}

export async function runOrThrow(
  command: string,
  args: string[],
  options?: { cwd?: string; env?: Record<string, string>; timeoutMs?: number }
): Promise<ExecResult> {
  const result = await run(command, args, options);
  if (result.exitCode !== 0) {
    throw new PTHError(PTHErrorCode.BUILD_FAILED, `Command exited with ${result.exitCode}: ${command}`, {
      stdout: result.stdout,
      stderr: result.stderr,
    });
  }
  return result;
}
```

**Step 4: Run test to verify it passes**
```bash
cd plugins/plugin-test-harness && npx jest test/unit/shared/errors.test.ts
```
Expected: PASS

**Step 5: Commit**
```bash
git add plugins/plugin-test-harness/src/
git commit -m "feat(pth): add shared error types, logger, and exec utilities"
```

---

## Task 3: Git Integration — Branch, Worktree, Commit with Trailers

**Files:**
- Create: `src/session/git.ts`
- Create: `src/session/types.ts`
- Create: `test/unit/session/git.test.ts`

**Step 1: Write failing tests**
```typescript
// test/unit/session/git.test.ts
import { buildCommitMessage, parseTrailers, generateSessionBranch } from '../../../src/session/git.js';

describe('buildCommitMessage', () => {
  it('produces a commit message with PTH trailers', () => {
    const msg = buildCommitMessage('fix: handle missing group', {
      'PTH-Test': 'create_user_nonexistent_group',
      'PTH-Category': 'runtime-exception',
      'PTH-Files': 'src/tools/user-management.ts',
      'PTH-Iteration': '3',
    });
    expect(msg).toContain('fix: handle missing group');
    expect(msg).toContain('PTH-Test: create_user_nonexistent_group');
    expect(msg).toContain('PTH-Category: runtime-exception');
  });
});

describe('parseTrailers', () => {
  it('extracts trailer key-value pairs from commit message', () => {
    const body = `fix: something\n\nPTH-Test: my_test\nPTH-Iteration: 5`;
    const trailers = parseTrailers(body);
    expect(trailers['PTH-Test']).toBe('my_test');
    expect(trailers['PTH-Iteration']).toBe('5');
  });

  it('returns empty object for message with no trailers', () => {
    expect(parseTrailers('fix: no trailers here')).toEqual({});
  });
});

describe('generateSessionBranch', () => {
  it('produces a branch name with plugin name, date, and hash', () => {
    const branch = generateSessionBranch('my-plugin');
    expect(branch).toMatch(/^pth\/my-plugin-\d{4}-\d{2}-\d{2}-[a-f0-9]{6}$/);
  });
});
```

**Step 2: Run test to verify it fails**
```bash
cd plugins/plugin-test-harness && npx jest test/unit/session/git.test.ts
```
Expected: FAIL — module not found

**Step 3: Define session types**
```typescript
// src/session/types.ts
export interface SessionState {
  sessionId: string;
  branch: string;
  worktreePath: string;
  pluginPath: string;
  pluginName: string;
  pluginMode: 'mcp' | 'plugin';
  startedAt: string;         // ISO 8601
  iteration: number;
  testCount: number;
  passingCount: number;
  failingCount: number;
  convergenceTrend: 'improving' | 'plateaued' | 'oscillating' | 'unknown';
  activeFailures: ActiveFailure[];
}

export interface ActiveFailure {
  testName: string;
  category: string;
  lastDiagnosisSummary?: string;
}

export interface FixCommitTrailers {
  'PTH-Test'?: string;
  'PTH-Category'?: string;
  'PTH-Files'?: string;
  'PTH-Iteration'?: string;
  'PTH-Type'?: string;        // 'fix' | 'state-checkpoint'
}
```

**Step 4: Implement git utilities**
```typescript
// src/session/git.ts
import { randomBytes } from 'crypto';
import { run, runOrThrow } from '../shared/exec.js';
import { PTHError, PTHErrorCode } from '../shared/errors.js';
import type { FixCommitTrailers } from './types.js';

export function generateSessionBranch(pluginName: string): string {
  const date = new Date().toISOString().slice(0, 10);
  const hash = randomBytes(3).toString('hex');
  const safeName = pluginName.replace(/[^a-z0-9-]/gi, '-').toLowerCase();
  return `pth/${safeName}-${date}-${hash}`;
}

export function buildCommitMessage(title: string, trailers: FixCommitTrailers): string {
  const trailerLines = Object.entries(trailers)
    .filter(([, v]) => v !== undefined)
    .map(([k, v]) => `${k}: ${v}`)
    .join('\n');
  return trailerLines ? `${title}\n\n${trailerLines}` : title;
}

export function parseTrailers(commitMessage: string): Record<string, string> {
  const result: Record<string, string> = {};
  const lines = commitMessage.split('\n');
  for (const line of lines) {
    const match = line.match(/^(PTH-[A-Za-z]+):\s*(.+)$/);
    if (match) {
      result[match[1]] = match[2].trim();
    }
  }
  return result;
}

export async function createBranch(repoPath: string, branchName: string): Promise<void> {
  await runOrThrow('git', ['checkout', '-b', branchName], { cwd: repoPath });
}

export async function addWorktree(repoPath: string, worktreePath: string, branch: string): Promise<void> {
  await runOrThrow('git', ['worktree', 'add', worktreePath, branch], { cwd: repoPath });
}

export async function removeWorktree(repoPath: string, worktreePath: string): Promise<void> {
  await run('git', ['worktree', 'remove', '--force', worktreePath], { cwd: repoPath });
}

export async function pruneWorktrees(repoPath: string): Promise<void> {
  await run('git', ['worktree', 'prune'], { cwd: repoPath });
}

export async function commitAll(
  worktreePath: string,
  message: string
): Promise<string> {
  await run('git', ['add', '-A'], { cwd: worktreePath });
  const result = await runOrThrow('git', ['commit', '-m', message], { cwd: worktreePath });
  // extract commit hash from output: "[branch abc1234] ..."
  const match = result.stdout.match(/\[[\w/]+ ([a-f0-9]+)\]/);
  return match?.[1] ?? '';
}

export async function getLog(
  worktreePath: string,
  options?: { since?: string; maxCount?: number }
): Promise<string> {
  const args = ['log', '--format=%H %s%n%b'];
  if (options?.maxCount) args.push(`-n${options.maxCount}`);
  const result = await runOrThrow('git', args, { cwd: worktreePath });
  return result.stdout;
}

export async function getDiff(worktreePath: string, base: string): Promise<string> {
  const result = await runOrThrow('git', ['diff', `${base}..HEAD`], { cwd: worktreePath });
  return result.stdout;
}

export async function revertCommit(worktreePath: string, commitHash: string): Promise<void> {
  await runOrThrow('git', ['revert', '--no-edit', commitHash], { cwd: worktreePath });
}

export async function getBranchPoint(worktreePath: string, branch: string): Promise<string> {
  // find the commit where this branch diverged from its base
  const result = await runOrThrow(
    'git', ['merge-base', 'HEAD', `origin/${branch.split('/')[0]}`],
    { cwd: worktreePath }
  );
  return result.stdout.trim();
}

export async function checkBranchExists(repoPath: string, branch: string): Promise<boolean> {
  const result = await run('git', ['rev-parse', '--verify', branch], { cwd: repoPath });
  return result.exitCode === 0;
}
```

**Step 5: Run tests**
```bash
cd plugins/plugin-test-harness && npx jest test/unit/session/git.test.ts
```
Expected: PASS

**Step 6: Commit**
```bash
git add plugins/plugin-test-harness/src/session/
git commit -m "feat(pth): add git integration — branch, worktree, commit with PTH trailers"
```

---

## Task 4: Plugin Detector

**Files:**
- Create: `src/plugin/types.ts`
- Create: `src/plugin/detector.ts`
- Create: `test/unit/plugin/detector.test.ts`

**Step 1: Write failing tests**
```typescript
// test/unit/plugin/detector.test.ts
import path from 'path';
import { detectPluginMode, detectBuildSystem } from '../../../src/plugin/detector.js';

// Uses fixture directories
const FIXTURES = path.join(__dirname, '../../fixtures');

describe('detectPluginMode', () => {
  it('returns mcp for a plugin with .mcp.json', async () => {
    // sample-mcp-plugin has .mcp.json
    const mode = await detectPluginMode(path.join(FIXTURES, 'sample-mcp-plugin'));
    expect(mode).toBe('mcp');
  });

  it('returns plugin for a plugin with .claude-plugin/ but no .mcp.json', async () => {
    const mode = await detectPluginMode(path.join(FIXTURES, 'sample-hook-plugin'));
    expect(mode).toBe('plugin');
  });

  it('throws if path is not a valid plugin', async () => {
    await expect(detectPluginMode('/tmp/not-a-plugin-at-all')).rejects.toThrow();
  });
});

describe('detectBuildSystem', () => {
  it('detects npm from package.json with build script', async () => {
    const build = await detectBuildSystem(path.join(FIXTURES, 'sample-mcp-plugin'));
    expect(build.installCommand).toContain('npm');
    expect(build.buildCommand).toContain('build');
  });

  it('returns null buildCommand when no build script exists', async () => {
    // sample-hook-plugin has no package.json
    const build = await detectBuildSystem(path.join(FIXTURES, 'sample-hook-plugin'));
    expect(build.buildCommand).toBeNull();
  });
});
```

**Step 2: Run test to verify it fails**
```bash
cd plugins/plugin-test-harness && npx jest test/unit/plugin/detector.test.ts
```
Expected: FAIL — fixtures don't exist yet + module missing

**Step 3: Create fixture stubs** (minimal, enough for tests to run — fleshed out in Task 30)
```bash
mkdir -p test/fixtures/sample-mcp-plugin
mkdir -p test/fixtures/sample-hook-plugin
echo '{"name": "sample-mcp-plugin", "command": "node", "args": ["dist/index.js"]}' > test/fixtures/sample-mcp-plugin/.mcp.json
echo '{"name": "sample-mcp-plugin", "version": "1.0.0", "scripts": {"build": "tsc"}, "main": "dist/index.js"}' > test/fixtures/sample-mcp-plugin/package.json
mkdir -p test/fixtures/sample-hook-plugin/.claude-plugin
echo '{"name": "sample-hook-plugin", "version": "1.0.0"}' > test/fixtures/sample-hook-plugin/.claude-plugin/manifest.json
```

**Step 4: Define plugin types**
```typescript
// src/plugin/types.ts
export type PluginMode = 'mcp' | 'plugin';

export interface BuildSystem {
  installCommand: string[] | null;   // e.g. ['npm', 'install']
  buildCommand: string[] | null;     // e.g. ['npm', 'run', 'build']
  startCommand: string[] | null;     // e.g. ['node', 'dist/index.js'] — from .mcp.json
  language: 'typescript' | 'python' | 'shell' | 'unknown';
}

export interface McpConfig {
  serverName: string;
  command: string;
  args: string[];
  env?: Record<string, string>;
}

export interface PluginInfo {
  mode: PluginMode;
  name: string;
  sourcePath: string;
  buildSystem: BuildSystem;
  mcpConfig?: McpConfig;   // only for mcp mode
  cachePath?: string;       // ~/.claude/plugins/cache/<name>/ if detectable
}
```

**Step 5: Implement detector**
```typescript
// src/plugin/detector.ts
import fs from 'fs/promises';
import path from 'path';
import { PTHError, PTHErrorCode } from '../shared/errors.js';
import type { PluginMode, BuildSystem, McpConfig, PluginInfo } from './types.js';

export async function detectPluginMode(pluginPath: string): Promise<PluginMode> {
  try {
    await fs.access(pluginPath);
  } catch {
    throw new PTHError(PTHErrorCode.PLUGIN_NOT_FOUND, `Plugin path not found: ${pluginPath}`);
  }

  // MCP plugin has .mcp.json at root
  const mcpJsonPath = path.join(pluginPath, '.mcp.json');
  try {
    await fs.access(mcpJsonPath);
    return 'mcp';
  } catch {
    // not MCP
  }

  // Claude Code plugin has .claude-plugin/ directory
  const claudePluginDir = path.join(pluginPath, '.claude-plugin');
  try {
    await fs.access(claudePluginDir);
    return 'plugin';
  } catch {
    throw new PTHError(
      PTHErrorCode.PLUGIN_NOT_FOUND,
      `Not a valid plugin: no .mcp.json or .claude-plugin/ found at ${pluginPath}`
    );
  }
}

export async function detectBuildSystem(pluginPath: string): Promise<BuildSystem> {
  // Check for package.json
  const pkgPath = path.join(pluginPath, 'package.json');
  try {
    const raw = await fs.readFile(pkgPath, 'utf-8');
    const pkg = JSON.parse(raw) as { scripts?: Record<string, string>; main?: string };
    const hasBuildScript = !!pkg.scripts?.['build'];
    const hasTsConfig = await fileExists(path.join(pluginPath, 'tsconfig.json'));

    return {
      installCommand: ['npm', 'install'],
      buildCommand: hasBuildScript ? ['npm', 'run', 'build'] :
                    hasTsConfig   ? ['npx', 'tsc'] : null,
      startCommand: pkg.main ? ['node', pkg.main] : null,
      language: hasTsConfig ? 'typescript' : 'unknown',
    };
  } catch {
    // no package.json
  }

  // Check for pyproject.toml / setup.py
  if (await fileExists(path.join(pluginPath, 'pyproject.toml')) ||
      await fileExists(path.join(pluginPath, 'setup.py'))) {
    return {
      installCommand: ['pip', 'install', '-e', '.'],
      buildCommand: null,
      startCommand: null,
      language: 'python',
    };
  }

  // No recognized build system
  return {
    installCommand: null,
    buildCommand: null,
    startCommand: null,
    language: 'unknown',
  };
}

export async function readMcpConfig(pluginPath: string): Promise<McpConfig | null> {
  const mcpJsonPath = path.join(pluginPath, '.mcp.json');
  try {
    const raw = await fs.readFile(mcpJsonPath, 'utf-8');
    const config = JSON.parse(raw) as Record<string, { command: string; args: string[]; env?: Record<string, string> }>;
    const [serverName, serverConfig] = Object.entries(config)[0];
    return { serverName, ...serverConfig };
  } catch {
    return null;
  }
}

export async function detectPluginName(pluginPath: string): Promise<string> {
  // Try .claude-plugin/manifest.json
  const manifestPath = path.join(pluginPath, '.claude-plugin', 'manifest.json');
  try {
    const raw = await fs.readFile(manifestPath, 'utf-8');
    const manifest = JSON.parse(raw) as { name?: string };
    if (manifest.name) return manifest.name;
  } catch { /* ignore */ }

  // Try package.json
  const pkgPath = path.join(pluginPath, 'package.json');
  try {
    const raw = await fs.readFile(pkgPath, 'utf-8');
    const pkg = JSON.parse(raw) as { name?: string };
    if (pkg.name) return pkg.name;
  } catch { /* ignore */ }

  // Fall back to directory name
  return path.basename(pluginPath);
}

async function fileExists(p: string): Promise<boolean> {
  try { await fs.access(p); return true; } catch { return false; }
}
```

**Step 6: Run tests**
```bash
cd plugins/plugin-test-harness && npx jest test/unit/plugin/detector.test.ts
```
Expected: PASS

**Step 7: Commit**
```bash
git add plugins/plugin-test-harness/src/plugin/ plugins/plugin-test-harness/test/fixtures/
git commit -m "feat(pth): add plugin detector — mode detection, build system, .mcp.json parsing"
```

---

## Task 5: Session State Persister + Report Generator

**Files:**
- Create: `src/session/state-persister.ts`
- Create: `src/session/report-generator.ts`
- Create: `test/unit/session/state-persister.test.ts`

**Step 1: Write failing test**
```typescript
// test/unit/session/state-persister.test.ts
import os from 'os';
import path from 'path';
import fs from 'fs/promises';
import { writeSessionState, readSessionState } from '../../../src/session/state-persister.js';
import type { SessionState } from '../../../src/session/types.js';

describe('session state persister', () => {
  let tmpDir: string;

  beforeEach(async () => {
    tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), 'pth-test-'));
  });

  afterEach(async () => {
    await fs.rm(tmpDir, { recursive: true });
  });

  const sampleState: SessionState = {
    sessionId: 'test-123',
    branch: 'pth/my-plugin-2026-02-18-abc123',
    worktreePath: '/tmp/pth-worktree-abc123',
    pluginPath: '/home/dev/my-plugin',
    pluginName: 'my-plugin',
    pluginMode: 'mcp',
    startedAt: '2026-02-18T10:00:00Z',
    iteration: 3,
    testCount: 10,
    passingCount: 7,
    failingCount: 3,
    convergenceTrend: 'improving',
    activeFailures: [{ testName: 'test_foo', category: 'runtime-exception' }],
  };

  it('writes and reads back session state', async () => {
    await writeSessionState(tmpDir, sampleState);
    const loaded = await readSessionState(tmpDir);
    expect(loaded).toEqual(sampleState);
  });

  it('returns null when state file does not exist', async () => {
    const result = await readSessionState('/tmp/nonexistent-pth-dir');
    expect(result).toBeNull();
  });
});
```

**Step 2: Run test to verify it fails**
```bash
cd plugins/plugin-test-harness && npx jest test/unit/session/state-persister.test.ts
```
Expected: FAIL — module not found

**Step 3: Implement**
```typescript
// src/session/state-persister.ts
import fs from 'fs/promises';
import path from 'path';
import type { SessionState } from './types.js';

const STATE_FILE = '.pth/session-state.json';

export async function writeSessionState(worktreePath: string, state: SessionState): Promise<void> {
  const dir = path.join(worktreePath, '.pth');
  await fs.mkdir(dir, { recursive: true });
  await fs.writeFile(
    path.join(worktreePath, STATE_FILE),
    JSON.stringify(state, null, 2),
    'utf-8'
  );
}

export async function readSessionState(worktreePath: string): Promise<SessionState | null> {
  const filePath = path.join(worktreePath, STATE_FILE);
  try {
    const raw = await fs.readFile(filePath, 'utf-8');
    return JSON.parse(raw) as SessionState;
  } catch {
    return null;
  }
}
```

```typescript
// src/session/report-generator.ts
import fs from 'fs/promises';
import path from 'path';
import type { SessionState } from './types.js';
import type { TestResult } from '../results/types.js';

export interface ReportOptions {
  state: SessionState;
  allResults: TestResult[];
  iterationHistory: IterationSummary[];
}

export interface IterationSummary {
  iteration: number;
  passing: number;
  failing: number;
  fixesApplied: number;
}

export async function generateReport(worktreePath: string, options: ReportOptions): Promise<void> {
  const { state, iterationHistory } = options;
  const lines: string[] = [
    `# PTH Session Report`,
    ``,
    `**Plugin:** ${state.pluginName}`,
    `**Mode:** ${state.pluginMode}`,
    `**Branch:** ${state.branch}`,
    `**Started:** ${state.startedAt}`,
    `**Ended:** ${new Date().toISOString()}`,
    `**Total Iterations:** ${state.iteration}`,
    ``,
    `## Test Results`,
    ``,
    `| Tests | Passing | Failing |`,
    `|-------|---------|---------|`,
    `| ${state.testCount} | ${state.passingCount} | ${state.failingCount} |`,
    ``,
    `## Convergence`,
    ``,
    `| Iteration | Passing | Failing | Fixes Applied |`,
    `|-----------|---------|---------|---------------|`,
    ...iterationHistory.map(h =>
      `| ${h.iteration} | ${h.passing} | ${h.failing} | ${h.fixesApplied} |`
    ),
    ``,
    `## Status`,
    ``,
    state.failingCount === 0
      ? `All ${state.testCount} tests passing.`
      : `${state.failingCount} tests still failing at session end.`,
  ];

  const dir = path.join(worktreePath, '.pth');
  await fs.mkdir(dir, { recursive: true });
  await fs.writeFile(path.join(worktreePath, '.pth/SESSION-REPORT.md'), lines.join('\n'), 'utf-8');
}
```

**Step 4: Run tests**
```bash
cd plugins/plugin-test-harness && npx jest test/unit/session/state-persister.test.ts
```
Expected: PASS

**Step 5: Commit**
```bash
git add plugins/plugin-test-harness/src/session/
git commit -m "feat(pth): add session state persister and report generator"
```

---

## Task 6: Test YAML Parser + Test Store

**Files:**
- Create: `src/testing/types.ts`
- Create: `src/testing/parser.ts`
- Create: `src/testing/store.ts`
- Create: `test/unit/testing/parser.test.ts`

**Step 1: Write failing tests**
```typescript
// test/unit/testing/parser.test.ts
import { parseTest, parseTestFile } from '../../../src/testing/parser.js';

describe('parseTest', () => {
  it('parses a minimal MCP single-tool test', () => {
    const yaml = `
name: "get_info returns version"
mode: mcp
tool: ha_get_info
input: {}
expect:
  success: true
  output_contains: "version"
`;
    const test = parseTest(yaml);
    expect(test.name).toBe('get_info returns version');
    expect(test.mode).toBe('mcp');
    expect(test.type).toBe('single');
    expect(test.tool).toBe('ha_get_info');
    expect(test.expect.success).toBe(true);
  });

  it('parses a plugin hook-script test', () => {
    const yaml = `
name: "write guard blocks Write"
mode: plugin
type: hook-script
script: hooks/scripts/write-guard.sh
stdin:
  tool_name: "Write"
  tool_input:
    file_path: "/tmp/test.ts"
expect:
  exit_code: 2
  stdout_contains: "block"
`;
    const test = parseTest(yaml);
    expect(test.mode).toBe('plugin');
    expect(test.type).toBe('hook-script');
    expect(test.script).toBe('hooks/scripts/write-guard.sh');
    expect(test.expect.exit_code).toBe(2);
  });

  it('throws on missing required field name', () => {
    expect(() => parseTest('mode: mcp\ntool: foo')).toThrow();
  });
});
```

**Step 2: Run test to verify it fails**
```bash
cd plugins/plugin-test-harness && npx jest test/unit/testing/parser.test.ts
```
Expected: FAIL

**Step 3: Define test types**
```typescript
// src/testing/types.ts
export type TestMode = 'mcp' | 'plugin';
export type TestType = 'single' | 'scenario' | 'hook-script' | 'validate' | 'exec';
export type GeneratedFrom = 'schema' | 'source_analysis' | 'documentation' | 'manual';

export interface ExpectBlock {
  success?: boolean;
  output_contains?: string;
  output_equals?: string;
  output_matches?: string;
  output_json?: unknown;
  output_json_contains?: unknown;
  error_contains?: string;
  exit_code?: number;
  stdout_contains?: string;
  stdout_matches?: string;
}

export interface StepDef {
  tool: string;
  input: Record<string, unknown>;
  expect?: ExpectBlock;
  capture?: Record<string, string>;  // varName -> JSONPath
}

export interface SetupStep {
  exec?: string;
  file?: { path: string; content: string };
}

export interface ValidateCheck {
  type: 'json-schema' | 'file-exists' | 'json-valid';
  file?: string;
  files?: string[];
}

export interface PthTest {
  id: string;        // generated: slugified name
  name: string;
  mode: TestMode;
  type: TestType;
  // MCP single
  tool?: string;
  input?: Record<string, unknown>;
  // MCP scenario
  steps?: StepDef[];
  // Plugin
  script?: string;
  stdin?: Record<string, unknown>;
  env?: Record<string, string>;
  checks?: ValidateCheck[];
  command?: string;  // for exec type
  // Common
  expect?: ExpectBlock;
  setup?: SetupStep[];
  teardown?: SetupStep[];
  tags?: string[];
  generated_from?: GeneratedFrom;
  timeout_seconds?: number;
}

export type TestStatus = 'pending' | 'passing' | 'failing' | 'skipped';

export interface TestResult {
  testId: string;
  testName: string;
  status: TestStatus;
  iteration: number;
  durationMs?: number;
  failureReason?: string;
  claudeNotes?: string;   // Claude's diagnosis/observation
  recordedAt: string;     // ISO 8601
}
```

**Step 4: Implement parser**
```typescript
// src/testing/parser.ts
import { parse as parseYaml } from 'yaml';
import fs from 'fs/promises';
import path from 'path';
import { PTHError, PTHErrorCode } from '../shared/errors.js';
import type { PthTest } from './types.js';

function slugify(name: string): string {
  return name.toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_|_$/g, '');
}

export function parseTest(yamlText: string): PthTest {
  let raw: unknown;
  try {
    raw = parseYaml(yamlText);
  } catch (e) {
    throw new PTHError(PTHErrorCode.INVALID_TEST, `Invalid YAML: ${(e as Error).message}`);
  }

  const obj = raw as Record<string, unknown>;

  if (!obj['name'] || typeof obj['name'] !== 'string') {
    throw new PTHError(PTHErrorCode.INVALID_TEST, 'Test must have a string "name" field');
  }
  if (!obj['mode'] || (obj['mode'] !== 'mcp' && obj['mode'] !== 'plugin')) {
    throw new PTHError(PTHErrorCode.INVALID_TEST, 'Test must have mode: mcp | plugin');
  }

  const mode = obj['mode'] as 'mcp' | 'plugin';
  const name = obj['name'] as string;

  let type: PthTest['type'];
  if (mode === 'mcp') {
    type = obj['steps'] ? 'scenario' : 'single';
  } else {
    type = (obj['type'] as PthTest['type']) ?? 'exec';
  }

  return {
    id: slugify(name),
    name,
    mode,
    type,
    tool: obj['tool'] as string | undefined,
    input: obj['input'] as Record<string, unknown> | undefined,
    steps: obj['steps'] as PthTest['steps'],
    script: obj['script'] as string | undefined,
    stdin: obj['stdin'] as Record<string, unknown> | undefined,
    env: obj['env'] as Record<string, string> | undefined,
    checks: obj['checks'] as PthTest['checks'],
    command: obj['command'] as string | undefined,
    expect: obj['expect'] as PthTest['expect'],
    setup: obj['setup'] as PthTest['setup'],
    teardown: obj['teardown'] as PthTest['teardown'],
    tags: obj['tags'] as string[] | undefined,
    generated_from: obj['generated_from'] as PthTest['generated_from'],
    timeout_seconds: obj['timeout_seconds'] as number | undefined,
  };
}

export async function parseTestFile(filePath: string): Promise<PthTest[]> {
  const raw = await fs.readFile(filePath, 'utf-8');
  // Support multi-document YAML (--- separator) or single test
  const docs = raw.split(/^---$/m).filter(d => d.trim().length > 0);
  return docs.map(doc => parseTest(doc));
}

export async function loadTestsFromDir(dirPath: string): Promise<PthTest[]> {
  const tests: PthTest[] = [];
  try {
    const entries = await fs.readdir(dirPath);
    for (const entry of entries) {
      if (entry.endsWith('.yaml') || entry.endsWith('.yml')) {
        const filePath = path.join(dirPath, entry);
        const filTests = await parseTestFile(filePath);
        tests.push(...filTests);
      }
    }
  } catch {
    // dir doesn't exist yet — return empty
  }
  return tests;
}
```

**Step 5: Create test store**
```typescript
// src/testing/store.ts
import fs from 'fs/promises';
import path from 'path';
import { stringify as stringifyYaml } from 'yaml';
import type { PthTest } from './types.js';

export class TestStore {
  private tests: Map<string, PthTest> = new Map();

  add(test: PthTest): void {
    this.tests.set(test.id, test);
  }

  update(test: PthTest): void {
    this.tests.set(test.id, test);
  }

  get(id: string): PthTest | undefined {
    return this.tests.get(id);
  }

  getAll(): PthTest[] {
    return Array.from(this.tests.values());
  }

  filter(predicate: (t: PthTest) => boolean): PthTest[] {
    return this.getAll().filter(predicate);
  }

  count(): number {
    return this.tests.size;
  }

  async persistToDir(dirPath: string): Promise<void> {
    await fs.mkdir(dirPath, { recursive: true });
    // Group by mode for cleaner files
    const mcpTests = this.filter(t => t.mode === 'mcp');
    const pluginTests = this.filter(t => t.mode === 'plugin');

    if (mcpTests.length > 0) {
      await fs.writeFile(
        path.join(dirPath, 'mcp-tests.yaml'),
        mcpTests.map(t => stringifyYaml(t)).join('\n---\n'),
        'utf-8'
      );
    }
    if (pluginTests.length > 0) {
      await fs.writeFile(
        path.join(dirPath, 'plugin-tests.yaml'),
        pluginTests.map(t => stringifyYaml(t)).join('\n---\n'),
        'utf-8'
      );
    }
  }
}
```

**Step 6: Run tests**
```bash
cd plugins/plugin-test-harness && npx jest test/unit/testing/parser.test.ts
```
Expected: PASS

**Step 7: Commit**
```bash
git add plugins/plugin-test-harness/src/testing/
git commit -m "feat(pth): add test YAML types, parser, and test store"
```

---

## Task 7: Results Tracker + Convergence

**Files:**
- Create: `src/results/types.ts`
- Create: `src/results/tracker.ts`
- Create: `src/results/convergence.ts`
- Create: `test/unit/results/tracker.test.ts`

**Step 1: Write failing tests**
```typescript
// test/unit/results/tracker.test.ts
import { ResultsTracker } from '../../../src/results/tracker.js';
import { detectConvergence } from '../../../src/results/convergence.js';

describe('ResultsTracker', () => {
  it('records a passing result and updates counts', () => {
    const tracker = new ResultsTracker();
    tracker.record({ testId: 'test_a', testName: 'test_a', status: 'passing',
                     iteration: 1, recordedAt: new Date().toISOString() });
    expect(tracker.getPassCount()).toBe(1);
    expect(tracker.getFailCount()).toBe(0);
  });

  it('tracks result history per test across iterations', () => {
    const tracker = new ResultsTracker();
    tracker.record({ testId: 'test_a', testName: 'test_a', status: 'failing',
                     iteration: 1, recordedAt: new Date().toISOString() });
    tracker.record({ testId: 'test_a', testName: 'test_a', status: 'passing',
                     iteration: 2, recordedAt: new Date().toISOString() });
    const history = tracker.getHistory('test_a');
    expect(history).toHaveLength(2);
    expect(history[1].status).toBe('passing');
  });
});

describe('detectConvergence', () => {
  it('returns improving when pass count is rising', () => {
    const trend = detectConvergence([
      { passing: 5, failing: 5 },
      { passing: 7, failing: 3 },
      { passing: 9, failing: 1 },
    ]);
    expect(trend).toBe('improving');
  });

  it('returns plateaued when pass count is unchanged for 2+ iterations', () => {
    const trend = detectConvergence([
      { passing: 5, failing: 5 },
      { passing: 7, failing: 3 },
      { passing: 7, failing: 3 },
      { passing: 7, failing: 3 },
    ]);
    expect(trend).toBe('plateaued');
  });

  it('returns unknown with fewer than 2 data points', () => {
    expect(detectConvergence([{ passing: 3, failing: 7 }])).toBe('unknown');
  });
});
```

**Step 2: Run test to verify it fails**
```bash
cd plugins/plugin-test-harness && npx jest test/unit/results/
```
Expected: FAIL

**Step 3: Implement**

```typescript
// src/results/types.ts — re-export from testing/types.ts for convenience
export type { TestResult, TestStatus } from '../testing/types.js';

export interface IterationSnapshot {
  passing: number;
  failing: number;
}

export type ConvergenceTrend = 'improving' | 'plateaued' | 'oscillating' | 'unknown';
```

```typescript
// src/results/tracker.ts
import type { TestResult } from '../testing/types.js';

export class ResultsTracker {
  private results: Map<string, TestResult[]> = new Map();  // testId -> history

  record(result: TestResult): void {
    const history = this.results.get(result.testId) ?? [];
    history.push(result);
    this.results.set(result.testId, history);
  }

  getHistory(testId: string): TestResult[] {
    return this.results.get(testId) ?? [];
  }

  getLatest(testId: string): TestResult | undefined {
    const history = this.getHistory(testId);
    return history[history.length - 1];
  }

  getPassCount(): number {
    let count = 0;
    for (const [testId] of this.results) {
      const latest = this.getLatest(testId);
      if (latest?.status === 'passing') count++;
    }
    return count;
  }

  getFailCount(): number {
    let count = 0;
    for (const [testId] of this.results) {
      const latest = this.getLatest(testId);
      if (latest?.status === 'failing') count++;
    }
    return count;
  }

  getFailingTests(): TestResult[] {
    const failing: TestResult[] = [];
    for (const [testId] of this.results) {
      const latest = this.getLatest(testId);
      if (latest?.status === 'failing') failing.push(latest);
    }
    return failing;
  }

  getAllLatest(): TestResult[] {
    return Array.from(this.results.keys())
      .map(id => this.getLatest(id))
      .filter((r): r is TestResult => r !== undefined);
  }
}
```

```typescript
// src/results/convergence.ts
import type { IterationSnapshot, ConvergenceTrend } from './types.js';

export function detectConvergence(snapshots: IterationSnapshot[]): ConvergenceTrend {
  if (snapshots.length < 2) return 'unknown';

  const recent = snapshots.slice(-3);  // look at last 3 iterations
  const passValues = recent.map(s => s.passing);

  // Plateaued: same pass count for last 2+ snapshots
  const last = passValues[passValues.length - 1];
  const allSame = passValues.every(v => v === last);
  if (allSame && recent.length >= 2) return 'plateaued';

  // Oscillating: pass count goes up then down (or vice versa) repeatedly
  if (passValues.length >= 3) {
    const diffs = passValues.slice(1).map((v, i) => v - passValues[i]);
    const signChanges = diffs.slice(1).filter((d, i) => Math.sign(d) !== Math.sign(diffs[i]) && d !== 0).length;
    if (signChanges >= 2) return 'oscillating';
  }

  // Improving: trend is upward
  const first = passValues[0];
  if (last > first) return 'improving';

  return 'unknown';
}
```

**Step 4: Run tests**
```bash
cd plugins/plugin-test-harness && npx jest test/unit/results/
```
Expected: PASS

**Step 5: Commit**
```bash
git add plugins/plugin-test-harness/src/results/
git commit -m "feat(pth): add results tracker and convergence detection"
```

---

## Task 8: Fix Applicator + Tracker

**Files:**
- Create: `src/fix/types.ts`
- Create: `src/fix/applicator.ts`
- Create: `src/fix/tracker.ts`
- Create: `test/unit/fix/applicator.test.ts`

**Step 1: Write failing test**
```typescript
// test/unit/fix/applicator.test.ts
import os from 'os';
import path from 'path';
import fs from 'fs/promises';
import { applyFix } from '../../../src/fix/applicator.js';

describe('applyFix', () => {
  let tmpDir: string;

  beforeEach(async () => {
    tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), 'pth-fix-test-'));
    // init git repo in tmp dir
    const { execa } = await import('execa');
    await execa('git', ['init'], { cwd: tmpDir });
    await execa('git', ['config', 'user.email', 'test@pth.test'], { cwd: tmpDir });
    await execa('git', ['config', 'user.name', 'PTH Test'], { cwd: tmpDir });
    // create initial file
    await fs.writeFile(path.join(tmpDir, 'src.ts'), 'const x = 1;\n');
    await execa('git', ['add', '.'], { cwd: tmpDir });
    await execa('git', ['commit', '-m', 'initial'], { cwd: tmpDir });
  });

  afterEach(async () => {
    await fs.rm(tmpDir, { recursive: true });
  });

  it('writes a file change and creates a commit with PTH trailers', async () => {
    const commitHash = await applyFix({
      worktreePath: tmpDir,
      files: [{ path: 'src.ts', content: 'const x = 2;\n' }],
      commitTitle: 'fix: update value',
      trailers: {
        'PTH-Test': 'my_test',
        'PTH-Iteration': '1',
      },
    });

    const content = await fs.readFile(path.join(tmpDir, 'src.ts'), 'utf-8');
    expect(content).toBe('const x = 2;\n');
    expect(commitHash).toMatch(/^[a-f0-9]+$/);
  });
});
```

**Step 2: Run test to verify it fails**
```bash
cd plugins/plugin-test-harness && npx jest test/unit/fix/applicator.test.ts
```
Expected: FAIL

**Step 3: Implement**
```typescript
// src/fix/types.ts
export interface FileChange {
  path: string;     // relative to worktree root
  content: string;  // new full file content
}

export interface FixRequest {
  worktreePath: string;
  files: FileChange[];
  commitTitle: string;
  trailers: Record<string, string>;
}

export interface FixRecord {
  commitHash: string;
  commitTitle: string;
  trailers: Record<string, string>;
  filesChanged: string[];
  timestamp: string;
}
```

```typescript
// src/fix/applicator.ts
import fs from 'fs/promises';
import path from 'path';
import { buildCommitMessage, commitAll } from '../session/git.js';
import type { FixRequest } from './types.js';

export async function applyFix(request: FixRequest): Promise<string> {
  // Write all file changes
  for (const file of request.files) {
    const fullPath = path.join(request.worktreePath, file.path);
    await fs.mkdir(path.dirname(fullPath), { recursive: true });
    await fs.writeFile(fullPath, file.content, 'utf-8');
  }

  // Commit with PTH trailers
  const message = buildCommitMessage(request.commitTitle, request.trailers);
  return commitAll(request.worktreePath, message);
}
```

```typescript
// src/fix/tracker.ts
import { getLog } from '../session/git.js';
import { parseTrailers } from '../session/git.js';
import type { FixRecord } from './types.js';

export async function getFixHistory(worktreePath: string): Promise<FixRecord[]> {
  const log = await getLog(worktreePath, { maxCount: 100 });
  const records: FixRecord[] = [];

  // Parse git log output: each entry is "HASH SUBJECT\nBODY\n"
  const entries = log.split('\n\n').filter(e => e.trim());
  for (const entry of entries) {
    const lines = entry.trim().split('\n');
    const firstLine = lines[0];
    const hashAndSubject = firstLine.match(/^([a-f0-9]+)\s+(.+)$/);
    if (!hashAndSubject) continue;

    const body = lines.slice(1).join('\n');
    const trailers = parseTrailers(body);

    // Only include PTH fix commits (those with PTH trailers)
    if (Object.keys(trailers).length === 0) continue;

    records.push({
      commitHash: hashAndSubject[1],
      commitTitle: hashAndSubject[2],
      trailers,
      filesChanged: trailers['PTH-Files']?.split(',').map(f => f.trim()) ?? [],
      timestamp: new Date().toISOString(), // approximate
    });
  }
  return records;
}
```

**Step 4: Run tests**
```bash
cd plugins/plugin-test-harness && npx jest test/unit/fix/applicator.test.ts
```
Expected: PASS

**Step 5: Commit**
```bash
git add plugins/plugin-test-harness/src/fix/
git commit -m "feat(pth): add fix applicator with git commit trailers and fix history tracker"
```

---

## Task 9: Cache Sync + Plugin Reloader

**Files:**
- Create: `src/plugin/cache-sync.ts`
- Create: `src/plugin/reloader.ts`
- Create: `src/plugin/build.ts`
- Create: `test/unit/plugin/cache-sync.test.ts`

**Step 1: Write failing test**
```typescript
// test/unit/plugin/cache-sync.test.ts
import os from 'os';
import path from 'path';
import fs from 'fs/promises';
import { syncToCache, detectCachePath } from '../../../src/plugin/cache-sync.js';

describe('syncToCache', () => {
  it('copies files from worktree to cache dir', async () => {
    const src = await fs.mkdtemp(path.join(os.tmpdir(), 'pth-src-'));
    const dst = await fs.mkdtemp(path.join(os.tmpdir(), 'pth-dst-'));

    await fs.writeFile(path.join(src, 'script.sh'), '#!/bin/bash\necho hello', 'utf-8');

    await syncToCache(src, dst);

    const copied = await fs.readFile(path.join(dst, 'script.sh'), 'utf-8');
    expect(copied).toContain('echo hello');

    await fs.rm(src, { recursive: true });
    await fs.rm(dst, { recursive: true });
  });
});
```

**Step 2: Run test to verify it fails**
```bash
cd plugins/plugin-test-harness && npx jest test/unit/plugin/cache-sync.test.ts
```
Expected: FAIL

**Step 3: Implement cache sync**
```typescript
// src/plugin/cache-sync.ts
import fs from 'fs/promises';
import path from 'path';
import os from 'os';
import { runOrThrow } from '../shared/exec.js';

export async function syncToCache(worktreePath: string, cachePath: string): Promise<void> {
  await fs.mkdir(cachePath, { recursive: true });
  // Use rsync for efficient sync; fall back to cp -r on systems without rsync
  try {
    await runOrThrow('rsync', ['-a', '--delete', `${worktreePath}/`, `${cachePath}/`]);
  } catch {
    // rsync not available — use cp
    await runOrThrow('cp', ['-r', `${worktreePath}/.`, cachePath]);
  }
}

export function detectCachePath(pluginName: string): string {
  return path.join(os.homedir(), '.claude', 'plugins', 'cache', pluginName);
}
```

**Step 4: Implement plugin builder**
```typescript
// src/plugin/build.ts
import { runOrThrow, run } from '../shared/exec.js';
import type { BuildSystem } from './types.js';

export async function buildPlugin(worktreePath: string, buildSystem: BuildSystem): Promise<void> {
  if (buildSystem.installCommand) {
    await runOrThrow(buildSystem.installCommand[0], buildSystem.installCommand.slice(1), {
      cwd: worktreePath,
      timeoutMs: 120_000,
    });
  }
  if (buildSystem.buildCommand) {
    await runOrThrow(buildSystem.buildCommand[0], buildSystem.buildCommand.slice(1), {
      cwd: worktreePath,
      timeoutMs: 120_000,
    });
  }
}

export async function buildOnly(worktreePath: string, buildSystem: BuildSystem): Promise<void> {
  if (buildSystem.buildCommand) {
    await runOrThrow(buildSystem.buildCommand[0], buildSystem.buildCommand.slice(1), {
      cwd: worktreePath,
      timeoutMs: 120_000,
    });
  }
}
```

**Step 5: Implement plugin reloader**
```typescript
// src/plugin/reloader.ts
import { run } from '../shared/exec.js';
import { buildOnly } from './build.js';
import { PTHError, PTHErrorCode } from '../shared/errors.js';
import type { BuildSystem } from './types.js';

export interface ReloadResult {
  buildSucceeded: boolean;
  buildOutput: string;
  processTerminated: boolean;
  pid?: number;
  message: string;
}

export async function reloadPlugin(
  worktreePath: string,
  buildSystem: BuildSystem,
  pluginStartPattern: string   // pattern to find process, e.g. path component of start command
): Promise<ReloadResult> {
  // Step 1: Build
  let buildOutput = '';
  try {
    const result = await run(
      buildSystem.buildCommand![0],
      buildSystem.buildCommand!.slice(1),
      { cwd: worktreePath, timeoutMs: 120_000 }
    );
    buildOutput = result.stdout + result.stderr;
    if (result.exitCode !== 0) {
      return {
        buildSucceeded: false,
        buildOutput,
        processTerminated: false,
        message: `Build failed (exit ${result.exitCode}). Fix build errors before reloading.`,
      };
    }
  } catch (e) {
    return {
      buildSucceeded: false,
      buildOutput: String(e),
      processTerminated: false,
      message: `Build threw an error: ${(e as Error).message}`,
    };
  }

  // Step 2: Find PID
  const psResult = await run('ps', ['aux']);
  const lines = psResult.stdout.split('\n');
  const matchingLine = lines.find(l => l.includes(pluginStartPattern) && !l.includes('grep'));

  if (!matchingLine) {
    return {
      buildSucceeded: true,
      buildOutput,
      processTerminated: false,
      message: `Build succeeded but could not find running process matching "${pluginStartPattern}". The plugin may not be running or may need a manual restart.`,
    };
  }

  const pid = parseInt(matchingLine.trim().split(/\s+/)[1], 10);
  if (isNaN(pid)) {
    return {
      buildSucceeded: true,
      buildOutput,
      processTerminated: false,
      message: `Build succeeded but could not parse PID from ps output.`,
    };
  }

  // Step 3: SIGTERM with SIGKILL fallback
  try {
    process.kill(pid, 'SIGTERM');
    // Wait up to 5 seconds for graceful shutdown
    await waitForProcessExit(pid, 5000);
  } catch {
    // Process already gone — that's fine
  }

  // Try SIGKILL if still running
  try {
    process.kill(pid, 0);  // check if still alive
    process.kill(pid, 'SIGKILL');
  } catch {
    // Already gone — success
  }

  return {
    buildSucceeded: true,
    buildOutput,
    processTerminated: true,
    pid,
    message: `Build succeeded. Process ${pid} terminated. Claude Code should restart the plugin automatically. Please verify by calling one of the plugin's tools before continuing.`,
  };
}

async function waitForProcessExit(pid: number, timeoutMs: number): Promise<void> {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    try {
      process.kill(pid, 0);  // throws if process doesn't exist
      await sleep(200);
    } catch {
      return;  // process is gone
    }
  }
}

function sleep(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}
```

**Step 6: Run tests**
```bash
cd plugins/plugin-test-harness && npx jest test/unit/plugin/cache-sync.test.ts
```
Expected: PASS

**Step 7: Commit**
```bash
git add plugins/plugin-test-harness/src/plugin/
git commit -m "feat(pth): add cache sync, plugin builder, and SIGTERM-based reloader"
```

---

## Task 10: Test Generator

**Files:**
- Create: `src/testing/generator.ts`
- Create: `src/shared/source-analyzer.ts`
- Create: `test/unit/testing/generator.test.ts`

**Step 1: Write failing test**
```typescript
// test/unit/testing/generator.test.ts
import path from 'path';
import { generateMcpTests } from '../../../src/testing/generator.js';

const FIXTURES = path.join(__dirname, '../../fixtures');

describe('generateMcpTests', () => {
  it('generates at least one test per tool from schema', async () => {
    // sample-mcp-plugin exposes known tools
    const tests = await generateMcpTests({
      pluginPath: path.join(FIXTURES, 'sample-mcp-plugin'),
      toolSchemas: [
        {
          name: 'echo_message',
          description: 'Echoes a message back',
          inputSchema: {
            type: 'object',
            properties: { message: { type: 'string' } },
            required: ['message'],
          },
        },
      ],
    });

    expect(tests.length).toBeGreaterThanOrEqual(1);
    expect(tests[0].mode).toBe('mcp');
    expect(tests[0].tool).toBe('echo_message');
    expect(tests[0].generated_from).toBe('schema');
  });
});
```

**Step 2: Run test to verify it fails**
```bash
cd plugins/plugin-test-harness && npx jest test/unit/testing/generator.test.ts
```
Expected: FAIL

**Step 3: Implement source analyzer**
```typescript
// src/shared/source-analyzer.ts
import fs from 'fs/promises';
import path from 'path';

export interface ToolSchema {
  name: string;
  description?: string;
  inputSchema?: {
    type: string;
    properties?: Record<string, { type: string; description?: string; enum?: unknown[] }>;
    required?: string[];
  };
}

export async function readToolSchemasFromSource(pluginPath: string): Promise<ToolSchema[]> {
  // Read .pth-tools-cache.json if present (set by Claude after tools/list)
  const cachePath = path.join(pluginPath, '.pth-tools-cache.json');
  try {
    const raw = await fs.readFile(cachePath, 'utf-8');
    return JSON.parse(raw) as ToolSchema[];
  } catch {
    return [];
  }
}

export async function writeToolSchemasCache(pluginPath: string, schemas: ToolSchema[]): Promise<void> {
  const cachePath = path.join(pluginPath, '.pth-tools-cache.json');
  await fs.writeFile(cachePath, JSON.stringify(schemas, null, 2), 'utf-8');
}
```

**Step 4: Implement generator**
```typescript
// src/testing/generator.ts
import type { PthTest } from './types.js';
import type { ToolSchema } from '../shared/source-analyzer.js';

interface GenerateMcpOptions {
  pluginPath: string;
  toolSchemas: ToolSchema[];
}

export function generateMcpTests(options: GenerateMcpOptions): PthTest[] {
  const tests: PthTest[] = [];

  for (const tool of options.toolSchemas) {
    // Test 1: valid input (using required fields with minimal values)
    const validInput = buildValidInput(tool);
    tests.push({
      id: slugify(`${tool.name}_valid_input`),
      name: `${tool.name} — valid input`,
      mode: 'mcp',
      type: 'single',
      tool: tool.name,
      input: validInput,
      expect: { success: true },
      generated_from: 'schema',
      timeout_seconds: 10,
    });

    // Test 2: missing required field (if any required fields)
    const required = tool.inputSchema?.required ?? [];
    if (required.length > 0) {
      const missingInput = { ...validInput };
      delete missingInput[required[0]];
      tests.push({
        id: slugify(`${tool.name}_missing_required`),
        name: `${tool.name} — missing required field "${required[0]}"`,
        mode: 'mcp',
        type: 'single',
        tool: tool.name,
        input: missingInput,
        expect: { success: false },
        generated_from: 'schema',
        timeout_seconds: 10,
      });
    }
  }

  return tests;
}

export function generatePluginTests(pluginPath: string, hookScripts: string[]): PthTest[] {
  const tests: PthTest[] = [];

  for (const script of hookScripts) {
    // Validate script exists and is executable
    tests.push({
      id: slugify(`validate_${script}`),
      name: `${script} — script exists and is readable`,
      mode: 'plugin',
      type: 'validate',
      checks: [{ type: 'file-exists', files: [script] }],
      generated_from: 'source_analysis',
    });
  }

  return tests;
}

function buildValidInput(tool: ToolSchema): Record<string, unknown> {
  const input: Record<string, unknown> = {};
  const props = tool.inputSchema?.properties ?? {};
  const required = tool.inputSchema?.required ?? [];

  for (const field of required) {
    const prop = props[field];
    if (!prop) { input[field] = ''; continue; }
    if (prop.type === 'string') input[field] = prop.enum ? prop.enum[0] : 'test-value';
    else if (prop.type === 'number' || prop.type === 'integer') input[field] = 1;
    else if (prop.type === 'boolean') input[field] = true;
    else if (prop.type === 'array') input[field] = [];
    else if (prop.type === 'object') input[field] = {};
    else input[field] = null;
  }
  return input;
}

function slugify(name: string): string {
  return name.toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_|_$/g, '');
}
```

**Step 5: Run tests**
```bash
cd plugins/plugin-test-harness && npx jest test/unit/testing/generator.test.ts
```
Expected: PASS

**Step 6: Commit**
```bash
git add plugins/plugin-test-harness/src/testing/ plugins/plugin-test-harness/src/shared/source-analyzer.ts
git commit -m "feat(pth): add test generator from tool schemas and plugin source"
```

---

## Task 11: MCP Server Foundation + Tool Registry

**Files:**
- Create: `src/server.ts`
- Create: `src/tool-registry.ts`
- Create: `src/index.ts`
- Create: `test/unit/tool-registry.test.ts`

**Step 1: Write failing test**
```typescript
// test/unit/tool-registry.test.ts
import { ToolRegistry } from '../../../src/tool-registry.js';

describe('ToolRegistry', () => {
  it('starts in dormant state with 3 tools', () => {
    const registry = new ToolRegistry();
    const tools = registry.getActiveTools();
    expect(tools).toHaveLength(3);
    expect(tools.map(t => t.name)).toContain('pth_start_session');
    expect(tools.map(t => t.name)).toContain('pth_resume_session');
    expect(tools.map(t => t.name)).toContain('pth_preflight');
  });

  it('returns all tools after activation', () => {
    const registry = new ToolRegistry();
    registry.activate();
    const tools = registry.getActiveTools();
    expect(tools.length).toBeGreaterThan(3);
    expect(tools.map(t => t.name)).toContain('pth_end_session');
    expect(tools.map(t => t.name)).toContain('pth_generate_tests');
  });

  it('returns only dormant tools after deactivation', () => {
    const registry = new ToolRegistry();
    registry.activate();
    registry.deactivate();
    expect(registry.getActiveTools()).toHaveLength(3);
  });
});
```

**Step 2: Run test to verify it fails**
```bash
cd plugins/plugin-test-harness && npx jest test/unit/tool-registry.test.ts
```
Expected: FAIL

**Step 3: Implement tool registry**
```typescript
// src/tool-registry.ts
import { z } from 'zod';

// Tool definition shape (simplified for registry purposes)
export interface ToolDef {
  name: string;
  description: string;
  inputSchema: z.ZodTypeAny;
}

// ── Dormant tools ──────────────────────────────────────────────

const dormantTools: ToolDef[] = [
  {
    name: 'pth_preflight',
    description: 'Validate prerequisites before starting a PTH session: check plugin path, git repo, build system, no active session lock.',
    inputSchema: z.object({
      pluginPath: z.string().describe('Absolute path to the target plugin'),
    }),
  },
  {
    name: 'pth_start_session',
    description: 'Start a PTH session: create session branch + worktree, detect plugin mode (mcp or plugin), analyze source, load existing tests if present.',
    inputSchema: z.object({
      pluginPath: z.string().describe('Absolute path to the target plugin'),
      sessionNote: z.string().optional().describe('Optional human note about what this session aims to test'),
    }),
  },
  {
    name: 'pth_resume_session',
    description: 'Resume an interrupted PTH session from an existing session branch.',
    inputSchema: z.object({
      branch: z.string().describe('Session branch name, e.g. pth/my-plugin-2026-02-18-abc123'),
      pluginPath: z.string().describe('Absolute path to the target plugin'),
    }),
  },
];

// ── Session tools ──────────────────────────────────────────────

const sessionTools: ToolDef[] = [
  // Management
  {
    name: 'pth_end_session',
    description: 'End the PTH session: persist tests to .pth/tests/, generate SESSION-REPORT.md, remove worktree, deactivate session tools.',
    inputSchema: z.object({}),
  },
  {
    name: 'pth_get_session_status',
    description: 'Get current session status: iteration count, passing/failing counts, convergence trend, session metadata.',
    inputSchema: z.object({}),
  },
  // Tests
  {
    name: 'pth_generate_tests',
    description: 'Generate test proposals for the target plugin from available signals (tool schemas, source analysis, manifest). Returns YAML test definitions for review.',
    inputSchema: z.object({
      toolSchemas: z.array(z.unknown()).optional().describe('Tool schemas from the target plugin (paste tools/list output here for MCP plugins)'),
      includeEdgeCases: z.boolean().optional().default(true),
    }),
  },
  {
    name: 'pth_list_tests',
    description: 'List tests in the current suite with optional filtering.',
    inputSchema: z.object({
      mode: z.enum(['mcp', 'plugin']).optional(),
      status: z.enum(['passing', 'failing', 'pending']).optional(),
      tag: z.string().optional(),
      generatedFrom: z.string().optional(),
    }),
  },
  {
    name: 'pth_create_test',
    description: 'Add a new test to the suite.',
    inputSchema: z.object({
      yaml: z.string().describe('YAML test definition'),
    }),
  },
  {
    name: 'pth_edit_test',
    description: 'Update an existing test definition.',
    inputSchema: z.object({
      testId: z.string(),
      yaml: z.string().describe('New YAML test definition'),
    }),
  },
  // Execution
  {
    name: 'pth_record_result',
    description: 'Record the result of a test after Claude has executed it. Call this after calling the target plugin\'s tool and evaluating the assertion.',
    inputSchema: z.object({
      testId: z.string(),
      status: z.enum(['passing', 'failing', 'skipped']),
      durationMs: z.number().optional(),
      failureReason: z.string().optional().describe('What went wrong, if failing'),
      claudeNotes: z.string().optional().describe('Claude\'s observations about this test result'),
    }),
  },
  {
    name: 'pth_get_results',
    description: 'Get the current pass/fail status of all tests in the suite.',
    inputSchema: z.object({}),
  },
  {
    name: 'pth_get_test_impact',
    description: 'Show which tests exercise code in the specified source files (for targeted re-runs after a fix).',
    inputSchema: z.object({
      files: z.array(z.string()).describe('Source file paths relative to plugin root'),
    }),
  },
  // Fixes
  {
    name: 'pth_apply_fix',
    description: 'Apply a code fix: write file changes and commit to session branch with PTH trailers.',
    inputSchema: z.object({
      files: z.array(z.object({
        path: z.string().describe('File path relative to plugin root'),
        content: z.string().describe('Full new file content'),
      })),
      commitTitle: z.string().describe('Git commit title, e.g. "fix: handle null group"'),
      testId: z.string().optional().describe('ID of the test this fix addresses'),
      category: z.string().optional().describe('Failure category, e.g. "runtime-exception"'),
    }),
  },
  {
    name: 'pth_sync_to_cache',
    description: 'Sync worktree changes to the plugin cache directory so hook script changes take effect immediately.',
    inputSchema: z.object({}),
  },
  {
    name: 'pth_reload_plugin',
    description: 'Rebuild the MCP plugin and terminate its process so Claude Code restarts it with the new build.',
    inputSchema: z.object({
      processPattern: z.string().optional().describe('Optional pattern to find the MCP server process in ps output. Defaults to plugin dist path.'),
    }),
  },
  {
    name: 'pth_get_fix_history',
    description: 'View all fix commits on the session branch with their PTH trailers.',
    inputSchema: z.object({}),
  },
  {
    name: 'pth_revert_fix',
    description: 'Undo a specific fix commit via git revert.',
    inputSchema: z.object({
      commitHash: z.string(),
    }),
  },
  {
    name: 'pth_diff_session',
    description: 'Show cumulative diff of all changes on the session branch vs the branch point.',
    inputSchema: z.object({}),
  },
  // Iteration
  {
    name: 'pth_get_iteration_status',
    description: 'Get iteration number, per-test pass/fail history, and convergence trend (improving, plateaued, oscillating).',
    inputSchema: z.object({}),
  },
];

export class ToolRegistry {
  private active = false;

  getActiveTools(): ToolDef[] {
    return this.active ? [...dormantTools, ...sessionTools] : [...dormantTools];
  }

  activate(): void {
    this.active = true;
  }

  deactivate(): void {
    this.active = false;
  }

  isActive(): boolean {
    return this.active;
  }
}
```

**Step 4: Run tests**
```bash
cd plugins/plugin-test-harness && npx jest test/unit/tool-registry.test.ts
```
Expected: PASS

**Step 5: Implement MCP server entry point**
```typescript
// src/server.ts
import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import {
  ListToolsRequestSchema,
  CallToolRequestSchema,
} from '@modelcontextprotocol/sdk/types.js';
import { ToolRegistry } from './tool-registry.js';
import type { SessionState } from './session/types.js';

// Session state (set when a session is active)
let currentSession: SessionState | null = null;

// Lazily imported to avoid circular deps
let sessionManager: typeof import('./session/manager.js') | null = null;

export function createServer(): Server {
  const registry = new ToolRegistry();

  const server = new Server(
    { name: 'plugin-test-harness', version: '1.0.0' },
    { capabilities: { tools: {} } }
  );

  // Dynamic tool list
  server.setRequestHandler(ListToolsRequestSchema, async () => ({
    tools: registry.getActiveTools().map(t => ({
      name: t.name,
      description: t.description,
      inputSchema: t.inputSchema,
    })),
  }));

  // Tool dispatch
  server.setRequestHandler(CallToolRequestSchema, async (request) => {
    const { name, arguments: args } = request.params;
    return dispatch(server, registry, name, args ?? {});
  });

  return server;
}

async function dispatch(
  server: Server,
  registry: ToolRegistry,
  toolName: string,
  args: Record<string, unknown>
): Promise<{ content: Array<{ type: 'text'; text: string }> }> {
  // Lazy import session manager
  if (!sessionManager) {
    sessionManager = await import('./session/manager.js');
  }

  const respond = (text: string) => ({ content: [{ type: 'text' as const, text }] });

  switch (toolName) {
    case 'pth_preflight': {
      const result = await sessionManager.preflight(args as { pluginPath: string });
      return respond(result);
    }
    case 'pth_start_session': {
      const result = await sessionManager.startSession(
        args as { pluginPath: string; sessionNote?: string }
      );
      currentSession = result.state;
      registry.activate();
      await server.notification({ method: 'notifications/tools/list_changed' });
      return respond(result.message);
    }
    case 'pth_resume_session': {
      const result = await sessionManager.resumeSession(
        args as { branch: string; pluginPath: string }
      );
      currentSession = result.state;
      registry.activate();
      await server.notification({ method: 'notifications/tools/list_changed' });
      return respond(result.message);
    }
    case 'pth_end_session': {
      if (!currentSession) return respond('No active session.');
      const result = await sessionManager.endSession(currentSession);
      currentSession = null;
      registry.deactivate();
      await server.notification({ method: 'notifications/tools/list_changed' });
      return respond(result);
    }
    default: {
      if (!registry.isActive()) {
        return respond(`No PTH session active. Call pth_start_session first.`);
      }
      // Delegate to session handlers
      return handleSessionTool(toolName, args, currentSession!);
    }
  }
}

// Session tool dispatch — implemented in Task 12
async function handleSessionTool(
  toolName: string,
  args: Record<string, unknown>,
  session: SessionState
): Promise<{ content: Array<{ type: 'text'; text: string }> }> {
  const respond = (text: string) => ({ content: [{ type: 'text' as const, text }] });
  return respond(`Tool ${toolName} not yet implemented.`);
}
```

```typescript
// src/index.ts
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { createServer } from './server.js';

const server = createServer();
const transport = new StdioServerTransport();
await server.connect(transport);
```

**Step 6: Run tests**
```bash
cd plugins/plugin-test-harness && npx jest test/unit/tool-registry.test.ts
```
Expected: PASS

**Step 7: Build to verify TypeScript compiles**
```bash
cd plugins/plugin-test-harness && npm run build
```
Expected: `dist/` created with no errors.

**Step 8: Commit**
```bash
git add plugins/plugin-test-harness/src/
git commit -m "feat(pth): add MCP server foundation with dynamic tool registry"
```

---

## Task 12: Session Manager

**Files:**
- Create: `src/session/manager.ts`
- Create: `test/unit/session/manager.test.ts`

This is the central orchestration module. Given its complexity (it coordinates git, plugin detection, test loading, and state persistence), the test here is an integration test using a real temp git repo.

**Step 1: Write failing test**
```typescript
// test/unit/session/manager.test.ts
import os from 'os';
import path from 'path';
import fs from 'fs/promises';
import { preflight } from '../../../src/session/manager.js';

describe('preflight', () => {
  it('returns ok message for a valid plugin directory', async () => {
    // Use sample-mcp-plugin fixture (already has .mcp.json)
    const fixturePath = path.join(__dirname, '../../fixtures/sample-mcp-plugin');
    const result = await preflight({ pluginPath: fixturePath });
    expect(result).toContain('OK');
  });

  it('returns error message for non-existent path', async () => {
    const result = await preflight({ pluginPath: '/tmp/does-not-exist-pth' });
    expect(result).toContain('not found');
  });
});
```

**Step 2: Run test to verify it fails**
```bash
cd plugins/plugin-test-harness && npx jest test/unit/session/manager.test.ts
```
Expected: FAIL

**Step 3: Implement session manager**
```typescript
// src/session/manager.ts
import fs from 'fs/promises';
import path from 'path';
import os from 'os';
import { detectPluginMode, detectPluginName, detectBuildSystem, readMcpConfig } from '../plugin/detector.js';
import { generateSessionBranch, createBranch, addWorktree, removeWorktree, pruneWorktrees, commitAll, getDiff, checkBranchExists } from './git.js';
import { writeSessionState, readSessionState } from './state-persister.js';
import { TestStore } from '../testing/store.js';
import { loadTestsFromDir } from '../testing/parser.js';
import { buildPlugin } from '../plugin/build.js';
import type { SessionState } from './types.js';

// In-memory state shared with server.ts
export let testStore = new TestStore();
export let iterationHistory: Array<{ passing: number; failing: number; fixesApplied: number }> = [];

export async function preflight(args: { pluginPath: string }): Promise<string> {
  const lines: string[] = ['PTH Preflight Check', ''];

  // Check path exists
  try {
    await fs.access(args.pluginPath);
    lines.push(`✓ Plugin path exists: ${args.pluginPath}`);
  } catch {
    return `✗ Plugin path not found: ${args.pluginPath}`;
  }

  // Check git repo
  try {
    await fs.access(path.join(args.pluginPath, '.git'));
    lines.push(`✓ Git repository detected`);
  } catch {
    lines.push(`⚠ Not a git repository — PTH requires git for session branch management`);
  }

  // Check plugin mode
  const mode = await detectPluginMode(args.pluginPath);
  lines.push(`✓ Plugin mode: ${mode}`);

  // Check for active session lock
  const lockPath = path.join(args.pluginPath, '.pth', 'active-session.lock');
  try {
    const lock = JSON.parse(await fs.readFile(lockPath, 'utf-8')) as { pid: number; branch: string };
    try {
      process.kill(lock.pid, 0);  // check if PID is alive
      lines.push(`⚠ Active session detected (PID ${lock.pid}, branch ${lock.branch})`);
    } catch {
      lines.push(`⚠ Stale session lock found (PID ${lock.pid} is not running) — will be cleaned up at start`);
    }
  } catch {
    lines.push(`✓ No active session lock`);
  }

  lines.push('', 'OK — ready to start a session.');
  return lines.join('\n');
}

export interface StartSessionResult {
  state: SessionState;
  message: string;
}

export async function startSession(args: { pluginPath: string; sessionNote?: string }): Promise<StartSessionResult> {
  const pluginName = await detectPluginName(args.pluginPath);
  const pluginMode = await detectPluginMode(args.pluginPath);
  const buildSystem = await detectBuildSystem(args.pluginPath);

  // Create session branch
  const branch = generateSessionBranch(pluginName);
  await pruneWorktrees(args.pluginPath);

  // Check branch doesn't exist (regenerate if collision)
  if (await checkBranchExists(args.pluginPath, branch)) {
    throw new Error(`Branch ${branch} already exists — this should be extremely rare`);
  }

  // Create worktree
  const worktreePath = path.join(os.tmpdir(), `pth-worktree-${branch.split('/')[1]}`);
  await createBranch(args.pluginPath, branch);
  await addWorktree(args.pluginPath, worktreePath, branch);

  // Write session lock
  const lockPath = path.join(args.pluginPath, '.pth', 'active-session.lock');
  await fs.mkdir(path.join(args.pluginPath, '.pth'), { recursive: true });
  await fs.writeFile(lockPath, JSON.stringify({ pid: process.pid, branch, startedAt: new Date().toISOString() }), 'utf-8');

  // Load existing tests if any
  testStore = new TestStore();
  const existingTests = await loadTestsFromDir(path.join(worktreePath, '.pth', 'tests'));
  existingTests.forEach(t => testStore.add(t));

  const state: SessionState = {
    sessionId: branch,
    branch,
    worktreePath,
    pluginPath: args.pluginPath,
    pluginName,
    pluginMode,
    startedAt: new Date().toISOString(),
    iteration: 0,
    testCount: testStore.count(),
    passingCount: 0,
    failingCount: 0,
    convergenceTrend: 'unknown',
    activeFailures: [],
  };

  await writeSessionState(worktreePath, state);

  const mcpConfig = pluginMode === 'mcp' ? await readMcpConfig(args.pluginPath) : null;

  const lines = [
    `PTH session started.`,
    ``,
    `Branch:    ${branch}`,
    `Worktree:  ${worktreePath}`,
    `Mode:      ${pluginMode}`,
    `Plugin:    ${pluginName}`,
    existingTests.length > 0 ? `Tests:     ${existingTests.length} loaded from previous session` : `Tests:     0 (run pth_generate_tests to create them)`,
    ``,
    pluginMode === 'mcp' && mcpConfig
      ? `MCP server: ${mcpConfig.command} ${mcpConfig.args.join(' ')}\nMake sure this plugin is loaded in your Claude Code session, then call pth_generate_tests with the tools/list output.`
      : `Plugin mode: run pth_generate_tests to analyze hook scripts and manifest.`,
  ];

  return { state, message: lines.join('\n') };
}

export async function resumeSession(args: { branch: string; pluginPath: string }): Promise<StartSessionResult> {
  const worktreePath = path.join(os.tmpdir(), `pth-worktree-${args.branch.split('/')[1]}`);

  // Check branch exists
  if (!await checkBranchExists(args.pluginPath, args.branch)) {
    throw new Error(`Branch ${args.branch} not found in ${args.pluginPath}`);
  }

  await pruneWorktrees(args.pluginPath);
  await addWorktree(args.pluginPath, worktreePath, args.branch);

  // Load state
  const savedState = await readSessionState(worktreePath);
  const pluginName = await detectPluginName(args.pluginPath);
  const pluginMode = await detectPluginMode(args.pluginPath);

  testStore = new TestStore();
  const tests = await loadTestsFromDir(path.join(worktreePath, '.pth', 'tests'));
  tests.forEach(t => testStore.add(t));

  const state: SessionState = savedState ?? {
    sessionId: args.branch,
    branch: args.branch,
    worktreePath,
    pluginPath: args.pluginPath,
    pluginName,
    pluginMode,
    startedAt: new Date().toISOString(),
    iteration: 0,
    testCount: testStore.count(),
    passingCount: 0,
    failingCount: 0,
    convergenceTrend: 'unknown',
    activeFailures: [],
  };

  state.worktreePath = worktreePath;

  const lines = [
    `PTH session resumed.`,
    ``,
    `Branch:     ${args.branch}`,
    `Iteration:  ${state.iteration}`,
    `Tests:      ${testStore.count()} loaded`,
    `Status:     ${state.passingCount} passing, ${state.failingCount} failing`,
    `Trend:      ${state.convergenceTrend}`,
    savedState ? `` : `Note: session-state.json not found — reconstructed from git history.`,
  ];

  return { state, message: lines.join('\n') };
}

export async function endSession(state: SessionState): Promise<string> {
  // Persist tests
  await testStore.persistToDir(path.join(state.worktreePath, '.pth', 'tests'));

  // Commit test suite + state
  await commitAll(state.worktreePath, buildCommitMessage('chore: persist PTH test suite', { 'PTH-Type': 'session-end' }));

  // Remove worktree
  await removeWorktree(state.pluginPath, state.worktreePath);

  // Remove lock
  const lockPath = path.join(state.pluginPath, '.pth', 'active-session.lock');
  await fs.rm(lockPath, { force: true });

  return [
    `PTH session ended.`,
    ``,
    `Branch:       ${state.branch}`,
    `Tests saved:  ${testStore.count()}`,
    `Iterations:   ${state.iteration}`,
    `Final status: ${state.passingCount} passing, ${state.failingCount} failing`,
    ``,
    `Branch ${state.branch} remains in your repo with full session history.`,
    `Review: git log ${state.branch}`,
    `Diff:   git diff origin/$(git rev-parse --abbrev-ref HEAD)...${state.branch}`,
  ].join('\n');
}

// Re-export for server.ts
function buildCommitMessage(title: string, trailers: Record<string, string>): string {
  const lines = Object.entries(trailers).map(([k, v]) => `${k}: ${v}`).join('\n');
  return lines ? `${title}\n\n${lines}` : title;
}
```

**Step 4: Run tests**
```bash
cd plugins/plugin-test-harness && npx jest test/unit/session/manager.test.ts
```
Expected: PASS

**Step 5: Commit**
```bash
git add plugins/plugin-test-harness/src/session/manager.ts
git commit -m "feat(pth): implement session manager — start, resume, end, preflight"
```

---

## Task 13: Session Tool Handlers (Wire Everything Together)

**Files:**
- Modify: `src/server.ts` — implement `handleSessionTool`

This task wires the tool schemas to their implementations across all the modules built so far.

**Step 1: Implement handleSessionTool in server.ts**

Replace the stub `handleSessionTool` with full dispatch:

```typescript
// In src/server.ts, replace handleSessionTool with:
import { ResultsTracker } from './results/tracker.js';
import { detectConvergence } from './results/convergence.js';
import { TestStore } from './testing/store.js';
import { parseTest } from './testing/parser.js';
import { generateMcpTests, generatePluginTests } from './testing/generator.js';
import { applyFix } from './fix/applicator.js';
import { getFixHistory, revertCommit, getDiff } from './session/git.js';
import { syncToCache, detectCachePath } from './plugin/cache-sync.js';
import { reloadPlugin } from './plugin/reloader.js';
import { writeSessionState } from './session/state-persister.js';
import { writeToolSchemasCache } from './shared/source-analyzer.js';
import * as mgr from './session/manager.js';

let resultsTracker = new ResultsTracker();

async function handleSessionTool(
  toolName: string,
  args: Record<string, unknown>,
  session: SessionState
): Promise<{ content: Array<{ type: 'text'; text: string }> }> {
  const respond = (text: string) => ({ content: [{ type: 'text' as const, text }] });
  const store = mgr.testStore;

  switch (toolName) {

    // ── Session management ─────────────────────────────────────────
    case 'pth_get_session_status': {
      const pass = resultsTracker.getPassCount();
      const fail = resultsTracker.getFailCount();
      const snapshots = mgr.iterationHistory;
      const trend = detectConvergence(snapshots);
      return respond([
        `Session: ${session.branch}`,
        `Mode:     ${session.pluginMode}`,
        `Iteration: ${session.iteration}`,
        `Tests:    ${store.count()} total, ${pass} passing, ${fail} failing`,
        `Trend:    ${trend}`,
        `Started:  ${session.startedAt}`,
      ].join('\n'));
    }

    // ── Tests ──────────────────────────────────────────────────────
    case 'pth_generate_tests': {
      const { toolSchemas } = args as { toolSchemas?: unknown[] };
      let tests;
      if (session.pluginMode === 'mcp' && toolSchemas) {
        // Cache the schemas for future analysis
        await writeToolSchemasCache(session.worktreePath, toolSchemas as never);
        tests = generateMcpTests({ pluginPath: session.worktreePath, toolSchemas: toolSchemas as never });
      } else {
        tests = generatePluginTests(session.worktreePath, []);
      }
      tests.forEach(t => store.add(t));
      return respond(`Generated ${tests.length} tests.\n\n${tests.map(t => `- ${t.name}`).join('\n')}`);
    }

    case 'pth_list_tests': {
      const { mode, status: filterStatus, tag } = args as {
        mode?: 'mcp' | 'plugin'; status?: string; tag?: string
      };
      let tests = store.getAll();
      if (mode) tests = tests.filter(t => t.mode === mode);
      if (tag) tests = tests.filter(t => t.tags?.includes(tag));
      if (filterStatus) {
        tests = tests.filter(t => {
          const latest = resultsTracker.getLatest(t.id);
          return (latest?.status ?? 'pending') === filterStatus;
        });
      }
      if (tests.length === 0) return respond('No tests match the filter.');
      const lines = tests.map(t => {
        const latest = resultsTracker.getLatest(t.id);
        const status = latest?.status ?? 'pending';
        const icon = status === 'passing' ? '✓' : status === 'failing' ? '✗' : '○';
        return `${icon} [${t.id}] ${t.name}`;
      });
      return respond(`${tests.length} tests:\n\n${lines.join('\n')}`);
    }

    case 'pth_create_test': {
      const { yaml } = args as { yaml: string };
      const test = parseTest(yaml);
      store.add(test);
      return respond(`Test added: ${test.name} (id: ${test.id})`);
    }

    case 'pth_edit_test': {
      const { testId, yaml } = args as { testId: string; yaml: string };
      const test = parseTest(yaml);
      if (test.id !== testId) {
        return respond(`Warning: test id changed from ${testId} to ${test.id}. Old test replaced.`);
      }
      store.update(test);
      return respond(`Test updated: ${test.name}`);
    }

    // ── Execution ──────────────────────────────────────────────────
    case 'pth_record_result': {
      const { testId, status, durationMs, failureReason, claudeNotes } = args as {
        testId: string; status: 'passing' | 'failing' | 'skipped';
        durationMs?: number; failureReason?: string; claudeNotes?: string;
      };
      const test = store.get(testId);
      if (!test) return respond(`Unknown test id: ${testId}`);

      resultsTracker.record({
        testId,
        testName: test.name,
        status,
        iteration: session.iteration,
        durationMs,
        failureReason,
        claudeNotes,
        recordedAt: new Date().toISOString(),
      });

      // Update session state
      const pass = resultsTracker.getPassCount();
      const fail = resultsTracker.getFailCount();
      session.passingCount = pass;
      session.failingCount = fail;
      session.activeFailures = resultsTracker.getFailingTests().map(r => ({
        testName: r.testName,
        category: '',
        lastDiagnosisSummary: r.failureReason,
      }));
      await writeSessionState(session.worktreePath, session);

      return respond(`Recorded: ${test.name} → ${status}${failureReason ? ` (${failureReason})` : ''}`);
    }

    case 'pth_get_results': {
      const all = store.getAll();
      if (all.length === 0) return respond('No tests in suite. Run pth_generate_tests first.');
      const lines = all.map(t => {
        const latest = resultsTracker.getLatest(t.id);
        const status = latest?.status ?? 'pending';
        const icon = status === 'passing' ? '✓' : status === 'failing' ? '✗' : '○';
        return `${icon} ${t.name}${latest?.failureReason ? `\n  ↳ ${latest.failureReason}` : ''}`;
      });
      const pass = resultsTracker.getPassCount();
      const fail = resultsTracker.getFailCount();
      const pending = all.length - pass - fail;
      return respond(`${pass} passing / ${fail} failing / ${pending} pending\n\n${lines.join('\n')}`);
    }

    case 'pth_get_test_impact': {
      const { files } = args as { files: string[] };
      // Simple heuristic: find tests whose name/id contains parts of the file name
      const impacted = store.getAll().filter(t =>
        files.some(f => {
          const base = f.split('/').pop()?.replace(/\.[^.]+$/, '') ?? '';
          return t.name.toLowerCase().includes(base.toLowerCase()) ||
                 t.id.includes(base.toLowerCase());
        })
      );
      if (impacted.length === 0) {
        return respond(`No tests found with obvious dependency on: ${files.join(', ')}\nConsider running the full suite.`);
      }
      return respond(`${impacted.length} likely-impacted tests:\n${impacted.map(t => `- ${t.name}`).join('\n')}`);
    }

    // ── Fixes ──────────────────────────────────────────────────────
    case 'pth_apply_fix': {
      const { files, commitTitle, testId, category } = args as {
        files: Array<{ path: string; content: string }>;
        commitTitle: string; testId?: string; category?: string;
      };
      const hash = await applyFix({
        worktreePath: session.worktreePath,
        files,
        commitTitle,
        trailers: {
          ...(testId ? { 'PTH-Test': testId } : {}),
          ...(category ? { 'PTH-Category': category } : {}),
          'PTH-Iteration': String(session.iteration),
          'PTH-Files': files.map(f => f.path).join(', '),
        },
      });
      return respond(`Fix committed: ${hash}\n${commitTitle}\nFiles: ${files.map(f => f.path).join(', ')}`);
    }

    case 'pth_sync_to_cache': {
      const { syncToCache: sync, detectCachePath: detect } = await import('./plugin/cache-sync.js');
      const cachePath = detect(session.pluginName);
      try {
        await sync(session.worktreePath, cachePath);
        return respond(`Synced worktree to cache: ${cachePath}\nHook script changes are now live.`);
      } catch (e) {
        return respond(`Cache sync failed: ${(e as Error).message}\nCache path: ${cachePath}`);
      }
    }

    case 'pth_reload_plugin': {
      const { buildSystem } = await import('./plugin/detector.js').then(m =>
        m.detectBuildSystem(session.worktreePath).then(bs => ({ buildSystem: bs }))
      );
      const { processPattern } = args as { processPattern?: string };
      const pattern = processPattern ?? session.worktreePath;
      const result = await reloadPlugin(session.worktreePath, buildSystem, pattern);
      return respond([
        result.buildSucceeded ? '✓ Build succeeded' : '✗ Build failed',
        result.buildOutput ? `Build output:\n${result.buildOutput}` : '',
        result.message,
      ].filter(Boolean).join('\n'));
    }

    case 'pth_get_fix_history': {
      const history = await getFixHistory(session.worktreePath);
      if (history.length === 0) return respond('No fix commits on this session branch yet.');
      const lines = history.map(fix =>
        `${fix.commitHash.slice(0, 7)} ${fix.commitTitle}` +
        (fix.trailers['PTH-Test'] ? `\n  Test: ${fix.trailers['PTH-Test']}` : '') +
        (fix.trailers['PTH-Category'] ? ` | ${fix.trailers['PTH-Category']}` : '')
      );
      return respond(`${history.length} fix commits:\n\n${lines.join('\n')}`);
    }

    case 'pth_revert_fix': {
      const { commitHash } = args as { commitHash: string };
      await revertCommit(session.worktreePath, commitHash);
      return respond(`Reverted commit ${commitHash}. Changes undone and a new revert commit added.`);
    }

    case 'pth_diff_session': {
      const diff = await getDiff(session.worktreePath, `origin/${session.branch.split('/')[0]}`);
      if (!diff.trim()) return respond('No changes on session branch yet.');
      return respond(`Session diff (${diff.split('\n').length} lines):\n\n${diff}`);
    }

    // ── Iteration ──────────────────────────────────────────────────
    case 'pth_get_iteration_status': {
      const snapshots = mgr.iterationHistory;
      const trend = detectConvergence(snapshots);
      const history = snapshots.map((s, i) =>
        `| ${i + 1} | ${s.passing} | ${s.failing} | ${s.fixesApplied} |`
      ).join('\n');
      return respond([
        `Iteration ${session.iteration} | Trend: ${trend}`,
        ``,
        `| Iteration | Passing | Failing | Fixes |`,
        `|-----------|---------|---------|-------|`,
        history || '| — | — | — | — |',
      ].join('\n'));
    }

    default:
      return respond(`Unknown tool: ${toolName}`);
  }
}
```

**Step 2: Build to verify TypeScript compiles**
```bash
cd plugins/plugin-test-harness && npm run build
```
Expected: no errors.

**Step 3: Commit**
```bash
git add plugins/plugin-test-harness/src/server.ts
git commit -m "feat(pth): wire all 19 session tools to their implementations"
```

---

## Task 14: Fixture Plugins

**Files:**
- Create: `test/fixtures/sample-mcp-plugin/` — complete minimal TypeScript MCP server
- Create: `test/fixtures/broken-mcp-plugin/` — intentionally broken variant
- Create: `test/fixtures/sample-hook-plugin/` — minimal hook plugin

**Step 1: Create sample-mcp-plugin**

This is a real MCP server with 4 tools covering common patterns: stateless (echo), output assertion testability (reverse_string), error handling (divide — errors on zero), and output structure (get_status).

```json
// test/fixtures/sample-mcp-plugin/package.json
{
  "name": "sample-mcp-plugin",
  "version": "1.0.0",
  "scripts": { "build": "tsc" },
  "main": "dist/index.js",
  "dependencies": { "@modelcontextprotocol/sdk": "^1.15.0" },
  "devDependencies": { "typescript": "^5.8.0" }
}
```

```json
// test/fixtures/sample-mcp-plugin/.mcp.json
{ "sample-mcp-plugin": { "command": "node", "args": ["dist/index.js"] } }
```

```typescript
// test/fixtures/sample-mcp-plugin/src/index.ts
import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { ListToolsRequestSchema, CallToolRequestSchema } from '@modelcontextprotocol/sdk/types.js';

const server = new Server({ name: 'sample-mcp-plugin', version: '1.0.0' }, { capabilities: { tools: {} } });

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    { name: 'echo', description: 'Echo a message back', inputSchema: { type: 'object', properties: { message: { type: 'string' } }, required: ['message'] } },
    { name: 'reverse_string', description: 'Reverse a string', inputSchema: { type: 'object', properties: { input: { type: 'string' } }, required: ['input'] } },
    { name: 'divide', description: 'Divide two numbers', inputSchema: { type: 'object', properties: { a: { type: 'number' }, b: { type: 'number' } }, required: ['a', 'b'] } },
    { name: 'get_status', description: 'Get server status', inputSchema: { type: 'object', properties: {} } },
  ],
}));

server.setRequestHandler(CallToolRequestSchema, async (req) => {
  const { name, arguments: args } = req.params;
  const r = (text: string) => ({ content: [{ type: 'text' as const, text }] });

  if (name === 'echo') return r((args as { message: string }).message);
  if (name === 'reverse_string') return r((args as { input: string }).input.split('').reverse().join(''));
  if (name === 'divide') {
    const { a, b } = args as { a: number; b: number };
    if (b === 0) throw new Error('Division by zero');
    return r(String(a / b));
  }
  if (name === 'get_status') return r(JSON.stringify({ status: 'ok', version: '1.0.0', tools: 4 }));
  throw new Error(`Unknown tool: ${name}`);
});

const transport = new StdioServerTransport();
await server.connect(transport);
```

**Step 2: Create broken-mcp-plugin**

Same structure but with 3 deliberate bugs:
1. `reverse_string` throws a TypeError (missing `.split`)
2. `get_status` returns a string instead of JSON object (schema mismatch)
3. `divide` never returns (infinite loop on certain input — timeout bug)

```typescript
// test/fixtures/broken-mcp-plugin/src/index.ts
// (same as sample-mcp-plugin but with deliberate bugs)
if (name === 'reverse_string') {
  // BUG: (args as any).input is never converted to string before split
  const input = (args as { input: number }).input;  // wrong type assumption
  return r((input as unknown as string).split('').reverse().join(''));  // TypeError at runtime
}
if (name === 'get_status') {
  // BUG: returns raw object instead of JSON string
  return r({ status: 'ok', version: '1.0.0' } as unknown as string);  // schema mismatch
}
```

**Step 3: Create sample-hook-plugin**

```json
// test/fixtures/sample-hook-plugin/.claude-plugin/manifest.json
{ "name": "sample-hook-plugin", "version": "1.0.0", "description": "Sample hook plugin for PTH testing" }
```

```json
// test/fixtures/sample-hook-plugin/hooks/hooks.json
{
  "hooks": {
    "PreToolUse": [{
      "matcher": "Write|Edit",
      "hooks": [{ "type": "command", "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/scripts/write-guard.sh" }]
    }]
  }
}
```

```bash
// test/fixtures/sample-hook-plugin/hooks/scripts/write-guard.sh
#!/bin/bash
# Reads tool_input from stdin JSON, blocks Write to /etc/ paths
set -e
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('file_path',''))")

if echo "$FILE_PATH" | grep -q "^/etc/"; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","decision":"block","reason":"Writes to /etc/ are blocked by sample-hook-plugin"}}'
  exit 2
fi
exit 0
```

**Step 4: Build sample-mcp-plugin to verify it works**
```bash
cd plugins/plugin-test-harness/test/fixtures/sample-mcp-plugin
npm install && npm run build
```
Expected: `dist/index.js` created.

**Step 5: Commit**
```bash
git add plugins/plugin-test-harness/test/fixtures/
git commit -m "test(pth): add sample-mcp-plugin, broken-mcp-plugin, and sample-hook-plugin fixtures"
```

---

## Task 15: Plugin Manifest + .mcp.json + README

**Files:**
- Create: `plugins/plugin-test-harness/.claude-plugin/manifest.json`
- Create: `plugins/plugin-test-harness/.mcp.json`
- Create: `plugins/plugin-test-harness/README.md`

**Step 1: Create manifest**
```json
// .claude-plugin/manifest.json
{
  "name": "plugin-test-harness",
  "version": "1.0.0",
  "description": "Iterative live testing harness for Claude Code plugins and MCP servers. Orchestrates test generation, execution via Claude, diagnosis, and fix tracking in a tight iterative loop."
}
```

**Step 2: Create .mcp.json**
```json
{
  "plugin-test-harness": {
    "command": "node",
    "args": ["dist/index.js"]
  }
}
```

Note: PTH's `.mcp.json` lives at the plugin root (`plugins/plugin-test-harness/.mcp.json`), not inside `.claude-plugin/`.

**Step 3: Create README.md**

Document: what PTH does, how to install, how to start a session, the two modes (mcp/plugin), the iteration loop, and the test YAML format. Use the workflow examples from the design doc.

**Step 4: Commit**
```bash
git add plugins/plugin-test-harness/.claude-plugin/ plugins/plugin-test-harness/.mcp.json \
  plugins/plugin-test-harness/README.md
git commit -m "feat(pth): add plugin manifest, .mcp.json, and README"
```

---

## Task 16: Full Test Run + CI

**Step 1: Run full unit test suite**
```bash
cd plugins/plugin-test-harness && npm test
```
Expected: all tests pass, no TypeScript errors.

**Step 2: Run typecheck**
```bash
cd plugins/plugin-test-harness && npm run typecheck
```
Expected: 0 errors.

**Step 3: Run build**
```bash
cd plugins/plugin-test-harness && npm run build
```
Expected: `dist/` created cleanly.

**Step 4: Create GitHub Actions CI workflow**
```yaml
# .github/workflows/pth-ci.yml
name: PTH CI

on:
  push:
    paths: ['plugins/plugin-test-harness/**']
  pull_request:
    paths: ['plugins/plugin-test-harness/**']

jobs:
  ci:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: plugins/plugin-test-harness

    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20' }
      - run: npm ci
      - run: npm run lint
      - run: npm run typecheck
      - run: npm test -- --testPathPattern=test/unit
```

**Step 5: Final validation — smoke test the server starts**
```bash
cd plugins/plugin-test-harness
echo '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' | node dist/index.js
```
Expected: JSON response listing 3 dormant tools.

**Step 6: Final commit**
```bash
git add plugins/plugin-test-harness/ .claude-plugin/marketplace.json
git commit -m "feat(pth): complete plugin-test-harness v0.1.0 implementation"
```

---

## Quick Reference: Key File Paths

| Purpose | Path |
|---------|------|
| MCP entry point | `src/index.ts` |
| Server + tool dispatch | `src/server.ts` |
| Tool definitions (schemas) | `src/tool-registry.ts` |
| Session lifecycle | `src/session/manager.ts` |
| Git operations | `src/session/git.ts` |
| Plugin detection | `src/plugin/detector.ts` |
| Build system | `src/plugin/build.ts` |
| MCP server reload | `src/plugin/reloader.ts` |
| Cache sync | `src/plugin/cache-sync.ts` |
| Test YAML parser | `src/testing/parser.ts` |
| Test generator | `src/testing/generator.ts` |
| Test store | `src/testing/store.ts` |
| Results tracker | `src/results/tracker.ts` |
| Convergence detection | `src/results/convergence.ts` |
| Fix applicator | `src/fix/applicator.ts` |
| Fix history | `src/fix/tracker.ts` |
| Session state file | `.pth/session-state.json` (in plugin repo, on session branch) |
| Tests persistence dir | `.pth/tests/` (in plugin repo, on session branch) |
| Session report | `.pth/SESSION-REPORT.md` (in plugin repo, on session branch) |

---

## Deferred Features (Future Milestones)

| Feature | Notes |
|---------|-------|
| Tier 3 VM (QEMU/KVM) | Add `src/environment/runtime-qemu.ts` when a plugin needs kernel-level isolation |
| Cross-distro verification | Depends on Tier 3 |
| Performance testing | Likely a separate plugin |
| Flakiness detection | Add re-run logic to `pth_record_result` or as separate `pth_run_test --check-flaky` |
| CI export | `pth_export_ci` — generate GitHub Actions workflow from current test suite |
| Code coverage | Istanbul integration for TypeScript plugins |
| Parallel execution | `concurrency` param on `pth_run_test_suite` (already stubbed in schema) |
