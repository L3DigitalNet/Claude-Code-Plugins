---
name: design-review
description: >
  Iterative design document review with principle enforcement, gap analysis,
  and auto-fix. Use when reviewing, auditing, or improving any design document,
  architecture spec, API contract, system design, or technical plan. Triggers
  automatically when the user asks to "review a design", "audit a spec",
  "improve a technical doc", or similar. Invoke directly with /design-review.
---

This skill runs the full Design Document Review & Iterative Refinement Protocol.
See the /design-review command for the complete protocol definition.

When invoked automatically (not via slash command), begin by asking:
"Would you like me to run a structured iterative review on this document?
This includes principle enforcement, gap analysis, and optional auto-fix.
Type /design-review [path/to/document.md] to begin — the command reads
the file directly from the filesystem."
