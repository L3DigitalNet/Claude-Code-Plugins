# YubiKey Access Hardening Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a diagnostics module that surfaces actionable error messages when YubiKey HMAC-SHA1 access fails, and harden the OS config to prevent pcscd from re-activating.

**Architecture:** New `server/diagnostics.py` module with a single `diagnose_unlock_failure(config)` function that checks pcscd status, hidraw device presence, and slot:serial config. Called from `vault.unlock()` error handlers only. `_PCSCD_HINT` removed from vault.py entirely.

**Tech Stack:** Python 3.12+, subprocess, glob, os, structlog

**Spec:** `docs/plans/2026-03-14-yubikey-access-hardening-design.md`

---

## File Structure

| File | Responsibility |
|------|---------------|
| `server/diagnostics.py` | **New** — `diagnose_unlock_failure()` with three sequential checks (pcscd, hidraw, serial) |
| `server/vault.py` | Remove `_PCSCD_HINT`; call diagnostics from `unlock()` error paths; remove hint from `run_cli()` timeout |
| `tests/unit/test_diagnostics.py` | **New** — unit tests for all diagnostic check branches |
| `tests/unit/test_vault.py` | Update unlock/run_cli error assertions |
| `docs/keepass-cred-mgr-setup.md` | Add "YubiKey Access Prerequisites" section after Step 1 |
| `CHANGELOG.md` | v0.4.2 entry |

---

## Chunk 1: Diagnostics Module + Tests

### Task 1: Write diagnostic check tests

**Files:**
- Create: `tests/unit/test_diagnostics.py`

- [ ] **Step 1: Create test file with pcscd-active test**

```python
"""Tests for server.diagnostics — YubiKey unlock failure diagnostics."""

from unittest.mock import patch, MagicMock
import subprocess

import pytest

from server.config import Config

pytestmark = pytest.mark.unit


def _make_config(yubikey_slot: str = "2") -> Config:
    """Minimal Config for diagnostics tests (only yubikey_slot matters)."""
    return Config(
        database_path="/tmp/test.kdbx",
        audit_log_path="/tmp/audit.jsonl",
        yubikey_slot=yubikey_slot,
        grace_period_seconds=10,
        yubikey_poll_interval_seconds=5,
        write_lock_timeout_seconds=10,
        page_size=50,
        log_level="INFO",
    )


class TestDiagnoseUnlockFailure:

    @patch("subprocess.run")
    def test_pcscd_active_returns_mask_command(self, mock_run):
        from server.diagnostics import diagnose_unlock_failure

        mock_run.return_value = MagicMock(returncode=0)  # systemctl is-active → active
        result = diagnose_unlock_failure(_make_config())
        assert "pcscd" in result
        assert "mask" in result

    @patch("os.access", return_value=True)
    @patch("glob.glob", return_value=[])
    @patch("subprocess.run")
    def test_no_hidraw_returns_usb_reset(self, mock_run, mock_glob, mock_access):
        from server.diagnostics import diagnose_unlock_failure

        # pcscd inactive (returncode=3)
        mock_run.return_value = MagicMock(returncode=3)
        result = diagnose_unlock_failure(_make_config())
        assert "unbind" in result.lower() or "hidraw" in result.lower()

    @patch("os.access", return_value=True)
    @patch("glob.glob", return_value=["/dev/hidraw0"])
    @patch("subprocess.run")
    def test_hidraw_present_no_yubikey_returns_usb_reset(self, mock_run, mock_glob, mock_access):
        from server.diagnostics import diagnose_unlock_failure

        # pcscd inactive, udevadm shows non-YubiKey device
        mock_run.side_effect = [
            MagicMock(returncode=3),  # systemctl is-active pcscd → inactive
            MagicMock(returncode=0, stdout="ID_VENDOR=Logitech\n"),  # udevadm for hidraw0
        ]
        result = diagnose_unlock_failure(_make_config())
        assert "hidraw" in result.lower() or "unbind" in result.lower()

    @patch("os.access", return_value=True)
    @patch("glob.glob", return_value=["/dev/hidraw0"])
    @patch("subprocess.run")
    def test_yubikey_otp_present_slot_only_returns_serial_hint(
        self, mock_run, mock_glob, mock_access
    ):
        from server.diagnostics import diagnose_unlock_failure

        mock_run.side_effect = [
            MagicMock(returncode=3),  # pcscd inactive
            MagicMock(
                returncode=0,
                stdout="ID_VENDOR=Yubico\nID_USB_INTERFACE_NUM=00\n",
            ),  # udevadm → YubiKey OTP interface
        ]
        result = diagnose_unlock_failure(_make_config(yubikey_slot="2"))
        assert "serial" in result.lower()
        assert "ykman" in result

    @patch("os.access", return_value=True)
    @patch("glob.glob", return_value=["/dev/hidraw0"])
    @patch("subprocess.run")
    def test_all_checks_pass_returns_empty(self, mock_run, mock_glob, mock_access):
        from server.diagnostics import diagnose_unlock_failure

        mock_run.side_effect = [
            MagicMock(returncode=3),  # pcscd inactive
            MagicMock(
                returncode=0,
                stdout="ID_VENDOR=Yubico\nID_USB_INTERFACE_NUM=00\n",
            ),
        ]
        # Config already has serial
        result = diagnose_unlock_failure(_make_config(yubikey_slot="2:36834370"))
        assert result == ""

    @patch("subprocess.run", side_effect=OSError("command not found"))
    def test_subprocess_failure_returns_empty(self, mock_run):
        from server.diagnostics import diagnose_unlock_failure

        result = diagnose_unlock_failure(_make_config())
        assert result == ""

    @patch("subprocess.run", side_effect=subprocess.TimeoutExpired("cmd", 5))
    def test_subprocess_timeout_returns_empty(self, mock_run):
        from server.diagnostics import diagnose_unlock_failure

        result = diagnose_unlock_failure(_make_config())
        assert result == ""

    @patch("os.access", return_value=False)
    @patch("glob.glob", return_value=["/dev/hidraw0"])
    @patch("subprocess.run")
    def test_hidraw_not_readable_treated_as_missing(self, mock_run, mock_glob, mock_access):
        from server.diagnostics import diagnose_unlock_failure

        mock_run.side_effect = [
            MagicMock(returncode=3),  # pcscd inactive
            MagicMock(
                returncode=0,
                stdout="ID_VENDOR=Yubico\nID_USB_INTERFACE_NUM=00\n",
            ),
        ]
        result = diagnose_unlock_failure(_make_config())
        assert "hidraw" in result.lower() or "unbind" in result.lower()
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd plugins/keepass-cred-mgr && uv run --with pytest,pytest-asyncio,pytest-cov pytest tests/unit/test_diagnostics.py -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'server.diagnostics'`

