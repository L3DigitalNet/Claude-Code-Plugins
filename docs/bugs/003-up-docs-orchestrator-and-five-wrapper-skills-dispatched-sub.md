---
bug_id: 3
date: 2026-04-20
title: "up-docs orchestrator and five wrapper skills dispatched sub-agents with bare names (e"
services: [claude-code-plugins]
tags: []
status: fixed
supersedes: null
superseded_by: null
---
# Bug 3: up-docs orchestrator and five wrapper skills dispatched sub-agents with bare names (e

## Cause

up-docs orchestrator and five wrapper skills dispatched sub-agents with bare names (e.g. "up-docs-propagate-repo") instead of plugin-namespaced form (e.g. "up-docs:up-docs-propagate-repo"), causing "Agent type not found" errors.

## Fix

Fixed all five skills and released in 0.4.1.

## Lesson

Sub-agents dispatched from inside a plugin must be referenced by their plugin-namespaced name, not the bare agent name, or dispatch fails with "Agent type not found".
