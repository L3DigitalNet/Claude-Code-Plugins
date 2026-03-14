# Audit Findings Fix Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix all 11 audit findings from the keepass-cred-mgr plugin audit, ordered by severity with cross-impact verification between each fix.

**Architecture:** No new files. All fixes are edits to existing modules: `read.py` (multi-line notes parsing, inactive entry access), `write.py` (falsy vs None), `vault.py` (stale docstring), `main.py` (unused exception), and documentation files. Tests first for code changes.

**Tech Stack:** Python 3.12+, pytest, keepassxc-cli output parsing

**Findings reference:**
- 🔴1: marketplace.json version mismatch (0.4.1 vs 0.4.2)
- 🔴2: `/keepass-audit` command calls `get_entry` on `[INACTIVE]` titles, which raises `EntryInactive`
- 🔴3: `pyproject.toml` version stale (0.3.0)
- 🟡4: Stale "Group allowlist" references in vault.py docstring and README Security Model
- 🟡5: `create_entry` treats falsy `""` same as `None` (silent field omission)
- 🟡6: `_parse_show_output` truncates multi-line notes to first line
- 🟡7: `search_entries` and `list_entries` accept unused `audit` parameter
- 🟢8: `import_entries` docstring doesn't mention tag bypass
- 🟢9: `_shred_file` limitations on COW/SSD (documentation only)
- 🟢10: `deactivate_entry` notes failure already documented — no change
- 🟢11: Unreachable `TimeoutError` in `unlock_vault` handler

---

## File Structure

