# Track A: Principles Alignment Criteria

Load this template when performing principles alignment analysis. It defines what to examine in each component type and the rules for determining principle status.

## Component Examination Table

| Component | Look for | Relevant principles |
|-----------|----------|---------------------|
| **Commands** (`commands/*.md`) | Inline instruction length, delegation vs. direct action, context cost | Context management, template externalization |
| **Skills** (`skills/*/SKILL.md`) | Trigger specificity, scope creep, load-on-demand behavior | On-demand loading, single responsibility |
| **Agents** (`agents/*.md`) | Tool restrictions, role boundaries, context isolation | Enforcement layers, disposable context |
| **Hooks** (`hooks/hooks.json`, `scripts/*.sh`) | Mechanical enforcement of stated constraints, dispatcher pattern, stdin JSON parsing | Mechanical > Structural > Behavioral, hooks best practices |
| **MCP server** (`.mcp.json`, `src/`) | Tool granularity, safety gates, structured output | Plugin-specific principles |
| **Templates** (`templates/`) | Externalized instructions vs. inline prompts | Template externalization |
| **docs/DESIGN.md / README.md** | Stated intent vs. actual implementation drift | All principles |

## Analysis Rules

### Status Definitions

**Upheld**: Concrete implementation evidence — a hook, a structural constraint, a template, or an explicit architectural choice — makes the principle true. The enforcement is appropriate to the principle's intent.

**Partially Upheld**: The intent is present but enforcement is weaker than the principle implies. Common pattern: a behavioral instruction where a mechanical hook is feasible, or a structural pattern inconsistently applied across components.

**Violated**: The implementation contradicts the principle, or nothing in the codebase enforces or supports it. The principle exists only as documentation with zero implementation footprint.

### Enforcement Layer Hierarchy

For each principle, identify both the **actual** enforcement layer and the **expected** layer:

**Mechanical** (strongest): Hooks that deterministically block/warn regardless of AI behavior. A developer cannot accidentally violate it.

**Structural** (medium): File organization, agent tool restrictions, template externalization patterns. Violating requires deliberate structural changes.

**Behavioral** (weakest): Instructions in prompts, comments, README guidance. Relies on an agent reading and following instructions. Violation is easy and often accidental.

**If a principle claims or implies mechanical enforcement but relies on behavioral instructions alone, that is a gap** — even if the behavior usually works.

### Special Checks

**Orphaned principles**: Stated in README's `## Principles` section but nothing in the codebase enforces them. Flag these — they may indicate aspirational principles never implemented, or principles whose enforcement was removed but the documentation wasn't updated.

**Undocumented enforcement**: Hooks or structural constraints enforcing rules not captured in any stated principle. May indicate missing principles that should be added.

## Checkpoint: [C1] LLM-Optimized Commenting

This checkpoint evaluates whether in-code comments are optimized for the actual reader — the next AI session that loads these files into its context window. The human manages at the architecture and decision level; the AI reads code line by line. Comments should serve that reader.

### What to look for

**Architectural role headers (highest value).** Every file should open with a brief comment block explaining: what this file does in the system, which other files it relates to, and what would break if it changed. This is the single most valuable comment type for an LLM loading a file into context for the first time. An AI session can read a function body and understand its mechanics — it cannot infer why this file exists or how it fits into the broader architecture without being told.

**Intent over mechanics.** Comments should explain WHY, not WHAT. An LLM can read `if count > 10:` and understand the comparison — it needs to know why 10 is the threshold, what happens at the boundary, and whether this is a hard requirement or a heuristic. Flag comments that restate code in English ("increment counter by 1", "check if null", "loop through items").

**Constraint annotations.** Non-obvious constraints, ordering dependencies, and "looks wrong but is intentional" situations must be called out explicitly. These are the single most common cause of AI-introduced regressions — the LLM sees code that looks suboptimal, "fixes" it, and breaks something because the original was deliberately shaped by a constraint it couldn't see. Examples: "stdin must be consumed before any other reads", "this runs under set -e so avoid (( ))", "intentionally O(n²) — dataset is always <50 items".

**Decision context.** When a design choice was made between alternatives, the comment should capture the reasoning: "chose X over Y because Z". This prevents future AI sessions from re-deriving the same analysis and potentially choosing Y without the context that ruled it out.

**Cross-file relationship notes.** When one file depends on the behavior or output format of another, both sides should note the contract. Example: "Output format must match what the orchestrator parses in review.md Phase 3" in a template file, and "Expects the format defined in templates/pass-report.md" in the command file. Without these, an AI modifying one side has no signal that the other side will break.

### Anti-patterns to flag

**Syntax narration.** Comments that explain language features rather than domain logic. "Define a function", "import the json module", "return the result". These waste context tokens and provide zero value to an LLM that already understands the language.

**Decorative structure.** Long lines of `#====` or `#----` or `# ---- Section ----` used as visual dividers. These burn tokens without conveying information. A brief `# --- Phase 2: Analysis ---` is fine; a 80-character decorative border is a finding.

**Stale comments.** Comments that describe behavior the code no longer exhibits. An LLM trusting a stale comment will produce incorrect analysis and potentially introduce bugs based on false assumptions about the code's behavior.

**Missing comments on non-obvious code.** The absence of comments on complex conditionals, regex patterns, shell pipeline chains, or anything that requires domain-specific knowledge to understand. If a human reviewer would need the original author to explain it, an AI reviewer definitely needs a comment.

### Status Classification

**Good**: Most files have architectural role headers, comments explain intent and constraints, cross-file contracts are noted, minimal syntax narration.

**Adequate**: Some files have good comments but coverage is inconsistent. Key constraints are documented but architectural context is sparse.

**Poor**: Comments are predominantly syntax narration, missing on complex code, or absent entirely. No architectural role headers. Cross-file dependencies are undocumented.
