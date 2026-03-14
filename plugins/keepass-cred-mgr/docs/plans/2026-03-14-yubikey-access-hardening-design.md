# YubiKey Access Hardening Design

**Date**: 2026-03-14
**Plugin**: keepass-cred-mgr
**Version target**: 0.4.2

## Problem Statement

Three distinct issues prevent reliable YubiKey HMAC-SHA1 access from the keepass-cred-mgr MCP server:

1. **pcscd exclusive lock**: The PC/SC Smart Card Daemon (`pcscd`) holds an exclusive lock on the YubiKey's CCID interface, which on some systems blocks the HID interface that keepassxc-cli needs for HMAC-SHA1 challenge-response. `ykman list` works (USB enumeration) but `keepassxc-cli --yubikey 2` fails.

2. **Serial detection broken without pcscd**: keepassxc-cli 2.7.10 uses `libykpers` for HMAC-SHA1, which relies on pcscd/CCID for serial enumeration. With pcscd stopped, `--yubikey 2` (slot only) fails with "could not find interface for hardware key with serial number 0". The explicit `--yubikey 2:36834370` (slot:serial) format bypasses this.

3. **hidraw device node vanishes**: The OTP/HID interface's `/dev/hidraw` node can disappear after repeated failed keepassxc-cli attempts. The kernel re-enumerates the device but the node isn't recreated until a USB unbind/rebind cycle. This is a kernel/udev race condition.

When any of these occur, the MCP server surfaces raw keepassxc-cli error output with no actionable guidance.

## Approach

**Approach A (selected)**: New diagnostics module + systemd mask.

- `server/diagnostics.py` with a single public function called from `vault.unlock()` only on failure
- `systemctl mask pcscd.socket` to permanently prevent pcscd from blocking access
- Diagnostics run only on the error path; zero overhead on happy path

Rejected alternatives:
- **Inline diagnostics in vault.py**: Mixes diagnostic logic with the vault state machine. Less testable.
- **Auto-recovery via USB reset script**: Requires elevated privileges. Violates principle of least privilege for an MCP server process.
- **Setup script**: Adds maintenance burden for a one-time operation better handled by documentation.

## Design

### 1. Slot:Serial Config Support (completed)

`yubikey_slot` config field changed from `int` to `str`. Accepts `"2"` (slot only) or `"2:36834370"` (slot:serial).

- `Config.yubikey_slot`: type `str`
- Integer values from YAML auto-coerced to string for backward compatibility
- Validation: slot portion must be a positive integer; serial portion (if present) is passed through
- `YubiKeyInterface.slot()` returns `str`
- All `str()` wrappers removed from callers in `vault.py` and `tools/write.py`
- `config.example.yaml` and `README.md` updated with new format

### 2. Diagnostics Module (`server/diagnostics.py`)

Single public function: `diagnose_unlock_failure(config: Config) -> str`

Called from `vault.unlock()` on any unlock failure (all three exception types). Returns a human-readable diagnostic string with the specific problem and fix command. If no diagnosis matches, returns an empty string (caller uses the original error as-is).

Three checks run in sequence; the first match wins:

1. **pcscd check**: `subprocess.run(["systemctl", "is-active", "pcscd"], ...)` -- exit code 0 means active. Returns message identifying pcscd as the blocker with fix command: `sudo systemctl stop pcscd pcscd.socket && sudo systemctl mask pcscd.socket`

2. **hidraw check**: For each `/dev/hidraw*` node (via `glob.glob`), run `subprocess.run(["udevadm", "info", "--name=/dev/hidrawN"], ...)` and check stdout for both `ID_VENDOR=Yubico` (or `ID_VENDOR_ID=1050`) and `ID_USB_INTERFACE_NUM=00` (the OTP/keyboard interface, as distinct from interface 01 which is FIDO). Both conditions must match. If no hidraw device matches both criteria, the OTP interface is considered missing. An empty glob result (no hidraw nodes at all) is treated identically to no-match. Returns message with USB unbind/rebind command. Additionally, if a matching node exists but is not readable by the current user (`os.access(path, os.R_OK)` returns False), treat it as missing (wrong permissions produce the same keepassxc-cli error as a missing node).

3. **serial hint**: If neither pcscd nor hidraw explains the failure, checks whether `config.yubikey_slot` contains a `:` character. If not (slot-only format), suggests adding the serial via `ykman list --serials`.

4. **Fallback**: If all checks pass, returns empty string.

All checks use `subprocess.run` with `timeout=5`. No async required since this only runs on the error path. All subprocess failures (`OSError`, `TimeoutExpired`) are caught and the check is skipped (best-effort diagnostics).

### 3. Vault Integration

