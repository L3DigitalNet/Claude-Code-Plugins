# KeePassXC Credential Manager — Design & Dependency Reference

> Living document — updated throughout the design process.
> Last updated: 2026-02-28

---

## Project Overview

A local MCP server enabling Claude Code to interact natively with a KeePass (`.kdbx`) vault.
Designed for **trusted local machines only** — not intended for direct use on remote/cloud servers.

### Use Environment

- Trusted local machines with physical access controls
- Full disk encryption (FDE)
- Firewall protected
- Segregated VLANs (separate from IoT and less-trusted devices)
- Remote access to cloud servers via SSH only — MCP server never runs directly on remote machines

### Security Philosophy

Pragmatic security calibrated to the actual threat model. Primary remaining threats:

1. **Prompt injection** — malicious content in files/web pages Claude reads during agentic tasks attempting to trigger credential retrieval
2. **Accidental exposure** — secrets leaking into logs, shell history, or Claude's context window
3. **Dependency compromise** — malicious or vulnerable packages

Deprioritized given environment:
- Transport encryption (stdio MCP transport used)
- Network-level socket access controls
- Multi-user isolation

---

## Architecture

### Two-Database Design

Two separate `.kdbx` files serve distinct purposes:

| Database | Authentication | Purpose |
|---|---|---|
| **Primary** | YubiKey (HMAC-SHA1, slot 2) only | Used exclusively by the MCP server |
| **Backup** | Master password only | Manual recovery copy — never used by MCP server |

The MCP server only ever interacts with the primary database. The backup exists solely as a recovery path if the YubiKey is lost, and should be stored separately from the primary (e.g. encrypted USB drive or air-gapped machine).

**Keeping databases in sync:** KeePassXC's **Database → Import → Merge from KeePass database** function reconciles the two files. Merge primary into backup periodically to keep it current.

### Vault Access

- **KeePassXC** provides the GUI for database management on both databases
- **`keepassxc-cli`** used by the MCP server for programmatic vault interaction (primary database only)
- `pykeepass` is **not** used — KeePassXC dependency accepted for GUI and YubiKey/SSH agent support
- **REPL mode**: `keepassxc-cli open <database>` starts a persistent interactive session; all subsequent commands are sent via stdin and read from stdout. One YubiKey touch per session rather than per command.
- **Qt argument quoting**: The REPL uses Qt's `QProcess::splitCommand` (double-quote style). Arguments with spaces must use double quotes — POSIX single-quote quoting is not recognised and silently breaks entries with spaces in their titles.

### Authentication

Single path only — YubiKey challenge-response against the primary database:

1. Server detects YubiKey is inserted (polled via `ykman list`)
2. Server invokes `keepassxc-cli --yubikey 2 open <database>` — the CLI internally manages the HMAC-SHA1 challenge-response
3. YubiKey blinks — user physically touches the key to authorize the CLI's challenge
4. On valid response, the REPL session is open; all subsequent `run_cli()` calls reuse it without re-authenticating

If no YubiKey is present, the MCP server returns a `YubiKeyNotPresent` error and does not attempt to open the vault.

### Session Behavior

- Vault remains open as long as the YubiKey is physically inserted
- `unlock_vault` opens a persistent `keepassxc-cli open` REPL process — one touch per session
- Server continuously polls for YubiKey presence
- **YubiKey removed → grace period begins (default 10 s), vault stays open**
  - Handles transient USB bus interruptions and accidental dislodging of the 5C Nano
  - YubiKey reinserted within grace period → timer cancelled, REPL continues uninterrupted, no re-touch required
  - YubiKey still absent after grace period → vault locks (REPL process killed), in-flight tool call fails with `VaultLocked`
- After lock, any reinsertion requires a fresh `unlock_vault` call and YubiKey touch — no exceptions
- No inactivity timeout — physical key presence is the session gate
- `import_entries` always locks the vault after merge (REPL state would diverge from the merged database); call `unlock_vault` again to continue

### MCP Transport

- **stdio** — local only, no network socket exposed

### Concurrency

- Write operations (`create_entry`, `deactivate_entry`, `add_attachment`) acquire a file lock before executing
- Second concurrent writer waits up to a configurable timeout, then fails with `WriteLockTimeout` error
- Read operations do not require a lock