### Task 2: Implement diagnostics module

**Files:**
- Create: `server/diagnostics.py`

- [ ] **Step 3: Write the diagnostics module**

```python
"""YubiKey unlock failure diagnostics.

Called from vault.unlock() on any unlock error. Checks pcscd status, hidraw
device presence, and slot:serial config. Returns a human-readable diagnostic
string, or empty string if no diagnosis matches.
"""

from __future__ import annotations

import glob
import os
import subprocess

import structlog

from server.config import Config

log: structlog.stdlib.BoundLogger = structlog.get_logger("keepass-cred-mgr.diagnostics")

_SUBPROCESS_TIMEOUT = 5


def _check_pcscd() -> str | None:
    """Return diagnostic message if pcscd is active, None otherwise."""
    try:
        result = subprocess.run(
            ["systemctl", "is-active", "pcscd"],
            capture_output=True, text=True, timeout=_SUBPROCESS_TIMEOUT,
        )
        if result.returncode == 0:
            return (
                "pcscd (PC/SC Smart Card Daemon) is running and holds an exclusive lock "
                "on the YubiKey CCID interface, blocking HMAC-SHA1 challenge-response. "
                "Fix: sudo systemctl stop pcscd pcscd.socket && "
                "sudo systemctl mask pcscd.socket"
            )
    except (OSError, subprocess.TimeoutExpired):
        log.debug("diagnostics_pcscd_check_skipped", reason="subprocess failed")
    return None


def _check_hidraw() -> str | None:
    """Return diagnostic message if YubiKey OTP hidraw device is missing, None otherwise."""
    try:
        hidraw_nodes = glob.glob("/dev/hidraw*")
        for node in hidraw_nodes:
            result = subprocess.run(
                ["udevadm", "info", f"--name={node}"],
                capture_output=True, text=True, timeout=_SUBPROCESS_TIMEOUT,
            )
            if result.returncode != 0:
                continue
            stdout = result.stdout
            is_yubico = "ID_VENDOR=Yubico" in stdout or "ID_VENDOR_ID=1050" in stdout
            is_otp_interface = "ID_USB_INTERFACE_NUM=00" in stdout
            if is_yubico and is_otp_interface:
                if not os.access(node, os.R_OK):
                    break  # node exists but not readable — treat as missing
                return None  # OTP interface found and accessible
    except (OSError, subprocess.TimeoutExpired):
        log.debug("diagnostics_hidraw_check_skipped", reason="subprocess failed")
        return None

    return (
        "YubiKey OTP HID device not found (/dev/hidraw* has no Yubico interface 00 node). "
        "The device node may have disappeared after a failed access attempt. "
        "Fix: identify the USB bus ID with 'lsusb -d 1050:' then run: "
        "echo <BUS-ID> | sudo tee /sys/bus/usb/drivers/usb/unbind && sleep 1 && "
        "echo <BUS-ID> | sudo tee /sys/bus/usb/drivers/usb/bind"
    )


def _check_serial(config: Config) -> str | None:
    """Return diagnostic if config uses slot-only format (no serial), None otherwise."""
    if ":" not in config.yubikey_slot:
        return (
            "yubikey_slot is set to slot-only format without a serial number. "
            "Some systems cannot auto-detect the serial without pcscd. "
            "Find your serial with: ykman list --serials  "
            "Then set yubikey_slot to \"<slot>:<serial>\" in config "
            "(e.g., \"2:36834370\")"
        )
    return None


def diagnose_unlock_failure(config: Config) -> str:
    """Run sequential diagnostics and return the first matching message.

    Returns empty string if no diagnosis matches.
    """
    checks: list[tuple[str, callable]] = [
        ("pcscd", _check_pcscd),
        ("hidraw", _check_hidraw),
        ("serial", lambda: _check_serial(config)),
    ]
    for name, check in checks:
        try:
            result = check()
            if result is not None:
                return result
        except Exception:
            log.debug("diagnostics_check_failed", check=name)
            continue
    return ""
```

