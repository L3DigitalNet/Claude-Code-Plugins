---
title: Sub-Agents Reference
category: development
target_platform: linux
audience: ai_agent
keywords: [agents, subagents, tools, permissions, specialization]
---

# Sub-Agents Reference

## Overview

**Purpose:** Specialized Claude modes with custom tools and prompts **Invocation:**
`/agent-name [prompt]` **Location:** `agents/*.md` **Format:** Markdown with YAML
frontmatter

**Characteristics:**

- Custom system prompts
- Controlled tool access
- Dedicated workflows
- Isolated execution

## Built-in Agents

### Explore Agent

**Purpose:** Read-only code research **Invocation:** `/explore <query>`

**Available tools:**

- `semantic_search` - Semantic code search
- `grep_search` - Pattern matching
- `read_file` - Read file contents
- `list_dir` - Directory listing

**Restricted tools:**

- `write_file` - No write access
- `run_command` - No execution
- `replace_string_in_file` - No edits

**Use cases:**

- Code exploration
- Architecture understanding
- Finding examples
- API research

**Example:**

```bash
/explore Find all authentication-related files
/explore How is error handling implemented?
```

### Plan Agent

**Purpose:** Task planning and design **Invocation:** `/plan <task>`

**Available tools:**

- `read_file` - Read codebase
- `semantic_search` - Search code
- `list_dir` - Explore structure

**Restricted tools:**

- `run_command` - No execution
- `write_file` - No changes

**Use cases:**

- Break down complex tasks
- Design solutions
- Create implementation plans
- Propose approaches

**Example:**

```bash
/plan How should we refactor the authentication system?
/plan Design a testing strategy for this module
```

## Custom Agent Creation

**Location:** `agents/agent-name.md`

### Agent File Schema

**YAML frontmatter:**

```yaml
name: string # Agent identifier (lowercase-hyphenated)
description: string # Purpose and use case
tools: # Allowed tools array
  - 'read_file'
  - 'grep_search'
restrictedTools: # Explicitly denied tools
  - 'run_in_terminal'
  - 'replace_string_in_file'
```

**Markdown content:** Agent system prompt and instructions

### Minimum Viable Agent

```bash
mkdir -p my-plugin/agents
cat > my-plugin/agents/reviewer.md << 'EOF'
---
name: reviewer
description: Code review agent
tools:
  - "read_file"
  - "grep_search"
restrictedTools:
  - "write_file"
  - "run_command"
---

# Code Reviewer

You are a code reviewer. Focus on:
- Code quality
- Best practices
- Security issues
EOF
```

## Available Tools

### Read-Only Tools

| Tool              | Purpose              | Use In             |
| ----------------- | -------------------- | ------------------ |
| `read_file`       | Read file contents   | All agents         |
| `grep_search`     | Pattern search       | Research, analysis |
| `semantic_search` | Semantic code search | Exploration        |
| `list_dir`        | Directory listing    | Navigation         |
| `file_search`     | File name search     | Discovery          |

### Write Tools

| Tool                           | Purpose      | Restriction Level |
| ------------------------------ | ------------ | ----------------- |
| `write_file`                   | Create files | High risk         |
| `replace_string_in_file`       | Edit files   | High risk         |
| `multi_replace_string_in_file` | Batch edits  | High risk         |

### Execution Tools

| Tool                  | Purpose             | Restriction Level |
| --------------------- | ------------------- | ----------------- |
| `run_in_terminal`     | Execute commands    | Critical risk     |
| `get_terminal_output` | Read command output | Medium risk       |

### System Tools

| Tool           | Purpose           | Typical Use |
| -------------- | ----------------- | ----------- |
| `get_errors`   | Check errors      | Validation  |
| `switch_agent` | Change agent mode | Workflow    |

## Tool Access Control

### Allowlist Approach

**Strategy:** Explicitly list allowed tools (recommended)

```yaml
tools:
  - 'read_file'
  - 'grep_search'
  - 'semantic_search'
```

**Default:** All unlisted tools are restricted

### Denylist Approach

**Strategy:** Restrict specific tools

```yaml
restrictedTools:
  - 'run_in_terminal'
  - 'write_file'
```

**Default:** All unlisted tools are allowed