---

## Plugin Structure

The MCP server is packaged as a Claude Code plugin for distribution via the Claude-Code-Plugins marketplace repo (L3Digital).

### Directory Layout

```
keepass-cred-mgr/
├── .claude-plugin/
│   └── plugin.json              # Plugin manifest (required)
├── .mcp.json                    # MCP server declaration (required)
├── commands/                    # Custom slash commands
│   ├── keepass-status.md
│   ├── keepass-rotate.md
│   └── keepass-audit.md
├── skills/                      # Agent skills (one per concern)
│   ├── keepass-hygiene/
│   │   └── SKILL.md
│   ├── keepass-credential-cpanel/
│   │   └── SKILL.md
│   ├── keepass-credential-ftp/
│   │   └── SKILL.md
│   ├── keepass-credential-ssh/
│   │   └── SKILL.md
│   ├── keepass-credential-brave-search/
│   │   └── SKILL.md
│   └── keepass-credential-anthropic/
│       └── SKILL.md
├── agents/                      # Agents (none yet; provisioning agent planned)
├── server/                      # MCP server Python source
│   ├── main.py
│   ├── tools/
│   ├── vault.py
│   ├── yubikey.py
│   └── config.py
├── tests/                       # Unit and integration tests
├── config.example.yaml          # Example YAML allowlist config
└── README.md                    # Installation and usage instructions (required)

# Note: marketplace.json lives in the Claude-Code-Plugins repo root, not inside the plugin directory
```

### `.claude-plugin/plugin.json`

```json
{
  "name": "keepass-cred-mgr",
  "description": "MCP server for secure KeePass vault access from Claude Code via YubiKey authentication",
  "version": "0.3.1",
  "author": {
    "name": "L3Digital-Net",
    "url": "https://github.com/L3Digital-Net"
  },
  "homepage": "https://github.com/L3Digital-Net/Claude-Code-Plugins/tree/main/plugins/keepass-cred-mgr"
}
```

### `.mcp.json`

Declares the MCP server to Claude Code so it knows how to launch it. Uses flat format (no `mcpServers` wrapper — that format is not supported in plugin context):

```json
{
  "keepass": {
    "command": "bash",
    "args": ["${CLAUDE_PLUGIN_ROOT}/scripts/start-server.sh"]
  }
}
```

The `start-server.sh` wrapper resolves Python dependencies via `uv run --with` and starts the FastMCP server. This avoids relying on `.mcp.json` `cwd` or `env` fields, which may not work in plugin context.

### `marketplace.json` (in Claude-Code-Plugins repo root)

```json
{
  "name": "claude-code-plugins",
  "owner": {
    "name": "L3Digital",
    "url": "https://github.com/l3digital"
  },
  "plugins": [
    {
      "name": "keepass-cred-mgr",
      "source": "./keepass-cred-mgr",
      "description": "Secure KeePass vault access via YubiKey authentication"
    }
  ]
}
```

### Versioning

Semantic versioning (`MAJOR.MINOR.PATCH`) required for all published releases:
- **PATCH** — bug fixes, no interface changes
- **MINOR** — new tools or non-breaking changes
- **MAJOR** — breaking changes to tool surface or config format

### README.md Requirements

The README must cover at minimum:
- Prerequisites (KeePassXC, ykman, Python 3.12+, YubiKey 5C Nano or compatible)
- YubiKey configuration steps
- KeePassXC database setup steps
- YAML config setup
- Installation via `/plugin install keepass-cred-mgr@l3digital`
- Tool surface reference
- Security notes

### Slash Commands

Three custom slash commands ship with the plugin. Defined as markdown files in `commands/`.

| Command | File | Purpose |
|---|---|---|
| `/keepass-status` | `commands/keepass-status.md` | Show vault state, YubiKey presence, active session duration, and accessible groups |
| `/keepass-rotate` | `commands/keepass-rotate.md` | Guided multi-step credential rotation: deactivate old entry, create new entry, confirm |
| `/keepass-audit` | `commands/keepass-audit.md` | List all `[INACTIVE]` entries across all accessible groups with deactivation timestamps |

### Skills

Six skills ship with the plugin, one per concern. Each is defined as a `SKILL.md` in its own subfolder under `skills/`. Granular structure allows Claude to load only what is relevant to the current task.

