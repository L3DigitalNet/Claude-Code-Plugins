# design-refine

A Claude Code plugin for iteratively refining software and project design
documents through structured gap analysis, collaborative review, and consistency
auditing.

## Installation

### Test locally during development

```bash
claude --plugin-dir /path/to/design-refine
```

### Install from a local directory

```bash
claude plugin install --source /path/to/design-refine
```

### Install from GitHub

```bash
claude plugin install --source github:your-username/design-refine
```

## Usage

```
/design-refine:refine path/to/design-doc.md
```

The skill is set to `disable-model-invocation: true`, meaning Claude will not
auto-invoke it. You must explicitly run the slash command to start a review.

## How it works

The skill runs a structured loop:

1. **Comprehension** — Read and internalize the document's goals, principles,
   and scope
2. **Gap Analysis** — Identify gaps, inconsistencies, and opportunities for
   deeper elaboration
3. **Recommendations** — Present a prioritized, severity-labeled list (max 10
   per pass) for collaborative review
4. **Implementation** — Apply agreed-upon changes in place
5. **Consistency Audit** — Verify the document remains internally consistent
   after edits
6. **Loop or Complete** — Repeat until no meaningful refinements remain

The loop continues until you and Claude agree the document is stable. A
changelog summarizing all passes is produced at completion.

## Scope

This plugin is intentionally conservative. It will **not**:

- Propose new major features or architectural components
- Expand the project's scope beyond what's already described
- Make changes without your approval

It **will**:

- Find underspecified behavior, missing edge cases, and vague language
- Flag internal contradictions (structural and philosophical)
- Surface areas where existing features need deeper elaboration
- Ensure terminology and cross-references stay consistent across edits

## Plugin structure

```
design-refine/
├── .claude-plugin/
│   └── plugin.json        # Plugin manifest (required)
├── skills/
│   └── refine/
│       └── SKILL.md       # Skill instructions
└── README.md
```

## Tool permissions

The skill restricts Claude to file operations only via `allowed-tools`:

- **Read** — View file contents
- **Write** — Create new files
- **Edit** — Modify existing files
- **Grep** — Search within files
- **Glob** — Find files by pattern
