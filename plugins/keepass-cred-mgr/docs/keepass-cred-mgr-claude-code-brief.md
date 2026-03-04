# keepass-cred-mgr — Claude Code Implementation Brief

> Audience: Claude Code (Opus 4.6), acting as sole implementer.
> Goal: Produce a complete, tested, publishable Claude Code plugin.
> All design decisions are final. Do not re-derive or propose alternatives — implement exactly as specified.
> Read this document fully before writing any code.

---

## Project Context

Build a Claude Code plugin (`keepass-cred-mgr`) that exposes a KeePass `.kdbx` vault via MCP tools. Authentication is via YubiKey 5C Nano HMAC-SHA1 challenge-response on slot 2. All vault operations use `keepassxc-cli` — no `pykeepass` dependency. Transport is stdio (local only). The plugin is distributed via the L3Digital Claude-Code-Plugins marketplace repo.

**Runtime constraints that affect implementation:**
- `keepassxc-cli ls` returns titles only — username/URL metadata requires a `show` call per entry (N+1)
- `keepassxc-cli edit --notes` replaces notes entirely — appending requires a read-then-write sequence
- `ykman list` is used for YubiKey presence polling — NOT `keepassxc-cli` (which requires touch every call)
- All write operations must acquire a file lock before executing
- Secure temp files for attachment import: `chmod 600`, import, shred immediately

---

## Repository Structure

Create this exact layout. No additional files unless required by a dependency:

```
keepass-cred-mgr/
├── .claude-plugin/
│   └── plugin.json
├── .mcp.json
├── commands/
│   ├── keepass-status.md
│   ├── keepass-rotate.md
│   └── keepass-audit.md
├── skills/
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
├── agents/
│   └── .gitkeep
├── server/
│   ├── __init__.py
│   ├── main.py
│   ├── config.py
│   ├── vault.py
│   ├── yubikey.py
│   └── tools/
│       ├── __init__.py
│       ├── read.py
│       └── write.py
├── tests/
│   ├── __init__.py
│   ├── conftest.py
│   ├── fixtures/
│   │   └── test.kdbx          # password: "testpassword", no YubiKey
│   ├── unit/
│   │   ├── test_config.py
│   │   ├── test_vault.py
│   │   ├── test_yubikey.py
│   │   └── test_tools.py
│   └── integration/
│       └── test_integration.py
├── config.example.yaml
├── pyproject.toml
└── README.md
```

---

## Implementation Order

Execute phases in sequence. Do not start a phase until the previous phase passes its verification step.

### Phase 1 — Project Skeleton and Config

**Files:** `pyproject.toml`, `config.py`, `config.example.yaml`, `.claude-plugin/plugin.json`, `.mcp.json`

**`pyproject.toml`:**
```toml
[build-system]
requires = ["setuptools>=68"]
build-backend = "setuptools.backends.legacy:build"

[project]
name = "keepass-cred-mgr"
version = "0.3.2"
requires-python = ">=3.12"
dependencies = [
    "mcp",
    "structlog",
    "pyyaml",
    "filelock",
]

[project.optional-dependencies]
dev = ["pytest", "pytest-asyncio"]

[tool.pytest.ini_options]
asyncio_mode = "auto"
```

**`config.py`** — load and validate YAML config. Fields:

| Field | Type | Default | Notes |
|---|---|---|---|
| `database_path` | str | required | Absolute path to `.kdbx` |
| `yubikey_slot` | int | `2` | HMAC-SHA1 slot |
| `grace_period_seconds` | int | `10` | YubiKey removal grace window |
| `yubikey_poll_interval_seconds` | int | `5` | `ykman list` poll cadence |
| `write_lock_timeout_seconds` | int | `10` | Max wait for file lock |
| `page_size` | int | `50` | Max entries returned per list/search call |
| `log_level` | str | `INFO` | Python log level (`DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL`) |
| `allowed_groups` | list[str] | required | Groups visible to all tools |
| `audit_log_path` | str | required | Absolute path to `.jsonl` audit log |