**1. KeePass Credential Hygiene** (`skills/keepass-hygiene/SKILL.md`)

Model-invoked guidance Claude applies automatically whenever working with KeePass credentials. Covers:

- Always verify an entry is not `[INACTIVE]` before using it as a credential
- When vault access is required for SSH or GPG keys, prefer `get_attachment` over `get_entry` — but always check the SSH agent and `~/.ssh` first per the SSH Key Handling skill before accessing the vault at all
- Never log, echo, print, or include returned secrets in any output, comment, or file
- Always confirm a new credential was successfully stored before calling `deactivate_entry` on the old one
- When generating and storing new credentials, apply appropriate entropy and key type for the context

**2. cPanel Credential Handling** (`skills/keepass-credential-cpanel/SKILL.md`)

- Group: `Servers`
- Title format: `cPanel - <domain>`
- Required fields: username, password, URL (typically `https://domain.com:2083`)
- Notes field: hosting provider, associated domains
- Rotation guidance: rotate when access has been shared or revoked, or on hosting provider change

**3. FTP Credential Handling** (`skills/keepass-credential-ftp/SKILL.md`)

Covers both `lftp` and `sftp` workflows:

**FTP/FTPS entries:**
- Group: `Servers`
- Title format: `FTP - <host>`
- Required fields: username, password, URL (host), port if non-standard
- Notes field: protocol (plain FTP, FTPS explicit, FTPS implicit), client (`lftp`)
- `lftp` connection strings: `ftp+tls://user@host` (FTPS explicit), `ftps://user@host` (FTPS implicit)
- **Plain FTP security rule**: if the entry does not use TLS (FTPS), Claude must flag this as a security concern and require a note in the entry explicitly explaining why unencrypted FTP is in use. Claude will not silently store a plain FTP credential without this note.

**SFTP entries — split across two groups:**
- Connection credential: Group `Servers`, Title format `SFTP - <host>`, fields: username, host, port if non-standard
- SSH key used for authentication: Group `SSH Keys`, Title format `SSH - <host>` — handled per the SSH Key Handling skill
- Cross-reference: the `Servers` SFTP entry notes field must reference the corresponding `SSH Keys` entry title, and vice versa
- `lftp` connection string: `sftp://user@host`

**4. SSH Key Handling** (`skills/keepass-credential-ssh/SKILL.md`)

Key resolution order (Option B — agent-first):

1. Check `ssh-add -l` for a loaded key matching the host or purpose
2. If loaded in agent — use it directly, no vault interaction needed
3. If not in agent — check `~/.ssh` for an existing key file and load it
4. If not in `~/.ssh` — retrieve from KeePass via `get_attachment` and provision appropriately
5. Never retrieve a KeePass SSH key attachment if the key is already available locally or in the agent

Storage guidance:
- Group: `SSH Keys`
- Title format: `SSH - <host or purpose>`
- Password field: key passphrase (if any)
- Attachments: private key file and public key file
- Notes: target host(s), key type (ed25519 strongly preferred over RSA)
- KeePassXC SSH agent integration loads vault keys into the agent automatically on vault unlock — for routine connections the key will already be present in the agent

**5. Brave Search API Credential Handling** (`skills/keepass-credential-brave-search/SKILL.md`)

- Group: `API Keys`
- Title format: `Brave Search API - <purpose or project>`
- Password field: the API key value
- URL: `https://api.search.brave.com`
- Notes: subscription tier, rate limits if known, associated project
- Rotation: rotate if key appears in version control, logs, or any output
- Usage: retrieve via `get_entry` for injection into project config or `.env` files; never hardcode in source

**6. Anthropic API Credential Handling** (`skills/keepass-credential-anthropic/SKILL.md`)

- Group: `API Keys`
- Title format: `Anthropic API - <project name>`
- Password field: the API key value
- URL: `https://api.anthropic.com`
- Notes: associated project or workspace
- Workflow: keys are created in the Anthropic console by the user, then pasted into the conversation for Claude to store via `create_entry`
- Full read access: Claude may retrieve the key to write it directly to `.env` files, secrets managers, or SDK configuration files. Retrieval is for writing to destinations only — never for displaying in conversation
- **Elevated sensitivity rules** (billing implications):
  - Always inject via environment variable or secrets manager — never hardcode in source files
  - When retrieved, write directly to the target file or config — never echo or display the raw key value in conversation output under any circumstances
  - If Claude detects an Anthropic API key appearing in code, a commit, conversation output, or any log, flag it immediately and recommend rotation
  - Rotate immediately if exposed in version control, logs, or shared output