### Combined Approach

**Strategy:** Explicit allow + explicit deny

```yaml
tools:
  - 'read_file'
  - 'grep_search'
restrictedTools:
  - 'run_in_terminal'
```

**Behavior:** `tools` takes precedence, `restrictedTools` adds additional restrictions

Reference the agent in `manifest.json`:

```json
{
  "name": "my-plugin",
  "version": "1.0.0",
  "description": "Plugin with custom agent"
}
```

Agents in `.claude-plugin/agents/` are automatically discovered.

### 3. Invoke the agent

Users can invoke with:

```bash
/my-agent Do the thing
```

## Agent configuration

### Frontmatter fields

```yaml
name: agent-name
description: One-line summary
tools:
  - read_file
  - grep_search
restrictedTools:
  - run_in_terminal
permissions:
  mode: explicit
  allowFileWrite: false
```

#### Required fields

- **name**: Agent identifier (lowercase with hyphens)
- **description**: Brief summary

#### Optional fields

- **tools**: Allowed tools (explicit list)
- **restrictedTools**: Denied tools (takes precedence)
- **permissions**: Permission configuration
- **timeout**: Max execution time in seconds
- **maxTokens**: Token limit for responses

### Tool control

Three ways to control tool access:

#### 1. Explicit allow list

```yaml
tools:
  - read_file
  - grep_search
  - semantic_search
```

Agent can ONLY use these tools.

#### 2. Explicit deny list

```yaml
restrictedTools:
  - run_in_terminal
  - replace_string_in_file
```

Agent can use any tool EXCEPT these.

#### 3. Combined

```yaml
tools:
  - read_file
  - grep_search
  - run_in_terminal
restrictedTools:
  - run_in_terminal
```

`restrictedTools` takes precedence, so `run_in_terminal` is blocked.

### Permission modes

```yaml
permissions:
  mode: explicit # or 'permissive'
  allowFileWrite: false
  allowFileRead: true
  allowNetworkAccess: false
```

- **explicit**: Only allowed actions permitted
- **permissive**: All actions allowed except restricted

## Agent instructions

The markdown content below the frontmatter is the agent's system prompt.

### Example: Code reviewer

```markdown
---
name: reviewer
description: Systematic code review agent
tools:
  - read_file
  - grep_search
  - semantic_search
restrictedTools:
  - replace_string_in_file
  - run_in_terminal
---

# Code Review Agent

You are a meticulous code reviewer focused on quality, security, and best practices.

## Review process

1. **Read the code**: Understand what it does
2. **Check for issues**:
   - Security vulnerabilities
   - Performance problems
   - Code smells
   - Missing error handling
   - Unclear naming
3. **Provide feedback**: Clear, actionable suggestions
4. **Verify tests**: Ensure adequate test coverage

## Guidelines

- Be constructive and specific
- Explain WHY something is an issue
- Suggest concrete improvements
- Consider context and constraints
- Prioritize critical issues

## Focus areas

- **Security**: SQL injection, XSS, secrets in code
- **Performance**: N+1 queries, unnecessary loops
- **Maintainability**: Clear naming, proper abstractions
- **Testing**: Edge cases, error paths
```

## Advanced patterns

### Contextual agents

Load different behavior based on context:

```markdown
---
name: language-aware-agent
description: Adapts to programming language
---

# Language-Aware Agent

${language === 'python' ? `You are a Python expert. Follow PEP 8 and use type hints.` :
language === 'typescript' ?
`You are a TypeScript expert. Use strict mode and proper types.` :
`General programming assistant.`}
```

### Chained agents

One agent can invoke another:

```markdown
---
name: orchestrator
description: Coordinates multiple sub-agents
---

# Orchestrator

You coordinate specialized agents to complete complex tasks.

When analyzing code:

1. Use `/explore` to find relevant files
2. Use `/reviewer` to check code quality
3. Use `/plan` to propose improvements
```

### Hooks integration

Trigger agents at specific lifecycle points:

```markdown
---
name: session-starter
description: Runs at session start
---

# Session Start Agent

Run when a new session begins:

1. Check for uncommitted changes
2. Verify dependencies are installed
3. Display project status
```

