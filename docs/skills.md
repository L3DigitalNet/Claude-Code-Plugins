---
title: Skills Development Reference
category: development
target_platform: linux
audience: ai_agent
keywords: [skills, yaml, frontmatter, applyTo, triggers]
---

# Skills Development Reference

## Quick Reference

**Location:** `.claude-plugin/skills/` or `skills/` **File format:** Markdown with YAML
frontmatter **Invocation:** Context-based (AI determines relevance)

**Minimum viable skill:**

```markdown
---
name: skill-name
description: When to use this skill
---

Skill implementation instructions.
```

## SKILL.md Schema

### Required Fields

```yaml
name: string # Unique identifier (lowercase-hyphenated)
description: string # One-line summary of skill purpose and trigger conditions
```

### Optional Fields

```yaml
applyTo: # File patterns for context matching
  - '**/*.py'
  - 'src/**/*.ts'

triggerPhrases: # User input patterns that trigger skill
  - 'test driven development'
  - 'write tests'

priority: string # "high" | "normal" | "low" (default: normal)

arguments: # Parameterized skill inputs
  argName:
    type: string # "string" | "number" | "boolean"
    description: string # Argument purpose
    default: any # Default value

executeSubagent: # Run skill in isolated subagent
  name: string # Subagent identifier
  tools: # Tool access restrictions
    - 'read_file'
    - 'run_command'
```

## Field Reference

### name

**Type:** `string` **Required:** Yes **Format:** lowercase-hyphenated **Example:**
`python-testing-patterns`

```yaml
name: api-error-handling
```

### description

**Type:** `string` **Required:** Yes **Purpose:** Helps AI determine when to invoke
skill **Best practice:** Include trigger conditions and use cases

```yaml
description:
  Use when handling API errors, implementing retry logic, or building resilient HTTP
  clients. Triggers on "error handling", "retry", "resilience".
```

### applyTo

**Type:** `string[]` **Required:** No **Format:** Glob patterns **Purpose:** File-based
context matching

```yaml
applyTo:
  - '**/*.py' # All Python files
  - 'src/**' # Everything in src/
  - 'tests/*.test.ts' # TypeScript test files
  - '!**/generated/**' # Exclude generated/
```

**Glob syntax:**

- `*` - Single directory level
- `**` - Recursive directories
- `!` - Negation (exclude pattern)
- `{}` - Alternatives: `**/*.{js,ts}`

### triggerPhrases

**Type:** `string[]` **Required:** No **Purpose:** User input patterns that activate
skill

```yaml
triggerPhrases:
  - 'write tests'
  - 'test driven development'
  - 'tdd'
  - 'add test coverage'
```

**Case insensitive:** Matches regardless of capitalization

- **triggerPhrases**: Phrases that indicate skill should be used
- **priority**: `high`, `medium`, or `low` (default: `medium`)
- **arguments**: Configurable parameters for the skill
- **executeSubagent**: Run skill in a specialized subagent

## Matching patterns

### File patterns (applyTo)

Use glob patterns to specify when a skill is relevant:

```yaml
applyTo:
  - '**/*.{ts,tsx,js,jsx}' # TypeScript/JavaScript files
  - 'src/components/**' # Files in components directory
  - '**/*test.py' # Python test files
  - '!**/node_modules/**' # Exclude node_modules
```

### Trigger phrases

Claude looks for these phrases to decide when to invoke the skill:

```yaml
triggerPhrases:
  - 'async patterns'
  - 'background jobs'
  - 'task queue'
```

## Skill content

Write your skill content in markdown below the frontmatter. Use clear structure and
examples.

### Example: Testing skill

```markdown
---
name: python-testing-patterns
description: Comprehensive testing strategies with pytest
applyTo:
  - '**/*test*.py'
  - '**/tests/**'
triggerPhrases:
  - 'write tests'
  - 'test this'
  - 'add test coverage'
---

# Python Testing Patterns

## Structure

Use pytest for all testing:

\`\`\`python import pytest

def test_example(): result = my_function() assert result == expected_value \`\`\`

## Fixtures

Define reusable test fixtures:

\`\`\`python @pytest.fixture def sample_data(): return {"key": "value"}

def test_with_fixture(sample_data): assert sample_data["key"] == "value" \`\`\`

## Best practices

1. One assertion per test when possible
2. Use descriptive test names
3. Test edge cases and error conditions
4. Mock external dependencies
```

## Advanced features

### Arguments

Make skills configurable with arguments:

```markdown
---
name: api-generator
description: Generate REST API endpoints
arguments:
  style:
    type: string
    enum: ['rest', 'graphql']
    description: API style to generate
    default: 'rest'
  auth:
    type: boolean
    description: Include authentication
    default: true
---

# API Generator

${style === "rest" ? "REST" : "GraphQL"} API endpoint template:

...
```

Access arguments in your skill content using `${argumentName}` syntax.

### Subagent execution

Run skills in a specialized subagent with controlled tool access:

