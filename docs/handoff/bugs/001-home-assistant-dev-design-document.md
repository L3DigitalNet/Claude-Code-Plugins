---
bug_id: 1
date: 2026-04-20
title: 'home-assistant-dev DESIGN_DOCUMENT'
services: [claude-code-plugins]
tags: []
status: fixed
supersedes: null
superseded_by: null
---

# Bug 1: home-assistant-dev DESIGN_DOCUMENT

## Cause

home-assistant-dev DESIGN_DOCUMENT.md had stale version refs (2.2.2 vs 2.2.6).

## Fix

Fixed and released in 2.2.6.

## Lesson

Version references embedded in design/docs drift from the actual release; bump them as part of the release so docs and code stay in sync.
