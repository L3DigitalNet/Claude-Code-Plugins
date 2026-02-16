---
title: Hooks Reference
category: automation
target_platform: linux
audience: ai_agent
keywords: [hooks, lifecycle, events, automation, triggers]
---

# Hooks Reference

## Overview

**Purpose:** Intercept and modify Claude behavior at lifecycle events **Location:**
`hooks/hooks.json` **Format:** JSON configuration

**Use cases:**

- Inject context
- Transform inputs/outputs
- Trigger external commands
- Collect metrics
- Automate workflows

## Lifecycle Events

| Event          | Timing                            | Input            | Common Uses                         |
| -------------- | --------------------------------- | ---------------- | ----------------------------------- |
| `SessionStart` | Session begins                    | None             | Setup, welcome, dependency check    |
| `SessionEnd`   | Session ends                      | None             | Cleanup, metrics, summary           |
| `PrePrompt`    | Before user message processing    | User message     | Input validation, context injection |
| `PostPrompt`   | After processing, before response | Processed prompt | Prompt modification                 |
| `PreToolUse`   | Before tool execution             | Tool name, args  | Authorization, logging              |
| `PostToolUse`  | After tool execution              | Tool result      | Result transformation, side effects |
| `PreResponse`  | Before sending response           | Response text    | Output filtering                    |
| `PostResponse` | After response sent               | Response text    | Metrics, notifications              |
| `Error`        | On error                          | Error details    | Error handling, alerts              |

## Creating hooks

### Basic structure

Hooks are markdown files with YAML frontmatter:

```markdown
---
name: my-hook
description: What this hook does
event: SessionStart
---

# Hook Implementation

Your hook logic in natural language that tells Claude what to do.
```

### Location

Place hooks in your plugin:

```
.claude-plugin/
└── hooks/
    ├── session-start.md
    └── pre-tool-use.md
```

## Hook events

### SessionStart

Runs when a new session begins.

**Use for**:

- Display welcome message
- Check project status
- Verify dependencies
- Load session configuration

**Example**:

```markdown
---
name: welcome-hook
description: Display project status at session start
event: SessionStart
---

When a session starts:

1. Check git status for uncommitted changes
2. Verify all tests pass
3. Display summary of recent commits
4. Show any pending TODOs

Format output as a brief status report.
```

### SessionEnd

Runs when session ends.

**Use for**:

- Save session state
- Clean up resources
- Summary of changes made
- Reminder prompts

**Example**:

```markdown
---
name: session-summary
description: Summarize session changes
event: SessionEnd
---

When session ends:

1. List files modified
2. Count lines added/removed
3. Note new functions/classes created
4. Suggest next steps

Keep summary concise (3-5 lines).
```

### PrePrompt

Runs before Claude processes user input.

**Use for**:

- Inject additional context
- Add recent changes info
- Include environment details
- Append relevant documentation

**Input**: User's message **Output**: Modified message or additional context

**Example**:

```markdown
---
name: context-injector
description: Add project context to prompts
event: PrePrompt
---

Before processing user input:

1. Check current branch name
2. Identify active files in editor
3. Note any test failures
4. Add this context to the prompt

Format:
```

[Context] Branch: ${branch} Active files: ${files} Test status: ${testStatus} [End
Context]

${userMessage}

```

```

### PostPrompt

Runs after Claude processes input but before generating response.

**Use for**:

- Modify interpretation
- Add constraints
- Inject last-minute context

**Example**:

```markdown
---
name: constraint-enforcer
description: Enforce code style constraints
event: PostPrompt
---

After understanding user request:

Add constraint: "All code must follow the project's established patterns in
CONVENTIONS.md"
```

### PreToolUse

Runs before Claude calls a tool.

**Use for**:

- Log tool usage
- Validate parameters
- Add confirmations for dangerous operations
- Inject tool-specific context

**Input**: Tool name and arguments **Output**: Modified arguments or cancellation

**Example**:

```markdown
---
name: safe-delete
description: Confirm before deleting files
event: PreToolUse
tool: run_in_terminal
---

Before running terminal commands:

If command contains `rm` or `delete`:

1. List affected files
2. Ask user to confirm: "Delete these files? (y/n)"
3. Only proceed if confirmed

Otherwise allow command without prompt.
```

