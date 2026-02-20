# [Plugin Name] — Design Document

<!--
FULL TEMPLATE — use when your plugin uses any of:
  hooks (PostToolUse, PreToolUse, Stop, PreCompact)
  agents (custom subagent definitions)
  shell scripts (called by hooks or commands)
  MCP server (Model Context Protocol)
  persistent state files (config, queues, indexes, caches)

If your plugin is commands and/or skills only, use the simpler template
(docs/plugin-design-template-simple.md) instead.
-->

Version: 0.1 (Draft)
Status: In Progress — NOT FOR IMPLEMENTATION
Last Updated: YYYY-MM-DD
Authors: TBD
Reviewers: TBD

---

## Table of Contents

1. [Overview & Problem Statement](#1-overview--problem-statement)
2. [Goals & Non-Goals](#2-goals--non-goals)
3. [Design Principles](#3-design-principles)
4. [Plugin Architecture](#4-plugin-architecture)
5. [Core Workflows](#5-core-workflows)
6. [Domain-Specific Core Section](#6-domain-specific-core-section)
7. [Testing Strategy](#7-testing-strategy)
8. [Open Questions & Decisions Log](#8-open-questions--decisions-log)
9. [Appendix](#9-appendix)

---

## 1. Overview & Problem Statement

<!--
Two to four paragraphs covering:

1. THE FAILURE MODE: What currently goes wrong without this plugin? Be specific.
   Reference the real-world evidence — prior attempts, known patterns, observed
   failures. Avoid vague generalizations.

2. THE SCOPE: Why is this a plugin rather than a CLAUDE.md instruction? What does
   the plugin enforce mechanically that instructions cannot?

3. THE USER: Who experiences this problem? Be specific about the usage context
   (e.g., "solo developers maintaining multiple repos", "Claude sessions doing
   repetitive release work", "teams where multiple agents share state").

GOOD: "The release process involves N steps Claude consistently forgets or gets
wrong when operating under pressure. CLAUDE.md instructions are ignored when Claude
is mid-task. This plugin enforces pre-flight checks mechanically via hooks before
any irreversible operation runs."
BAD: "This plugin helps manage the workflow more efficiently."

Keep this section anchored to the specific problem — not a feature list.
-->

[Describe the problem statement here.]

---

## 2. Goals & Non-Goals

### Goals

<!--
3–6 goals, stated as outcomes the plugin guarantees — not features it ships.
Use active voice. Each goal should be verifiable: if you can't write a test that
confirms it, rewrite it until you can.
Prioritize: most critical outcome first.
-->

- [Goal 1]
- [Goal 2]
- [Goal 3]

### Non-Goals

<!--
3–5 explicit non-goals. Non-goals define the scope boundary — they're often
more useful than goals for preventing implementation drift.
Common patterns:
- "Not a replacement for X" — scope boundary against adjacent tools
- "Not designed for Y scenario" — scope boundary against edge cases
- "Not responsible for Z infrastructure" — dependency boundary
If you had to cut scope, what would go here? Add it as a non-goal now.
-->

- [Non-goal 1]
- [Non-goal 2]
- [Non-goal 3]

---

## 3. Design Principles

### Preamble

<!--
2–3 sentences explaining WHY these specific principles apply to THIS plugin.
Must include:
(a) The primary failure mode these principles collectively prevent (from §1)
(b) What the plugin explicitly de-prioritizes — the trade-off the principles encode
(c) If any two principles are in tension, name the tiebreaker rule here

AVOID: generic engineering values. If another plugin with a completely different
purpose could use the same preamble, it's too vague.
-->

[Preamble here.]

---

### P1 — [Principle Name]

<!--
The full principle format used across this repo. Every field is required.
See docs-manager/docs/design.md §3 for examples of well-formed principles.
-->

**Statement**:
[One declarative sentence — a decision rule the plugin follows when under implementation
pressure. It should tell you what to do in a specific situation, not just express a value.]

**Intent**:
[What specific failure mode does this principle prevent? Name it concretely. The minimum
bar: "Prevents [specific bad outcome] that would otherwise occur when [specific pressure]."
If no concrete failure mode comes to mind, the principle may be too vague.]

**Enforcement Heuristic**:
[What does a violation look like in practice? Name a specific code pattern, architectural
choice, or behavior. E.g., "A hook script that exits non-zero on failure" or "A command that
runs a destructive operation without first surfacing a summary for user confirmation." Be
specific enough that another developer could identify a violation without asking you.]

**Cost of Following This Principle**:
[What does this plugin or user give up to honor this principle? There must be a real cost.
If following this principle is free, it's not a principle — it's a platitude. E.g., "The
plugin gives up the ability to run silently end-to-end without user involvement, because
confirmation gates are required at key decision points."]

**Tiebreaker**:
[If this principle conflicts with another principle in this plugin, which one wins? State the
rule. E.g., "When P2 and P3 conflict, P2 takes precedence — correctness over speed."
If no conflict is expected: "None."]

**Risk Areas**:
[Which parts of this plugin are most likely to violate this principle under implementation
pressure? E.g., "The session-end hook, where the temptation is to skip the queue review
to reduce friction."]

---

<!--
Add P2, P3, etc. in the same format above. Copy the full block for each principle.
Most complex plugins need 4–7 principles. Under 3 usually means scope is too narrow
for a design doc; over 8 usually means scope is too broad for a single plugin.

After writing all principles, go back and add [→ Pn] cross-references in §5 and §6
wherever a design decision directly implements or depends on a specific principle.
-->

---

## 4. Plugin Architecture

### Components

<!--
List ONLY the components this plugin actually needs. For each component type you use,
explain why that type was chosen (not commands for this? why?). For each component type
you're NOT using, you don't need to mention it.

Component types:
- Commands  (/plugin-name [subcmd]): user-invocable, enter context on invocation
- Skills    (AI-invoked .md files): load contextually when Claude deems relevant
- Hooks     (shell scripts on tool events): run externally, only stdout enters context
- Agents    (custom subagent definitions): run in subprocess, tool-restricted
- Scripts   (shell scripts): called by hooks or commands, run externally
- MCP Server: exposes tools via Model Context Protocol, stdio or HTTP

For each component: name, purpose (one sentence), and context cost (when does it
enter Claude's context window, if at all).
-->

**Commands** (`/[name] <subcommand>`)
- [Subcommand 1]: [Purpose]
- [Subcommand 2]: [Purpose]

**Skills**
- [skill-name]: [When does Claude invoke this contextually?]

**Hooks**
- [hook-event] → [script-name.sh]: [What does this hook detect/enforce?]

**Scripts**
- [script-name.sh]: [Called by? Does what?]

**Agents** (if applicable)
- [agent-name]: [What task does it handle? What tool restrictions apply?]

**MCP Server** (if applicable)
- [server-name]: [What tools does it expose?]

---

### State & Configuration Files

<!--
List every file this plugin reads or writes outside its own directory.
For each file: path, purpose, format, and what breaks if it's missing or corrupted.
This section is critical for understanding the plugin's blast radius.

If the plugin is stateless (no files outside its directory): write "None — stateless plugin."
-->

```
~/.plugin-name/
  config.yaml        # [Purpose. Format. What breaks if absent?]
  state.json         # [Purpose. Format. What breaks if corrupted?]
  cache/
    snapshot.json    # [Purpose. Invalidation policy.]
```

```yaml
# ~/.plugin-name/config.yaml (example)
field-one: value     # [What does this field control?]
field-two: value     # [What does this field control?]
```

---

### Context Cost Model

<!--
A table showing what enters Claude's context window and when.
This matters because large context costs degrade performance at scale.
Reference: CLAUDE.md "Context Footprint" table for the standard format.
-->

| Component | Enters context? | When? |
|-----------|-----------------|-------|
| Command markdown | Yes | On `/[name]` invocation |
| Skills | Conditionally | When Claude deems relevant |
| Hook scripts | No | Run externally; only stdout returned |
| Scripts | No | Run externally; only stdout returned |
| Agent definitions | No (for parent) | Loaded by spawned agent |
| [State file summary] | Yes | [When?] |

---

### Failure Modes & Graceful Degradation

<!--
For each external dependency this plugin has (config files, git, network, other tools),
answer: what happens when it fails?

The goal is to ensure silent failures are impossible — the user cannot discover a broken
plugin by noticing absent behavior. Every failure must surface explicitly.

Format: Failure | Detection | Behavior | Recovery

Required entries: config file missing/corrupted, any external tool/API dependency.
Hook-specific: hook scripts should always exit 0 (see CLAUDE.md §Hooks Reference).
-->

| Failure | Detection | Behavior | Recovery |
|---------|-----------|----------|----------|
| Config file missing | [How?] | [What happens?] | [How to recover?] |
| [External dependency] unavailable | [How?] | [What happens?] | [Recovery command?] |
| State file corrupted | [How?] | [What happens?] | [Recovery?] |

---

## 5. Core Workflows

<!--
Describe 3–5 key user-facing workflows as numbered steps. For each workflow:
- Name it as a user action or trigger condition
- State what triggers it
- List steps with enough detail that another developer could implement it
- Annotate steps that implement a design principle with [→ Pn]
- Include at least one error/edge case workflow

Workflows are the source of truth for what the plugin does. If a feature isn't
described here, it won't be built. If it's here, it must be implemented.
-->

### [Workflow 1 Name]

<!--
Describe what triggers this workflow and what success looks like.
-->

1. [Step 1] [→ P1]
2. [Step 2]
3. [Step 3] [→ P2]

### [Workflow 2 Name]

1. [Step 1]
2. [Step 2]

### [Error/Edge Case Workflow]

1. [Step 1]

---

## 6. Domain-Specific Core Section

<!--
This placeholder is intentional. Replace this entire section with the technical
core most relevant to your plugin's domain. Choose the right heading:

For hook-heavy plugins → "6. Hook Design"
  Cover: hook events used, detection logic, queue/dispatch behavior,
  error handling contract (hooks must always exit 0 in this repo).

For agent-heavy plugins → "6. Agent Design"
  Cover: agent definitions, tool restrictions, task decomposition,
  how agents return results, context isolation strategy.

For MCP plugins → "6. MCP Tool Reference"
  Cover: tool schemas, input/output types, error codes, rate limits,
  authentication model.

For data-model-heavy plugins → "6. Data Model"
  Cover: schema definitions, persistence strategy, migration approach,
  consistency guarantees.

For command-surface-heavy plugins → "6. Command Reference"
  Cover: full flag reference for each command, input validation,
  error messages, edge cases.

Delete this comment block and replace it with the appropriate section title
and content. Don't leave this section as a placeholder — it's the technical
heart of your design.
-->

---

## 7. Testing Strategy

<!--
Cover all four layers. For each layer, be specific: framework, fixtures, scope.
If a layer doesn't apply, say why.
-->

### 7.1 Self-Test (`/[name] status --test`)

<!--
What can the plugin verify about itself at runtime?
Self-tests should be non-destructive read-only checks against the live environment.
Cover: config file validity, state file accessibility, dependency availability.
Self-test results feed into /[name] status output — operational vs content health.
If your plugin has no runtime state, this layer may not apply. Say so.
-->

**Self-test checks** (all read-only, non-destructive):
- [ ] [Check 1: e.g., config file exists and contains required fields]
- [ ] [Check 2: e.g., state file is valid JSON or absent]
- [ ] [Check 3: e.g., external dependency is reachable]

---

### 7.2 Unit Tests (bats)

<!--
What shell scripts have deterministic behavior testable with bats?
Tests must run against a disposable temp directory ($BATS_TMPDIR) — never against
~/ or any production state. If your plugin has no shell scripts: state this explicitly.
-->

**What bats covers:**
- Happy path: [description of core script behavior]
- Error path: [description of failure handling]
- Edge case: [description of boundary condition]

All bats tests use `$BATS_TMPDIR/[plugin]-test/` — never production files.

---

### 7.3 Structural Tests (Plugin Test Harness)

<!--
PTH validates plugin structure and component contracts — not behavior.
Standard checks apply to all plugins: hook.json schema, command frontmatter,
skill frontmatter, plugin.json fields.
List any plugin-specific structural requirements PTH should verify.
-->

**PTH checks for this plugin:**
- Hook registration: hooks.json uses the record format (keyed by event name)
- Command structure: all commands have required frontmatter fields
- Skill triggers: skill files have appropriate trigger metadata
- [Plugin-specific]: [describe any non-standard structural contract]

---

### 7.4 Sandboxed Workflow Tests

<!--
Manual end-to-end tests run in an isolated Claude Code session against a sandboxed
environment — never touching production state.
For each scenario: what you invoke, what you verify, what the success condition is.
-->

**Sandbox setup:**
```bash
# [Commands to create a throwaway test environment]
# Override config to point at sandbox, not production state
```

**Scenarios (one Claude session per scenario):**
1. [Scenario name] — invoke [command/trigger], verify [expected outcome]
2. [Scenario name] — invoke [command/trigger], verify [expected outcome]
3. Error path — [trigger failure condition], verify [expected error handling]

---

## 8. Open Questions & Decisions Log

<!--
Only log decisions that cannot be made now — they depend on external information,
require stakeholder agreement, or block implementation in a non-trivial way.

Per-entry criteria:
(a) Phrased as a single answerable question — not a topic or concern
(b) "Why it matters" names a concrete downstream consequence
(c) Does not duplicate a stub section (stubs = author can answer; OQs = cannot yet)
(d) Status at design time: always Open

If you find yourself writing an OQ you can answer right now — answer it here instead.
-->

| # | Question | Why it matters | Owner | Status |
|---|----------|----------------|-------|--------|
| OQ1 | [Specific, answerable question] | [Concrete consequence if unresolved] | TBD | Open |

---

## 9. Appendix

<!--
Fill incrementally during implementation. Seed section headers during design so
they're discoverable as implementation proceeds.
-->

### 9.1 Glossary

<!--
Domain terms unique to this plugin. Omit standard software/plugin terms unless
your usage differs from the standard meaning.
-->

| Term | Definition |
|------|------------|
| [Term] | [Definition] |

---

### 9.2 Command Reference

<!--
Expand each command entry with flags, examples, and edge-case behavior during
implementation. Seed entries here during design.
-->

| Command | Description | Key flags |
|---------|-------------|-----------|
| `/[name] [subcommand]` | [Description] | `--[flag]` |

---

### 9.3 Configuration Field Reference

<!--
All config fields with types, defaults, and validation rules.
Populate during implementation as fields are finalized.
-->

| Field | Required | Type | Default | Notes |
|-------|----------|------|---------|-------|
| `[field-name]` | ✓ | string | — | [What it controls, what breaks if wrong] |
