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

**Stage 5 — Implementation.** Claude executes the approved plan one step at a time, confirming each change before moving to the next. Scope is strictly limited to the approved plan. At the end, Claude lists all instruction markdown files as candidates for `/tighten-markdown`.

### How to run it

From a Claude Code session in your plugin workspace:

```
/review-context-efficiency
```

When prompted, either provide the path to your plugin's root directory or list the specific files you want reviewed.

### What to expect

Expect the review to surface findings across multiple principles. A finding is not necessarily a defect in your plugin's intent — it may reflect a tradeoff you made deliberately. Claude will flag ambiguous patterns as questions rather than violations, giving you the chance to clarify before anything is proposed for change.

---

## `/tighten-markdown`

### What it does

Applies a three-pass rewrite process to one instruction markdown file at a time. The three passes are sequential and each has its own checkpoint. Pass one cuts sentences that fail the behavioral standard. Pass two compresses surviving sentences. Pass three restructures the file for reading-order efficiency.

### The three-pass standard

Every sentence in an instruction file must satisfy at least one of three tests: it defines a behavior, constrains a choice, or specifies a format. Any sentence that fails all three is cut in Pass 1. The most common failures are motivational explanations ("this is important because..."), restatements of earlier definitions, and hedging qualifiers that do not add precision.

### How to run it

```
/tighten-markdown
```

When prompted, provide either a specific file path or a directory. If you provide a directory, Claude will list the markdown files it contains and ask you to confirm which ones to process.

### File-by-file processing

Claude processes one file at a time in the order you specify. After each file is complete, Claude confirms the word count reduction before moving to the next. A typical well-written but unoptimized instruction file sees a 30–50% word count reduction without any loss of behavioral information.

### What not to worry about

Claude is instructed not to cut content that looks like explanation but is actually a constraint. If a sentence explains *what changes* about Claude's behavior in a particular context, it earns its tokens. Explicit warnings and prohibitions are always preserved even when they seem obvious. Concrete examples that resolve genuine ambiguity are preserved; examples that illustrate something already clear are cut.

---

## Frequently Asked Questions

**Should I run both commands on the same session?** You can, but be aware that a long structural review followed by tightening multiple files will accumulate significant context. If your plugin has many files, consider running `/review-context-efficiency` in one session and `/tighten-markdown` in a fresh session using the file list the review produced.

**Can I run `/tighten-markdown` without running `/review-context-efficiency` first?** Yes. The tightening command is fully independent. It is useful any time you have written a new instruction file or updated an existing one and want to cut it down before deploying.

**What if I disagree with a recommended option in Stage 3?** Select a different option or ask Claude to explain the tradeoffs further. You can also defer any finding to a future review pass. The workflow is designed to keep you in control of every decision.

**Can I add the twelve principles to my own plugin's SKILL.md?** Yes, and this is encouraged. Plugins that are self-aware of the principles tend to produce leaner outputs by default, reducing how much remediation they need when reviewed.