### PostToolUse

Runs after tool execution completes.

**Use for**:

- Log results
- Transform tool output
- Trigger follow-up actions
- Error recovery

**Input**: Tool name, arguments, result **Output**: Modified result

**Example**:

```markdown
---
name: test-watcher
description: Notify on test failures
event: PostToolUse
tool: run_in_terminal
---

After running terminal commands:

If command contains `test` or `pytest`:

1. Check if output contains failures
2. If failures found, extract failure details
3. Add note: "⚠️ Tests failed. Review output above."

Pass through original output with any additions.
```

### PreResponse

Runs before sending response to user.

**Use for**:

- Format response
- Add disclaimers
- Inject tips
- Modify tone

**Input**: Claude's response **Output**: Modified response

**Example**:

```markdown
---
name: format-response
description: Add formatting to responses
event: PreResponse
---

Before sending response:

1. If response includes code changes, add: "💡 Tip: Review changes carefully before
   accepting."

2. If response mentions security, add: "🔒 Security note: Test security changes
   thoroughly."

3. Format consistently with project standards.
```

### PostResponse

Runs after response sent to user.

**Use for**:

- Log interactions
- Collect metrics
- Trigger background tasks
- Update state

**Example**:

```markdown
---
name: interaction-logger
description: Log interactions for analysis
event: PostResponse
---

After response sent:

1. Extract key metrics:
   - Tools used
   - Files modified
   - Response length
2. Append to `.claude/session.log`
3. No output to user

Format: `timestamp | tools | files | length`
```

### Error

Runs when an error occurs.

**Use for**:

- Error recovery
- User-friendly messages
- Debug information collection
- Fallback actions

**Input**: Error details **Output**: Recovery actions or modified error message

**Example**:

```markdown
---
name: error-handler
description: Provide helpful error messages
event: Error
---

When error occurs:

1. Identify error type
2. Check known issues in TROUBLESHOOTING.md
3. Provide specific guidance:
   - If auth error: "Try running: claude login"
   - If network error: "Check connection and retry"
   - If file error: "Verify file permissions"

Include link to relevant docs.
```

## Hook configuration

### Frontmatter fields

```yaml
name: hook-name
description: What the hook does
event: SessionStart
tool: read_file
priority: high
async: true
timeout: 5000
```

#### Required fields

- **name**: Hook identifier
- **description**: Brief summary
- **event**: Which event triggers the hook

#### Optional fields

- **tool**: Tool-specific hooks (for PreToolUse/PostToolUse)
- **priority**: `high`, `medium`, `low` (default: `medium`)
- **async**: Run asynchronously (default: `false`)
- **timeout**: Max execution time in milliseconds
- **condition**: When to run the hook

### Conditional execution

Run hooks only when conditions match:

```yaml
condition:
  filePattern: '**/*.py'
  userMessageContains: 'test'
  toolMatches: 'run_in_terminal'
```

**Example**:

```markdown
---
name: python-test-hook
description: Special handling for Python tests
event: PreToolUse
tool: run_in_terminal
condition:
  filePattern: '**/*test*.py'
  userMessageContains: 'test'
---

When running tests on Python files:

Add environment variables:

- PYTHONPATH=./src
- TESTING=1

Modify command to include coverage: `pytest --cov=src --cov-report=term-missing`
```

## Hook types

### Prompt-based hooks

Most hooks use natural language instructions:

```markdown
---
name: my-hook
event: PrePrompt
---

Natural language instructions for what to do.
```

Claude interprets and executes these instructions.

### Agent-based hooks

Complex hooks can use sub-agents:

```markdown
---
name: complex-hook
event: SessionStart
executeSubagent:
  name: setup-agent
  tools:
    - read_file
    - grep_search
---

# Setup Agent

You run at session start to verify project setup.

1. Check for .env file
2. Verify dependencies installed
3. Check git status
4. Report any issues
```

## Advanced patterns

### Chained hooks

Multiple hooks on same event execute in priority order:

```markdown
---
name: first-hook
event: PrePrompt
priority: high
---

Run first.
```