Config path sourced from env var `KEEPASS_CRED_MGR_CONFIG`. Raise `ValueError` with clear message on missing required fields or invalid types/ranges. Expand `~` in paths via `os.path.expanduser`.

**Verification:** `pytest tests/unit/test_config.py` — all pass.

---

### Phase 2 — YubiKey Interface

**Files:** `yubikey.py`

Define a `YubiKeyInterface` Protocol (structural typing, `@runtime_checkable`) with two methods:
- `is_present() -> bool` — returns True if YubiKey is detected
- `slot() -> int` — returns configured slot number

Implement `RealYubiKey(YubiKeyInterface)`:
- `is_present()` — runs `ykman list`, returns `True` if stdout is non-empty, `False` otherwise. Treat any subprocess error as not present.

Implement `MockYubiKey(YubiKeyInterface)`:
- Constructor takes `present: bool = True`
- `is_present()` — returns `self.present`
- `present` attribute settable at runtime for test state transitions

**Verification:** `pytest tests/unit/test_yubikey.py` — all pass.

---

### Phase 3 — Vault Module

**Files:** `vault.py`

`Vault` class manages all `keepassxc-cli` interactions. Constructor takes `config: Config` and `yubikey: YubiKeyInterface`.

**State:** `_unlocked: bool`, `_unlock_time: datetime | None`, `_grace_timer: asyncio.Task | None`

**Unlock flow:**
1. Check `yubikey.is_present()` — raise `YubiKeyNotPresent` if absent
2. Run `keepassxc-cli --yubikey {slot} open {database_path}` — this requires touch
3. On success, set `_unlocked = True`, `_unlock_time = datetime.now()`

**YubiKey polling (background async task, started on server init):**
- Poll `yubikey.is_present()` every `poll_interval` seconds
- On removal detected and no grace timer running: start `_grace_timer` (`asyncio.create_task`)
- Grace timer: sleep `grace_period_seconds`, then call `_lock()`
- On reinsertion detected while grace timer running: cancel timer, clear `_grace_timer`
- On reinsertion after lock: do NOT auto-unlock — require explicit unlock call (fresh touch)

**`_lock()`:** set `_unlocked = False`, log lock event

**`async run_cli(*args) -> str`:**
- Raises `VaultLocked` if `not self._unlocked`
- Runs `keepassxc-cli --yubikey {slot} {args}` via `asyncio.create_subprocess_exec` with 30s timeout
- Returns stdout. Raises `KeePassCLIError` on non-zero exit, `TimeoutError` on timeout.

**`async run_cli_binary(*args) -> bytes`:**
- Same as `run_cli` but returns raw stdout bytes. Used by `get_attachment` for binary content.

**`_entry_path(title, group) -> str`:**
- Returns `"{group}/{title}"` if group provided, else `"{title}"`

**Defined exceptions** (all inherit from `Exception`, registered as MCP errors):
```
VaultLocked
YubiKeyNotPresent
EntryNotFound
GroupNotAllowed
DuplicateEntry
EntryInactive
WriteLockTimeout
KeePassCLIError
```

**Group allowlist enforcement:** any method that accepts a `group` parameter must check it against `config.allowed_groups`. Raise `GroupNotAllowed` if not in list. For operations without a group parameter, search only within allowed groups.

**`[INACTIVE]` prefix constant:** `INACTIVE_PREFIX = "[INACTIVE] "`

**Verification:** `pytest tests/unit/test_vault.py` — all pass with `MockYubiKey`.

---

### Phase 4 — Read Tools

**Files:** `tools/read.py`

All read tools call `vault._run_cli` internally. No file lock required.

**`list_groups() -> list[str]`**
- `keepassxc-cli ls {db}` — parse stdout, return group names only (lines ending in `/`)
- Filter to `allowed_groups`

**`list_entries(group: str | None, include_inactive: bool = False) -> list[dict]`**
- `keepassxc-cli ls {db} {group}` — get titles
- Filter `[INACTIVE]` titles unless `include_inactive=True`
- For each title (up to `page_size`): `keepassxc-cli show {db} {group}/{title}` — parse username, URL
- Return list of `{"title": ..., "username": ..., "url": ...}`
- If no group provided, iterate all allowed groups