### Agents

No agents ship with the current release.

**Planned — Credential Provisioning Agent** (`agents/provision.md`)

A purpose-built agent for provisioning credentials when setting up a new project or server environment. Intended workflow:
- Audit existing vault entries relevant to the target environment
- Generate missing credentials (SSH keys, API keys, service logins) with appropriate parameters
- Store all new credentials in the correct groups with consistent naming
- Verify vault state on completion and report what was created

Deferred to keep the initial releases focused; the agent requires service-specific context that benefits from real-world usage patterns before codifying.

### Local Development Testing

Use a local marketplace to test iteratively before publishing:

```bash
# Structure
dev-marketplace/
├── .claude-plugin/marketplace.json
└── keepass-cred-mgr/                    # symlink or copy of plugin under development

# In Claude Code
/plugin marketplace add ./dev-marketplace
/plugin install keepass-cred-mgr@dev-marketplace

# After changes — reinstall to pick up updates
/plugin uninstall keepass-cred-mgr@dev-marketplace
/plugin install keepass-cred-mgr@dev-marketplace
```

---

## Hardware

| Item | Details |
|---|---|
| YubiKey Model | YubiKey 5C Nano |
| Manufacturer | Yubico |
| Model Number | 5060408461518 |
| Configured Slot | Slot 2 — HMAC-SHA1 Challenge-Response |
| Touch Required | Yes — mandatory, prevents silent prompt injection triggering |
| Backup Key | Required — same HMAC secret programmed to a second YubiKey |

---

## Software Dependencies

### System