**Scope: `vault.unlock()` only.** The `run_cli()` and `run_cli_binary()` methods are not changed. Their errors occur after a successful unlock (command-level failures, REPL crashes) where YubiKey access is not the issue. Diagnostics are only meaningful at unlock time.

In `vault.unlock()`, all three error handlers call `diagnose_unlock_failure()` unconditionally (no message substring matching). The function is cheap (skipped checks return immediately) and only runs on the error path:

- **`TimeoutError`**: YubiKey may have blinked but HMAC challenge never completed. Diagnostic appended to error message.
- **`IncompleteReadError`**: REPL exited before showing prompt. Diagnostic appended.
- **`KeePassCLIError`**: Any CLI error during unlock (not just "could not find interface"). Diagnostic appended.

If `diagnose_unlock_failure()` returns an empty string (no diagnosis matched), the original error message is used as-is.

The `_PCSCD_HINT` constant is removed from `vault.py`. The `run_cli()` timeout handler (line 264) currently appends `_PCSCD_HINT`; this reference is also removed since `run_cli()` timeouts are command-level, not YubiKey-access-level. The error message for `run_cli()` timeouts becomes just the timeout text with no hint.

### 4. OS Hardening (systemd mask)

This section documents the rationale behind the pcscd mask command that the diagnostics module surfaces to the user. The plugin does not execute this command itself; the user runs it manually when prompted by a diagnostic message, or proactively during initial setup per the documentation.

`pcscd.socket` should be masked via `systemctl mask pcscd.socket`. Masking creates a symlink to `/dev/null`, blocking all activation paths (manual start, socket activation, dependency pull-in). This survives package updates that re-enable the unit, unlike `systemctl disable`.

The service (`pcscd.service`) is already stopped and won't start without its socket trigger. Masking just the socket is sufficient.

### 5. Documentation

`docs/keepass-cred-mgr-setup.md` gets a new "YubiKey Access Prerequisites" section covering:

- pcscd conflict explanation and mask command
- hidraw device recovery (USB unbind/rebind)
- When to use slot:serial format and how to find the serial
- Diagnostic error messages and what they mean

### 6. Testing

**New file**: `tests/unit/test_diagnostics.py`

Tests for `diagnose_unlock_failure()` with mocked `subprocess.run`:

- pcscd active: returns pcscd-specific message with mask command
- pcscd inactive + hidraw missing: returns hidraw message with unbind/rebind command
- pcscd inactive + hidraw present + no serial in config: returns serial hint
- pcscd inactive + hidraw present + serial in config: returns generic fallback
- Subprocess failures (ykman not installed, permission denied): doesn't crash, returns best-effort

- hidraw node exists but not readable by current user: treated as missing, returns hidraw message

**Updated**: `tests/unit/test_vault.py` -- unlock error path assertions updated from `_PCSCD_HINT` text to verify that `diagnose_unlock_failure()` is called and its output appended. `_PCSCD_HINT` references in `run_cli()` timeout tests are updated to expect plain timeout message (no hint).

No integration tests for diagnostics (they check OS state that can't be reproduced in CI).

## File Changes

| File | Change |
|------|--------|
| `server/diagnostics.py` | **New** |
| `server/vault.py` | Remove `_PCSCD_HINT`; add diagnostic calls in `unlock()` error paths; remove hint from `run_cli()` timeout |
| `server/config.py` | Done: `yubikey_slot` is `str` |
| `server/yubikey.py` | Done: `slot()` returns `str` |
| `server/tools/write.py` | Done: `str()` wrapper removed |
| `tests/unit/test_diagnostics.py` | **New** |
| `tests/unit/test_vault.py` | Update unlock error assertions |
| `tests/unit/test_config.py` | Done: slot:serial tests added |
| `docs/keepass-cred-mgr-setup.md` | Add "YubiKey Access Prerequisites" section |
| `config.example.yaml` | Done: slot:serial comment |
| `README.md` | Done: config table updated |
| `CHANGELOG.md` | New entry for v0.4.2 |

**Not changed**: `main.py`, `tools/read.py`, `audit.py`, commands, skills.

## Success Criteria

**Automated (unit tests)**:
1. `diagnose_unlock_failure()` with pcscd active returns pcscd-specific message with mask command
2. `diagnose_unlock_failure()` with missing hidraw node returns USB reset command
3. `diagnose_unlock_failure()` with slot-only config and no other issues returns serial hint
4. `yubikey_slot: 2` (int) and `yubikey_slot: "2:36834370"` (str) both load correctly
5. All existing tests pass; new diagnostic tests pass
6. `vault.unlock()` error paths call `diagnose_unlock_failure()` and append its output
7. `run_cli()` timeout no longer includes `_PCSCD_HINT`

**Manual verification (not in test suite)**:
8. `pcscd.socket` is masked on the development machine (already done; documented in setup guide for new users)