**`search_entries(query: str, group: str | None, include_inactive: bool = False) -> list[dict]`**
- `keepassxc-cli search {db} {query}` — returns matching entry paths
- Filter to allowed groups only
- Filter `[INACTIVE]` unless flag set
- For each match (up to `page_size`): `keepassxc-cli show {db} {path}` — parse metadata
- Return list of `{"title": ..., "group": ..., "username": ..., "url": ...}`

**`get_entry(title: str, group: str | None) -> dict`**
- Raise `EntryInactive` if title starts with `INACTIVE_PREFIX`
- `keepassxc-cli show --show-protected {db} {path}`
- Parse all fields including password
- Audit log: tool=get_entry, title, group, secret_returned=True
- Return full entry dict

**`get_attachment(title: str, attachment_name: str, group: str | None) -> bytes`**
- Raise `EntryInactive` if title starts with `INACTIVE_PREFIX`
- `keepassxc-cli attachment-export --stdout {db} {path} {attachment_name}`
- Audit log: tool=get_attachment, title, group, attachment=attachment_name, secret_returned=True
- Return raw bytes

**Verification:** `pytest tests/unit/test_tools.py::TestReadTools` — all pass.

---

### Phase 5 — Write Tools

**Files:** `tools/write.py`

All write tools acquire a `FileLock` on the database path before executing. Lock timeout from config. Raise `WriteLockTimeout` on timeout.

**`create_entry(title: str, group: str, username: str | None, password: str | None, url: str | None, notes: str | None) -> None`**
- Check group in `allowed_groups` — raise `GroupNotAllowed` if not
- Check no active (non-`[INACTIVE]`) entry with same title exists in group — raise `DuplicateEntry` if found
- `keepassxc-cli add {db} {group}/{title} [--username ...] [--password ...] [--url ...] [--notes ...]`
- Audit log: tool=create_entry, title, group

**`deactivate_entry(title: str, group: str | None) -> None`**
- Raise `EntryInactive` if title already starts with `INACTIVE_PREFIX`
- Read existing notes: `keepassxc-cli show {db} {path}` — parse Notes field
- Build new notes: `{existing_notes}\n[DEACTIVATED: {ISO timestamp}]`
- `keepassxc-cli edit --title "[INACTIVE] {title}" {db} {path}`
- `keepassxc-cli edit --notes "{new_notes}" {db} {new_path}`  ← path changes after title edit
- Audit log: tool=deactivate_entry, title, group

**`add_attachment(title: str, attachment_name: str, content: bytes | str, group: str | None) -> None`**
- Raise `EntryInactive` if title starts with `INACTIVE_PREFIX`
- Write `content` to a `tempfile.NamedTemporaryFile(delete=False)`, `chmod 600`
- `keepassxc-cli attachment-import {db} {path} {attachment_name} {tmp_path}`
- Shred immediately: overwrite with zeros, then `os.unlink` — use `shutil` or manual write loop
- Audit log: tool=add_attachment, title, attachment=attachment_name

**Verification:** `pytest tests/unit/test_tools.py::TestWriteTools` — all pass.

---

### Phase 6 — Audit Logger

**Files:** `vault.py` (add logger) or separate `audit.py`

Use `structlog`. Configure JSON output (one record per line) to `config.audit_log_path`.

Every log record must include:
```json
{
  "timestamp": "<ISO 8601>",
  "tool": "<tool_name>",
  "title": "<entry_title>",
  "group": "<group_or_null>",
  "secret_returned": true|false,
  "attachment": "<name_or_null>"
}
```

Secret values and attachment content are **never** logged. Log file must be created if it does not exist. Parent directory must exist (raise clear error if not).

---

### Phase 7 — MCP Server Entry Point

**Files:** `main.py`

Wire everything together using the `mcp` SDK.

```python
# Pseudocode — implement using actual mcp SDK patterns
server = mcp.Server("keepass")
config = load_config()
yubikey = RealYubiKey(config.yubikey_slot)
vault = Vault(config, yubikey)

# Register all 9 tools with their schemas (including unlock_vault)
# Start YubiKey polling background task on server startup
# Handle VaultLocked / YubiKeyNotPresent as MCP errors
# Run with stdio transport
```

