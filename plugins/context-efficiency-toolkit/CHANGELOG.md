# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [0.1.0] - 2026-02-20

### Added

- `/review-context-efficiency` command: five-stage structured audit (Analysis, Consequence Mapping, Options, Implementation Plan, Implementation) against twelve context efficiency principles
- `/tighten-markdown` command: five-step prose rewrite process (Inventory, Cut, Compress, Structure, Write) for instruction markdown files
- `CONTEXT_EFFICIENCY_REFERENCE` skill: twelve-principle reference set covering Instruction Design (P1–P3), Runtime Efficiency (P4–P6), Agent Architecture (P7–P9), and Token Budget Awareness (P10–P12); loadable independently for principle lookups
- `CONTEXT_EFFICIENCY_REVIEW` skill: five-stage structured audit workflow that references principles by ID from `CONTEXT_EFFICIENCY_REFERENCE`
- `MARKDOWN_TIGHTEN` skill: behavioral rules and process for eliminating motivational prose, restatements, hedging, and preamble from instruction files

