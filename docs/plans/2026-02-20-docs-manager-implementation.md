# docs-manager Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a Claude Code plugin that manages the full documentation lifecycle — detecting changes via hooks, queuing documentation tasks silently, and surfacing them for batch review at session boundaries.

**Architecture:** Hook-based detection (PostToolUse/Stop) feeds a persistent JSON queue. Bash scripts handle all state management outside the context window. A dual-index system (JSON + Markdown mirror) tracks documents across machines via git. A single `/docs` command routes to subcommands; skills provide contextual awareness; agents handle bulk operations. The `git-markdown` index backend is implemented first (the default).

**Tech Stack:** Bash (scripts, hooks), Markdown (commands, skills, agents), JSON (queue, index), YAML (frontmatter, config), jq (JSON manipulation), bats (testing), Python 3 (frontmatter parsing in hooks)

**Design Reference:** `plugins/docs-manager/docs/design.md` — the authoritative specification. Section references (§N) point there.

**Open Questions Resolved:**
- OQ1 (hosted-api migration): Deferred — only `git-markdown` and `json` backends in initial implementation
- OQ2 (dismiss policy): Reason required before dismiss; items logged to session history file

---

## Prerequisites

| Tool | Required | Check | Purpose |
|------|----------|-------|---------|
| `jq` | Yes | `jq --version` | JSON manipulation in all scripts |
| `python3` | Yes | `python3 --version` | YAML frontmatter parsing |
| `git` | Yes | `git --version` | Index backend (git-markdown) |
| `bats` | For testing | `bats --version` | Bash script unit tests |

If `bats` is not installed: `sudo dnf install bats` (Fedora) or `npm install -g bats`.

---

## File Inventory

Every file this plan creates, grouped by purpose.

### Plugin Scaffold
```
plugins/docs-manager/.claude-plugin/plugin.json
plugins/docs-manager/CHANGELOG.md
.claude-plugin/marketplace.json                    (modify — add entry)
```

### Hook Configuration
```
plugins/docs-manager/hooks/hooks.json
```

### Scripts — Core Engine
```
plugins/docs-manager/scripts/bootstrap.sh          State directory init
plugins/docs-manager/scripts/queue-append.sh        Append item to queue
plugins/docs-manager/scripts/queue-read.sh          Read/display queue
plugins/docs-manager/scripts/queue-clear.sh         Clear queue with reason
plugins/docs-manager/scripts/queue-merge-fallback.sh  Merge fallback → main queue
plugins/docs-manager/scripts/frontmatter-read.sh    Extract YAML frontmatter
plugins/docs-manager/scripts/is-survival-context.sh P5 classification check
plugins/docs-manager/scripts/post-tool-use.sh       PostToolUse hook handler
plugins/docs-manager/scripts/stop.sh                Stop hook handler
```

### Scripts — Index Operations
```
plugins/docs-manager/scripts/index-register.sh      Register doc in index
plugins/docs-manager/scripts/index-query.sh         Query index
plugins/docs-manager/scripts/index-rebuild-md.sh    Regenerate docs-index.md
plugins/docs-manager/scripts/index-lock.sh          Acquire write lock
plugins/docs-manager/scripts/index-unlock.sh        Release write lock
plugins/docs-manager/scripts/index-source-lookup.sh Check if file is in source-files
```

### Commands
```
plugins/docs-manager/commands/docs.md               Main /docs command router
```

### Skills
```
plugins/docs-manager/skills/project-entry/SKILL.md      Project-entry freshness
plugins/docs-manager/skills/doc-creation/SKILL.md        Doc creation awareness
plugins/docs-manager/skills/session-boundary/SKILL.md    Session-end queue reminder
```

### Agents
```
plugins/docs-manager/agents/bulk-onboard.md         Bulk import agent
plugins/docs-manager/agents/full-review.md          Comprehensive review agent
plugins/docs-manager/agents/upstream-verify.md      Upstream verification agent
```

### Tests
```
plugins/docs-manager/tests/helpers.bash             Shared test helpers
plugins/docs-manager/tests/queue.bats               Queue script tests
plugins/docs-manager/tests/utilities.bats           Frontmatter/classifier tests
plugins/docs-manager/tests/detection.bats           Hook detection tests
plugins/docs-manager/tests/index.bats               Index operation tests
plugins/docs-manager/tests/fixtures/
  doc-with-frontmatter.md
  doc-without-frontmatter.md
  doc-ai-audience.md
  sample-queue.json
  sample-index.json
  sample-config.yaml
```

---

## Dependency Graph

```
Phase 1: Scaffold ──────────────────────────────┐
Phase 2: Queue System ──────────────────────────┤
Phase 3: Shared Utilities ──────────────────────┤
Phase 4: Hook Scripts (depends on 2+3) ─────────┤
Phase 5: Core Commands (depends on 2+4) ────────┘ ← MVP MILESTONE
                                                │
Phase 6: Index System ──────────────────────────┤
Phase 7: Index Commands (depends on 6) ─────────┤
Phase 8: Doc Lifecycle (depends on 6+7) ────────┤
Phase 9: Maintenance Commands (depends on 8) ───┤
Phase 10: Upstream Verification (depends on 6) ─┤
Phase 11: Skills ───────────────────────────────┤
Phase 12: Agents (depends on 6+8) ─────────────┤
Phase 13: Polish & Release ─────────────────────┘
```

---

## Phase 1: Plugin Scaffold

### Task 1: Create Plugin Manifest and Marketplace Entry

**Files:**
- Create: `plugins/docs-manager/.claude-plugin/plugin.json`
- Create: `plugins/docs-manager/CHANGELOG.md`
- Modify: `.claude-plugin/marketplace.json`

**Step 1: Create plugin.json**

```json
{
  "name": "docs-manager",
  "description": "Documentation lifecycle management — detects changes, queues tasks silently, surfaces them for batch review at session boundaries.",
  "version": "0.1.0",
  "author": {
    "name": "L3DigitalNet",
    "url": "https://github.com/L3DigitalNet"
  }
}
```

**Step 2: Create CHANGELOG.md**

```markdown
# Changelog

All notable changes to the docs-manager plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Added
- Initial plugin scaffold
```

**Step 3: Add marketplace entry**

Add to `.claude-plugin/marketplace.json` `plugins` array:
```json
{
  "name": "docs-manager",
  "description": "Documentation lifecycle management — detects changes, queues tasks silently, surfaces them for batch review at session boundaries.",
  "version": "0.1.0",
  "author": { "name": "L3DigitalNet", "url": "https://github.com/L3DigitalNet" },
  "category": "documentation",
  "homepage": "https://github.com/L3DigitalNet/Claude-Code-Plugins/tree/main/plugins/docs-manager",
  "source": "./plugins/docs-manager"
}
```

**Step 4: Validate marketplace**

Run: `./scripts/validate-marketplace.sh`
Expected: PASS (no validation errors)

**Step 5: Commit**

```bash
git add plugins/docs-manager/.claude-plugin/plugin.json plugins/docs-manager/CHANGELOG.md .claude-plugin/marketplace.json
git commit -m "feat(docs-manager): add plugin scaffold and marketplace entry"
```

---

### Task 2: State Directory Bootstrap Script

**Files:**
- Create: `plugins/docs-manager/scripts/bootstrap.sh`
- Test: `plugins/docs-manager/tests/helpers.bash` (shared helpers — created here, used by all tests)

**Step 1: Create shared test helpers**

```bash
# tests/helpers.bash — sourced by all .bats test files
# Sets up isolated temp environment so tests never touch ~/.docs-manager/

setup_test_env() {
    export DOCS_MANAGER_HOME="$BATS_TMPDIR/docs-manager-test-$$"
    export SCRIPTS_DIR="$BATS_TEST_DIRNAME/../scripts"
    mkdir -p "$DOCS_MANAGER_HOME"
}

teardown_test_env() {
    rm -rf "$DOCS_MANAGER_HOME"
}
```

**Step 2: Write failing test for bootstrap**