Then configure in a hook (see [Hooks](./hooks.md)).

## Examples

### Test generator agent

```markdown
---
name: test-gen
description: Generate comprehensive test cases
tools:
  - read_file
  - grep_search
  - create_file
restrictedTools:
  - run_in_terminal
---

# Test Generator

You generate comprehensive test cases for code.

## Process

1. **Analyze code**: Understand the implementation
2. **Identify test cases**:
   - Happy path
   - Edge cases
   - Error conditions
   - Boundary values
3. **Generate tests**: Write clear, maintainable tests
4. **Verify coverage**: Ensure all paths tested

## Test structure

\`\`\`python import pytest

def test_happy_path(): """Test normal operation.""" result = function(valid_input)
assert result == expected_output

def test_edge_case(): """Test boundary condition.""" result = function(edge_input)
assert result == edge_output

def test_error_handling(): """Test error condition.""" with
pytest.raises(ExpectedException): function(invalid_input) \`\`\`
```

### Documentation agent

```markdown
---
name: doc-gen
description: Generate and update documentation
tools:
  - read_file
  - grep_search
  - semantic_search
  - create_file
  - replace_string_in_file
---

# Documentation Generator

You create and maintain project documentation.

## Documentation types

### API documentation

- Function signatures
- Parameter descriptions
- Return values
- Examples
- Error conditions

### README files

- Project overview
- Installation instructions
- Usage examples
- Configuration options

### Inline comments

- Complex logic explanations
- Intent clarification
- Warning about edge cases

## Style guide

- Use clear, concise language
- Provide concrete examples
- Keep formatting consistent
- Update when code changes
```

### Security audit agent

```markdown
---
name: security-audit
description: Security vulnerability scanner
tools:
  - read_file
  - grep_search
  - semantic_search
restrictedTools:
  - run_in_terminal
  - create_file
  - replace_string_in_file
---

# Security Audit Agent

You perform security audits of code.

## Scan for

### Injection vulnerabilities

- SQL injection
- Command injection
- XSS vulnerabilities

### Authentication issues

- Weak password policies
- Missing authentication
- Broken session management

### Data exposure

- Secrets in code
- Unencrypted sensitive data
- Information leakage

### Dependencies

- Known vulnerable packages
- Outdated dependencies

## Report format

For each issue:

1. **Severity**: Critical/High/Medium/Low
2. **Location**: File and line number
3. **Description**: What the issue is
4. **Impact**: Potential consequences
5. **Remediation**: How to fix it
```

## Testing agents

Test your agent locally:

```bash
# Install plugin
/plugin install /path/to/plugin --scope local

# Invoke agent
/my-agent Test the agent behavior
```

Verify:

- Agent responds to invocation
- Tool restrictions work
- Instructions are followed
- Output is appropriate

## Best practices

### Clear instructions

Write specific, actionable instructions:

✅ Good: "Check for SQL injection by looking for string concatenation in SQL queries" ❌
Vague: "Look for security issues"

### Appropriate tool access

Only grant tools needed for the task:

✅ Read-only agent: `read_file`, `grep_search` ❌ Over-permissive: All tools allowed

### Focused purpose

One agent, one job:

✅ Good: Separate review and fix agents ❌ Too broad: One agent to review, fix, test,
and deploy

### Documentation

Document agent usage in README:

```markdown
## Agents

### /reviewer

Reviews code for quality and security issues.

Usage: `/reviewer Check the login.py file`

### /test-gen

Generates test cases for code.

Usage: `/test-gen Create tests for auth module`
```

## Debugging agents

### Agent not found

Check:

1. Agent file in `.claude-plugin/agents/`
2. Valid YAML frontmatter
3. Plugin installed and enabled

### Agent not following instructions

Check:

1. Instructions are clear and specific
2. No conflicting guidelines
3. Examples are provided

### Tool access issues

Check:

1. Required tools are in `tools` list
2. No overlap with `restrictedTools`
3. Permissions mode is correct

## Next steps

- [Skills](./skills.md) for domain knowledge
- [Hooks](./hooks.md) to trigger agents automatically
- [Plugins reference](./plugins-reference.md) for technical details
- [Create plugins](./plugins.md) to package and distribute agents
