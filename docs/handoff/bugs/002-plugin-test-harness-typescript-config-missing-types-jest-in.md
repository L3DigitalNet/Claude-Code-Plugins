---
bug_id: 2
date: 2026-04-20
title: "plugin-test-harness TypeScript config missing @types/jest in tsconfig types array; jest transform po"
services: [claude-code-plugins]
tags: []
status: fixed
supersedes: null
superseded_by: null
---
# Bug 2: plugin-test-harness TypeScript config missing @types/jest in tsconfig types array; jest transform po

## Cause

plugin-test-harness TypeScript config missing @types/jest in tsconfig types array; jest transform pointed at wrong config.

## Fix

Fixed and released in 0.7.4 (50 tests now pass, was 0).

## Lesson

When a TS test harness collects 0 tests, check that tsconfig `types` includes the test-framework types and the jest transform points at the right config.
