---
name: keepass-credential-ssh
description: >
  SSH key handling with agent-first resolution. Use when retrieving SSH keys, provisioning SSH access,
  or storing SSH key material. Triggers on mentions of SSH, ssh-agent, ssh-add, or key provisioning.
---

# SSH Key Handling

## Key Resolution Order (always follow this sequence)

1. Run: ssh-add -l
   If a key matching the host or purpose is loaded, use it. No vault access needed.

2. If not in agent: check ~/.ssh for an existing key file for this host.
   If found, load it with ssh-add and use it.

3. If not in ~/.ssh: retrieve from KeePass via get_attachment.
   Provision the key to ~/.ssh or load directly into the agent as appropriate.

RULE: Never retrieve a KeePass SSH key attachment if the key is already available locally or in the agent.

NOTE: KeePassXC SSH agent integration auto-loads vault keys into the agent on vault unlock. For routine SSH connections, the key will already be in the agent; no vault access required.

## Storage

GROUP: SSH Keys
TITLE FORMAT: SSH - <host or purpose>
PASSWORD FIELD: key passphrase (if any)
ATTACHMENTS: private key file (e.g. id_ed25519) AND public key file (e.g. id_ed25519.pub)
NOTES: target host(s), key type (ed25519 strongly preferred over RSA)
CROSS-REFERENCE: if this key is used for SFTP, notes must reference the corresponding Servers entry
