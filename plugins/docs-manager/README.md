# docs-manager

Documentation lifecycle management for Claude Code. Detects changes via hooks, queues documentation tasks silently, and surfaces them for batch review at session boundaries. Tracks documents across machines via a dual-index system (JSON + Markdown mirror) backed by git.

## Design Principles

- **P1 Act on Intent** — `/docs` commands execute without confirmation of the obvious
- **P2 Scope Fidelity** — complete the full requested scope without sub-task gates
- **P3 Succeed Quietly** — hooks run silently; only session-end summaries surface
- **P5 Convergence** — review cycles drive toward verified, indexed documentation
- **P6 Composable Units** — each script does one thing; `/docs` assembles workflows

## Installation

```bash
claude --plugin-dir ./plugins/docs-manager
```

Or via marketplace:
```bash
/plugin marketplace add L3DigitalNet/Claude-Code-Plugins
/plugin install docs-manager@l3digitalnet-plugins
```

### Prerequisites

| Tool | Required | Purpose |
|------|----------|---------|
| `jq` | Yes | JSON manipulation in all scripts |
| `python3` | Yes | YAML frontmatter parsing |
| `git` | For git-markdown backend | Index synchronization |
| `bats` | For testing | Bash script unit tests |

## Quick Start

1. **First run** — `/docs` triggers setup: choose index backend, confirm machine identity
2. **Onboard existing docs** — `/docs onboard ~/projects/homelab/` to batch-import
3. **Work normally** — hooks silently detect changes to managed documents
4. **Review at session end** — `/docs queue review` for multi-select approval flow

## Commands

| Command | Description |
|---------|-------------|
| `/docs queue` | Display current queue items |
| `/docs queue review` | Interactive review and approval |
| `/docs queue clear` | Dismiss all items (reason required) |
| `/docs status` | Operational and library health |
| `/docs hook status` | Hook registration and timestamps |
| `/docs index init` | Initialize documentation index |
| `/docs index sync` | Sync index with remote |
| `/docs index audit` | Check index integrity |
| `/docs library` | List documentation libraries |
| `/docs find <query>` | Search the documentation index |
| `/docs new` | Create a new managed document |
| `/docs onboard <path>` | Register existing docs in index |
| `/docs update <path>` | Update a managed document |
| `/docs review <path>` | Comprehensive document review |
| `/docs organize <path>` | Reorganize a document |
| `/docs audit` | Audit documentation quality |
| `/docs verify [path]` | Upstream verification |
| `/docs template` | Manage document templates |
| `/docs help` | Show all commands |

## Skills

| Skill | Trigger |
|-------|---------|
| `project-entry` | Entering a project directory with registered library |
| `doc-creation` | Creating `.md` files in managed locations |
| `session-boundary` | Session wrap-up detected in conversation |

## Agents

| Agent | Purpose |
|-------|---------|
| `bulk-onboard` | Context-efficient batch import of document directories |
| `full-review` | Comprehensive quality sweep (audit + consistency + upstream) |
| `upstream-verify` | Verify docs against upstream URLs |

## Hooks

| Event | Matcher | Behavior |
|-------|---------|----------|
| `PostToolUse` | `Write\|Edit\|MultiEdit` | Detect doc changes, queue items silently |
| `Stop` | `*` | Surface queue summary at session end |

## State Files

```
~/.docs-manager/
├── config.yaml              Machine identity, index backend settings
├── queue.json               Pending documentation items
├── queue.fallback.json      Overflow when main queue write fails
├── session-history.jsonl    Archive of cleared/dismissed items
├── docs-index.json          Document registry (if json backend)
├── docs-index.md            Human-readable mirror (auto-generated)
├── hooks/
│   ├── post-tool-use.last-fired
│   └── stop.last-fired
├── cache/
│   └── pending-writes.json  Offline writes waiting for sync
└── index.lock               Write lock (PID-based, auto-cleaned)
```

## Configuration

`~/.docs-manager/config.yaml`:
```yaml
machine: hostname
index:
  type: git-markdown    # or json
  location: ~/projects/docs-index
```

## Testing

```bash
# Unit tests
bats plugins/docs-manager/tests/queue.bats
bats plugins/docs-manager/tests/utilities.bats
bats plugins/docs-manager/tests/detection.bats
bats plugins/docs-manager/tests/index.bats

# All tests
bats plugins/docs-manager/tests/*.bats

# Marketplace validation
./scripts/validate-marketplace.sh
```