```markdown
---
name: code-reviewer
description: Systematic code review process
executeSubagent:
  name: reviewer
  tools:
    - read_file
    - grep_search
  restrictedTools:
    - write_file
    - run_command
  prompt: |
    You are a code reviewer. Focus on:
    - Code quality
    - Best practices
    - Security issues
---

# Code Review Checklist

1. Check for security vulnerabilities
2. Verify error handling
3. Review test coverage ...
```

## Skill types

### Knowledge skills

Domain-specific information Claude should know:

```markdown
---
name: company-api-patterns
description: Internal API conventions and patterns
applyTo:
  - 'src/api/**'
---

# API Conventions

All APIs must follow these patterns:

- Use async/await for all I/O
- Return typed responses
- Include error handling ...
```

### Workflow skills

Step-by-step procedures:

```markdown
---
name: deployment-checklist
description: Pre-deployment verification steps
triggerPhrases:
  - 'deploy'
  - 'release'
---

# Deployment Checklist

Before deploying:

1. [ ] All tests pass
2. [ ] Documentation updated
3. [ ] Version bumped
4. [ ] Changelog updated ...
```

### Template skills

Code generation templates:

```markdown
---
name: react-component-scaffold
description: Generate React component with tests
applyTo:
  - 'src/components/**/*.tsx'
---

# React Component Template

\`\`\`typescript interface ${ComponentName}Props { // Props here }

export const ${ComponentName}: React.FC<${ComponentName}Props> = (props) => { return (

<div> {/_ Component content _/} </div> ); }; \`\`\`
```

## Best practices

### Keep skills focused

Each skill should cover one specific area:

✅ Good: `python-async-patterns` ❌ Too broad: `python-best-practices`

### Use clear structure

- Start with overview
- Provide examples
- Include anti-patterns
- Add troubleshooting tips

### Make skills actionable

Include concrete examples and code snippets, not just theory.

### Test your skills

Create a test project and verify skills are invoked correctly:

1. Install plugin locally
2. Create files matching `applyTo` patterns
3. Use trigger phrases
4. Verify Claude applies the skill

### Version skills

Track skill versions in git and document breaking changes.

## Skill discovery

Claude determines which skills to load based on:

1. **File context**: Matches `applyTo` patterns
2. **User message**: Matches `triggerPhrases`
3. **Conversation context**: Related to previous skill usage
4. **Priority**: Higher priority skills preferred

Skills are loaded dynamically, so they don't slow down Claude unless relevant.

## Examples

### Debugging skill

```markdown
---
name: systematic-debugging
description: Systematic debugging workflow
triggerPhrases:
  - 'debug'
  - 'bug'
  - 'not working'
priority: high
---

# Systematic Debugging

## Process

1. **Reproduce**: Confirm the issue exists
2. **Isolate**: Narrow down the cause
3. **Hypothesize**: Form theories about root cause
4. **Test**: Verify each hypothesis
5. **Fix**: Implement solution
6. **Verify**: Confirm fix works

## Tools

- Add logging at key points
- Use debugger breakpoints
- Check error messages
- Review recent changes
```

### Home Assistant skill

```markdown
---
name: ha-integration-patterns
description: Home Assistant integration best practices
applyTo:
  - '**/custom_components/**/*.py'
triggerPhrases:
  - 'home assistant'
  - 'hass'
---

# Home Assistant Integration Patterns

## Async patterns

Always use async/await:

\`\`\`python async def async_setup_entry(hass, entry): """Set up from config entry."""
coordinator = DataUpdateCoordinator( hass, \_LOGGER, name="sensor",
update_interval=timedelta(seconds=30), ) await coordinator.async_refresh() \`\`\`

## Entity setup

Use coordinator pattern:

\`\`\`python class MySensorEntity(CoordinatorEntity, SensorEntity): """Representation of
a sensor."""

    def __init__(self, coordinator, config_entry):
        """Initialize the sensor."""
        super().__init__(coordinator)
        self._attr_unique_id = f"{config_entry.entry_id}_sensor"

\`\`\`
```

## Sharing skills

Skills are shared through plugins:

1. Create plugin with skills directory
2. Add skills to `.claude-plugin/skills/`
3. Publish plugin to marketplace
4. Users install and skills are available

See [Plugin marketplaces](./plugin-marketplaces.md) for distribution.

## Debugging skills

### Skill not loading

Check:

1. YAML frontmatter is valid
2. File is in `.claude-plugin/skills/` directory
3. Plugin is installed and enabled

### Skill not being used

Check:

1. `applyTo` patterns match current files
2. Trigger phrases are relevant
3. Priority is appropriate

### Invalid frontmatter

Run YAML validator:

```bash
# Python
python -c "import yaml; yaml.safe_load(open('skill.md').read().split('---')[1])"
```

## Next steps

- [Create plugins](./plugins.md) to package and distribute skills
- [Sub-agents](./sub-agents.md) to run skills in controlled environments
- [Hooks](./hooks.md) to trigger skills at specific lifecycle points
- [Plugin marketplaces](./plugin-marketplaces.md) to share your skills