```markdown
---
name: second-hook
event: PrePrompt
priority: medium
---

Run second.
```

### State management

Hooks can maintain state across invocations:

```markdown
---
name: counter-hook
event: PostToolUse
---

Maintain interaction count:

1. Read count from `.claude/stats.json`
2. Increment by 1
3. Write back to file
4. If count > 100, suggest: "Consider reviewing session stats"
```

### Transformation pipelines

Multiple hooks transform data sequentially:

```markdown
---
name: markdown-formatter
event: PreResponse
priority: high
---

Format code blocks with syntax highlighting.
```

```markdown
---
name: link-injector
event: PreResponse
priority: medium
---

Add links to referenced files.
```

## Examples

### Commit reminder

```markdown
---
name: commit-reminder
description: Remind to commit changes
event: SessionEnd
---

At session end:

1. Check for uncommitted changes
2. If found, remind user: "📝 You have uncommitted changes. Consider committing them:
   `/commit <message>`"
```

### Test enforcer

```markdown
---
name: test-enforcer
description: Require tests for new code
event: PostToolUse
tool: create_file
---

After creating new source files:

1. Check if file contains functions/classes
2. If yes, prompt: "✅ Created ${filename} ⚠️ Remember to add tests for new code."
```

### Performance monitor

```markdown
---
name: performance-monitor
description: Track tool execution time
event: PostToolUse
async: true
---

After each tool execution:

1. Calculate execution time
2. If > 5 seconds, log to `.claude/slow-tools.log`
3. Format: `${timestamp} | ${tool} | ${duration}ms`
4. No user output (async logging)
```

### Context preloader

```markdown
---
name: context-preloader
description: Load relevant docs automatically
event: PrePrompt
---

Before processing prompts:

1. Detect keywords: "authentication", "database", "api"
2. If found, inject content from relevant docs:
   - "authentication" → docs/AUTH.md
   - "database" → docs/DATABASE.md
   - "api" → docs/API.md

Prepend to user message:
```

[Relevant Documentation] ${docContent} [End Documentation]

```

```

## Debugging hooks

### Hook not triggering

Check:

1. Hook file in `.claude-plugin/hooks/`
2. Valid YAML frontmatter
3. Event name is correct
4. Condition matches context

### Hook errors

View hook execution errors:

```bash
/plugin
# Go to Errors tab
```

Common issues:

- Invalid YAML syntax
- Wrong event name
- Infinite loops (hook triggers itself)
- Timeout exceeded

### Test hooks

Test by triggering specific events:

```bash
# Test SessionStart hook
claude  # Start new session

# Test PreToolUse hook
/read_file test.py

# Test PostResponse hook
# Any interaction triggers this
```

### Debug output

Add logging to understand hook behavior:

```markdown
---
name: debug-hook
event: PrePrompt
---

Log to console: "[DEBUG] PrePrompt hook triggered with: ${userMessage}"

Then proceed normally.
```

## Best practices

### Keep hooks focused

One hook, one responsibility:

✅ Good: Separate hooks for logging and transformation ❌ Too complex: One hook doing
many unrelated things

### Avoid loops

Don't trigger the same event you're handling:

❌ Dangerous:

```markdown
---
event: PreToolUse
tool: read_file
---

Read another file here. # Could cause infinite loop
```

### Use async for side effects

Non-blocking operations should be async:

```yaml
async: true
```

Use for: logging, metrics, notifications

### Handle errors gracefully

Don't let hook failures break Claude:

```markdown
Try to do the thing. If it fails, log error and continue.
```

### Document hook behavior

Explain what hooks do in README:

```markdown
## Hooks

- **session-start**: Checks project setup
- **pre-response**: Adds helpful tips to responses
- **post-tool-use**: Logs tool usage stats
```

## Security considerations

- Hooks run with Claude's permissions
- Be careful with destructive operations
- Validate inputs before using in commands
- Don't log sensitive data
- Review hook code from untrusted sources

## Next steps

- [Skills](./skills.md) for domain knowledge
- [Sub-agents](./sub-agents.md) for specialized behaviors
- [Plugins reference](./plugins-reference.md) for technical details
- [Create plugins](./plugins.md) to package and distribute hooks