- [ ] **Step 4: Run diagnostic tests to verify they pass**

Run: `cd plugins/keepass-cred-mgr && uv run --with pytest,pytest-asyncio,pytest-cov pytest tests/unit/test_diagnostics.py -v`
Expected: 8 passed

- [ ] **Step 5: Commit diagnostics module and tests**

```bash
git add plugins/keepass-cred-mgr/server/diagnostics.py plugins/keepass-cred-mgr/tests/unit/test_diagnostics.py
git commit -m "feat(keepass-cred-mgr): add YubiKey unlock failure diagnostics module

Checks pcscd status, hidraw device presence, and slot:serial config
when vault.unlock() fails. Returns actionable error messages with
fix commands."
```

---

## Chunk 2: Vault Integration + Test Updates

### Task 3: Update vault.py to use diagnostics

**Files:**
- Modify: `server/vault.py:40-45` (remove `_PCSCD_HINT`)
- Modify: `server/vault.py:164-178` (unlock error handlers)
- Modify: `server/vault.py:262-264` (run_cli timeout)

- [ ] **Step 6: Remove `_PCSCD_HINT` and add diagnostic import**

In `server/vault.py`, remove lines 42-45 (the `_PCSCD_HINT` constant):

```python
# DELETE these lines:
_PCSCD_HINT = (
    " — if the YubiKey blinked but timed out, "
    "run: sudo systemctl stop pcscd pcscd.socket"
)
```

Add import at the top of the file (after the existing `from server.config import Config` import):

```python
from server.diagnostics import diagnose_unlock_failure
```

- [ ] **Step 7: Update unlock() error handlers to call diagnostics**

Note: `unlock()` has two exception handlers in the try block around `readuntil` — `TimeoutError` and `IncompleteReadError`. The spec lists `KeePassCLIError` as a third path, but `unlock()` doesn't currently catch it (it's raised by `run_cli()` after unlock). If a future change introduces a `KeePassCLIError` catch in `unlock()`, diagnostics should be added there too.

Replace the two error handlers in `unlock()` (lines 169-178) with:

```python
        except asyncio.TimeoutError:
            proc.kill()
            await proc.wait()
            diag = diagnose_unlock_failure(self._config)
            msg = "keepassxc-cli open timed out"
            if diag:
                msg += " — " + diag
            raise KeePassCLIError(msg)
        except asyncio.IncompleteReadError:
            await proc.wait()
            diag = diagnose_unlock_failure(self._config)
            msg = (
                "keepassxc-cli open exited before showing prompt"
                " — check database_path in config and YubiKey slot"
            )
            if diag:
                msg += ". " + diag
            raise KeePassCLIError(msg)
```