Each tool registration must include a description string accurate to the tool's actual behavior. Tool names must match exactly:
`unlock_vault`, `list_groups`, `list_entries`, `search_entries`, `get_entry`, `get_attachment`, `create_entry`, `deactivate_entry`, `add_attachment`

**Verification:** Server starts without error when invoked as `python3 -m server.main`. Exits cleanly on SIGINT.

---

### Phase 8 — Integration Tests

**Files:** `tests/integration/test_integration.py`, `tests/fixtures/test.kdbx`

**Test database requirements:**
- Password: `testpassword`
- No YubiKey required
- Groups: Servers, SSH Keys, API Keys
- Pre-seeded entries: at least 2 active entries per group, 1 `[INACTIVE]` entry in Servers

**Required integration test cases:**
1. Full read cycle: `list_groups` → `list_entries` → `get_entry` → confirm secret returned
2. Write cycle: `create_entry` → `list_entries` confirms presence → `get_entry` confirms fields
3. Rotation cycle: `create_entry` → `deactivate_entry` → confirm `[INACTIVE]` prefix → `create_entry` same title succeeds
4. Duplicate prevention: `create_entry` twice with same title → second raises `DuplicateEntry`
5. Attachment cycle: `create_entry` → `add_attachment` → `get_attachment` → confirm content matches → confirm temp file does not exist on disk
6. `[INACTIVE]` filtering: `list_entries` hides inactive by default, shows with `include_inactive=True`
7. `get_entry` on `[INACTIVE]` entry raises `EntryInactive`
8. Group allowlist: request for group not in allowed list raises `GroupNotAllowed`
9. Grace timer: `MockYubiKey.present = False` → wait `grace_period + 1s` → `list_groups` raises `VaultLocked`
10. Write lock contention: two concurrent `create_entry` calls → one succeeds, one raises `WriteLockTimeout` or waits and succeeds (configurable)

**Verification:** `pytest tests/integration/` — all pass.

---

### Phase 9 — Plugin Manifest Files

**`.claude-plugin/plugin.json`:**
```json
{
  "name": "keepass-cred-mgr",
  "description": "MCP server for secure KeePass vault access from Claude Code via YubiKey authentication",
  "version": "0.3.2",
  "author": {
    "name": "L3DigitalNet",
    "url": "https://github.com/L3DigitalNet"
  },
  "homepage": "https://github.com/L3DigitalNet/Claude-Code-Plugins/tree/main/plugins/keepass-cred-mgr"
}
```

**`.mcp.json`** (flat format — `mcpServers` wrapper not supported in plugin context):
```json
{
  "keepass": {
    "command": "bash",
    "args": ["${CLAUDE_PLUGIN_ROOT}/scripts/start-server.sh"]
  }
}
```

---

### Phase 10 — Slash Commands

Each file is a markdown document that Claude Code reads as a command definition. Write clear, imperative agent instructions.

**`commands/keepass-status.md`** — instructs Claude to:
1. Call `list_groups` — report accessible groups
2. Report vault state (locked/unlocked) based on whether call succeeds or raises `VaultLocked`
3. If unlocked: report session duration (time since `_unlock_time` if accessible, else omit)
4. List any `[INACTIVE]` entries pending review (call `list_entries(include_inactive=True)` per group, filter to inactive only, report count and titles)

**`commands/keepass-rotate.md`** — instructs Claude to:
1. Ask user: which credential to rotate? (title and group)
2. Ask user: what are the new credential values?
3. Call `create_entry` with new values — confirm success before proceeding
4. Call `deactivate_entry` on the old entry — confirm success
5. Report completion: new entry active, old entry deactivated, remind user to delete `[INACTIVE]` entry in KeePassXC GUI when ready

**`commands/keepass-audit.md`** — instructs Claude to:
1. Call `list_entries(include_inactive=True)` for each allowed group
2. Filter to entries with `[INACTIVE]` prefix only
3. For each: call `get_entry` to retrieve deactivation timestamp from notes (do NOT display password)
4. Present a table: group, title (without prefix), deactivation timestamp
5. Remind user: delete entries manually in KeePassXC GUI when satisfied

