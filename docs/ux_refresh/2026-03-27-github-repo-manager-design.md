# github-repo-manager: References Architecture Conversion

## Problem

The plugin has 15 skills (3,336 lines) that all funnel through a single `/repo-manager` command. These skills occupy the skill menu and load descriptions into context even when the plugin isn't being used. The command already reads one skill on demand; the pattern is half-adopted.

## Pattern

Follow the nominal plugin's architecture: commands as thin orchestrators, domain knowledge in `references/` loaded via `Read ${CLAUDE_PLUGIN_ROOT}/references/...` only when needed, no skills.

## New Directory Structure

```
github-repo-manager/
  .claude-plugin/plugin.json
  commands/repo-manager.md          # Thin orchestrator (~60-70 lines)
  references/
    session.md                      # Session flow, tiers, comms, error handling
    assessment.md                   # Module execution order, dedup, findings format
    command-reference.md            # gh-manager CLI syntax
    config.md                       # Config system
    cross-repo.md                   # Cross-repo scanning and batch ops
    modules/
      pr-management.md
      issue-triage.md
      security.md
      release-health.md
      community-health.md
      dependency-audit.md
      notifications.md
      discussions.md
      wiki-sync.md
  hooks/hooks.json                  # Unchanged
  scripts/                          # Unchanged
  helper/                           # Unchanged
  templates/                        # Unchanged
  tests/                            # Unchanged
  config/                           # Unchanged
```

The `skills/` directory is deleted entirely.

## Command Rewrite

The command becomes a thin orchestrator that routes to references:

```
Step 0: Ensure deps (unchanged)
Step 1: Read references/session.md → execute onboarding, determine scope
Step 2: Route by scope
  - Cross-repo → Read references/cross-repo.md
  - Single-repo narrow check → Read the relevant references/modules/*.md
  - Single-repo full assessment → Read references/assessment.md,
    then read each references/modules/*.md sequentially as the assessment progresses
```

`references/command-reference.md` and `references/config.md` are loaded on demand when CLI syntax or config operations are needed.

## Reference Content

Each reference is the former skill body with YAML frontmatter stripped. Architectural comment headers that describe inter-skill relationships (e.g., "Called by commands/repo-manager.md Step 1. Delegates to repo-manager-assessment/SKILL.md") should be removed or updated to reflect the new references layout. The domain content itself is unchanged.

| Reference | Source skill | Lines |
|-----------|-------------|-------|
| session.md | repo-manager | ~280 |
| assessment.md | repo-manager-assessment | ~210 |
| command-reference.md | repo-manager-reference | ~100 |
| config.md | repo-config | ~70 |
| cross-repo.md | cross-repo | ~210 |
| modules/pr-management.md | pr-management | ~250 |
| modules/issue-triage.md | issue-triage | ~210 |
| modules/security.md | security | ~200 |
| modules/release-health.md | release-health | ~210 |
| modules/community-health.md | community-health | ~340 |
| modules/dependency-audit.md | dependency-audit | ~165 |
| modules/notifications.md | notifications | ~155 |
| modules/discussions.md | discussions | ~185 |
| modules/wiki-sync.md | wiki-sync | ~365 |

Self-test skill (263 lines) is deleted without replacement. The bash test scripts are self-documenting.

## User-Facing Changes

- `/repo-manager` works identically
- 14 fewer entries in the skill menu
- Zero idle context footprint
- Modules load one at a time during assessment

## Migration Checklist

1. Create `references/` and `references/modules/`
2. Move 14 skill bodies to reference files (strip frontmatter)
3. Delete `skills/` directory
4. Rewrite `commands/repo-manager.md` as thin orchestrator
5. Update README.md (remove skills table, document references)
6. Update CHANGELOG.md
7. Bump version in plugin.json and marketplace.json
8. Run `./scripts/validate-marketplace.sh`
