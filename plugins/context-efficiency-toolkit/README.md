# Context Efficiency Toolkit

A Claude Code plugin that audits plugins for token and context efficiency, then rewrites their instruction files to be as lean as possible without losing behavioral information.

## Why This Exists

Plugins that are wasteful with tokens are not just slow or expensive — they are functionally defective. A plugin that works fine on small inputs but silently degrades on large ones because it bloated its own context is a buggy plugin, not just an inefficient one. This toolkit treats token efficiency as a correctness property and provides a structured, approval-gated workflow to diagnose and fix violations.

## Commands

### `/review-context-efficiency`

Runs a five-stage structured audit of a Claude Code plugin against twelve context efficiency principles covering instruction design, runtime behavior, agent architecture, and token budget self-governance.

The five stages are: Analysis and Diagnosis → Consequence Mapping → Options and Tradeoffs → Implementation Plan → Implementation. Each stage produces a checkpoint where you review findings and approve next steps before Claude proceeds. No changes are made without explicit approval.

**Usage:** Run from any Claude Code session within your plugin workspace. When prompted, provide the path to the plugin root directory or list its files.

### `/tighten-markdown`

Applies a three-pass rewrite process (cut, compress, restructure) to instruction markdown files, eliminating motivational prose, restatements, passive constructions, and unnecessary hedging. Operates on one file at a time with a checkpoint after each pass.

**Usage:** Run after `/review-context-efficiency` to tighten the prose in any instruction files the structural review surfaces as candidates. Can also be run independently on any markdown instruction file.

## The Twelve Principles

The review standard is built on twelve principles grouped into four layers.

**Instruction Design (P1–P3):** Imperative minimalism, format matching data type, reference over repetition.

**Runtime Efficiency (P4–P6):** Lazy context loading, process and discard, output verbosity matching its consumer.

**Agent Architecture (P7–P9):** Decompose by scope not convenience, subagents return structured extracts, orchestrator synthesizes rather than re-analyzes.

**Token Budget Awareness (P10–P12):** Fail fast and surface early, choose the lighter path when outcomes are equivalent, verbosity scales inverse to context depth.

## Recommended Workflow

Run `/review-context-efficiency` first to address structural and architectural issues. Then run `/tighten-markdown` on each instruction file the structural review surfaces as a candidate. Fixing structure before tightening prose ensures you are not polishing language on top of architecture that is about to change.

## Installation

```
/plugin install context-efficiency-toolkit@claude-code-plugins
```

## License

MIT
