# TODO

**Do not delete.**

## Purpose

This document is the user's visible task list alongside the v3 handoff system. Use it to track action items, follow-ups, and personal notes that should stay easy to find instead of living only in agent-facing handoff docs.

## Usage Instructions

- Write each actionable item as an unchecked Markdown task: `- [ ]`.
- When an item is completed during a session, change its marker to `- [x]`.
- During v3 handoff closeout, delete completed items from this document.
- Mirror any handoff task, todo, pending item, or follow-up here so the user can track it.
- Do not start or complete TODO items unless the user explicitly asks for that work.

<!-- LLM-EDIT-BOUNDARY: DO NOT EDIT ABOVE THIS LINE -->

## User Tracked Tasks

- From [https://github.com/L3DigitalNet/project-standards/tree/main/standards](https://github.com/L3DigitalNet/project-standards/tree/main/standards):
  - [x] Adopt markdown-tooling
  - [ ] Adopt python-tooling

## Repo & Agent Tracked Tasks

- [ ] **MCP E2E Tests (HA Container) CI is red** — `HA Dev Plugin Tests` → `MCP E2E Tests` job fails: the HA test container's demo integration loads 0 entities, so e2e assertions for `light.bed_light` / `sensor.outside_temperature` etc. fail (13 pass / 10 fail). Pre-existing, environmental (HA version / container onboarding), NOT a dependency issue — surfaced after the 2026-06-08 `typescript-eslint` bump cleared the `npm ci` ERESOLVE that previously masked it. The other 4 HA jobs pass.