| Package | Purpose | Install |
|---|---|---|
| KeePassXC | Vault GUI, SSH agent integration, YubiKey support | [keepassxc.org](https://keepassxc.org) or package manager |
| `keepassxc-cli` | Programmatic vault access (bundled with KeePassXC) | Included with KeePassXC |
| YubiKey Manager (`ykman`) | YubiKey configuration and presence detection | `sudo apt install yubikey-manager` / `brew install ykman` |
| `ssh-agent` | SSH key broker — loaded automatically by KeePassXC | Pre-installed on all target platforms |
| `gpg` | GPG key import during machine provisioning | `sudo apt install gnupg` / `brew install gnupg` |

### Python

| Package | Purpose |
|---|---|
| `mcp` | Anthropic's official MCP Python SDK |
| `structlog` | Structured logging throughout (replaces stdlib logging) |
| `pyyaml` | YAML config file parsing |
| `filelock` | Write operation file locking |
| `pytest` | Test framework |
| `pytest-asyncio` | Async test support |

> Python version requirement: 3.12+ (developed on 3.14.2)

---

## Configuration Steps

### 1. YubiKey — Initial Setup

The HMAC secret must be specified explicitly (not auto-generated) so it can be replicated to a backup key. Generate a strong random hex secret offline first, then program both keys with it.

```bash
# Program primary key — slot 2, touch required
ykman otp chalresp --touch 2 <your-secret-hex>

# Program backup key — identical command, identical secret
ykman otp chalresp --touch 2 <your-secret-hex>

# Verify slot 2 configuration
ykman otp info
```

> Store the backup key in a physically separate, secure location.
> Program the backup key **before** creating any workflow dependency on the primary.

### 2. KeePassXC — Primary Database (YubiKey only)

1. Open KeePassXC → **Database → New Database**
2. When prompted for credentials, leave master password blank
3. Enable **Challenge-Response** → select YubiKey Slot 2
4. Touch the key when it blinks to complete the test challenge
5. Save the database to your preferred local path

### 3. KeePassXC — Backup Database (Master password only)

1. Open KeePassXC → **Database → New Database**
2. Set a strong master password — no YubiKey component
3. Save to an encrypted USB drive or air-gapped machine, physically separate from primary
4. Periodically sync via **Database → Import → Merge from KeePass database** (merge primary into backup)

### 4. KeePassXC — SSH Agent Integration

Enables KeePassXC to automatically load SSH private keys into `ssh-agent` when the database is unlocked and remove them when it locks. No keys ever touch disk during normal operation.

**Global setup:**

1. Open KeePassXC → **Tools → Settings → SSH Agent**
2. Enable **SSH Agent integration**
3. On Linux: ensure `SSH_AUTH_SOCK` is set in your environment (most desktop environments handle this automatically; if not, add `eval $(ssh-agent -s)` to your shell profile)
4. On macOS: the system SSH agent is used automatically — no additional setup required

**Per-entry SSH key setup:**

For each SSH key stored in the primary database:

1. Create a new entry for the key
2. Store the passphrase (if any) in the password field
3. Attach the private key file (e.g. `id_ed25519`) via **Advanced → Attachments**
4. Attach the public key file (e.g. `id_ed25519.pub`) as a second attachment
5. Go to the **SSH Agent** tab on the entry
6. Select the private key attachment
7. Enable **Add key to agent when database is opened**
8. Enable **Remove key from agent when database is closed**

### 5. KeePassXC — GPG Key Storage

KeePassXC has no native GPG agent integration. Store keys as attachments for retrieval during machine provisioning. The MCP server's `get_attachment` tool can pipe the key directly to `gpg --import` without writing a file to disk.

**Storing a GPG key via Claude Code (preferred):**

Claude Code can generate or receive GPG key material and store it directly using `create_entry` followed by `add_attachment`. The `add_attachment` tool uses a secure temp file internally — key material is never written to disk by the user.

1. `create_entry("GPG Key - <key-id>", "GPG Keys", username=<key-id>, password=<passphrase>)`
2. `add_attachment("GPG Key - <key-id>", "gpg-private.asc", <armored-private-key-content>, "GPG Keys")`
3. `add_attachment("GPG Key - <key-id>", "gpg-public.asc", <armored-public-key-content>, "GPG Keys")`

**Storing a GPG key manually (alternative):**

If importing an existing key from outside Claude Code:

```bash
# Export private key in ASCII-armored format
gpg --armor --export-secret-keys <key-id> > gpg-private.asc

# Export public key
gpg --armor --export <key-id> > gpg-public.asc
```

1. Create a new KeePassXC entry for the GPG key
2. Store the passphrase in the password field
3. Attach `gpg-private.asc` and `gpg-public.asc` via **Advanced → Attachments**
4. Delete the exported `.asc` files from disk after attaching

**Importing on a new machine via MCP server:**

Claude Code retrieves the armored key via `get_attachment` and imports directly — no intermediate file written to disk.

### 6. KeePassXC — Recommended Group Structure

Suggested group layout for the primary database. Groups not on the allowlist in the MCP server config are invisible to all tools.

```
Primary Database
├── Servers          # SSH credentials, server logins, cPanel, SFTP connection credentials
├── SSH Keys         # SSH private/public key pairs
├── GPG Keys         # GPG key pairs
├── Git              # GitHub PATs, GitLab tokens, etc.
├── API Keys         # Project API keys and tokens
└── Services         # Project-related site logins
```

### 7. MCP Server — YAML Allowlist Config

Location: outside any project directory. Path specified at server startup.

```yaml
database_path: /path/to/primary.kdbx
yubikey_slot: 2
grace_period_seconds: 10
yubikey_poll_interval_seconds: 5
write_lock_timeout_seconds: 10
page_size: 50
log_level: INFO

allowed_groups:
  - Servers
  - SSH Keys
  - GPG Keys
  - Git
  - API Keys
  - Services

audit_log_path: /path/to/logs/keepass-cred-mgr-audit.jsonl
```

---

## MCP Tool Surface

YubiKey presence is required for all tool calls. The vault must be open before any tool executes.
All tools respect the `allowed_groups` allowlist — entries outside allowed groups are invisible regardless of what is requested.

### Inactive Entry Convention

Inactive credentials are prefixed with `[INACTIVE]` in their title (e.g. `[INACTIVE] example cred`).

- All read tools hide `[INACTIVE]` entries by default
- Pass `include_inactive=true` to any read tool that returns entries (`list_entries`, `search_entries`) to make them visible for audit purposes
- Claude Code never uses an `[INACTIVE]` entry as a credential under any circumstance
- `[INACTIVE]` entries are only removed manually by the user in the KeePassXC GUI

### Read Tools

| Tool | Parameters | Returns | Notes |
|---|---|---|---|
| `list_groups()` | — | Group names | No secrets |
| `list_entries(group?, include_inactive?)` | `group`: optional; `include_inactive`: default false | Titles, usernames, URLs (via per-entry show calls) | No secrets; hides `[INACTIVE]` entries unless flag set |
| `search_entries(query, group?, include_inactive?)` | `query`: string; `group`: optional; `include_inactive`: default false | Matching entry metadata | No secrets; hides `[INACTIVE]` entries unless flag set |
| `get_entry(title, group?)` | `title`; `group`: optional | Full entry including password/secret | Returns secret — logged; blocked if entry is `[INACTIVE]` |
| `get_attachment(title, attachment_name, group?)` | `title`; `attachment_name`; `group`: optional | Attachment contents | Returns secret — logged; blocked if entry is `[INACTIVE]` |

### Write Tools

| Tool | Parameters | Behavior | Notes |
|---|---|---|---|
| `create_entry(title, group, ...)` | `title`, `group`, `username?`, `password?`, `url?`, `notes?` | Creates new entry | Fails if an active entry with the same title already exists in that group |
| `deactivate_entry(title, group?)` | `title`; `group`: optional | Renames entry to `[INACTIVE] <title>`, appends deactivation timestamp to notes | Cannot be applied to an already-inactive entry |
| `add_attachment(title, attachment_name, content, group?)` | `title`; `attachment_name`; `content`: binary or text; `group`: optional | Writes content to a `chmod 600` temp file, imports via `keepassxc-cli attachment-import`, immediately shreds temp file | Temp file exists for milliseconds only; fails if entry is `[INACTIVE]` |
| `import_entries(entries)` | `entries`: list of `{group, title, username?, password?, url?, notes?}` | Builds XML → creates staging KDBX → merges into production database | 2 YubiKey touches regardless of entry count; vault locks after merge |

### CLI Commands Used

All operations implemented via `keepassxc-cli` — no additional Python dependencies required for the tool surface. Commands marked **REPL** are dispatched through the persistent REPL stdin/stdout. Commands marked **subprocess** spawn a separate process (binary output or merge operations that must touch the database file directly).

| MCP Tool | keepassxc-cli command | Dispatch |
|---|---|---|
| `list_groups()` | `ls` | REPL |
| `list_entries(group?)` | `ls <group>` → titles only; `show` per entry for username/URL metadata | REPL |
| `search_entries(query)` | `search <term>` → titles only; `show` per result for metadata | REPL |
| `get_entry(title)` | `show --show-protected <entry>` | REPL |
| `get_attachment(title, name)` | `attachment-export --stdout <entry> <name>` | subprocess (raw bytes can't transit text REPL) |
| `create_entry(title, ...)` | `add <entry> [--username u] [-p]` (password via stdin) | REPL |
| `deactivate_entry(title)` | `show <entry>` → `edit --title "[INACTIVE] <title>"` → `edit --notes "<existing+timestamp>"` | REPL |
| `add_attachment(title, name, content)` | temp file → `attachment-import <entry> <name> <tmp>` → shred | REPL |
| `import_entries(entries)` | `import --set-password <xml> <staging.kdbx>` → `merge --yubikey 2 --no-password <primary> <staging>` | subprocess (file-level merge) |
| YubiKey unlock | `keepassxc-cli --yubikey 2 --no-password open <database>` → persistent REPL session | subprocess (starts REPL) |

### Credential Rotation Workflow

1. `deactivate_entry("example cred")` → renames to `[INACTIVE] example cred`, timestamps notes
2. `create_entry("example cred", ...)` → title is now free, new active credential created
3. User reviews `[INACTIVE]` entries in KeePassXC GUI and deletes when satisfied

**Write design principles:**

- Claude Code can never overwrite or delete entries
- Duplicate prevention: `create_entry` fails if an active (non-`[INACTIVE]`) entry with the same title exists in the group
- `pykeepass` is **not required** — all operations use `keepassxc-cli` natively

---

## Audit Logging

- Every tool call logged with: timestamp, tool name, entry title, group, whether a secret or attachment was returned
- Actual secret values and attachment contents are **never** logged
- Log location: defined in YAML config, outside any project directory
- Format: structured JSON (one record per line) via `structlog`

---

## Testing Strategy

Full unit and integration test suite. YubiKey hardware dependency abstracted behind a `YubiKeyInterface` to enable mocking in tests.

### Unit Tests

- All tool logic: filtering `[INACTIVE]` entries, duplicate detection, `[INACTIVE]` prefix application, `include_inactive` flag behavior
- Grace period timer logic: expiry, cancellation on reinsertion, re-lock behavior
- File lock acquisition, timeout, and release
- Error condition handling for all defined error states
- Config YAML parsing and allowlist enforcement
- Secure temp file creation, permission verification, and shredding

### Integration Tests

- Full REPL open/close cycle against real `keepassxc-cli` binary (no YubiKey required; `PasswordVault` substitutes password-based auth)
- All read tools against a real test `.kdbx` database; results verified against known fixture content
- All write tools against a real test `.kdbx` database, verified by subsequent read
- Rotation cycle: create → deactivate → confirm `[INACTIVE]` prefix → re-create same title
- Duplicate prevention across REPL session boundaries
- Group allowlist enforcement — unlisted group raises `GroupNotAllowed`

### Test Database

A dedicated test `.kdbx` database is checked into the repository, unlockable with a known test password (no YubiKey required for CI). The `PasswordVault` helper (in `tests/helpers.py`) subclasses `Vault`, overrides `unlock()` to pipe the password via stdin and open the real REPL, and inherits all `run_cli()` calls from the parent. This tests the full REPL protocol — including Qt-style argument quoting and echo stripping — against the real binary.

---

## Open Design Decisions

- [x] **#1** ~~Verify `keepassxc-cli` supports all required tool surface operations~~ — Resolved. All tool surface operations confirmed supported natively. `expire_entry` replaced with `deactivate_entry` using `[INACTIVE]` title prefix convention. `pykeepass` not required. YubiKey unlock is a native `keepassxc-cli` flag (`--yubikey 2`).
- [x] **#2** ~~Confirm ykman list reliably detects YubiKey presence/absence~~ — Resolved. `ykman list` retained for presence polling. Using `keepassxc-cli --yubikey 2` for polling is not viable as it would require a physical touch every 5 seconds. `ykman list` does pure USB device enumeration — no touch, no crypto, no vault interaction.
- [x] **#3** ~~Define MCP error response format~~ — Resolved. Use MCP Python SDK built-in exception types. Idiomatic, structured, and natively understood by Claude Code. Defined error states: `VaultLocked`, `EntryNotFound`, `GroupNotAllowed`, `DuplicateEntry`, `EntryInactive`, `YubiKeyNotPresent`, `WriteLockTimeout`.
- [x] **#4** ~~Assess attachment size limits~~ — Resolved. SSH and GPG keys are small (a few KB at most). Non-issue in practice for the defined use cases.
- [x] **#5** ~~Determine attachment creation support~~ — Resolved. Added `add_attachment` tool using secure temp file approach: key material written to a `chmod 600` temp file, passed to `keepassxc-cli attachment-import`, then immediately shredded. No `pykeepass` required. Temp file exists for milliseconds only — acceptable on FDE machines.
- [x] **#6** ~~Define concurrency behavior~~ — Resolved. File lock on write operations. Second writer waits or fails with a clear `WriteLockTimeout` error. Prevents race conditions on the `.kdbx` file.
- [x] **#7** ~~Document installation and deployment~~ — Resolved. Full plugin structure, manifests, versioning strategy, README requirements, and local dev testing workflow documented. See Plugin Structure section.
- [x] **#8** ~~Define testing strategy~~ — Resolved. Full unit + integration tests including mocked YubiKey interactions. YubiKey hardware dependency abstracted behind an interface to enable mocking.
- [x] **#9** ~~Define slash commands~~ — Resolved. Three commands included: `/keepass-status` (vault/session diagnostics), `/keepass-rotate` (guided credential rotation workflow), `/keepass-audit` (list all `[INACTIVE]` entries pending review). `/keepass-search` and `/keepass-new` excluded — adequately served by natural language requests.