---

### Phase 11 — Skills

Each skill is a `SKILL.md` file. Write as dense, imperative agent instructions — not prose documentation. Claude loads these at task time.

**`skills/keepass-hygiene/SKILL.md`:**
```
# KeePass Credential Hygiene

RULES — apply whenever interacting with KeePass via MCP tools:

1. Never use an [INACTIVE] entry as a credential. If get_entry or get_attachment returns an EntryInactive error, stop and inform the user.
2. When vault access is required for SSH or GPG key material, use get_attachment — not get_entry. Exception: check ssh-agent and ~/.ssh first per the SSH skill before accessing the vault at all.
3. Never include returned secrets in conversation output, comments, code, logs, or any file other than the intended destination.
4. On credential rotation: confirm create_entry succeeded before calling deactivate_entry. Never deactivate before confirming the new credential is stored.
5. When generating new credentials, use cryptographically appropriate parameters: ed25519 for SSH keys, 32+ character random strings for passwords, correct key types per service.
```

**`skills/keepass-credential-cpanel/SKILL.md`:**
```
# cPanel Credential Handling

GROUP: Servers
TITLE FORMAT: cPanel - <domain>
REQUIRED FIELDS: username, password, url (https://<domain>:2083)
NOTES: hosting provider name, all associated domains

ROTATION: rotate when access has been shared or revoked, or on hosting provider change.
```

**`skills/keepass-credential-ftp/SKILL.md`:**
```
# FTP/SFTP Credential Handling

## FTP / FTPS

GROUP: Servers
TITLE FORMAT: FTP - <host>
REQUIRED FIELDS: username, password, url (host), port (if non-standard)
NOTES FIELD: protocol variant and lftp connection string

PROTOCOL VARIANTS:
- FTPS explicit: ftp+tls://user@host
- FTPS implicit: ftps://user@host
- Plain FTP: ftp://user@host ← SECURITY VIOLATION — see rule below

PLAIN FTP RULE: If the entry uses plain unencrypted FTP (no TLS), you MUST:
1. Flag this as a security concern to the user before storing
2. Require the user to provide a written explanation in the notes field
3. Do not store the entry without this note present

## SFTP

SFTP entries are split across two groups:

CONNECTION CREDENTIAL:
- Group: Servers
- Title: SFTP - <host>
- Fields: username, url (host), port (if non-standard)
- Notes: reference to the SSH Keys entry (e.g. "SSH key: SSH - <host>")

SSH KEY (handle per keepass-credential-ssh skill):
- Group: SSH Keys
- Title: SSH - <host>
- Notes: must reference back to the SFTP connection entry

lftp connection string: sftp://user@host
```

**`skills/keepass-credential-ssh/SKILL.md`:**
```
# SSH Key Handling

## Key Resolution Order (always follow this sequence)

1. Run: ssh-add -l
   → If a key matching the host or purpose is loaded, use it. No vault access needed.

2. If not in agent: check ~/.ssh for an existing key file for this host.
   → If found, load it with ssh-add and use it.

3. If not in ~/.ssh: retrieve from KeePass via get_attachment.
   → Provision the key to ~/.ssh or load directly into the agent as appropriate.

RULE: Never retrieve a KeePass SSH key attachment if the key is already available locally or in the agent.

NOTE: KeePassXC SSH agent integration auto-loads vault keys into the agent on vault unlock. For routine SSH connections, the key will already be in the agent — no vault access required.

## Storage

GROUP: SSH Keys
TITLE FORMAT: SSH - <host or purpose>
PASSWORD FIELD: key passphrase (if any)
ATTACHMENTS: private key file (e.g. id_ed25519) AND public key file (e.g. id_ed25519.pub)
NOTES: target host(s), key type — ed25519 strongly preferred over RSA
CROSS-REFERENCE: if this key is used for SFTP, notes must reference the corresponding Servers entry
```

