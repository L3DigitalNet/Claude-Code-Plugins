# Linux Sysadmin: Single Dispatcher Skill

**Date:** 2026-03-26
**Status:** Approved
**Goal:** Replace 137 individual skills with one dispatcher skill that references topic guide files, eliminating skill list pollution while preserving topic discoverability.

## Problem

The linux-sysadmin plugin registers 137 skills in Claude Code's skill list. Each skill appears individually in slash command autocompletion and the AI's available-skills context. This pollutes the interface for users and consumes context window space listing skills the AI rarely needs simultaneously.

## Design

### Directory Structure (after)

```
plugins/linux-sysadmin/
├── skills/
│   └── sysadmin/
│       └── SKILL.md              # Single dispatcher skill
├── guides/                       # 137 topic directories
│   ├── docker/
│   │   ├── guide.md              # Former SKILL.md (frontmatter stripped)
│   │   └── references/           # Unchanged
│   ├── nginx/
│   │   ├── guide.md
│   │   └── references/
│   └── ...136 more
├── commands/sysadmin.md          # Unchanged
├── hooks/hooks.json              # Context message updated
├── scripts/sysadmin-context.sh   # Reference updated
└── README.md                     # Updated
```

### Single Dispatcher Skill (`skills/sysadmin/SKILL.md`)

The skill has three sections:

1. **Frontmatter** with:
   - `name: sysadmin`
   - Broad `description` covering Linux system administration
   - `triggerPhrases` containing ~80 high-value keywords (service names, common commands) drawn from the most frequently needed topics. Not exhaustive; the topic index covers the rest.
   - No `globs` (too many patterns from 137 topics to be useful in one field)

2. **Topic Index** -- a compact table with columns: topic name, one-line description. All 137 topics listed alphabetically. This gives Claude enough context to identify which guide to load without reading all guides upfront.

3. **Dispatcher Instructions** -- tells Claude:
   - When a topic matches, `Read` the guide at the relative path `guides/{topic}/guide.md`
   - Guide files may reference a `references/` subdirectory with annotated configs, cheatsheets, and doc links
   - Read references only when the user needs deeper detail
   - Multiple topics can be loaded in one session

### Guide Files (`guides/{topic}/guide.md`)

Each guide file is the former `SKILL.md` with these changes:
- YAML frontmatter removed entirely (no longer a skill; metadata serves no purpose)
- A `# {Topic Name}` heading added at the top for readability
- Body content unchanged
- `references/` subdirectory unchanged

### Hook Update (`scripts/sysadmin-context.sh`)

The SessionStart hook message changes from referencing 137 individual skills to referencing the single `linux-sysadmin:sysadmin` skill:

```
Before: Skill("linux-sysadmin:postgresql"), Skill("linux-sysadmin:nginx"), ...
After:  Skill("linux-sysadmin:sysadmin") — it contains a topic index and will load the right guide
```

### What Does NOT Change

- `commands/sysadmin.md` -- the `/sysadmin` stack design command is unchanged
- `hooks/hooks.json` -- structure unchanged (still SessionStart)
- `.claude-plugin/plugin.json` -- version bumped, description updated
- Guide content -- the technical content of all 137 topics is preserved verbatim
- `references/` subdirectories within each topic -- unchanged

## Migration

The migration is a bulk rename/move operation:

1. Create `guides/` directory at plugin root
2. Move all 137 directories from `skills/` to `guides/`
3. Rename `SKILL.md` to `guide.md` in each, stripping YAML frontmatter and adding a heading
4. Create `skills/sysadmin/SKILL.md` with the dispatcher content
5. Update `scripts/sysadmin-context.sh`
6. Update `plugin.json` version
7. Update marketplace entry version
8. Update `README.md`
9. Update `CHANGELOG.md`

## Tradeoffs

**Lost:** Per-topic glob-based triggering (90 topics had file-matching globs like `**/Dockerfile`). The single skill can't carry 90 different glob patterns effectively.

**Kept:** Keyword-based triggering via the dispatcher skill's `triggerPhrases` and `description`. The topic index inside the skill body lets Claude identify the right guide even for topics not in the trigger phrases.

**Gained:** Clean skill list (1 entry instead of 137), faster plugin load, less context window consumed by skill metadata.

## Success Criteria

- `claude --plugin-dir ./plugins/linux-sysadmin` shows 1 skill, not 137
- Asking about a covered topic (e.g., "configure nginx") triggers the sysadmin skill and Claude reads the right guide
- The `/sysadmin` command still works
- All 137 guide files are accessible and contain their original content
