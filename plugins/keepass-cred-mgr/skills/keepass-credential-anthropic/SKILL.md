---
name: keepass-credential-anthropic
description: >
  Anthropic API credential handling with elevated sensitivity. Use when storing, retrieving,
  or rotating Anthropic API keys. Triggers on mentions of Anthropic API, Claude API keys,
  sk-ant- prefixed keys, or ANTHROPIC_API_KEY environment variable.
---

# Anthropic API Credential Handling

GROUP: API Keys
TITLE FORMAT: Anthropic API - <project name>
PASSWORD FIELD: API key value
URL: https://api.anthropic.com
NOTES: associated project or workspace

STORAGE WORKFLOW: User creates key in Anthropic console and pastes it into conversation.
Call create_entry to store it immediately. Confirm stored before the key leaves the conversation context.

RETRIEVAL: Full read access permitted for development tasks (populating .env files, configuring SDKs, setting up project secrets).
RULE: When retrieved, write directly to the target file or config.
RULE: Never echo or display the raw key value in conversation output under any circumstances.

ELEVATED SENSITIVITY (billing implications):
- Always inject via environment variable; never hardcode in source files
- If an Anthropic API key is detected in code, a commit, output, or any log: flag immediately and recommend rotation
- Rotate immediately on any exposure