- [ ] **Step 8: Remove `_PCSCD_HINT` from run_cli() timeout**

Replace line 264:
```python
                    f"keepassxc-cli {args[0]} timed out" + _PCSCD_HINT
```

With:
```python
                    f"keepassxc-cli {args[0]} timed out"
```

- [ ] **Step 9: Verify vault.py has no remaining references to `_PCSCD_HINT`**

Run: `grep -n _PCSCD_HINT plugins/keepass-cred-mgr/server/vault.py`
Expected: no output

### Task 4: Update vault tests

**Files:**
- Modify: `tests/unit/test_vault.py:118-128` (unlock timeout test)
- Modify: `tests/unit/test_vault.py:224-232` (run_cli timeout test)

- [ ] **Step 10: Update unlock timeout test to check for diagnostics call**

Replace `test_unlock_pcscd_hint_in_timeout_error` (lines 118-128) with:

```python
    @patch("server.vault.diagnose_unlock_failure", return_value="diag: test message")
    @patch("asyncio.create_subprocess_exec")
    async def test_unlock_timeout_calls_diagnostics(
        self, mock_exec, mock_diag, test_config, mock_yubikey
    ):
        """Timeout during unlock calls diagnose_unlock_failure and appends result."""
        mock_exec.return_value = _mock_unlock_proc(fail=asyncio.TimeoutError)
        from server.vault import KeePassCLIError, Vault

        vault = Vault(test_config, mock_yubikey)
        with pytest.raises(KeePassCLIError, match="diag: test message"):
            await vault.unlock()
        mock_diag.assert_called_once_with(test_config)

    @patch("server.vault.diagnose_unlock_failure", return_value="")
    @patch("asyncio.create_subprocess_exec")
    async def test_unlock_timeout_no_diag_plain_message(
        self, mock_exec, mock_diag, test_config, mock_yubikey
    ):
        """When diagnostics returns empty, error is just the timeout text."""
        mock_exec.return_value = _mock_unlock_proc(fail=asyncio.TimeoutError)
        from server.vault import KeePassCLIError, Vault

        vault = Vault(test_config, mock_yubikey)
        with pytest.raises(KeePassCLIError, match="timed out") as exc_info:
            await vault.unlock()
        assert "—" not in str(exc_info.value)

    @patch("server.vault.diagnose_unlock_failure", return_value="diag: incomplete")
    @patch("asyncio.create_subprocess_exec")
    async def test_unlock_incomplete_read_calls_diagnostics(
        self, mock_exec, mock_diag, test_config, mock_yubikey
    ):
        """IncompleteReadError during unlock calls diagnostics."""
        mock_exec.return_value = _mock_unlock_proc(fail=asyncio.IncompleteReadError)
        from server.vault import KeePassCLIError, Vault

        vault = Vault(test_config, mock_yubikey)
        with pytest.raises(KeePassCLIError, match="diag: incomplete"):
            await vault.unlock()
        mock_diag.assert_called_once_with(test_config)
```

- [ ] **Step 11: Update run_cli timeout test to not expect pcscd hint**

Replace `test_run_cli_raises_on_timeout` (lines 224-232) with:

```python
    async def test_run_cli_raises_on_timeout(self, test_config, mock_yubikey):
        """TimeoutError from readuntil wraps to KeePassCLIError (no pcscd hint)."""
        from server.vault import KeePassCLIError, Vault

        vault = Vault(test_config, mock_yubikey)
        vault._unlocked = True
        vault._repl_proc = _mock_repl_proc([asyncio.TimeoutError()])
        with pytest.raises(KeePassCLIError, match="timed out") as exc_info:
            await vault.run_cli("show", test_config.database_path, "Servers/Entry")
        assert "pcscd" not in str(exc_info.value)
```

- [ ] **Step 12: Run all unit tests**

Run: `cd plugins/keepass-cred-mgr && uv run --with pytest,pytest-asyncio,pytest-cov pytest tests/unit/ -v`
Expected: all pass (182 existing + 8 new diagnostics + 2 new vault = ~192)

- [ ] **Step 13: Commit vault integration and test updates**

```bash
git add plugins/keepass-cred-mgr/server/vault.py plugins/keepass-cred-mgr/tests/unit/test_vault.py
git commit -m "feat(keepass-cred-mgr): integrate diagnostics into vault.unlock() error paths

Replace _PCSCD_HINT with diagnose_unlock_failure() calls on both
unlock error paths (timeout, incomplete read). Remove hint from
run_cli() timeout since that's a command-level error, not a YubiKey
access issue."
```

