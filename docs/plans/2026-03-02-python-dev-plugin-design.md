# python-dev Plugin Design

**Date:** 2026-03-02
**Status:** Approved

## Problem

11 Python-focused skills exist only in `~/.claude/skills/` (local machine). They are not distributable, not discoverable as a cohesive unit, and there is no slash command for running a comprehensive Python code review against all domains at once.

## Solution

Create a `python-dev` plugin that packages all 11 skills and adds a `/python-code-review` command. Publish to the marketplace so the skills become installable and distributable.

## Plugin Structure

```
plugins/python-dev/
├── .claude-plugin/plugin.json
├── CHANGELOG.md
├── README.md
├── commands/
│   └── python-code-review.md
└── skills/
    ├── async-python-patterns/SKILL.md
    ├── python-anti-patterns/SKILL.md
    ├── python-background-jobs/SKILL.md
    ├── python-code-style/SKILL.md
    ├── python-configuration/SKILL.md
    ├── python-design-patterns/SKILL.md
    ├── python-observability/SKILL.md
    ├── python-resilience/SKILL.md
    ├── python-resource-management/SKILL.md
    ├── python-testing-patterns/SKILL.md
    └── python-type-safety/SKILL.md
```

## Skills

Copied verbatim from `~/.claude/skills/python-*/` and `~/.claude/skills/async-python-patterns/`. The `name:` and `description:` frontmatter fields are preserved so context-triggered loading continues to work.

Before copying, each skill's `description:` trigger keywords are reviewed and updated where needed to ensure appropriate, non-overlapping trigger conditions.

After the plugin is committed to the repo, the local copies in `~/.claude/skills/` can be removed — the installed plugin provides them.

## `/python-code-review` Command

**Invocation:** `/python-code-review [path]`
- Path is optional; defaults to the current working directory
- Accepts a file path, directory path, or glob pattern

**Behavior:**

1. Identify target Python files (`.py`) at the given path
2. Read the files
3. Audit systematically across all 11 domains, in this order:
   - Anti-patterns (highest signal, check first)
   - Type safety
   - Design patterns
   - Code style
   - Resource management
   - Resilience
   - Configuration
   - Observability
   - Testing
   - Async patterns
   - Background jobs
4. Emit findings per domain using 🔴 critical / 🟡 needs attention / 🟢 looks good
5. Conclude with a summary of the top 3 action items

**Allowed tools:** Read, Glob, Grep, Bash (for finding files)

## Marketplace Entry

New entry added to `.claude-plugin/marketplace.json`:

```json
{
  "name": "python-dev",
  "description": "11 Python development skills covering async patterns, anti-patterns, type safety, testing, resilience, observability, and more. Includes /python-code-review for comprehensive code audits.",
  "version": "1.0.0",
  "author": { "name": "L3DigitalNet", "url": "https://github.com/L3DigitalNet" },
  "source": "./plugins/python-dev",
  "homepage": "https://github.com/L3DigitalNet/Claude-Code-Plugins/tree/main/plugins/python-dev"
}
```

## Implementation Steps

1. Read and audit all 11 skill `description:` trigger fields — update any that are vague, overlapping, or missing key trigger phrases
2. Create plugin directory and `plugin.json`
3. Copy all 11 skills into `plugins/python-dev/skills/`
4. Write `commands/python-code-review.md`
5. Write `README.md` and `CHANGELOG.md`
6. Add marketplace entry to `.claude-plugin/marketplace.json`
7. Run `./scripts/validate-marketplace.sh`
8. Commit to `testing` branch