| File | Changes |
|------|---------|
| `server/tools/read.py` | Fix `_parse_show_output` for multi-line notes; add `allow_inactive` param to `get_entry`; remove `audit` param from `list_entries` and `search_entries` |
| `server/tools/write.py` | Fix `create_entry` falsy check; update `import_entries` docstring (`deactivate_entry`'s inline notes parse is left as-is since it only needs the first line for timestamp appending) |
| `server/main.py` | Update `get_entry` handler to pass `allow_inactive`; fix `list_entries`/`search_entries` calls (remove audit arg); remove unreachable `TimeoutError` from `unlock_vault` |
| `server/vault.py` | Fix docstring (remove "Group allowlist" reference) |
| `tests/unit/test_tools.py` | New tests for multi-line notes, inactive entry access, falsy fields |
| `README.md` | Fix Security Model section (remove group allowlist reference) |
| `.claude-plugin/marketplace.json` (repo root) | Bump version to 0.4.2 |
| `pyproject.toml` | Bump version to 0.4.2 |
| `CHANGELOG.md` | Add 0.4.2 fixes |
| `commands/keepass-audit.md` | Note that `get_entry` is called with `allow_inactive=True` |

---

## Chunk 1: Multi-line Notes + Inactive Entry Access (🔴2, 🟡6)

These are intertwined: fixing the audit command (🔴2) requires `get_entry` to accept inactive titles, and the notes it reads may be multi-line (🟡6).

### Task 1: Fix `_parse_show_output` for multi-line notes

**Files:**
- Modify: `server/tools/read.py:26-43`
- Test: `tests/unit/test_tools.py`

keepassxc-cli `show` output format: known fields appear as `Key: value` on a single line. Notes can span multiple lines — continuation lines have no `Key: ` prefix. The parser currently only captures the first Notes line.

- [ ] **Step 1: Write failing test for multi-line notes**

Add to `TestParseShowOutput` in `tests/unit/test_tools.py`:

```python
    def test_multiline_notes(self):
        from server.tools.read import _parse_show_output
        output = (
            "Title: Web Server\n"
            "UserName: admin\n"
            "Password: s3cret\n"
            "URL: https://example.com\n"
            "Notes: Line one\n"
            "Line two\n"
            "Line three\n"
        )
        result = _parse_show_output(output)
        assert result["notes"] == "Line one\nLine two\nLine three"

    def test_multiline_notes_followed_by_field(self):
        """Notes continuation stops when another known field appears."""
        from server.tools.read import _parse_show_output
        output = (
            "Title: Entry\n"
            "Notes: First line\n"
            "Second line\n"
            "Tags: some-tag\n"
        )
        result = _parse_show_output(output)
        assert result["notes"] == "First line\nSecond line"

    def test_single_line_notes_unchanged(self):
        """Existing single-line notes behavior preserved."""
        from server.tools.read import _parse_show_output
        output = "Title: Entry\nNotes: Single line\nUserName: admin\n"
        result = _parse_show_output(output)
        assert result["notes"] == "Single line"
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd plugins/keepass-cred-mgr && uv run --with pytest,pytest-asyncio,pytest-cov pytest tests/unit/test_tools.py::TestParseShowOutput -v`
Expected: 2 new tests FAIL (multiline notes returns only first line)

- [ ] **Step 3: Fix `_parse_show_output` to handle multi-line notes**

Replace lines 26-43 in `server/tools/read.py`:

```python
# Known field prefixes that terminate a multi-line notes block.
_KNOWN_FIELDS = {"username", "password", "url", "notes", "title", "tags"}


def _parse_show_output(stdout: str) -> EntryFields:
    """Parse keepassxc-cli show output into a string field dict.

    Notes can span multiple lines — continuation lines have no 'Key: ' prefix.
    Continuation stops when a line starts with a known field key followed by ': '.
    """
    fields: dict[str, str] = {}
    in_notes = False
    notes_lines: list[str] = []

    for line in stdout.strip().splitlines():
        if ": " in line:
            key, _, value = line.partition(": ")
            key_lower = key.strip().lower()
            if key_lower in _KNOWN_FIELDS:
                # A known field ends any notes continuation
                if in_notes:
                    fields["notes"] = "\n".join(notes_lines)
                    in_notes = False
                if key_lower == "notes":
                    notes_lines = [value.strip()]
                    in_notes = True
                elif key_lower == "username":
                    fields["username"] = value.strip()
                elif key_lower == "password":
                    fields["password"] = value.strip()
                elif key_lower == "url":
                    fields["url"] = value.strip()
                elif key_lower == "title":
                    fields["title"] = value.strip()
                continue
        # Line without a known field prefix — notes continuation
        if in_notes:
            notes_lines.append(line)

    if in_notes:
        fields["notes"] = "\n".join(notes_lines)

    return fields
```

- [ ] **Step 4: Run tests**

Run: `cd plugins/keepass-cred-mgr && uv run --with pytest,pytest-asyncio,pytest-cov pytest tests/unit/test_tools.py::TestParseShowOutput -v`
Expected: all pass (4 existing + 3 new = 7)

- [ ] **Step 5: Run full test suite to check for regressions**

Run: `cd plugins/keepass-cred-mgr && uv run --with pytest,pytest-asyncio,pytest-cov pytest tests/unit/ -q`
Expected: all 192 pass

### Task 2: Allow `get_entry` on inactive entries for audit command

**Files:**
- Modify: `server/tools/read.py:155-188` (`get_entry`)
- Modify: `server/main.py:171-186` (`get_entry` handler)
- Modify: `commands/keepass-audit.md`
- Test: `tests/unit/test_tools.py`

- [ ] **Step 6: Write failing test for `get_entry` with `allow_inactive=True`**

Add to `TestReadTools` in `tests/unit/test_tools.py`:

```python
    async def test_get_entry_allows_inactive_when_flag_set(self, unlocked_vault):
        """get_entry with allow_inactive=True returns the entry without raising."""
        from server.tools.read import get_entry

        vault, audit = unlocked_vault
        vault._repl_proc.stdout.readuntil.side_effect = [
            _repl_resp(
                b"Title: [INACTIVE] Old Server\n"
                b"UserName: admin\n"
                b"Password: oldpass\n"
                b"URL: https://old.example.com\n"
                b"Notes: Some notes\n[DEACTIVATED: 2026-03-01T00:00:00+00:00]\n"
            )
        ]
        result = await get_entry(
            vault, audit,
            title="[INACTIVE] Old Server", group="Servers",
            allow_inactive=True,
        )
        assert result["title"] == "[INACTIVE] Old Server"
        assert result["password"] == "oldpass"
        assert "DEACTIVATED" in result["notes"]

    async def test_get_entry_still_blocks_inactive_by_default(self, unlocked_vault):
        """Default behavior unchanged — inactive entries raise EntryInactive."""
        from server.tools.read import get_entry
        from server.vault import EntryInactive

        vault, audit = unlocked_vault
        with pytest.raises(EntryInactive):
            await get_entry(vault, audit, title="[INACTIVE] Old Server", group="Servers")
```

- [ ] **Step 7: Run tests to verify they fail**

Run: `cd plugins/keepass-cred-mgr && uv run --with pytest,pytest-asyncio,pytest-cov pytest tests/unit/test_tools.py::TestReadTools::test_get_entry_allows_inactive_when_flag_set -v`
Expected: FAIL (unexpected keyword argument `allow_inactive`)

- [ ] **Step 8: Add `allow_inactive` parameter to `get_entry`**

In `server/tools/read.py`, update `get_entry` (line 155):

```python
async def get_entry(
    vault: Vault,
    audit: AuditLogger,
    *,
    title: str,
    group: str | None = None,
    allow_inactive: bool = False,
) -> EntryFields:
    if not allow_inactive and title.startswith(INACTIVE_PREFIX):
        raise EntryInactive(f"Entry '{title}' is deactivated")
```

In `server/main.py`, update the `get_entry` handler (line 172) to accept and pass the new parameter:

```python
@mcp.tool()
async def get_entry(
    ctx: Context[Any, Any, Any], title: str, group: str | None = None,
    allow_inactive: bool = False,
) -> dict[str, str]:
    """Get full entry details including password. Logs to audit trail.
    Set allow_inactive=True to read [INACTIVE] entries (used by /keepass-audit)."""
    log.info("tool_invoked", tool="get_entry")
    app = _get_ctx(ctx)
    try:
        return await read_tools.get_entry(
            app.vault, app.audit, title=title, group=group,
            allow_inactive=allow_inactive,
        )
```

- [ ] **Step 9: Update `/keepass-audit` command to mention `allow_inactive`**

In `commands/keepass-audit.md`, update Step 2 to clarify:

Replace:
```
For each inactive entry, call `get_entry` to retrieve the notes field.
```

With:
```
For each inactive entry, call `get_entry` with `allow_inactive=true` to retrieve the notes field.
```

- [ ] **Step 10: Run full test suite**

Run: `cd plugins/keepass-cred-mgr && uv run --with pytest,pytest-asyncio,pytest-cov pytest tests/unit/ -q`
Expected: all pass (~197: 192 baseline + 5 new tests)

- [ ] **Step 11: Commit**

```bash
git add plugins/keepass-cred-mgr/server/tools/read.py \
       plugins/keepass-cred-mgr/server/main.py \
       plugins/keepass-cred-mgr/commands/keepass-audit.md \
       plugins/keepass-cred-mgr/tests/unit/test_tools.py
git commit -m "fix(keepass-cred-mgr): multi-line notes parsing and allow_inactive for audit

_parse_show_output now captures continuation lines after Notes field.
get_entry accepts allow_inactive=True for /keepass-audit command.
Fixes audit findings #2 and #6."
```

---

## Chunk 2: Falsy Fields + Unused Audit Param + Docstrings (🟡5, 🟡7, 🟡4, 🟢8, 🟢11)

### Task 3: Fix `create_entry` falsy field check

**Files:**
- Modify: `server/tools/write.py:99-114`
- Test: `tests/unit/test_tools.py`

- [ ] **Step 12: Write failing test for empty string username**

Add to `TestWriteTools` in `tests/unit/test_tools.py`:

```python
    async def test_create_entry_empty_string_username_passed(self, unlocked_vault):
        """Empty string username is passed to CLI, not silently dropped."""
        from server.tools.write import create_entry

        vault, audit = unlocked_vault
        vault._repl_proc.stdout.readuntil.side_effect = [
            _repl_resp(b""),  # ls: no existing entries
            _repl_resp(b""),  # add success
        ]
        await create_entry(vault, audit, title="New", group="Servers", username="")
        write_calls = vault._repl_proc.stdin.write.call_args_list
        add_cmd = write_calls[1][0][0]
        assert b"--username" in add_cmd
```

- [ ] **Step 13: Run test to verify it fails**

Run: `cd plugins/keepass-cred-mgr && uv run --with pytest,pytest-asyncio,pytest-cov pytest tests/unit/test_tools.py::TestWriteTools::test_create_entry_empty_string_username_passed -v`
Expected: FAIL (`--username` not in add_cmd because `if username:` skips empty string)

- [ ] **Step 14: Fix falsy checks in `create_entry`**

In `server/tools/write.py`, replace lines 102-107:

```python
        if username:
            cmd.extend(["--username", username])
        if url:
            cmd.extend(["--url", url])
        if notes:
            cmd.extend(["--notes", notes])
```

With:

```python
        if username is not None:
            cmd.extend(["--username", username])
        if url is not None:
            cmd.extend(["--url", url])
        if notes is not None:
            cmd.extend(["--notes", notes])
```

- [ ] **Step 15: Run tests**

Run: `cd plugins/keepass-cred-mgr && uv run --with pytest,pytest-asyncio,pytest-cov pytest tests/unit/ -q`
Expected: all pass

### Task 4: Remove unused `audit` parameter from list/search

**Files:**
- Modify: `server/tools/read.py:69-75, 111-118` (function signatures)
- Modify: `server/main.py:144-149, 162-168` (handler calls)
- Modify: `tests/unit/test_tools.py` (all callers of `list_entries` and `search_entries`)

- [ ] **Step 16: Remove `audit` from `list_entries` and `search_entries` signatures**

In `server/tools/read.py`, change `list_entries` signature (line 69):

```python
async def list_entries(
    vault: Vault,
    *,
    group: str | None = None,
    include_inactive: bool = False,
) -> list[EntrySummary]:
```

Change `search_entries` signature (line 111):

```python
async def search_entries(
    vault: Vault,
    *,
    query: str,
    group: str | None = None,
    include_inactive: bool = False,
) -> list[SearchResult]:
```

- [ ] **Step 17: Update `main.py` handler calls**

In `server/main.py`, update `list_entries` handler (line 145):

```python
        return await read_tools.list_entries(
            app.vault, group=group, include_inactive=include_inactive
        )
```

Update `search_entries` handler (line 163):

```python
        return await read_tools.search_entries(
            app.vault,
            query=query, group=group, include_inactive=include_inactive,
        )
```

- [ ] **Step 18: Update all test callers**

In `tests/unit/test_tools.py`, find-and-replace all `list_entries(vault, audit` → `list_entries(vault` and `search_entries(vault, audit` → `search_entries(vault`. Affected tests:

- `test_list_entries_filters_inactive` (line 112)
- `test_list_entries_includes_inactive` (line 128)
- `test_list_entries_any_group_accessible` (line 257)
- `test_list_entries_group_none_iterates_all` (line 277)
- `test_list_entries_page_size_truncation` (line 316)
- `test_search_entries` (line 190)
- `test_search_with_group_filter` (line 615)
- `test_search_filters_inactive_by_default` (line 628)
- `test_search_entry_without_group_prefix` (line 642)
- `test_search_multilevel_path` (line 655)
- `test_search_truncates_at_page_size` (line 679)
- `test_search_entries_excludes_restricted` (line 979)
- `test_list_entries_excludes_restricted` (line 992)

- [ ] **Step 19: Run full test suite**

Run: `cd plugins/keepass-cred-mgr && uv run --with pytest,pytest-asyncio,pytest-cov pytest tests/unit/ -q`
Expected: all pass

### Task 5: Fix stale docstrings, README, and minor documentation

**Files:**
- Modify: `server/vault.py:1-6` (docstring)
- Modify: `README.md:206-210` (Security Model section)
- Modify: `server/tools/write.py:338-355` (`import_entries` docstring)
- Modify: `server/main.py:107-118` (`unlock_vault` handler — remove unreachable `TimeoutError`)

- [ ] **Step 20: Fix vault.py docstring**

Replace line 5 in `server/vault.py`:

```python
Group allowlist enforced on all operations.
```

With:

```python
Tag-based access control: AI RESTRICTED blocks all access, READ ONLY blocks writes.
```

- [ ] **Step 21: Fix README Security Model section**

In `README.md`, replace:

```
- **Group allowlist** limits which entries are visible, regardless of what Claude requests
```

With:

```
- **Tag-based access control** restricts entries: `AI RESTRICTED` blocks all AI access, `READ ONLY` blocks writes
```

- [ ] **Step 22: Update `import_entries` docstring**

In `server/tools/write.py`, add to the `import_entries` docstring (after "call unlock_vault again to continue"):

```
    Tag-based access control (AI RESTRICTED, READ ONLY) does not apply to
    imported entries — they are new entries without tags.
```

- [ ] **Step 23: Remove unreachable `TimeoutError` from `unlock_vault` handler**

In `server/main.py`, line 117, change:

```python
    except (YubiKeyNotPresent, KeePassCLIError, TimeoutError) as e:
```

To:

```python
    except (YubiKeyNotPresent, KeePassCLIError) as e:
```

(vault.unlock() wraps TimeoutError into KeePassCLIError before re-raising, so TimeoutError never reaches the handler)

- [ ] **Step 24: Run full test suite**

Run: `cd plugins/keepass-cred-mgr && uv run --with pytest,pytest-asyncio,pytest-cov pytest tests/unit/ -q`
Expected: all pass

- [ ] **Step 25: Commit**

```bash
git add plugins/keepass-cred-mgr/server/tools/write.py \
       plugins/keepass-cred-mgr/server/tools/read.py \
       plugins/keepass-cred-mgr/server/main.py \
       plugins/keepass-cred-mgr/server/vault.py \
       plugins/keepass-cred-mgr/README.md \
       plugins/keepass-cred-mgr/tests/unit/test_tools.py
git commit -m "fix(keepass-cred-mgr): falsy field check, unused audit param, stale docs

create_entry uses 'is not None' instead of truthy check for optional
fields. Remove unused audit param from list_entries/search_entries.
Fix stale 'Group allowlist' references in vault.py docstring and
README Security Model. Remove unreachable TimeoutError from
unlock_vault handler. Add tag bypass note to import_entries docstring.
Fixes audit findings #4, #5, #7, #8, #11."
```

---

## Chunk 3: Version Metadata + CHANGELOG (🔴1, 🔴3)

Done last so the version bump captures all fixes in a single entry.

### Task 6: Sync all version numbers

**Files:**
- Modify: `.claude-plugin/marketplace.json` (repo root)
- Modify: `pyproject.toml`
- Modify: `CHANGELOG.md`

- [ ] **Step 26: Update marketplace.json version**

In `.claude-plugin/marketplace.json`, find the `keepass-cred-mgr` entry and change:

```json
"version": "0.4.1",
```

To:

```json
"version": "0.4.2",
```

- [ ] **Step 27: Update pyproject.toml version**

In `plugins/keepass-cred-mgr/pyproject.toml`, change:

```toml
version = "0.3.0"
```

To:

```toml
version = "0.4.2"
```

- [ ] **Step 28: Update CHANGELOG with fix entries**

In `plugins/keepass-cred-mgr/CHANGELOG.md`, add to the existing `## [0.4.2]` section's `### Fixed` subsection (create it if absent):

```markdown
### Fixed

- `/keepass-audit` command: `get_entry` now accepts `allow_inactive=True` to read `[INACTIVE]` entries without raising `EntryInactive`
- `_parse_show_output` now captures multi-line notes (continuation lines after `Notes:` field)
- `create_entry` uses `is not None` instead of truthy check for optional fields; empty string values are no longer silently dropped
- Stale "Group allowlist" references removed from `vault.py` docstring and README Security Model section
- Unreachable `TimeoutError` removed from `unlock_vault` exception handler
- Unused `audit` parameter removed from `list_entries` and `search_entries` signatures
- `pyproject.toml` version synced to 0.4.2 (was stale at 0.3.0)
- `marketplace.json` version synced to 0.4.2 (was stale at 0.4.1)
```

- [ ] **Step 29: Run marketplace validator**

Run: `cd /home/chris/git-l3digital/Claude-Code-Plugins && ./scripts/validate-marketplace.sh`
Expected: 0 errors, 0 warnings

- [ ] **Step 30: Run full test suite one final time**

Run: `cd plugins/keepass-cred-mgr && uv run --with pytest,pytest-asyncio,pytest-cov pytest tests/unit/ -q`
Expected: all pass

- [ ] **Step 31: Commit**

```bash
git add .claude-plugin/marketplace.json \
       plugins/keepass-cred-mgr/pyproject.toml \
       plugins/keepass-cred-mgr/CHANGELOG.md
git commit -m "fix(keepass-cred-mgr): sync version metadata to 0.4.2

marketplace.json (was 0.4.1) and pyproject.toml (was 0.3.0) now
match plugin.json at 0.4.2. Changelog updated with all audit fixes.
Fixes audit findings #1 and #3."
```