---

## Chunk 3: Documentation + OS Hardening + Release

### Task 5: Update setup documentation

**Files:**
- Modify: `docs/keepass-cred-mgr-setup.md` (add section after Step 1)

- [ ] **Step 14: Add YubiKey Access Prerequisites section**

Insert after the `## Step 1 — Install System Dependencies` section (after line 48) and before `## Step 2`.

Content to insert (note: contains bash code blocks — write directly to the file, not copy-paste from this plan):

**Section heading:** `## Step 1a — YubiKey Access Prerequisites`

**Subsection 1: "Disable pcscd (required)"** — explain that pcscd holds exclusive lock on CCID, blocking HMAC-SHA1. Provide commands: `sudo systemctl stop pcscd pcscd.socket` and `sudo systemctl mask pcscd.socket`. Verify with `systemctl status pcscd.socket` (should show "Loaded: masked"). Note that `mask` is stronger than `disable`.

**Subsection 2: "Verify YubiKey HID access"** — loop over `/dev/hidraw*` checking `udevadm info` for `ID_VENDOR=Yubico`. If no device appears, provide USB unbind/rebind commands using `lsusb -d 1050:` to find the bus ID.

**Subsection 3: "Configure slot:serial (if needed)"** — if keepassxc-cli fails with "serial number 0" error, find serial with `ykman list --serials` and update config to `"2:SERIAL"` format.

- [ ] **Step 15: Update Step 7 config example to show slot:serial comment**

In `docs/keepass-cred-mgr-setup.md`, replace the `yubikey_slot: 2` line in the Step 7 YAML block with:

```yaml
yubikey_slot: "2"              # or "2:SERIAL" if auto-detect fails (see Step 1a)
```

### Task 6: Mask pcscd.socket (OS hardening)

- [ ] **Step 16: Upgrade pcscd from disabled to masked**

```bash
sudo systemctl mask pcscd.socket
```

Verify:
```bash
systemctl status pcscd.socket
# Should show "Loaded: masked (/dev/null)"
```

Rollback (if pcscd is needed for another tool): `sudo systemctl unmask pcscd.socket && sudo systemctl enable pcscd.socket`

### Task 7: Update CHANGELOG

**Files:**
- Modify: `CHANGELOG.md`

- [ ] **Step 17: Add v0.4.2 changelog entry**

Add after the `## [0.4.1]` section:

```markdown
## [0.4.2] - 2026-03-14

### Added

- `server/diagnostics.py`: YubiKey unlock failure diagnostics module; checks pcscd status, hidraw device presence, and slot:serial config on any unlock failure
- `yubikey_slot` config field now accepts `"slot:serial"` format (e.g., `"2:36834370"`) for systems where keepassxc-cli cannot auto-detect the YubiKey serial
- "YubiKey Access Prerequisites" section in setup guide covering pcscd conflicts, hidraw recovery, and serial configuration

### Changed

- `yubikey_slot` config type changed from `int` to `str`; integer values from YAML are auto-coerced for backward compatibility
- `vault.unlock()` error messages now include specific diagnostics (pcscd blocking, missing hidraw node, missing serial) instead of a generic pcscd hint
- `run_cli()` timeout error no longer includes the pcscd hint (command-level timeouts are unrelated to YubiKey access)

### Removed

- `_PCSCD_HINT` constant from `vault.py` (replaced by diagnostics module)
```

- [ ] **Step 18: Bump version in plugin.json**

Update `plugins/keepass-cred-mgr/.claude-plugin/plugin.json` version from `"0.4.1"` to `"0.4.2"`.

- [ ] **Step 19: Run full test suite**

Run: `cd plugins/keepass-cred-mgr && uv run --with pytest,pytest-asyncio,pytest-cov pytest tests/unit/ -v`
Expected: all pass

- [ ] **Step 20: Commit documentation and release prep**

```bash
git add plugins/keepass-cred-mgr/docs/keepass-cred-mgr-setup.md \
       plugins/keepass-cred-mgr/CHANGELOG.md \
       plugins/keepass-cred-mgr/.claude-plugin/plugin.json
git commit -m "docs(keepass-cred-mgr): add YubiKey access prerequisites and v0.4.2 changelog

Setup guide now covers pcscd masking, hidraw recovery, and slot:serial
configuration. Changelog documents diagnostics module, config type
change, and improved error messages."
```
