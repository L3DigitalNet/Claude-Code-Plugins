# [Plugin Name] — Design Document

<!--
SIMPLE TEMPLATE — use when your plugin consists only of commands and/or skills,
has no hooks, no shell scripts, no agents, no MCP server, and no persistent state.
Examples of simple plugins: a slash command that wraps a git workflow, a skill that
loads domain knowledge contextually, a command that audits a specific file type.

If your plugin requires hooks, agents, scripts, or external state, use the full
template (docs/plugin-design-template-full.md) instead.
-->

Version: 0.1 (Draft)
Status: In Progress — NOT FOR IMPLEMENTATION
Last Updated: YYYY-MM-DD

---

## 1. Problem Statement

<!--
One to two paragraphs. Answer three questions:
1. Who has this problem? (be specific — "Claude sessions in this repo", "solo sysadmins",
   "developers who release frequently")
2. What currently goes wrong without this plugin? Name the concrete failure mode.
3. Why is this the right scope for a plugin, not a CLAUDE.md instruction or a one-off
   script?

GOOD: "When running a release, Claude frequently forgets to check git user.email before
creating a tag. This causes commits with personal email addresses on public repos. A one-off
check in CLAUDE.md isn't reliable because Claude skips it under time pressure."
BAD: "This plugin helps streamline the workflow and improve efficiency."
-->

[Describe the specific workflow failure this plugin prevents. Be concrete about who experiences
it and what goes wrong.]

---

## 2. Goals & Non-Goals

### Goals

<!--
List 2–4 outcomes, stated as things the plugin achieves — not features it implements.
Use active voice: "Ensures X", "Prevents Y", "Surfaces Z before W".
If you can't imagine a test that verifies a goal, it's too vague.
-->

- [Goal 1]
- [Goal 2]
- [Goal 3]

### Non-Goals

<!--
List 2–3 things this plugin deliberately does NOT do. Non-goals are often more
useful than goals because they prevent scope creep during implementation.
Common patterns: "Not a replacement for X", "Does not handle Y edge case",
"Not intended for Z use case".
-->

- [Non-goal 1]
- [Non-goal 2]

---

## 3. Design Principles

<!--
2–4 principles specific to THIS plugin. Generic best practices ("keep it simple",
"handle errors gracefully") are not principles — they're platitudes. A real principle
has a cost: something the plugin gives up to honor it.

Each principle entry should answer:
- What decision rule does this establish?
- What does the plugin give up by following it?
- What failure mode does it prevent?

Reference these principles in §6 Workflows with [→ P1] annotations.
-->

**P1 — [Principle Name]**: [One declarative sentence stating the decision rule.]
*Cost: [What the plugin or user gives up when this principle is honored under pressure.]*

**P2 — [Principle Name]**: [Statement.]
*Cost: [Cost.]*

<!-- Add P3, P4 as needed. Most simple plugins need 2–4 principles. -->

---

## 4. Components

<!--
For each component, state: type, name, one-sentence purpose, and when it triggers.
Keep this table honest — only list components you will actually build.

Component types:
- Command: User-invocable slash command (/plugin-name [subcmd])
- Skill:   AI-invoked Markdown file; loads contextually when relevant
-->

| Type | Name | Purpose | Trigger |
|------|------|---------|---------|
| Command | `/[name]` | [What does invoking this command do?] | User types `/[name]` |
| Skill | `[skill-name]` | [When does Claude use this contextually?] | [Trigger condition] |

<!--
If your plugin grows to need hooks, agents, or scripts, switch to the full template.
-->

---

## 5. Key Workflows

<!--
Describe 2–3 end-to-end scenarios as numbered steps. Each workflow should cover:
- What triggers it (user types a command, Claude detects a context, etc.)
- What Claude does at each step
- What the user experiences
- What success looks like at the end

Annotate steps that implement a design principle with [→ Pn].
Keep each workflow to 4–8 steps.
-->

### Workflow 1: [Primary Use Case]

1. [Step 1]
2. [Step 2]
3. [Step 3]

### Workflow 2: [Secondary Use Case or Error Path]

1. [Step 1]
2. [Step 2]

---

## 6. Testing

<!--
For simple plugins, testing is usually:
1. Manual end-to-end: List the specific scenarios you'll run in a Claude session to
   confirm correct behavior. Be concrete — "invoke /command with no args and verify
   the error message matches the spec."
2. PTH structural: What plugin-test-harness checks apply? (command file structure,
   skill frontmatter, required fields)

If there are no shell scripts, bats tests are not needed. Say so explicitly.
-->

**Manual scenarios:**
- [ ] [Scenario 1: specific action + expected result]
- [ ] [Scenario 2]
- [ ] [Error path: what happens when X is missing or wrong?]

**PTH structural checks:**
- [ ] Command file has required frontmatter (`argument-hint`, `description`)
- [ ] Skill file has `name` and `description` in frontmatter
- [ ] [Any plugin-specific structural requirement]

---

## 7. Open Questions

<!--
Only list decisions that cannot be made now — either because they depend on external
information or require resolution before implementation begins.
If you can answer the question right now, answer it here instead of logging it as a
question. Stubs and open questions are different things.
-->

| # | Question | Why it matters | Status |
|---|----------|----------------|--------|
| OQ1 | [Specific, answerable question] | [Concrete consequence if not resolved] | Open |
