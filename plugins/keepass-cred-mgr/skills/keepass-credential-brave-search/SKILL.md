---
name: keepass-credential-brave-search
description: >
  Brave Search API credential handling. Use when storing or retrieving Brave Search API keys.
  Triggers on mentions of Brave Search, web search API keys, or BSA- prefixed keys.
---

# Brave Search API Credential Handling

GROUP: API Keys
TITLE FORMAT: Brave Search API - <purpose or project>
PASSWORD FIELD: API key value
URL: https://api.search.brave.com
NOTES: subscription tier, rate limits (if known), associated project

RETRIEVAL: use get_entry. Write key to .env file or config; never display raw value in conversation.
ROTATION: rotate immediately if key appears in version control, logs, or any output.