Create `tests/queue.bats` (we'll add queue tests to this file in Task 3):
```bash
#!/usr/bin/env bats

load helpers

setup() { setup_test_env; }
teardown() { teardown_test_env; }

@test "bootstrap creates state directory structure" {
    run bash "$SCRIPTS_DIR/bootstrap.sh"
    [ "$status" -eq 0 ]
    [ -d "$DOCS_MANAGER_HOME" ]
    [ -d "$DOCS_MANAGER_HOME/hooks" ]
    [ -d "$DOCS_MANAGER_HOME/cache" ]
}

@test "bootstrap creates queue.json if missing" {
    run bash "$SCRIPTS_DIR/bootstrap.sh"
    [ "$status" -eq 0 ]
    [ -f "$DOCS_MANAGER_HOME/queue.json" ]
    run jq '.items | length' "$DOCS_MANAGER_HOME/queue.json"
    [ "$output" = "0" ]
}

@test "bootstrap is idempotent — does not overwrite existing queue" {
    mkdir -p "$DOCS_MANAGER_HOME"
    echo '{"created":"2026-01-01T00:00:00Z","items":[{"id":"q-001"}]}' > "$DOCS_MANAGER_HOME/queue.json"
    run bash "$SCRIPTS_DIR/bootstrap.sh"
    [ "$status" -eq 0 ]
    run jq '.items | length' "$DOCS_MANAGER_HOME/queue.json"
    [ "$output" = "1" ]
}
```

**Step 3: Verify tests fail**

Run: `bats plugins/docs-manager/tests/queue.bats`
Expected: FAIL (bootstrap.sh does not exist)

**Step 4: Implement bootstrap.sh**

```bash
#!/usr/bin/env bash
# Creates ~/.docs-manager/ directory structure and empty queue.
# Called on first plugin use or by /docs setup. Idempotent.
set -euo pipefail

DOCS_MANAGER_HOME="${DOCS_MANAGER_HOME:-$HOME/.docs-manager}"

main() {
    mkdir -p "$DOCS_MANAGER_HOME"/{hooks,cache}

    if [[ ! -f "$DOCS_MANAGER_HOME/queue.json" ]]; then
        printf '{"created":"%s","items":[]}\n' \
            "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
            > "$DOCS_MANAGER_HOME/queue.json"
    fi

    echo "docs-manager initialized at $DOCS_MANAGER_HOME"
}

if ! main "$@"; then
    echo "⚠ docs-manager bootstrap failed" >&2
    exit 1
fi
```

**Step 5: Verify tests pass**

Run: `bats plugins/docs-manager/tests/queue.bats`
Expected: 3 tests, 3 passed

**Step 6: Commit**

```bash
git add plugins/docs-manager/scripts/bootstrap.sh plugins/docs-manager/tests/
git commit -m "feat(docs-manager): add state bootstrap script with tests"
```

---

## Phase 2: Queue System

### Task 3: Queue Append Script

**Files:**
- Create: `plugins/docs-manager/scripts/queue-append.sh`
- Modify: `plugins/docs-manager/tests/queue.bats`

**Step 1: Write failing tests**

Append to `tests/queue.bats`:

```bash
@test "queue-append adds item to empty queue" {
    bash "$SCRIPTS_DIR/bootstrap.sh"
    run bash "$SCRIPTS_DIR/queue-append.sh" \
        --type "doc-modified" \
        --doc-path "/tmp/test.md" \
        --library "test-lib" \
        --trigger "direct-write"
    [ "$status" -eq 0 ]
    run jq '.items | length' "$DOCS_MANAGER_HOME/queue.json"
    [ "$output" = "1" ]
    run jq -r '.items[0].type' "$DOCS_MANAGER_HOME/queue.json"
    [ "$output" = "doc-modified" ]
}

@test "queue-append generates sequential IDs" {
    bash "$SCRIPTS_DIR/bootstrap.sh"
    bash "$SCRIPTS_DIR/queue-append.sh" --type "doc-modified" --doc-path "/tmp/a.md" --library "lib" --trigger "direct-write"
    bash "$SCRIPTS_DIR/queue-append.sh" --type "doc-modified" --doc-path "/tmp/b.md" --library "lib" --trigger "direct-write"
    run jq -r '.items[1].id' "$DOCS_MANAGER_HOME/queue.json"
    [ "$output" = "q-002" ]
}

@test "queue-append deduplicates same doc-path + type" {
    bash "$SCRIPTS_DIR/bootstrap.sh"
    bash "$SCRIPTS_DIR/queue-append.sh" --type "doc-modified" --doc-path "/tmp/a.md" --library "lib" --trigger "direct-write"
    bash "$SCRIPTS_DIR/queue-append.sh" --type "doc-modified" --doc-path "/tmp/a.md" --library "lib" --trigger "direct-write"
    run jq '.items | length' "$DOCS_MANAGER_HOME/queue.json"
    [ "$output" = "1" ]
}

@test "queue-append includes source-file when provided" {
    bash "$SCRIPTS_DIR/bootstrap.sh"
    run bash "$SCRIPTS_DIR/queue-append.sh" \
        --type "source-file-changed" \
        --doc-path "/tmp/readme.md" \
        --library "lib" \
        --trigger "source-file-association" \
        --source-file "/etc/caddy/Caddyfile"
    [ "$status" -eq 0 ]
    run jq -r '.items[0]["source-file"]' "$DOCS_MANAGER_HOME/queue.json"
    [ "$output" = "/etc/caddy/Caddyfile" ]
}

@test "queue-append writes to fallback on main queue write failure" {
    bash "$SCRIPTS_DIR/bootstrap.sh"
    # Make queue.json unwritable
    chmod 444 "$DOCS_MANAGER_HOME/queue.json"
    run bash "$SCRIPTS_DIR/queue-append.sh" --type "doc-modified" --doc-path "/tmp/a.md" --library "lib" --trigger "direct-write"
    [ "$status" -eq 0 ]  # Always exits 0
    [ -f "$DOCS_MANAGER_HOME/queue.fallback.json" ]
    chmod 644 "$DOCS_MANAGER_HOME/queue.json"  # cleanup
}

@test "queue-append always exits 0 even on error" {
    # No bootstrap — DOCS_MANAGER_HOME doesn't exist properly
    export DOCS_MANAGER_HOME="$BATS_TMPDIR/nonexistent-$$"
    run bash "$SCRIPTS_DIR/queue-append.sh" --type "doc-modified" --doc-path "/tmp/a.md" --library "lib" --trigger "direct-write"
    [ "$status" -eq 0 ]
}
```

**Step 2: Verify tests fail**

Run: `bats plugins/docs-manager/tests/queue.bats`
Expected: New tests FAIL (queue-append.sh does not exist)

**Step 3: Implement queue-append.sh**

```bash
#!/usr/bin/env bash
# Appends a detection event to the docs-manager queue.
# Called by hook scripts. ALWAYS exits 0 — failures go to fallback queue.
# §9.1, §7.3 in design.md
set -euo pipefail

DOCS_MANAGER_HOME="${DOCS_MANAGER_HOME:-$HOME/.docs-manager}"
QUEUE_FILE="$DOCS_MANAGER_HOME/queue.json"
FALLBACK_FILE="$DOCS_MANAGER_HOME/queue.fallback.json"

main() {
    local type="" doc_path="" library="" trigger="" source_file="" priority="standard"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --type)        type="$2";        shift 2 ;;
            --doc-path)    doc_path="$2";    shift 2 ;;
            --library)     library="$2";     shift 2 ;;
            --trigger)     trigger="$2";     shift 2 ;;
            --source-file) source_file="$2"; shift 2 ;;
            --priority)    priority="$2";    shift 2 ;;
            *) return 1 ;;
        esac
    done

    [[ -z "$type" || -z "$doc_path" || -z "$library" || -z "$trigger" ]] && return 1

    # Ensure queue exists
    if [[ ! -f "$QUEUE_FILE" ]]; then
        mkdir -p "$(dirname "$QUEUE_FILE")"
        printf '{"created":"%s","items":[]}\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$QUEUE_FILE"
    fi

    # Deduplicate: skip if same doc-path + type already pending
    local exists
    exists=$(jq --arg dp "$doc_path" --arg t "$type" \
        '[.items[] | select(.["doc-path"] == $dp and .type == $t and .status == "pending")] | length' \
        "$QUEUE_FILE" 2>/dev/null || echo "0")
    [[ "$exists" -gt 0 ]] && return 0

    # Generate next ID
    local count
    count=$(jq '.items | length' "$QUEUE_FILE" 2>/dev/null || echo "0")
    local id
    id=$(printf "q-%03d" $((count + 1)))

    # Build entry
    local now
    now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    local entry
    entry=$(jq -n \
        --arg id "$id" --arg type "$type" --arg doc_path "$doc_path" \
        --arg library "$library" --arg detected_at "$now" \
        --arg trigger "$trigger" --arg priority "$priority" \
        --arg source_file "$source_file" \
        '{id:$id, type:$type, "doc-path":$doc_path, library:$library,
          "detected-at":$detected_at, trigger:$trigger, priority:$priority,
          status:"pending", note:null}
         + (if $source_file != "" then {"source-file":$source_file} else {} end)')

    # Append atomically (temp file + mv)
    local tmp="$QUEUE_FILE.tmp.$$"
    if jq --argjson entry "$entry" '.items += [$entry]' "$QUEUE_FILE" > "$tmp" 2>/dev/null; then
        mv "$tmp" "$QUEUE_FILE"
    else
        rm -f "$tmp"
        # Fallback queue
        if [[ -f "$FALLBACK_FILE" ]]; then
            local ftmp="$FALLBACK_FILE.tmp.$$"
            jq --argjson entry "$entry" '.items += [$entry]' "$FALLBACK_FILE" > "$ftmp" 2>/dev/null \
                && mv "$ftmp" "$FALLBACK_FILE" || rm -f "$ftmp"
        else
            printf '{"created":"%s","items":[%s]}\n' "$now" "$entry" > "$FALLBACK_FILE"
        fi
        echo "⚠ Queue write failed — item saved to fallback queue"
    fi
}

if ! main "$@"; then
    echo "⚠ docs-manager queue-append: missing required arguments"
fi
exit 0
```

Make executable: `chmod +x plugins/docs-manager/scripts/queue-append.sh`

**Step 4: Verify tests pass**

Run: `bats plugins/docs-manager/tests/queue.bats`
Expected: All tests pass

**Step 5: Commit**

```bash
git add plugins/docs-manager/scripts/queue-append.sh plugins/docs-manager/tests/queue.bats
git commit -m "feat(docs-manager): add queue append script with dedup and fallback"
```

---

### Task 4: Queue Read Script

**Files:**
- Create: `plugins/docs-manager/scripts/queue-read.sh`
- Modify: `plugins/docs-manager/tests/queue.bats`

**Step 1: Write failing tests**

Append to `tests/queue.bats`:

```bash
@test "queue-read outputs empty message for empty queue" {
    bash "$SCRIPTS_DIR/bootstrap.sh"
    run bash "$SCRIPTS_DIR/queue-read.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"empty"* ]] || [[ "$output" == *"0 items"* ]]
}

@test "queue-read outputs item count and details" {
    bash "$SCRIPTS_DIR/bootstrap.sh"
    bash "$SCRIPTS_DIR/queue-append.sh" --type "doc-modified" --doc-path "/tmp/a.md" --library "lib" --trigger "direct-write"
    run bash "$SCRIPTS_DIR/queue-read.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"1"* ]]
    [[ "$output" == *"/tmp/a.md"* ]]
}

@test "queue-read --json outputs valid JSON" {
    bash "$SCRIPTS_DIR/bootstrap.sh"
    bash "$SCRIPTS_DIR/queue-append.sh" --type "doc-modified" --doc-path "/tmp/a.md" --library "lib" --trigger "direct-write"
    run bash "$SCRIPTS_DIR/queue-read.sh" --json
    [ "$status" -eq 0 ]
    echo "$output" | jq . > /dev/null 2>&1  # valid JSON
}

@test "queue-read merges fallback queue before reading" {
    bash "$SCRIPTS_DIR/bootstrap.sh"
    # Simulate fallback queue with one item
    printf '{"created":"2026-01-01T00:00:00Z","items":[{"id":"fb-001","type":"doc-modified","doc-path":"/tmp/fb.md","library":"lib","detected-at":"2026-01-01T00:00:00Z","trigger":"direct-write","priority":"standard","status":"pending","note":null}]}\n' \
        > "$DOCS_MANAGER_HOME/queue.fallback.json"
    run bash "$SCRIPTS_DIR/queue-read.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"/tmp/fb.md"* ]]
    [ ! -f "$DOCS_MANAGER_HOME/queue.fallback.json" ]  # fallback consumed
}
```

**Step 2: Verify fail, implement, verify pass**

`queue-read.sh` specification:
- Reads `$DOCS_MANAGER_HOME/queue.json`
- If fallback queue exists, merges it into main queue first (then deletes fallback)
- Default output: human-readable summary (count + table of items)
- `--json` flag: outputs raw queue JSON
- `--status <status>` flag: filter by status
- `--count` flag: outputs just the item count (integer)
- Items sorted by priority (critical first) then detected-at
- Always exits 0

**Step 3: Commit**

```bash
git add plugins/docs-manager/scripts/queue-read.sh plugins/docs-manager/tests/queue.bats
git commit -m "feat(docs-manager): add queue read script with fallback merge"
```

---

### Task 5: Queue Clear and Fallback Merge Scripts

**Files:**
- Create: `plugins/docs-manager/scripts/queue-clear.sh`
- Create: `plugins/docs-manager/scripts/queue-merge-fallback.sh`
- Modify: `plugins/docs-manager/tests/queue.bats`

**Step 1: Write failing tests**

```bash
@test "queue-clear empties queue and writes history log" {
    bash "$SCRIPTS_DIR/bootstrap.sh"
    bash "$SCRIPTS_DIR/queue-append.sh" --type "doc-modified" --doc-path "/tmp/a.md" --library "lib" --trigger "direct-write"
    run bash "$SCRIPTS_DIR/queue-clear.sh" --reason "Testing clear"
    [ "$status" -eq 0 ]
    run jq '.items | length' "$DOCS_MANAGER_HOME/queue.json"
    [ "$output" = "0" ]
}

@test "queue-clear requires a reason" {
    bash "$SCRIPTS_DIR/bootstrap.sh"
    bash "$SCRIPTS_DIR/queue-append.sh" --type "doc-modified" --doc-path "/tmp/a.md" --library "lib" --trigger "direct-write"
    run bash "$SCRIPTS_DIR/queue-clear.sh"
    [ "$status" -eq 1 ]  # Fails without reason
}

@test "queue-clear writes cleared items to session history" {
    bash "$SCRIPTS_DIR/bootstrap.sh"
    bash "$SCRIPTS_DIR/queue-append.sh" --type "doc-modified" --doc-path "/tmp/a.md" --library "lib" --trigger "direct-write"
    bash "$SCRIPTS_DIR/queue-clear.sh" --reason "Test"
    [ -f "$DOCS_MANAGER_HOME/session-history.jsonl" ]
}

@test "queue-merge-fallback combines fallback into main queue" {
    bash "$SCRIPTS_DIR/bootstrap.sh"
    bash "$SCRIPTS_DIR/queue-append.sh" --type "doc-modified" --doc-path "/tmp/a.md" --library "lib" --trigger "direct-write"
    printf '{"created":"2026-01-01T00:00:00Z","items":[{"id":"fb-001","type":"doc-modified","doc-path":"/tmp/fb.md","library":"lib","detected-at":"2026-01-01T00:00:00Z","trigger":"direct-write","priority":"standard","status":"pending","note":null}]}\n' \
        > "$DOCS_MANAGER_HOME/queue.fallback.json"
    run bash "$SCRIPTS_DIR/queue-merge-fallback.sh"
    [ "$status" -eq 0 ]
    run jq '.items | length' "$DOCS_MANAGER_HOME/queue.json"
    [ "$output" = "2" ]
    [ ! -f "$DOCS_MANAGER_HOME/queue.fallback.json" ]
}
```

**Step 2: Verify fail, implement, verify pass**

`queue-clear.sh` specification:
- Requires `--reason "text"` argument (exits 1 without it)
- Reads current queue items
- Writes cleared items + reason + timestamp to `$DOCS_MANAGER_HOME/session-history.jsonl` (append, one JSON object per line)
- Resets queue.json items array to empty
- Outputs count of cleared items

`queue-merge-fallback.sh` specification:
- Checks if `queue.fallback.json` exists; exits 0 if not
- Reads all items from fallback
- Appends to main queue (deduplicating by doc-path + type)
- Deletes fallback file on success

**Step 3: Commit**

```bash
git add plugins/docs-manager/scripts/queue-clear.sh plugins/docs-manager/scripts/queue-merge-fallback.sh plugins/docs-manager/tests/queue.bats
git commit -m "feat(docs-manager): add queue clear and fallback merge scripts"
```

---

## Phase 3: Shared Utilities

### Task 6: Frontmatter Reader

**Files:**
- Create: `plugins/docs-manager/scripts/frontmatter-read.sh`
- Create: `plugins/docs-manager/tests/utilities.bats`
- Create: `plugins/docs-manager/tests/fixtures/doc-with-frontmatter.md`
- Create: `plugins/docs-manager/tests/fixtures/doc-without-frontmatter.md`
- Create: `plugins/docs-manager/tests/fixtures/doc-ai-audience.md`

**Step 1: Create test fixtures**

`tests/fixtures/doc-with-frontmatter.md`:
```markdown
---
library: raspi5-homelab
machine: raspi5
doc-type: sysadmin
last-verified: 2026-02-18
status: active
upstream-url: https://caddyserver.com/docs/
source-files:
  - /etc/caddy/Caddyfile
---

# Caddy Reverse Proxy

Content here.
```

`tests/fixtures/doc-without-frontmatter.md`:
```markdown
# Just a regular file

No frontmatter here.
```

`tests/fixtures/doc-ai-audience.md`:
```markdown
---
library: raspi5-homelab
machine: raspi5
doc-type: sysadmin
audience: ai
last-verified: 2026-02-18
status: active
---

Token-efficient AI context.
```

**Step 2: Write failing tests**

```bash
#!/usr/bin/env bats

load helpers

setup() { setup_test_env; }
teardown() { teardown_test_env; }

@test "frontmatter-read extracts specific field" {
    run bash "$SCRIPTS_DIR/frontmatter-read.sh" "$BATS_TEST_DIRNAME/fixtures/doc-with-frontmatter.md" library
    [ "$status" -eq 0 ]
    [ "$output" = "raspi5-homelab" ]
}

@test "frontmatter-read outputs all fields as JSON" {
    run bash "$SCRIPTS_DIR/frontmatter-read.sh" "$BATS_TEST_DIRNAME/fixtures/doc-with-frontmatter.md"
    [ "$status" -eq 0 ]
    echo "$output" | jq . > /dev/null 2>&1  # valid JSON
    run bash -c "echo '$output' | jq -r '.library'"
    [ "$output" = "raspi5-homelab" ]
}

@test "frontmatter-read returns exit 1 for file without frontmatter" {
    run bash "$SCRIPTS_DIR/frontmatter-read.sh" "$BATS_TEST_DIRNAME/fixtures/doc-without-frontmatter.md" library
    [ "$status" -eq 1 ]
}

@test "frontmatter-read extracts source-files as JSON array" {
    run bash "$SCRIPTS_DIR/frontmatter-read.sh" "$BATS_TEST_DIRNAME/fixtures/doc-with-frontmatter.md" source-files
    [ "$status" -eq 0 ]
    [[ "$output" == *"/etc/caddy/Caddyfile"* ]]
}

@test "frontmatter-read handles docs-manager frontmatter check" {
    run bash "$SCRIPTS_DIR/frontmatter-read.sh" "$BATS_TEST_DIRNAME/fixtures/doc-with-frontmatter.md" --has-frontmatter
    [ "$status" -eq 0 ]
    run bash "$SCRIPTS_DIR/frontmatter-read.sh" "$BATS_TEST_DIRNAME/fixtures/doc-without-frontmatter.md" --has-frontmatter
    [ "$status" -eq 1 ]
}
```

**Step 3: Verify fail, implement, verify pass**

`frontmatter-read.sh` specification:
- Input: `<file-path> [field-name | --has-frontmatter]`
- Uses Python 3 to parse YAML between `---` delimiters
- No field argument: outputs all frontmatter as JSON object
- Field argument: outputs that field's value (string or JSON for arrays/objects)
- `--has-frontmatter`: exits 0 if file has docs-manager frontmatter (has `library` field), exits 1 if not
- Exits 1 if no frontmatter found or file doesn't exist

Implementation uses Python because YAML parsing in pure bash is fragile. The Python snippet:
```python
import sys, json, yaml

filepath = sys.argv[1]
field = sys.argv[2] if len(sys.argv) > 2 else None

with open(filepath) as f:
    content = f.read()

if not content.startswith('---'):
    sys.exit(1)

end = content.index('---', 3)
fm = yaml.safe_load(content[3:end])

if fm is None:
    sys.exit(1)

if field == '--has-frontmatter':
    sys.exit(0 if 'library' in fm else 1)
elif field:
    val = fm.get(field)
    if val is None:
        sys.exit(1)
    print(json.dumps(val) if isinstance(val, (list, dict)) else val)
else:
    print(json.dumps(fm, default=str))
```

Note: Requires `pyyaml`. The script should check for it and fall back to a regex-based approach if missing. Alternatively, since `pyyaml` may not be installed, use a simpler approach: read between `---` delimiters and parse key-value pairs with Python's stdlib only (no yaml import). For the simple frontmatter format used by docs-manager (flat keys, simple lists), a regex parser is sufficient.

**Step 4: Commit**

```bash
git add plugins/docs-manager/scripts/frontmatter-read.sh plugins/docs-manager/tests/utilities.bats plugins/docs-manager/tests/fixtures/
git commit -m "feat(docs-manager): add frontmatter reader utility with tests"
```

---

### Task 7: Survival-Context Classifier

**Files:**
- Create: `plugins/docs-manager/scripts/is-survival-context.sh`
- Modify: `plugins/docs-manager/tests/utilities.bats`

**Step 1: Write failing tests**

Append to `tests/utilities.bats`:

```bash
@test "is-survival-context: sysadmin + human = true" {
    run bash "$SCRIPTS_DIR/is-survival-context.sh" "$BATS_TEST_DIRNAME/fixtures/doc-with-frontmatter.md"
    [ "$status" -eq 0 ]
    [ "$output" = "true" ]
}

@test "is-survival-context: sysadmin + ai audience = false" {
    run bash "$SCRIPTS_DIR/is-survival-context.sh" "$BATS_TEST_DIRNAME/fixtures/doc-ai-audience.md"
    [ "$status" -eq 0 ]
    [ "$output" = "false" ]
}

@test "is-survival-context: file without frontmatter = false" {
    run bash "$SCRIPTS_DIR/is-survival-context.sh" "$BATS_TEST_DIRNAME/fixtures/doc-without-frontmatter.md"
    [ "$status" -eq 0 ]
    [ "$output" = "false" ]
}

@test "is-survival-context: accepts --doc-type and --audience flags" {
    run bash "$SCRIPTS_DIR/is-survival-context.sh" --doc-type sysadmin --audience human
    [ "$status" -eq 0 ]
    [ "$output" = "true" ]
    run bash "$SCRIPTS_DIR/is-survival-context.sh" --doc-type ai-artifact --audience human
    [ "$status" -eq 0 ]
    [ "$output" = "false" ]
}
```

**Step 2: Verify fail, implement, verify pass**

`is-survival-context.sh` specification (implements §6.2 classification rule):
- Input: file path OR `--doc-type TYPE --audience AUDIENCE`
- If file path: reads frontmatter via `frontmatter-read.sh`
- Classification rule:
  1. `doc-type` is `sysadmin`, `dev`, or `personal` (NOT `ai-artifact`, NOT `system`)
  2. `audience` is `human` or `both` (NOT `ai`)
  3. If `audience` not set, defaults to `human`
  4. `audience: ai` overrides doc-type (the P5 exception)
- Outputs: `true` or `false`
- Always exits 0

This script is the **single shared implementation** of the P5 classification rule. Template inference, hook scripts, and document creation all call this script — they never encode the rule independently. (§6.2)

**Step 3: Commit**

```bash
git add plugins/docs-manager/scripts/is-survival-context.sh plugins/docs-manager/tests/utilities.bats
git commit -m "feat(docs-manager): add survival-context classifier (P5 rule)"
```

---

## Phase 4: Hook Scripts

### Task 8: PostToolUse Detection Script

**Files:**
- Create: `plugins/docs-manager/scripts/post-tool-use.sh`
- Create: `plugins/docs-manager/tests/detection.bats`

**Step 1: Write failing tests**

```bash
#!/usr/bin/env bats

load helpers

setup() {
    setup_test_env
    bash "$SCRIPTS_DIR/bootstrap.sh"
}
teardown() { teardown_test_env; }

# Helper: simulate PostToolUse stdin JSON
post_tool_json() {
    local file_path="$1"
    printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":"test"}}\n' "$file_path"
}

@test "post-tool-use: Path A — file with frontmatter queued as doc-modified" {
    # Create a doc with frontmatter in test env
    local doc="$DOCS_MANAGER_HOME/testdoc.md"
    cp "$BATS_TEST_DIRNAME/fixtures/doc-with-frontmatter.md" "$doc"
    post_tool_json "$doc" | bash "$SCRIPTS_DIR/post-tool-use.sh"
    run jq '.items | length' "$DOCS_MANAGER_HOME/queue.json"
    [ "$output" = "1" ]
    run jq -r '.items[0].type' "$DOCS_MANAGER_HOME/queue.json"
    [ "$output" = "doc-modified" ]
}

@test "post-tool-use: file without frontmatter is ignored" {
    local doc="$DOCS_MANAGER_HOME/plain.md"
    cp "$BATS_TEST_DIRNAME/fixtures/doc-without-frontmatter.md" "$doc"
    post_tool_json "$doc" | bash "$SCRIPTS_DIR/post-tool-use.sh"
    run jq '.items | length' "$DOCS_MANAGER_HOME/queue.json"
    [ "$output" = "0" ]
}

@test "post-tool-use: non-markdown file is ignored" {
    post_tool_json "/tmp/script.py" | bash "$SCRIPTS_DIR/post-tool-use.sh"
    run jq '.items | length' "$DOCS_MANAGER_HOME/queue.json"
    [ "$output" = "0" ]
}

@test "post-tool-use: writes last-fired timestamp on success" {
    local doc="$DOCS_MANAGER_HOME/testdoc.md"
    cp "$BATS_TEST_DIRNAME/fixtures/doc-with-frontmatter.md" "$doc"
    post_tool_json "$doc" | bash "$SCRIPTS_DIR/post-tool-use.sh"
    [ -f "$DOCS_MANAGER_HOME/hooks/post-tool-use.last-fired" ]
}

@test "post-tool-use: always exits 0 even on error" {
    echo "invalid json" | bash "$SCRIPTS_DIR/post-tool-use.sh"
    run echo $?
    # Script should have exited 0 (we test by checking it didn't crash the test)
}
```

Note: Path B detection (source-file association) requires the index system (Phase 6). The PostToolUse hook initially implements **Path A only**. Path B is added in Task 16 after the index exists.

**Step 2: Verify fail, implement, verify pass**

`post-tool-use.sh` specification (§7.2):
- Input: JSON on stdin (Claude Code PostToolUse context)
- Extracts `file_path` from `tool_input`
- Quick filters (before any expensive checks):
  - Ignores non-`.md` files
  - Ignores files inside `node_modules/`, `.git/`, `__pycache__/`
- **Path A**: Calls `frontmatter-read.sh --has-frontmatter` on the file
  - If yes: extracts `library` field, appends queue item as `doc-modified`
- **Path B** (deferred to Task 16): Check index for source-file associations
- Queue threshold check: if queue has >20 items, outputs warning to stdout
- Writes timestamp to `$DOCS_MANAGER_HOME/hooks/post-tool-use.last-fired`
- Error handling: wraps main() in the §7.6 error contract (always exits 0)

```bash
#!/usr/bin/env bash
# PostToolUse hook handler — detects doc-relevant file changes.
# Reads tool context JSON from stdin. Always exits 0.
# §7.2, §7.3, §7.6 in design.md
set -euo pipefail

DOCS_MANAGER_HOME="${DOCS_MANAGER_HOME:-$HOME/.docs-manager}"
SCRIPTS_DIR="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")" && pwd)}/scripts"
# When called as a hook, CLAUDE_PLUGIN_ROOT is set. In tests, fall back to script dir.
[[ -z "${CLAUDE_PLUGIN_ROOT:-}" ]] && SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"

main() {
    # Read stdin
    local input
    input=$(cat)

    # Extract file path
    local file_path
    file_path=$(echo "$input" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('file_path',''))" 2>/dev/null || echo "")
    [[ -z "$file_path" ]] && return 0

    # Quick filter: only .md files
    [[ "$file_path" != *.md ]] && return 0

    # Quick filter: skip noise directories
    case "$file_path" in
        */node_modules/*|*/.git/*|*/__pycache__/*) return 0 ;;
    esac

    # File must exist (may have been a delete operation)
    [[ ! -f "$file_path" ]] && return 0

    # Path A: check for docs-manager frontmatter
    if bash "$SCRIPTS_DIR/frontmatter-read.sh" "$file_path" --has-frontmatter 2>/dev/null; then
        local library
        library=$(bash "$SCRIPTS_DIR/frontmatter-read.sh" "$file_path" library 2>/dev/null || echo "unknown")
        bash "$SCRIPTS_DIR/queue-append.sh" \
            --type "doc-modified" \
            --doc-path "$file_path" \
            --library "$library" \
            --trigger "direct-write"
    fi

    # Path B: source-file association (requires index — added in Phase 6, Task 16)

    # Queue threshold warning (§7.3)
    local count
    count=$(bash "$SCRIPTS_DIR/queue-read.sh" --count 2>/dev/null || echo "0")
    if [[ "$count" -gt 20 ]]; then
        echo "Documentation queue has $count items. Consider \`/docs queue review\` before continuing."
    fi

    # Write last-fired timestamp
    mkdir -p "$DOCS_MANAGER_HOME/hooks"
    date -u +%Y-%m-%dT%H:%M:%SZ > "$DOCS_MANAGER_HOME/hooks/post-tool-use.last-fired"
}

if ! main; then
    echo "⚠ docs-manager PostToolUse hook encountered an issue"
    echo "Documentation detection may be incomplete this session."
    echo "Run /docs hook status to diagnose."
fi
exit 0
```

**Step 3: Commit**

```bash
git add plugins/docs-manager/scripts/post-tool-use.sh plugins/docs-manager/tests/detection.bats
git commit -m "feat(docs-manager): add PostToolUse hook detection (Path A)"
```

---

### Task 9: Stop Hook Script and hooks.json

**Files:**
- Create: `plugins/docs-manager/scripts/stop.sh`
- Create: `plugins/docs-manager/hooks/hooks.json`
- Modify: `plugins/docs-manager/tests/detection.bats`

**Step 1: Write failing tests**

Append to `tests/detection.bats`:

```bash
@test "stop: outputs queue summary when items exist" {
    bash "$SCRIPTS_DIR/queue-append.sh" --type "doc-modified" --doc-path "/tmp/a.md" --library "lib" --trigger "direct-write"
    run bash "$SCRIPTS_DIR/stop.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"1"* ]]
    [[ "$output" == *"queued"* ]] || [[ "$output" == *"documentation"* ]]
}

@test "stop: silent when queue is empty" {
    run bash "$SCRIPTS_DIR/stop.sh"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "stop: writes last-fired timestamp" {
    run bash "$SCRIPTS_DIR/stop.sh"
    [ -f "$DOCS_MANAGER_HOME/hooks/stop.last-fired" ]
}
```

**Step 2: Verify fail, implement, verify pass**

`stop.sh` specification (§7.4):
- Reads queue item count
- If >0: outputs session-end message to stdout (injected into Claude context)
- Message format: `"Session ending with N queued documentation items. Run /docs queue review to review, or /docs queue clear --reason '...' to dismiss all."`
- If 0: outputs nothing (silent)
- Writes last-fired timestamp
- Always exits 0

`hooks/hooks.json`:
```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/post-tool-use.sh"
          }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/stop.sh"
          }
        ]
      }
    ]
  }
}
```

**Step 3: Commit**

```bash
git add plugins/docs-manager/scripts/stop.sh plugins/docs-manager/hooks/hooks.json plugins/docs-manager/tests/detection.bats
git commit -m "feat(docs-manager): add Stop hook and hooks.json registration"
```

---

## Phase 5: Core Commands

### Task 10: Main /docs Command Router

**Files:**
- Create: `plugins/docs-manager/commands/docs.md`

This is the single command file that handles all `/docs <subcommand>` invocations. It loads into context on every `/docs` call, so it must be **lean** — detailed workflow instructions belong in skills, not here.

**Specification:**

The command file should contain:
1. YAML frontmatter: `name: docs`, `description: Documentation lifecycle management`
2. Usage summary: `/docs <subcommand> [args]`
3. Routing table: one section per subcommand with 3-10 lines of instruction
4. References to scripts for mechanical operations
5. References to skills for complex workflows

**Subcommands to include in the initial router** (Phase 5 — others added in later phases):

| Subcommand | Behavior | Implementation |
|------------|----------|----------------|
| `queue` | Display current queue items | Call `queue-read.sh`, format output |
| `queue review` | Trigger review flow | Multi-select UI per §5.2 |
| `queue clear` | Dismiss all with reason | Call `queue-clear.sh` with `--reason` |
| `status` | Operational + library health | Call scripts, format §11.4 output |
| `hook status` | Check hook health | Read last-fired timestamps |
| `help` | Show command list | Output the routing table |
| (no arg) | Show brief status summary | Same as `status` but abbreviated |

**Subcommands to add as stubs** (implemented in later phases):
- `new`, `onboard`, `find`, `update`, `review`, `organize`, `library`, `index`, `audit`, `dedupe`, `consistency`, `streamline`, `compress`, `full-review`, `template`, `verify`

Each stub outputs: `"The /docs [subcommand] command will be available in a future update. Current version: 0.1.0"`

**Key patterns for the command file:**
- Parse first argument as subcommand
- Use `AskUserQuestion` with `multiSelect: true` for queue review (§5.2)
- Call scripts via `bash ${CLAUDE_PLUGIN_ROOT}/scripts/<script>.sh`
- Keep each subcommand section under 15 lines
- Total file should be under 250 lines

**Commit:**

```bash
git add plugins/docs-manager/commands/docs.md
git commit -m "feat(docs-manager): add /docs command router with queue and status subcommands"
```

---

### Task 11: Queue Review Workflow Detail

This task fills in the queue review logic within the `/docs` command. The review workflow (§5.2) is the most interactive part of the MVP.

**Workflow specification:**

1. Read queue via `queue-read.sh --json`
2. For each pending item, Claude reads the associated file and its current state
3. Claude drafts a 1-3 sentence proposed update per item
4. Present items via `AskUserQuestion` with `multiSelect: true`:
   - Each option: `"[doc-name] — [change-type]: [proposed update summary]"`
   - Selected items = approved
5. If unselected items remain, present second multi-select:
   - `"These N items were not approved. Select any to permanently dismiss — the rest defer to next session."`
6. Apply approved updates (Claude edits the documents)
7. Write dismissed items to session history (via `queue-clear.sh` per-item)
8. Deferred items: update status to `"deferred"` in queue.json

**No separate file needed** — this logic lives in the `queue review` section of `commands/docs.md`. The key is that the command instructs Claude on the multi-step flow, and Claude executes it using the standard tools (Read, Edit, AskUserQuestion).

**Commit:** Combined with Task 10 or as a follow-up refinement.

---

### Task 12: Status and Help Subcommands

**Specification for `/docs status`** (§11.4):

The status command gathers data from scripts and formats the two-section output:

**Operational Health** — calls:
- Check `config.yaml` exists and is valid
- Read hook last-fired timestamps from `$DOCS_MANAGER_HOME/hooks/`
- Check queue.json validity
- Check index.lock status
- Check for pending offline writes

**Library Health** — calls:
- Count registered documents (from index — stub until Phase 6)
- Count missing recommended fields
- Count docs without upstream-url
- Count overdue verification items
- Count pending queue items

Output format matches §11.4 exactly (the ASCII box format).

The `--test` flag runs the self-test suite (§12.1): all operational health checks plus index JSON validation.

**Specification for `/docs help`:**

Outputs the command reference table from §15.2 of the design, filtered to only show implemented commands (not stubs). Format:

```
/docs — Documentation Lifecycle Manager

Commands:
  queue              Display current queue items
  queue review       Review and approve queued items
  queue clear        Dismiss all items (reason required)
  status [--test]    Operational and library health
  hook status        Check hook registration and timestamps
  help               This help text

Coming soon: new, onboard, find, update, review, organize, library,
index, audit, dedupe, consistency, streamline, compress, full-review,
template, verify
```

**Commit:**

```bash
git add plugins/docs-manager/commands/docs.md
git commit -m "feat(docs-manager): complete MVP — queue, status, help commands"
```

---

> ### MVP MILESTONE
>
> At this point the core detection → queue → review loop works:
> 1. User edits a `.md` file with docs-manager frontmatter → PostToolUse hook detects it → queue item appended
> 2. Session ends → Stop hook injects queue summary
> 3. `/docs queue` shows pending items
> 4. `/docs queue review` triggers the multi-select approval flow
> 5. `/docs status` shows operational health
>
> **Manual smoke test:** Install the plugin (`claude --plugin-dir ./plugins/docs-manager`), edit a frontmattered doc, end the session, verify detection works.

---

## Phase 6: Index System

### Task 13: Index Schema and Register Script

**Files:**
- Create: `plugins/docs-manager/scripts/index-register.sh`
- Create: `plugins/docs-manager/tests/index.bats`
- Create: `plugins/docs-manager/tests/fixtures/sample-index.json`

**Specification:**

`docs-index.json` schema (§6.3):
```json
{
  "version": "1.0",
  "last-updated": "2026-02-20T00:00:00Z",
  "libraries": [
    {
      "name": "raspi5-homelab",
      "machine": "raspi5",
      "description": "...",
      "root-path": "~/projects/homelab/raspi5/"
    }
  ],
  "documents": [
    {
      "id": "doc-001",
      "path": "~/projects/homelab/raspi5/caddy/README.md",
      "title": "Caddy Reverse Proxy",
      "library": "raspi5-homelab",
      "machine": "raspi5",
      "doc-type": "sysadmin",
      "status": "active",
      "last-verified": "2026-02-18",
      "template": "homelab-service-runbook",
      "upstream-url": "https://caddyserver.com/docs/",
      "source-files": ["/etc/caddy/Caddyfile"],
      "cross-refs": ["../pihole/README.md"],
      "incoming-refs": ["../README.md"],
      "summary": "One-line summary of the document"
    }
  ]
}
```

`index-register.sh` interface:
- Input: `--path <doc-path> [--library <name>] [--title <title>]`
- Reads frontmatter from the document to populate fields
- If `--library` not provided, reads from frontmatter
- Generates sequential doc ID
- Acquires index lock, appends to `docs-index.json`, releases lock
- Rebuilds `docs-index.md` (calls `index-rebuild-md.sh`)
- If library doesn't exist in index, creates it (prompts for description if interactive)

**Tests:**
- Register a doc → verify index entry created
- Register duplicate path → verify no duplicate entry
- Register with missing library → verify error
- Register creates library if new

**Commit:**

```bash
git add plugins/docs-manager/scripts/index-register.sh plugins/docs-manager/tests/index.bats plugins/docs-manager/tests/fixtures/sample-index.json
git commit -m "feat(docs-manager): add index register script with schema"
```

---

### Task 14: Index Query and Rebuild-MD Scripts

**Files:**
- Create: `plugins/docs-manager/scripts/index-query.sh`
- Create: `plugins/docs-manager/scripts/index-rebuild-md.sh`
- Modify: `plugins/docs-manager/tests/index.bats`

**`index-query.sh` specification:**
- Input: `--machine <name>` (default: hostname), plus optional filters:
  - `--library <name>` — filter by library
  - `--doc-type <type>` — filter by doc-type
  - `--search <text>` — search title and path
  - `--path <path>` — exact path lookup
  - `--source-file <path>` — find docs with this source-file (for Path B detection)
- Output: JSON array of matching document entries
- `--human` flag: outputs formatted table (title, library, path, last-verified, summary)
- Reads from index location specified in config.yaml
- Falls back to cache snapshot if index unreachable (§13.5)
- Machine-filtered by default (§6.5)

**`index-rebuild-md.sh` specification:**
- Reads `docs-index.json`
- Generates `docs-index.md` (human-readable mirror, §6.3)
- Format: one section per library, with document tables
- Never edited manually — always regenerated

**Tests:**
- Query by machine returns only matching docs
- Query by library filters correctly
- Query `--source-file` returns associated docs
- Rebuild-md produces valid markdown with all index entries

**Commit:**

```bash
git add plugins/docs-manager/scripts/index-query.sh plugins/docs-manager/scripts/index-rebuild-md.sh plugins/docs-manager/tests/index.bats
git commit -m "feat(docs-manager): add index query and markdown rebuild scripts"
```

---

### Task 15: Index Locking Scripts

**Files:**
- Create: `plugins/docs-manager/scripts/index-lock.sh`
- Create: `plugins/docs-manager/scripts/index-unlock.sh`
- Modify: `plugins/docs-manager/tests/index.bats`

**`index-lock.sh` specification (§6.6):**
- Writes `$DOCS_MANAGER_HOME/index.lock` with `{pid, acquired, operation}`
- Lock acquisition protocol:
  1. If lock exists: read PID, check if process alive (`kill -0`)
  2. Dead PID → remove stale lock, proceed
  3. Alive PID → wait up to N seconds (from config, default 5)
  4. Timeout → exit 1 with error message
- Atomic write: temp file + mv
- Input: `--operation <name>` (for the lock file metadata)

**`index-unlock.sh` specification:**
- Removes `$DOCS_MANAGER_HOME/index.lock`
- Only removes if current PID matches lock PID (safety check)

**Tests:**
- Lock acquired successfully
- Lock is idempotent for same PID
- Stale lock from dead PID is cleaned up
- Concurrent lock from live PID waits then fails
- Unlock removes lock file
- Unlock refuses if PID doesn't match

**Commit:**

```bash
git add plugins/docs-manager/scripts/index-lock.sh plugins/docs-manager/scripts/index-unlock.sh plugins/docs-manager/tests/index.bats
git commit -m "feat(docs-manager): add index locking scripts"
```

---

### Task 16: Source-Files Lookup and Path B Detection

**Files:**
- Create: `plugins/docs-manager/scripts/index-source-lookup.sh`
- Modify: `plugins/docs-manager/scripts/post-tool-use.sh` (add Path B)
- Modify: `plugins/docs-manager/tests/detection.bats`

**`index-source-lookup.sh` specification:**
- Input: `<file-path>`
- Queries index for any document whose `source-files` array contains the given path
- Output: JSON array of matching document entries (empty array if none)
- Used by PostToolUse hook for Path B detection

**Update to `post-tool-use.sh`:**
After the existing Path A check, add Path B:
```bash
# Path B: source-file association
local associated
associated=$(bash "$SCRIPTS_DIR/index-source-lookup.sh" "$file_path" 2>/dev/null || echo "[]")
if [[ "$associated" != "[]" ]]; then
    # For each associated doc, queue a source-file-changed item
    echo "$associated" | jq -r '.[] | .path + "|" + .library' | while IFS='|' read -r doc_path library; do
        bash "$SCRIPTS_DIR/queue-append.sh" \
            --type "source-file-changed" \
            --doc-path "$doc_path" \
            --library "$library" \
            --trigger "source-file-association" \
            --source-file "$file_path"
    done
fi
```

**Tests:**
- Source-file match triggers `source-file-changed` queue item
- Non-matching source-file produces no queue item
- Multiple docs referencing same source-file produce multiple queue items

**Commit:**

```bash
git add plugins/docs-manager/scripts/index-source-lookup.sh plugins/docs-manager/scripts/post-tool-use.sh plugins/docs-manager/tests/detection.bats
git commit -m "feat(docs-manager): add Path B detection via source-file lookup"
```

---

## Phase 7: Index & Library Commands

### Task 17: Index Subcommands

Add to `commands/docs.md` the following subcommands (replace stubs):

**`/docs index init`** (§4 failure table):
- Checks if index location exists (from config.yaml)
- If git-markdown: clones repo or initializes new one
- Creates empty `docs-index.json` and `docs-index.md` if not present
- Runs bootstrap.sh if needed

**`/docs index sync`** (§15.2):
- For git-markdown: `git pull` in index location
- Applies pending offline writes from `cache/pending-writes.json`
- Checks for merge conflicts → routes to `/docs index repair`
- Updates local cache snapshot

**`/docs index audit`** (§6.6):
- Orphan detection: check each index entry's file exists
- Present orphans: remove, update path, or keep
- Also runs during sync and before cross-ref repair

**`/docs index repair`** (§6.6):
- Union-merge strategy for conflicts
- Interactive for true conflicts (same doc modified on both machines)

**Commit:**

```bash
git add plugins/docs-manager/commands/docs.md
git commit -m "feat(docs-manager): add index management subcommands"
```

---

### Task 18: Library and Find Subcommands

Add to `commands/docs.md`:

**`/docs library`** (§6.1):
- Lists all libraries on current machine
- `--all-machines` shows all libraries across machines
- Shows: name, machine, description, document count
- Filters out `meta` library by default

**`/docs find <query>`** (§5.4):
- Calls `index-query.sh` with search term
- Displays: title, library, path, last-verified, summary
- Shows cross-references: "Links to: [X, Y]" and "Linked from: [Z]"
- Supports flags: `--library`, `--type`, `--machine`

**Commit:**

```bash
git add plugins/docs-manager/commands/docs.md
git commit -m "feat(docs-manager): add library and find subcommands"
```

---

## Phase 8: Document Lifecycle

### Task 19: First-Run Setup Flow

**Specification (§11.0):**

The setup flow triggers automatically on first `/docs` invocation when `~/.docs-manager/config.yaml` is absent. It should be added as a check at the top of the `/docs` command router.

**Flow:**
1. Detect missing config.yaml
2. Conversational questions (not a form):
   - "Where would you like to store your documentation index?" → map response to backend type
   - If git-markdown: "What's the path to your documentation repo?" → validate it exists
   - Machine identity: default to hostname, ask to confirm or override
3. Write `config.yaml`
4. Run bootstrap.sh
5. Create machine setup note in `meta` library
6. Validate backend accessibility

**Implementation:** The setup logic is a section within the `/docs` command that fires before subcommand routing. It uses `AskUserQuestion` for the key decisions.

**Commit:**

```bash
git add plugins/docs-manager/commands/docs.md
git commit -m "feat(docs-manager): add first-run setup flow"
```

---

### Task 20: /docs new Command

**Specification (§5.1):**

Replace the `new` stub in `commands/docs.md`:

1. Check index for related existing docs → surface matches
2. Ask three questions (§5.1 step 3):
   - State snapshot? / Process flow? / Dependencies?
3. Infer template from context (directory, library, intent)
4. Draft document with frontmatter and structure
5. User reviews and confirms
6. Save file, register in index
7. If third-party tool: prompt for `upstream-url`

**Key implementation detail:** The three questions should use `AskUserQuestion` with bounded options (yes/no/partial for each). Template inference calls the skill system or uses registered templates from the index.

**Commit:**

```bash
git add plugins/docs-manager/commands/docs.md
git commit -m "feat(docs-manager): add /docs new document creation workflow"
```

---

### Task 21: Template System

**Files:**
- Create: `plugins/docs-manager/scripts/template-register.sh` (extract template skeleton from existing doc)

**Specification (§8):**

`/docs template register --from <path>`:
- Analyzes document structure (headings, tables, frontmatter, prose ratio)
- Extracts reusable skeleton with `{{placeholder}}` syntax
- Saves to index location under `templates/` directory
- Registers template name in index

`/docs template register --file <path>`:
- Copies template file to `templates/` in index location
- Registers in index

Template inference (§8.4):
- Check current directory against known library root-paths
- Check filename patterns (README.md, RUNBOOK.md, etc.)
- Check library type (sysadmin → service runbook, dev → readme, etc.)
- If confidence low, ask one question: "This looks like a [type] document. Should I use the [template] template?"

**Commit:**

```bash
git add plugins/docs-manager/scripts/template-register.sh plugins/docs-manager/commands/docs.md
git commit -m "feat(docs-manager): add template registration and inference"
```

---

### Task 22: /docs onboard Command

**Specification (§11.1-11.3):**

**Single document** (`/docs onboard <path>`):
1. Read document, infer library/type/machine/source-files
2. Present assignments for confirmation
3. Add frontmatter
4. Register in index
5. Prompt for upstream-url if third-party
6. Suggest cross-references

**Directory bulk** (`/docs onboard <directory>`):
1. Scan all `.md` files recursively
2. Group by inferred library, present summary with confidence
3. User reviews/corrects groupings
4. Batch frontmatter addition
5. Single index update
6. Follow-up pass for upstream URLs

**Implementation:** Single-doc is inline in the command. Bulk import delegates to the `bulk-onboard` agent (Phase 12) for context efficiency.

**Commit:**

```bash
git add plugins/docs-manager/commands/docs.md
git commit -m "feat(docs-manager): add /docs onboard (single and directory)"
```

---

## Phase 9: Maintenance Commands

### Task 23: /docs update and /docs review

**Specification:**

**`/docs update <path>`:**
- Read the doc and its source-files
- Check freshness (has associated code changed?)
- If stale: Claude drafts updates, user confirms
- Update `last-verified` frontmatter

**`/docs review <path>`:**
- Comprehensive single-doc review:
  - Staleness check
  - P5 compliance (survival-context docs have prose sections)
  - Internal consistency (cross-refs valid, source-files exist)
  - Upstream verification if `upstream-url` present
- `--full` flag: also checks adjacent docs in same library

**Commit:**

```bash
git add plugins/docs-manager/commands/docs.md
git commit -m "feat(docs-manager): add /docs update and /docs review"
```

---

### Task 24: /docs organize

**Specification (§5.5):**

`/docs organize <path>`:
1. Analyze content → infer correct library, directory, filename, structure
2. Present proposed reorganization
3. On confirm: move/rename file, update frontmatter, update index path
4. Repair cross-references: find all docs that link to old path (via incoming-refs in index), update their `cross-refs` fields
5. Regenerate `docs-index.md`

**Commit:**

```bash
git add plugins/docs-manager/commands/docs.md
git commit -m "feat(docs-manager): add /docs organize with cross-ref repair"
```

---

### Task 25: /docs audit

**Specification:**

`/docs audit`:
- Missing recommended fields (source-files, upstream-url, template)
- `--p5`: check survival-context docs for missing prose sections
- `--p7`: list docs without upstream-url that describe third-party tools
- Output: prioritized list (critical / standard / reference)
- Each finding includes the repair action

**Commit:**

```bash
git add plugins/docs-manager/commands/docs.md
git commit -m "feat(docs-manager): add /docs audit"
```

---

### Task 26: Remaining Maintenance Commands

**Specification:**

**`/docs dedupe`** — Find near-duplicate documents within a library. Compare titles, content similarity, source-file overlap. `--across-libraries` flag for cross-library dedup.

**`/docs consistency`** — Check internal consistency: cross-refs point to existing docs, source-files exist, library assignments match directory structure.

**`/docs streamline`** — Identify redundant content within a single document. Suggest condensation.

**`/docs compress <path>`** — Compress for token efficiency (AI-audience docs only, per P5). Refuse to compress survival-context documents.

**`/docs full-review`** — Comprehensive sweep combining: audit + consistency + upstream verification. Delegates to `full-review` agent for context efficiency.

**Commit:**

```bash
git add plugins/docs-manager/commands/docs.md
git commit -m "feat(docs-manager): add dedupe, consistency, streamline, compress, full-review"
```

---

## Phase 10: Upstream Verification

### Task 27: /docs verify Command

**Specification (§10):**

`/docs verify [path]`:
- Single doc: verify against its `upstream-url`
- No path: verify all docs due for re-verification (based on `review-frequency`)
- `--all`: bypass tiered batching, verify everything
- `--tier <N>`: verify specific tier only

**Verification process (§10.2):**
1. Fetch upstream via `WebFetch` or `WebSearch`
2. Compare: config keys, version requirements, deprecated options
3. Confident match → update `last-verified`
4. Confident discrepancy → queue correction
5. Uncertain → queue with specific question for user

**Tiered batching (§10.4):**
- Tier 1: critical docs → ask to proceed
- Tier 2: standard docs → ask to continue or defer
- Tier 3: reference docs → ask to continue or defer
- Deferred tiers → queue as `upstream-check-due`

**Commit:**

```bash
git add plugins/docs-manager/commands/docs.md
git commit -m "feat(docs-manager): add /docs verify with tiered batching"
```

---

## Phase 11: Skills

### Task 28: Project-Entry Awareness Skill

**Files:**
- Create: `plugins/docs-manager/skills/project-entry/SKILL.md`

**Specification (§7.5):**

```yaml
---
name: project-entry
description: Triggers freshness scan when entering a new project directory
---
```

Content: When Claude detects entry into a new project directory (via directory context change), check if the project has a registered library. If so, run a freshness scan for that library and append concerning items to the queue. Inject brief context: "N documentation items queued for this project."

**Commit:**

```bash
git add plugins/docs-manager/skills/project-entry/SKILL.md
git commit -m "feat(docs-manager): add project-entry awareness skill"
```

---

### Task 29: Doc Creation and Session Boundary Skills

**Files:**
- Create: `plugins/docs-manager/skills/doc-creation/SKILL.md`
- Create: `plugins/docs-manager/skills/session-boundary/SKILL.md`

**Doc creation skill:** Activates when Claude is about to create a `.md` file in a location not registered in the docs-manager index. Suggests using `/docs new` instead of raw file creation, to ensure proper frontmatter and index registration.

**Session boundary skill:** Reminds Claude to check the queue at session boundaries. Activates when Claude is wrapping up work. References the Stop hook output and suggests `/docs queue review`.

**Commit:**

```bash
git add plugins/docs-manager/skills/
git commit -m "feat(docs-manager): add doc-creation and session-boundary skills"
```

---

## Phase 12: Agents

### Task 30: Bulk Onboard, Full-Review, and Upstream Verify Agents

**Files:**
- Create: `plugins/docs-manager/agents/bulk-onboard.md`
- Create: `plugins/docs-manager/agents/full-review.md`
- Create: `plugins/docs-manager/agents/upstream-verify.md`

**Bulk onboard agent:**
```yaml
---
name: bulk-onboard
description: Imports a directory of existing documents into the docs-manager library
tools: Read, Grep, Glob, Bash, Write, Edit
---
```
Receives: directory path, target library (optional). Scans all `.md` files, infers groupings, adds frontmatter, registers in index. Returns summary of imported docs.

**Full-review agent:**
```yaml
---
name: full-review
description: Comprehensive documentation review sweep
tools: Read, Grep, Glob, Bash, WebFetch, WebSearch
---
```
Runs: audit + consistency + upstream verification across all active docs. Returns structured findings report.

**Upstream verify agent:**
```yaml
---
name: upstream-verify
description: Verifies third-party documentation against upstream sources
tools: Read, Grep, Glob, WebFetch, WebSearch
---
```
Receives: list of docs with upstream-urls. Fetches upstream, compares, returns discrepancy report.

**Commit:**

```bash
git add plugins/docs-manager/agents/
git commit -m "feat(docs-manager): add bulk-onboard, full-review, and upstream-verify agents"
```

---

## Phase 13: Polish & Release

### Task 31: README.md

**Files:**
- Create: `plugins/docs-manager/README.md`

**Specification:**

Follow the established plugin README pattern:
1. Summary (2-3 sentences)
2. Design Principles (P1-P7 one-liners)
3. Installation
4. Quick Start (first-run → onboard → queue review cycle)
5. Commands table (all `/docs` subcommands)
6. Skills table
7. Agents table
8. Hooks table (PostToolUse, Stop)
9. State files (`~/.docs-manager/` layout)
10. Configuration (`config.yaml` reference)
11. Testing (`bats`, PTH, sandboxed workflows)

**Commit:**

```bash
git add plugins/docs-manager/README.md
git commit -m "docs(docs-manager): add README"
```

---

### Task 32: Final Validation and Changelog Update

**Steps:**
1. Run `./scripts/validate-marketplace.sh` — must pass
2. Run `bats plugins/docs-manager/tests/*.bats` — all tests must pass
3. Update `CHANGELOG.md` with all features added
4. Bump version to `0.1.0` in `plugin.json` and `marketplace.json`
5. Final commit

```bash
git add -A plugins/docs-manager/ .claude-plugin/marketplace.json
git commit -m "feat(docs-manager): complete v0.1.0 — documentation lifecycle management plugin"
```

---

## Testing Checklist

Run these at each phase boundary:

### Phase 1-5 (MVP)
```bash
bats plugins/docs-manager/tests/queue.bats
bats plugins/docs-manager/tests/utilities.bats
bats plugins/docs-manager/tests/detection.bats
./scripts/validate-marketplace.sh
```

### Phase 6-7 (Index)
```bash
bats plugins/docs-manager/tests/index.bats
# Plus all previous
```

### Phase 13 (Release)
```bash
bats plugins/docs-manager/tests/*.bats          # All unit tests
./scripts/validate-marketplace.sh               # Marketplace validation
claude --plugin-dir ./plugins/docs-manager      # Manual smoke test
```

### Sandboxed Workflow Tests (§12.4)
```bash
# Create throwaway index
mkdir -p /tmp/docs-manager-sandbox/{index,docs,templates}
git init /tmp/docs-manager-sandbox/index
# Override config
cat > ~/.docs-manager/config.yaml.test << 'EOF'
machine: test
index:
  type: git-markdown
  location: /tmp/docs-manager-sandbox/index
EOF
```

Test scenarios (manual, one session each):
1. `/docs new` → verify frontmatter + index registration
2. `/docs onboard <dir>` → verify grouping + batch import
3. Session-end queue review → verify detection + approval flow
4. `/docs organize` → verify cross-ref repair
5. `/docs verify` → verify tiered upstream batching
6. `/docs status --test` → verify all self-test checks pass