**`skills/keepass-credential-brave-search/SKILL.md`:**
```
# Brave Search API Credential Handling

GROUP: API Keys
TITLE FORMAT: Brave Search API - <purpose or project>
PASSWORD FIELD: API key value
URL: https://api.search.brave.com
NOTES: subscription tier, rate limits (if known), associated project

RETRIEVAL: use get_entry. Write key to .env file or config — never display raw value in conversation.
ROTATION: rotate immediately if key appears in version control, logs, or any output.
```

**`skills/keepass-credential-anthropic/SKILL.md`:**
```
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
- Always inject via environment variable — never hardcode in source files
- If an Anthropic API key is detected in code, a commit, output, or any log: flag immediately and recommend rotation
- Rotate immediately on any exposure
```

---

### Phase 12 — README and config.example.yaml

**`config.example.yaml`:**
```yaml
# keepass-cred-mgr configuration
# Copy to ~/.config/keepass-cred-mgr/config.yaml and edit paths

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

**`README.md`** must cover (write complete prose, not placeholders):
- What this plugin does and why
- Prerequisites: KeePassXC, ykman, Python 3.12+, YubiKey 5C Nano or compatible
- Installation: `/plugin marketplace add l3digital/claude-code-plugins` then `/plugin install keepass-cred-mgr@l3digital`
- Setup: point to the keepass-cred-mgr-setup.md document (or inline the steps)
- YAML config setup with field reference
- Complete tool surface reference table (all 8 tools, parameters, return values)
- Slash commands reference
- Security model summary
- Known limitations (N+1 CLI calls on list, page_size cap, no delete/overwrite)

---

## Known Implementation Gotchas

**`keepassxc-cli` path handling:** Entry paths are `Group/Title`. If the title itself contains `/`, CLI behavior is undefined — document as unsupported and reject titles containing `/` in `create_entry`.

**`deactivate_entry` path change:** After `edit --title` renames the entry, the path changes. The second `edit --notes` call must use the new path (`{group}/[INACTIVE] {title}`), not the original.

**`ykman list` on no YubiKey:** Returns empty stdout with exit code 0 — do not treat as error. Empty stdout = no key present.

**Temp file shredding:** `os.unlink` alone is not a shred. Overwrite with zeros first:
```python
with open(tmp_path, 'r+b') as f:
    f.write(b'\x00' * os.path.getsize(tmp_path))
os.unlink(tmp_path)
```

**`asyncio` and `subprocess`:** All CLI calls use `asyncio.create_subprocess_exec` with `asyncio.wait_for(timeout=30)`. YubiKey presence polling uses `asyncio.to_thread()` to call the synchronous `ykman list` via `subprocess.run` without blocking the event loop.

**`page_size` applies per call:** `list_entries` and `search_entries` both cap results at `page_size`. Log a warning if results are truncated.

**Test database:** Create `tests/fixtures/test.kdbx` using `keepassxc-cli db-create --set-password testpassword tests/fixtures/test.kdbx` then seed entries via `keepassxc-cli add` commands in a setup script. Check the database into the repo.

---

## Final Verification Checklist

Before declaring implementation complete, confirm all of the following:

- [ ] `pytest tests/unit/` — all pass, no warnings
- [ ] `pytest tests/integration/` — all pass against real test.kdbx
- [ ] `python3 -m server.main` starts and exits cleanly
- [ ] All 8 MCP tools appear in server tool listing
- [ ] Audit log is written on `get_entry` and `get_attachment` calls
- [ ] Temp file does not persist after `add_attachment`
- [ ] `[INACTIVE]` entries invisible by default, visible with flag
- [ ] `GroupNotAllowed` raised for any group not in allowlist
- [ ] `WriteLockTimeout` raised on lock contention (test with forced delay)
- [ ] Server raises `VaultLocked` after grace period expiry (mock test)
- [ ] All 6 skill files present and contain substantive content
- [ ] All 3 command files present and contain clear agent instructions
- [ ] `README.md` is complete (no placeholder sections)
- [ ] `config.example.yaml` is present and correct
- [ ] No secrets appear in any test output, log, or fixture file
