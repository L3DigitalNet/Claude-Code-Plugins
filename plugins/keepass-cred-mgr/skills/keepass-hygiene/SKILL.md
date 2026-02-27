---
name: keepass-hygiene
description: >
  KeePass credential hygiene rules. Apply whenever interacting with KeePass via MCP tools,
  handling secrets, or performing credential rotation. Loaded automatically on any vault operation.
---

# KeePass Credential Hygiene

RULES: apply whenever interacting with KeePass via MCP tools.

1. Never use an [INACTIVE] entry as a credential. If get_entry or get_attachment returns an EntryInactive error, stop and inform the user.
2. When vault access is required for SSH or GPG key material, use get_attachment, not get_entry. Exception: check ssh-agent and ~/.ssh first per the SSH skill before accessing the vault at all.
3. Never include returned secrets in conversation output, comments, code, logs, or any file other than the intended destination.
4. On credential rotation: confirm create_entry succeeded before calling deactivate_entry. Never deactivate before confirming the new credential is stored.
5. When generating new credentials, use cryptographically appropriate parameters: ed25519 for SSH keys, 32+ character random strings for passwords, correct key types per service.
