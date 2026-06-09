# Agent Instructions

This repository uses a custom session memory/handoff system as the canonical instruction source.

Before editing code:

1. Load the canonical instruction source: `<path-or-command>`.
2. Follow the resolved instructions as the active implementation contract.
3. If the canonical source is unavailable, stop and report that the instruction source cannot be resolved.

The resolved instructions must preserve the Python Tooling SSOT Standard, including the verification gate, fix pass, dependency rules, typing rules, testing rules, security rules, and VS Code rules.
