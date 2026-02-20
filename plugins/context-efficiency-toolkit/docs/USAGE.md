# Usage Guide — Context Efficiency Toolkit

## Overview

This plugin provides two commands that work best in sequence. Run `/review-context-efficiency` first to audit and fix structural and architectural issues in a plugin. Run `/tighten-markdown` afterward to rewrite instruction files at the prose level. Running them in this order matters: you want the architecture settled before you polish the language on top of it.

---

## `/review-context-efficiency`

### What it does

Audits a Claude Code plugin against twelve context efficiency principles across five sequential stages. Each stage produces a checkpoint where you review Claude's findings and approve the next step. Claude will not advance or make any changes without explicit approval.

### The five stages

**Stage 1 — Analysis and Diagnosis.** Claude reads every file in the plugin and classifies each principle as COMPLIANT, VIOLATION, or AMBIGUOUS, with severity rated HIGH, MEDIUM, or LOW. HIGH severity means a problem that compounds across runs or agent turns. MEDIUM means a recurring fixed cost. LOW means a bounded, one-time impact.

**Stage 2 — Consequence Mapping.** Claude translates each violation into a concrete real-world impact. Instead of "violates P4," you get "reads all N files on every invocation even when one is relevant, adding approximately X tokens of noise per run and risking context exhaustion on repositories larger than Y files."

**Stage 3 — Options and Tradeoffs.** For each HIGH or MEDIUM finding, Claude presents two to three distinct remediation strategies with explicit tradeoffs. You select which option to proceed with. LOW findings are grouped into a single minor polish option.

**Stage 4 — Implementation Plan.** Claude sequences the approved options in dependency order and presents a numbered plan for your review. No changes happen at this stage — only planning.

**Stage 5 — Implementation.** Claude executes the approved plan in sequence, reporting a brief progress note after each step. Scope is strictly limited to the approved plan. At the end, Claude may optionally note instruction markdown files as candidates for `/tighten-markdown`.

### How to run it

From a Claude Code session in your plugin workspace:

```
/review-context-efficiency
```

When prompted, either provide the path to your plugin's root directory or list the specific files you want reviewed.

> **Note:** The review command loads two skill files: `CONTEXT_EFFICIENCY_REFERENCE.md` (principle definitions) and `CONTEXT_EFFICIENCY_REVIEW.md` (workflow). Both are required; the workflow references principles by ID from the reference skill. The reference skill can also be loaded independently when you want to look up what a specific principle means.

### What to expect

Expect the review to surface findings across multiple principles. A finding is not necessarily a defect in your plugin's intent — it may reflect a tradeoff you made deliberately. Claude will flag ambiguous patterns as questions rather than violations, giving you the chance to clarify before anything is proposed for change.

---

## `/tighten-markdown`

### What it does

Applies a five-step process to one instruction markdown file at a time: Step 1 inventories the file and proceeds automatically, Steps 2–4 apply the cut/compress/structure passes (each with an approval checkpoint), and Step 5 writes the result. Three approval checkpoints gate the process — after Step 2 (before cuts), after Step 3 (before compression is finalized), and at Step 4 (before the file is written).

### The three-pass standard

Every sentence in an instruction file must satisfy at least one of three tests: it defines a behavior, constrains a choice, or specifies a format. Any sentence that fails all three is cut in Pass 1. The most common failures are motivational explanations ("this is important because..."), restatements of earlier definitions, and hedging qualifiers that do not add precision.

### How to run it

```
/tighten-markdown
```

When prompted, provide either a specific file path or a directory path. If you provide a directory, Claude will list the markdown files it contains as a numbered list and ask you to reply with the numbers of the files to process, in order.

### File-by-file processing

Claude processes one file at a time in the order you specify. After each file is complete, Claude reports the word count reduction and approximate token savings before moving to the next. A typical well-written but unoptimized instruction file sees a 30–50% word count reduction without any loss of behavioral information. For a directory with multiple files, expect three interaction checkpoints per file (Steps 2, 3, and 4); Claude presents a numbered list of discovered files and asks you to reply with the numbers you want to process, in order.

### What not to worry about

Claude is instructed not to cut content that looks like explanation but is actually a constraint. If a sentence explains *what changes* about Claude's behavior in a particular context, it earns its tokens. Explicit warnings and prohibitions are always preserved even when they seem obvious. Concrete examples that resolve genuine ambiguity are preserved; examples that illustrate something already clear are cut.

---

## Frequently Asked Questions

**A command ran but produced no structured output or stages — what went wrong?** Both commands work by instructing Claude to read a skill file from the plugin's skills directory. If the plugin is not correctly installed or the skill path is not resolved, the command will silently fail to load its behavioral instructions. Check that the plugin is installed (`/plugin list`), then try re-installing. If the problem persists, you can run the skill directly by pasting the contents of `skills/CONTEXT_EFFICIENCY_REVIEW.md` or `skills/MARKDOWN_TIGHTEN.md` into your session manually.

**Should I run both commands on the same session?** You can, but be aware that a long structural review followed by tightening multiple files will accumulate significant context. If your plugin has many files, consider running `/review-context-efficiency` in one session and `/tighten-markdown` in a fresh session using the file list the review produced.

**Can I run `/tighten-markdown` without running `/review-context-efficiency` first?** Yes. The tightening command is fully independent. It is useful any time you have written a new instruction file or updated an existing one and want to cut it down before deploying.

**What if I disagree with a recommended option in Stage 3?** Select a different option or ask Claude to explain the tradeoffs further. You can also defer any finding to a future review pass. The workflow is designed to keep you in control of every decision.

**Can I add the twelve principles to my own plugin's SKILL.md?** Yes, and this is encouraged. Plugins that are self-aware of the principles tend to produce leaner outputs by default, reducing how much remediation they need when reviewed.
