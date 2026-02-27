# KeePassXC Credential Manager — Manual Setup Guide

> Everything you need to do by hand before the plugin is installed and running.
> Complete steps in order — each section depends on the previous.

---

## Prerequisites Checklist

- [ ] YubiKey 5C Nano (primary) — in hand
- [ ] YubiKey 5C Nano (backup) — required before proceeding past Step 1
- [ ] KeePassXC installed
- [ ] `ykman` (YubiKey Manager) installed
- [ ] `gpg` installed (only needed if storing GPG keys)
- [ ] Python 3.12+ installed

---

## Step 1 — Install System Dependencies

### Linux

```bash
# YubiKey Manager
sudo apt install yubikey-manager

# GPG (if not already installed)
sudo apt install gnupg

# Verify KeePassXC CLI is available after installing KeePassXC
keepassxc-cli --version
```

### macOS

```bash
# YubiKey Manager
brew install ykman

# GPG (if not already installed)
brew install gnupg

# KeePassXC — install from https://keepassxc.org or via brew
brew install --cask keepassxc

# Verify KeePassXC CLI is available
keepassxc-cli --version
```

---

## Step 2 — Configure YubiKey HMAC-SHA1 (Both Keys)

> ⚠️ **Do both keys before moving on.** Once you build a workflow dependency on the primary key, losing it without a configured backup means losing access to the primary database.

**Generate a strong hex secret offline first.** You can use:

```bash
# Generate a 20-byte (40 hex character) random secret
python3 -c "import secrets; print(secrets.token_hex(20))"
```

Save this secret somewhere secure offline before proceeding — you need it to program the backup key.

**Program primary key:**

```bash
ykman otp chalresp --touch 2 <your-secret-hex>
```

**Program backup key (same secret):**

```bash
ykman otp chalresp --touch 2 <your-secret-hex>
```

**Verify slot 2 is configured on each key:**

```bash
ykman otp info
```

Slot 2 should show `HMAC-SHA1` with touch required.

> Store the backup YubiKey in a physically separate, secure location.

---

## Step 3 — Create the Primary KeePass Database (YubiKey only)

1. Open KeePassXC → **Database → New Database**
2. Name the database and choose a save location
3. On the credentials screen:
   - Leave the **Password** field blank
   - Enable **Challenge-Response**
   - Select your YubiKey, **Slot 2**
4. Touch the key when it blinks to complete the test challenge
5. Save the database

---

## Step 4 — Create the Backup KeePass Database (Master password only)

1. Open KeePassXC → **Database → New Database**
2. Set a **strong master password** — no YubiKey component
3. Save to a location that is physically separate from the primary database:
   - Encrypted USB drive, or
   - Air-gapped machine
4. **Do not store the backup database on the same machine as the primary**

**Keeping backup in sync (periodic maintenance):**

Open the backup database → **Database → Import → Merge from KeePass database** → select the primary database → touch YubiKey when prompted.

---

## Step 5 — Create Group Structure in Primary Database

In KeePassXC, create the following top-level groups in the primary database. Right-click the root entry → **Add Group**:

| Group | Contents |
|---|---|
| `Servers` | SSH credentials, server logins, cPanel, SFTP connection credentials |
| `SSH Keys` | SSH private/public key pairs |
| `GPG Keys` | GPG key pairs |
| `Git` | GitHub PATs, GitLab tokens, etc. |
| `API Keys` | Project API keys and tokens (Anthropic, Brave Search, etc.) |
| `Services` | Project-related site logins (hosting dashboards, domain registrars, SaaS tools, etc.) |

---

## Step 6 — Enable SSH Agent Integration in KeePassXC

**Global setup:**

1. Open KeePassXC → **Tools → Settings → SSH Agent**
2. Enable **SSH Agent integration**
3. **Linux only:** ensure `SSH_AUTH_SOCK` is set in your shell environment:
   ```bash
   # Check if it's already set
   echo $SSH_AUTH_SOCK
   
   # If empty, add to your shell profile (~/.bashrc, ~/.zshrc, etc.)
   eval $(ssh-agent -s)
   ```
4. **macOS:** the system SSH agent is used automatically — no additional setup needed

**Per-entry SSH key setup** (repeat for each SSH key you add to the database):

1. Create a new entry in the `SSH Keys` group
2. Store the passphrase (if any) in the **Password** field
3. Open the entry → **Advanced → Attachments** → attach the private key file (e.g. `id_ed25519`)
4. Attach the public key file (e.g. `id_ed25519.pub`) as a second attachment
5. Go to the **SSH Agent** tab on the entry
6. Select the private key attachment
7. Enable **Add key to agent when database is opened**
8. Enable **Remove key from agent when database is closed**

---

## Step 7 — Create the YAML Config File

Create the config file at `~/.config/keepass-cred-mgr/config.yaml` (the default path the MCP server expects):

```bash
mkdir -p ~/.config/keepass-cred-mgr
```

Then create `~/.config/keepass-cred-mgr/config.yaml` with the following content, updating paths to match your setup:

```yaml
database_path: /path/to/your/primary.kdbx
yubikey_slot: 2
grace_period_seconds: 10
yubikey_poll_interval_seconds: 5
write_lock_timeout_seconds: 10
page_size: 50

allowed_groups:
  - Servers
  - SSH Keys
  - GPG Keys
  - Git
  - API Keys
  - Services

audit_log_path: ~/.local/share/keepass-cred-mgr/audit.jsonl
```

Create the audit log directory:

```bash
mkdir -p ~/.local/share/keepass-cred-mgr
```

---

## Step 8 — Install the Plugin

Once the plugin is published to the Claude-Code-Plugins marketplace:

```bash
# In Claude Code — add the L3Digital marketplace (one time)
/plugin marketplace add l3digital/claude-code-plugins

# Install the plugin
/plugin install keepass-cred-mgr@l3digital
```

Verify installation:

```bash
/plugin
# Select "Manage Plugins" and confirm keepass-cred-mgr is listed and enabled
```

Test the slash commands:

```bash
/keepass-status
```

---

## Ongoing Maintenance

**Sync backup database** — periodically after adding new entries to the primary:
- Open backup database → **Database → Import → Merge from KeePass database** → select primary

**Rotate YubiKey HMAC secret** — if you suspect key compromise:
- Re-program both keys with a new secret
- Re-configure the primary database challenge-response with the new key

**Review inactive entries** — run `/keepass-audit` in Claude Code periodically to identify `[INACTIVE]` entries ready for deletion in KeePassXC

---

## Quick Reference — Entry Naming Conventions

| Credential Type | Group | Title Format |
|---|---|---|
| cPanel | `Servers` | `cPanel - <domain>` |
| FTP/FTPS | `Servers` | `FTP - <host>` |
| SFTP connection | `Servers` | `SFTP - <host>` |
| SSH key | `SSH Keys` | `SSH - <host or purpose>` |
| GPG key | `GPG Keys` | `GPG Key - <key-id>` |
| GitHub/GitLab PAT | `Git` | `GitHub PAT - <purpose>` |
| Anthropic API key | `API Keys` | `Anthropic API - <project name>` |
| Brave Search API | `API Keys` | `Brave Search API - <purpose or project>` |
| Hosting dashboards, SaaS | `Services` | `<Service Name> - <purpose>` |
