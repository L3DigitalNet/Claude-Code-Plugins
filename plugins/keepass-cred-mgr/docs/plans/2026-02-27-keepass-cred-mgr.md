# keepass-cred-mgr Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a Claude Code MCP plugin that exposes a KeePass `.kdbx` vault via 8 MCP tools, authenticated by YubiKey HMAC-SHA1 challenge-response, with slash commands, credential-handling skills, and full test coverage.

**Architecture:** Python FastMCP server (`@mcp.tool()` decorators) over stdio transport. All vault operations delegate to `keepassxc-cli` subprocess calls. YubiKey presence is polled via `ykman list` with a grace-period lock state machine. Write operations acquire a `FileLock` on the database. Audit logging via `structlog` to JSONL.

**Tech Stack:** Python 3.12+, `mcp` (FastMCP), `structlog`, `pyyaml`, `filelock`, `pytest`, `pytest-asyncio`

---

## Task 1: Create project skeleton and pyproject.toml

**Files:**
- Create: `plugins/keepass-cred-mgr/pyproject.toml`
- Create: `plugins/keepass-cred-mgr/server/__init__.py`
- Create: `plugins/keepass-cred-mgr/server/tools/__init__.py`
- Create: `plugins/keepass-cred-mgr/tests/__init__.py`
- Create: `plugins/keepass-cred-mgr/tests/unit/__init__.py`
- Create: `plugins/keepass-cred-mgr/tests/integration/__init__.py`
- Create: `plugins/keepass-cred-mgr/tests/fixtures/.gitkeep`
- Create: `plugins/keepass-cred-mgr/agents/.gitkeep`

**Step 1: Create the directory tree and pyproject.toml**

```toml
# plugins/keepass-cred-mgr/pyproject.toml
[build-system]
requires = ["setuptools>=68"]
build-backend = "setuptools.backends._legacy:_Backend"

[project]
name = "keepass-cred-mgr"
version = "1.0.0"
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
testpaths = ["tests"]
markers = [
    "unit: Unit tests (fast, no external dependencies)",
    "integration: Integration tests (require keepassxc-cli)",
]
```

**Step 2: Create all `__init__.py` and `.gitkeep` files**

All `__init__.py` files are empty. The `agents/.gitkeep` and `tests/fixtures/.gitkeep` are empty placeholder files.

**Step 3: Verify project skeleton**

Run: `cd plugins/keepass-cred-mgr && python3 -c "import server; import server.tools; print('OK')"`
Expected: `OK`

**Step 4: Install dev dependencies**

Run: `cd plugins/keepass-cred-mgr && pip install -e ".[dev]"`
Expected: Successful installation

**Step 5: Commit**

```bash
git add plugins/keepass-cred-mgr/
git commit -m "feat(keepass-cred-mgr): scaffold project skeleton and pyproject.toml"
```

---

## Task 2: Implement config module with TDD

**Files:**
- Create: `plugins/keepass-cred-mgr/server/config.py`
- Create: `plugins/keepass-cred-mgr/tests/unit/test_config.py`
- Create: `plugins/keepass-cred-mgr/config.example.yaml`

**Step 1: Write the failing tests**

```python
# tests/unit/test_config.py
import os
import pytest
import yaml
from pathlib import Path


@pytest.fixture
def valid_config(tmp_path):
    """Write a valid config YAML and set env var."""
    cfg = {
        "database_path": "/tmp/test.kdbx",
        "yubikey_slot": 2,
        "grace_period_seconds": 10,
        "yubikey_poll_interval_seconds": 5,
        "write_lock_timeout_seconds": 10,
        "page_size": 50,
        "allowed_groups": ["Servers", "SSH Keys", "API Keys"],
        "audit_log_path": str(tmp_path / "audit.jsonl"),
    }
    config_file = tmp_path / "config.yaml"
    config_file.write_text(yaml.dump(cfg))
    return str(config_file)


@pytest.fixture
def minimal_config(tmp_path):
    """Config with only required fields — defaults should fill the rest."""
    cfg = {
        "database_path": "/tmp/test.kdbx",
        "allowed_groups": ["Servers"],
        "audit_log_path": str(tmp_path / "audit.jsonl"),
    }
    config_file = tmp_path / "config.yaml"
    config_file.write_text(yaml.dump(cfg))
    return str(config_file)


class TestConfigLoading:
    def test_loads_valid_config(self, valid_config):
        from server.config import load_config

        config = load_config(valid_config)
        assert config.database_path == "/tmp/test.kdbx"
        assert config.yubikey_slot == 2
        assert config.allowed_groups == ["Servers", "SSH Keys", "API Keys"]

    def test_defaults_applied_for_optional_fields(self, minimal_config):
        from server.config import load_config

        config = load_config(minimal_config)
        assert config.yubikey_slot == 2
        assert config.grace_period_seconds == 10
        assert config.yubikey_poll_interval_seconds == 5
        assert config.write_lock_timeout_seconds == 10
        assert config.page_size == 50

    def test_expands_tilde_in_paths(self, tmp_path):
        cfg = {
            "database_path": "~/vault.kdbx",
            "allowed_groups": ["Servers"],
            "audit_log_path": "~/audit.jsonl",
        }
        config_file = tmp_path / "config.yaml"
        config_file.write_text(yaml.dump(cfg))
        from server.config import load_config

        config = load_config(str(config_file))
        assert "~" not in config.database_path
        assert "~" not in config.audit_log_path
        assert config.database_path == os.path.expanduser("~/vault.kdbx")

    def test_raises_on_missing_database_path(self, tmp_path):
        cfg = {
            "allowed_groups": ["Servers"],
            "audit_log_path": str(tmp_path / "audit.jsonl"),
        }
        config_file = tmp_path / "config.yaml"
        config_file.write_text(yaml.dump(cfg))
        from server.config import load_config

        with pytest.raises(ValueError, match="database_path"):
            load_config(str(config_file))

    def test_raises_on_missing_allowed_groups(self, tmp_path):
        cfg = {
            "database_path": "/tmp/test.kdbx",
            "audit_log_path": str(tmp_path / "audit.jsonl"),
        }
        config_file = tmp_path / "config.yaml"
        config_file.write_text(yaml.dump(cfg))
        from server.config import load_config

        with pytest.raises(ValueError, match="allowed_groups"):
            load_config(str(config_file))

    def test_raises_on_missing_audit_log_path(self, tmp_path):
        cfg = {
            "database_path": "/tmp/test.kdbx",
            "allowed_groups": ["Servers"],
        }
        config_file = tmp_path / "config.yaml"
        config_file.write_text(yaml.dump(cfg))
        from server.config import load_config

        with pytest.raises(ValueError, match="audit_log_path"):
            load_config(str(config_file))

    def test_loads_from_env_var(self, valid_config, monkeypatch):
        monkeypatch.setenv("KEEPASS_CRED_MGR_CONFIG", valid_config)
        from server.config import load_config

        config = load_config()
        assert config.database_path == "/tmp/test.kdbx"

    def test_raises_on_missing_config_file(self):
        from server.config import load_config

        with pytest.raises(FileNotFoundError):
            load_config("/nonexistent/path.yaml")
```

**Step 2: Run tests to verify they fail**

Run: `cd plugins/keepass-cred-mgr && python3 -m pytest tests/unit/test_config.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'server.config'`

**Step 3: Implement the config module**

```python
# server/config.py
"""Configuration loader for keepass-cred-mgr.

Reads YAML config from a file path or the KEEPASS_CRED_MGR_CONFIG env var.
Required fields: database_path, allowed_groups, audit_log_path.
Optional fields get defaults (see Config dataclass).
"""

from __future__ import annotations

import os
from dataclasses import dataclass, field
from pathlib import Path

import yaml


@dataclass(frozen=True)
class Config:
    database_path: str
    allowed_groups: list[str]
    audit_log_path: str
    yubikey_slot: int = 2
    grace_period_seconds: int = 10
    yubikey_poll_interval_seconds: int = 5
    write_lock_timeout_seconds: int = 10
    page_size: int = 50


_REQUIRED_FIELDS = ("database_path", "allowed_groups", "audit_log_path")


def load_config(path: str | None = None) -> Config:
    if path is None:
        path = os.environ.get("KEEPASS_CRED_MGR_CONFIG")
    if path is None:
        raise FileNotFoundError(
            "No config path provided and KEEPASS_CRED_MGR_CONFIG is not set"
        )

    config_path = Path(path)
    if not config_path.exists():
        raise FileNotFoundError(f"Config file not found: {config_path}")

    with open(config_path) as f:
        raw = yaml.safe_load(f) or {}

    for field_name in _REQUIRED_FIELDS:
        if field_name not in raw:
            raise ValueError(f"Missing required config field: {field_name}")

    # Expand ~ in path fields
    for key in ("database_path", "audit_log_path"):
        if key in raw and isinstance(raw[key], str):
            raw[key] = os.path.expanduser(raw[key])

    return Config(
        database_path=raw["database_path"],
        allowed_groups=raw["allowed_groups"],
        audit_log_path=raw["audit_log_path"],
        yubikey_slot=raw.get("yubikey_slot", 2),
        grace_period_seconds=raw.get("grace_period_seconds", 10),
        yubikey_poll_interval_seconds=raw.get("yubikey_poll_interval_seconds", 5),
        write_lock_timeout_seconds=raw.get("write_lock_timeout_seconds", 10),
        page_size=raw.get("page_size", 50),
    )
```

**Step 4: Run tests to verify they pass**

Run: `cd plugins/keepass-cred-mgr && python3 -m pytest tests/unit/test_config.py -v`
Expected: All 8 tests PASS

**Step 5: Create config.example.yaml**

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

**Step 6: Commit**

```bash
git add plugins/keepass-cred-mgr/server/config.py plugins/keepass-cred-mgr/tests/unit/test_config.py plugins/keepass-cred-mgr/config.example.yaml
git commit -m "feat(keepass-cred-mgr): add config module with YAML loading and validation"
```

---

## Task 3: Implement YubiKey interface with TDD

**Files:**
- Create: `plugins/keepass-cred-mgr/server/yubikey.py`
- Create: `plugins/keepass-cred-mgr/tests/unit/test_yubikey.py`

**Step 1: Write the failing tests**

```python
# tests/unit/test_yubikey.py
import subprocess
from unittest.mock import patch

import pytest


class TestMockYubiKey:
    def test_default_present(self):
        from server.yubikey import MockYubiKey

        yk = MockYubiKey()
        assert yk.is_present() is True

    def test_present_false(self):
        from server.yubikey import MockYubiKey

        yk = MockYubiKey(present=False)
        assert yk.is_present() is False

    def test_slot_returns_configured(self):
        from server.yubikey import MockYubiKey

        yk = MockYubiKey(slot=3)
        assert yk.slot() == 3

    def test_runtime_state_change(self):
        from server.yubikey import MockYubiKey

        yk = MockYubiKey(present=True)
        assert yk.is_present() is True
        yk.present = False
        assert yk.is_present() is False
        yk.present = True
        assert yk.is_present() is True


class TestRealYubiKey:
    @patch("subprocess.run")
    def test_present_when_ykman_returns_output(self, mock_run):
        mock_run.return_value = subprocess.CompletedProcess(
            args=["ykman", "list"],
            returncode=0,
            stdout="YubiKey 5C Nano (5.4.3) [OTP+FIDO+CCID] Serial: 12345678\n",
        )
        from server.yubikey import RealYubiKey

        yk = RealYubiKey(slot=2)
        assert yk.is_present() is True
        mock_run.assert_called_once_with(
            ["ykman", "list"], capture_output=True, text=True, timeout=5
        )

    @patch("subprocess.run")
    def test_not_present_when_ykman_returns_empty(self, mock_run):
        mock_run.return_value = subprocess.CompletedProcess(
            args=["ykman", "list"], returncode=0, stdout=""
        )
        from server.yubikey import RealYubiKey

        yk = RealYubiKey(slot=2)
        assert yk.is_present() is False

    @patch("subprocess.run")
    def test_not_present_on_subprocess_error(self, mock_run):
        mock_run.side_effect = subprocess.SubprocessError("ykman not found")
        from server.yubikey import RealYubiKey

        yk = RealYubiKey(slot=2)
        assert yk.is_present() is False

    @patch("subprocess.run")
    def test_not_present_on_timeout(self, mock_run):
        mock_run.side_effect = subprocess.TimeoutExpired(cmd="ykman", timeout=5)
        from server.yubikey import RealYubiKey

        yk = RealYubiKey(slot=2)
        assert yk.is_present() is False

    def test_slot_returns_configured(self):
        from server.yubikey import RealYubiKey

        yk = RealYubiKey(slot=2)
        assert yk.slot() == 2


class TestYubiKeyInterface:
    def test_mock_implements_interface(self):
        from server.yubikey import MockYubiKey, YubiKeyInterface

        yk = MockYubiKey()
        assert isinstance(yk, YubiKeyInterface)

    def test_real_implements_interface(self):
        from server.yubikey import RealYubiKey, YubiKeyInterface

        yk = RealYubiKey(slot=2)
        assert isinstance(yk, YubiKeyInterface)
```

**Step 2: Run tests to verify they fail**

Run: `cd plugins/keepass-cred-mgr && python3 -m pytest tests/unit/test_yubikey.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'server.yubikey'`

**Step 3: Implement the yubikey module**

```python
# server/yubikey.py
"""YubiKey presence detection interface.

Uses `ykman list` for polling — NOT keepassxc-cli (which requires touch every call).
Treat any subprocess error as "not present" to avoid blocking the polling loop.
"""

from __future__ import annotations

import subprocess
from abc import ABC, abstractmethod


class YubiKeyInterface(ABC):
    @abstractmethod
    def is_present(self) -> bool: ...

    @abstractmethod
    def slot(self) -> int: ...


class RealYubiKey(YubiKeyInterface):
    def __init__(self, slot: int = 2) -> None:
        self._slot = slot

    def is_present(self) -> bool:
        try:
            result = subprocess.run(
                ["ykman", "list"], capture_output=True, text=True, timeout=5
            )
            return bool(result.stdout.strip())
        except (subprocess.SubprocessError, subprocess.TimeoutExpired, OSError):
            return False

    def slot(self) -> int:
        return self._slot


class MockYubiKey(YubiKeyInterface):
    def __init__(self, present: bool = True, slot: int = 2) -> None:
        self.present = present
        self._slot = slot

    def is_present(self) -> bool:
        return self.present

    def slot(self) -> int:
        return self._slot
```

**Step 4: Run tests to verify they pass**

Run: `cd plugins/keepass-cred-mgr && python3 -m pytest tests/unit/test_yubikey.py -v`
Expected: All 10 tests PASS

**Step 5: Commit**

```bash
git add plugins/keepass-cred-mgr/server/yubikey.py plugins/keepass-cred-mgr/tests/unit/test_yubikey.py
git commit -m "feat(keepass-cred-mgr): add YubiKey interface with real and mock implementations"
```

---

## Task 4: Implement vault module with TDD

**Files:**
- Create: `plugins/keepass-cred-mgr/server/vault.py`
- Create: `plugins/keepass-cred-mgr/tests/unit/test_vault.py`
- Create: `plugins/keepass-cred-mgr/tests/conftest.py`

**Step 1: Write shared test fixtures (conftest.py)**

```python
# tests/conftest.py
import pytest
import yaml
from pathlib import Path

from server.config import Config, load_config
from server.yubikey import MockYubiKey


@pytest.fixture
def mock_yubikey():
    return MockYubiKey(present=True, slot=2)


@pytest.fixture
def test_config(tmp_path):
    db_path = tmp_path / "test.kdbx"
    db_path.touch()
    audit_path = tmp_path / "audit.jsonl"
    cfg = {
        "database_path": str(db_path),
        "yubikey_slot": 2,
        "grace_period_seconds": 2,
        "yubikey_poll_interval_seconds": 1,
        "write_lock_timeout_seconds": 2,
        "page_size": 50,
        "allowed_groups": ["Servers", "SSH Keys", "API Keys"],
        "audit_log_path": str(audit_path),
    }
    config_file = tmp_path / "config.yaml"
    config_file.write_text(yaml.dump(cfg))
    return load_config(str(config_file))
```

**Step 2: Write the failing vault tests**

```python
# tests/unit/test_vault.py
import asyncio
import subprocess
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from server.yubikey import MockYubiKey


class TestVaultExceptions:
    def test_all_exceptions_exist(self):
        from server.vault import (
            VaultLocked,
            YubiKeyNotPresent,
            EntryNotFound,
            GroupNotAllowed,
            DuplicateEntry,
            EntryInactive,
            WriteLockTimeout,
            KeePassCLIError,
        )
        # All should be subclasses of Exception
        for exc_cls in (
            VaultLocked, YubiKeyNotPresent, EntryNotFound,
            GroupNotAllowed, DuplicateEntry, EntryInactive,
            WriteLockTimeout, KeePassCLIError,
        ):
            assert issubclass(exc_cls, Exception)


class TestVaultState:
    def test_starts_locked(self, test_config, mock_yubikey):
        from server.vault import Vault

        vault = Vault(test_config, mock_yubikey)
        assert vault.is_unlocked is False

    def test_unlock_raises_when_yubikey_absent(self, test_config):
        from server.vault import Vault, YubiKeyNotPresent

        yk = MockYubiKey(present=False)
        vault = Vault(test_config, yk)
        with pytest.raises(YubiKeyNotPresent):
            vault.unlock()

    @patch("subprocess.run")
    def test_unlock_succeeds_with_yubikey(self, mock_run, test_config, mock_yubikey):
        mock_run.return_value = subprocess.CompletedProcess(
            args=[], returncode=0, stdout="", stderr=""
        )
        from server.vault import Vault

        vault = Vault(test_config, mock_yubikey)
        vault.unlock()
        assert vault.is_unlocked is True

    @patch("subprocess.run")
    def test_unlock_raises_on_cli_error(self, mock_run, test_config, mock_yubikey):
        mock_run.return_value = subprocess.CompletedProcess(
            args=[], returncode=1, stdout="", stderr="Error: Invalid credentials"
        )
        from server.vault import Vault, KeePassCLIError

        vault = Vault(test_config, mock_yubikey)
        with pytest.raises(KeePassCLIError):
            vault.unlock()

    @patch("subprocess.run")
    def test_run_cli_raises_when_locked(self, mock_run, test_config, mock_yubikey):
        from server.vault import Vault, VaultLocked

        vault = Vault(test_config, mock_yubikey)
        with pytest.raises(VaultLocked):
            vault.run_cli("ls", test_config.database_path)


class TestVaultGroupAllowlist:
    @patch("subprocess.run")
    def test_check_group_allowed(self, mock_run, test_config, mock_yubikey):
        mock_run.return_value = subprocess.CompletedProcess(
            args=[], returncode=0, stdout="", stderr=""
        )
        from server.vault import Vault

        vault = Vault(test_config, mock_yubikey)
        vault.unlock()
        vault.check_group_allowed("Servers")  # Should not raise

    @patch("subprocess.run")
    def test_check_group_not_allowed(self, mock_run, test_config, mock_yubikey):
        mock_run.return_value = subprocess.CompletedProcess(
            args=[], returncode=0, stdout="", stderr=""
        )
        from server.vault import Vault, GroupNotAllowed

        vault = Vault(test_config, mock_yubikey)
        vault.unlock()
        with pytest.raises(GroupNotAllowed):
            vault.check_group_allowed("Banking")


class TestVaultRunCli:
    @patch("subprocess.run")
    def test_run_cli_returns_stdout(self, mock_run, test_config, mock_yubikey):
        # First call: unlock
        # Second call: actual CLI command
        mock_run.side_effect = [
            subprocess.CompletedProcess(args=[], returncode=0, stdout="", stderr=""),
            subprocess.CompletedProcess(
                args=[], returncode=0, stdout="Group1/\nGroup2/\n", stderr=""
            ),
        ]
        from server.vault import Vault

        vault = Vault(test_config, mock_yubikey)
        vault.unlock()
        result = vault.run_cli("ls", test_config.database_path)
        assert "Group1/" in result

    @patch("subprocess.run")
    def test_run_cli_raises_on_error(self, mock_run, test_config, mock_yubikey):
        mock_run.side_effect = [
            subprocess.CompletedProcess(args=[], returncode=0, stdout="", stderr=""),
            subprocess.CompletedProcess(
                args=[], returncode=1, stdout="", stderr="Error: entry not found"
            ),
        ]
        from server.vault import Vault, KeePassCLIError

        vault = Vault(test_config, mock_yubikey)
        vault.unlock()
        with pytest.raises(KeePassCLIError):
            vault.run_cli("show", test_config.database_path, "Nonexistent")


class TestVaultEntryPath:
    def test_with_group(self, test_config, mock_yubikey):
        from server.vault import Vault

        vault = Vault(test_config, mock_yubikey)
        assert vault.entry_path("My Entry", "Servers") == "Servers/My Entry"

    def test_without_group(self, test_config, mock_yubikey):
        from server.vault import Vault

        vault = Vault(test_config, mock_yubikey)
        assert vault.entry_path("My Entry", None) == "My Entry"


class TestVaultGraceTimer:
    @pytest.mark.asyncio
    async def test_lock_after_grace_period(self, test_config):
        from server.vault import Vault

        yk = MockYubiKey(present=True)
        vault = Vault(test_config, yk)
        with patch("subprocess.run") as mock_run:
            mock_run.return_value = subprocess.CompletedProcess(
                args=[], returncode=0, stdout="", stderr=""
            )
            vault.unlock()

        assert vault.is_unlocked is True

        # Start polling, then remove YubiKey
        poll_task = asyncio.create_task(vault.start_polling())
        await asyncio.sleep(0.1)  # Let poll loop start
        yk.present = False
        # Grace period is 2s in test_config — wait for it plus buffer
        await asyncio.sleep(3)
        assert vault.is_unlocked is False
        poll_task.cancel()
        try:
            await poll_task
        except asyncio.CancelledError:
            pass

    @pytest.mark.asyncio
    async def test_reinsertion_cancels_grace(self, test_config):
        from server.vault import Vault

        yk = MockYubiKey(present=True)
        vault = Vault(test_config, yk)
        with patch("subprocess.run") as mock_run:
            mock_run.return_value = subprocess.CompletedProcess(
                args=[], returncode=0, stdout="", stderr=""
            )
            vault.unlock()

        poll_task = asyncio.create_task(vault.start_polling())
        await asyncio.sleep(0.1)
        yk.present = False
        await asyncio.sleep(0.5)  # Within grace period
        yk.present = True  # Reinsert before grace expires
        await asyncio.sleep(2)  # Wait past original grace period
        assert vault.is_unlocked is True  # Should still be unlocked
        poll_task.cancel()
        try:
            await poll_task
        except asyncio.CancelledError:
            pass
```

**Step 3: Run tests to verify they fail**

Run: `cd plugins/keepass-cred-mgr && python3 -m pytest tests/unit/test_vault.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'server.vault'`

**Step 4: Implement the vault module**

```python
# server/vault.py
"""Vault manager — mediates all keepassxc-cli interactions.

State machine: locked ←→ unlocked via YubiKey touch.
Background polling of ykman with grace period before auto-lock.
Group allowlist enforced on all operations.
"""

from __future__ import annotations

import asyncio
import logging
import subprocess
import sys
from datetime import datetime, timezone

from server.config import Config
from server.yubikey import YubiKeyInterface

# All logging to stderr — stdout is reserved for MCP stdio protocol
logger = logging.getLogger("keepass-cred-mgr.vault")
logger.addHandler(logging.StreamHandler(sys.stderr))

INACTIVE_PREFIX = "[INACTIVE] "


# --- Exceptions ---

class VaultLocked(Exception):
    """Vault is locked; unlock with YubiKey touch first."""


class YubiKeyNotPresent(Exception):
    """YubiKey not detected; insert key and retry."""


class EntryNotFound(Exception):
    """No entry matches the given title/path."""


class GroupNotAllowed(Exception):
    """The requested group is not in the configured allowlist."""


class DuplicateEntry(Exception):
    """An active entry with this title already exists in the group."""


class EntryInactive(Exception):
    """This entry is deactivated; create a new entry instead."""


class WriteLockTimeout(Exception):
    """Could not acquire the write lock within the timeout."""


class KeePassCLIError(Exception):
    """keepassxc-cli returned a non-zero exit code."""


# --- Vault ---

class Vault:
    def __init__(self, config: Config, yubikey: YubiKeyInterface) -> None:
        self._config = config
        self._yubikey = yubikey
        self._unlocked = False
        self._unlock_time: datetime | None = None
        self._grace_timer: asyncio.Task | None = None

    @property
    def is_unlocked(self) -> bool:
        return self._unlocked

    @property
    def unlock_time(self) -> datetime | None:
        return self._unlock_time

    @property
    def config(self) -> Config:
        return self._config

    def unlock(self) -> None:
        if not self._yubikey.is_present():
            raise YubiKeyNotPresent("Insert YubiKey and try again")

        result = subprocess.run(
            [
                "keepassxc-cli", "open",
                "--yubikey", str(self._yubikey.slot()),
                self._config.database_path,
            ],
            capture_output=True, text=True, timeout=30,
        )
        if result.returncode != 0:
            raise KeePassCLIError(
                f"keepassxc-cli open failed: {result.stderr.strip()}"
            )
        self._unlocked = True
        self._unlock_time = datetime.now(timezone.utc)
        logger.info("Vault unlocked")

    def _lock(self) -> None:
        self._unlocked = False
        logger.info("Vault locked (YubiKey removed)")

    def check_group_allowed(self, group: str) -> None:
        if group not in self._config.allowed_groups:
            raise GroupNotAllowed(
                f"Group '{group}' is not in allowed_groups: {self._config.allowed_groups}"
            )

    def entry_path(self, title: str, group: str | None) -> str:
        if group:
            return f"{group}/{title}"
        return title

    def run_cli(self, *args: str) -> str:
        if not self._unlocked:
            raise VaultLocked("Vault is locked; call unlock() first")

        cmd = [
            "keepassxc-cli",
            "--yubikey", str(self._yubikey.slot()),
            *args,
        ]
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        if result.returncode != 0:
            raise KeePassCLIError(
                f"keepassxc-cli {args[0]} failed: {result.stderr.strip()}"
            )
        return result.stdout

    async def start_polling(self) -> None:
        interval = self._config.yubikey_poll_interval_seconds
        while True:
            try:
                present = self._yubikey.is_present()

                if not present and self._unlocked and self._grace_timer is None:
                    logger.info("YubiKey removed — starting grace timer")
                    self._grace_timer = asyncio.create_task(self._grace_countdown())

                if present and self._grace_timer is not None:
                    logger.info("YubiKey reinserted — cancelling grace timer")
                    self._grace_timer.cancel()
                    try:
                        await self._grace_timer
                    except asyncio.CancelledError:
                        pass
                    self._grace_timer = None

                await asyncio.sleep(interval)
            except asyncio.CancelledError:
                if self._grace_timer:
                    self._grace_timer.cancel()
                raise

    async def _grace_countdown(self) -> None:
        await asyncio.sleep(self._config.grace_period_seconds)
        self._lock()
        self._grace_timer = None
```

**Step 5: Run tests to verify they pass**

Run: `cd plugins/keepass-cred-mgr && python3 -m pytest tests/unit/test_vault.py -v`
Expected: All tests PASS

**Step 6: Commit**

```bash
git add plugins/keepass-cred-mgr/server/vault.py plugins/keepass-cred-mgr/tests/unit/test_vault.py plugins/keepass-cred-mgr/tests/conftest.py
git commit -m "feat(keepass-cred-mgr): add vault module with CLI wrapper, state machine, and grace timer"
```

---

## Task 5: Implement audit logger

**Files:**
- Create: `plugins/keepass-cred-mgr/server/audit.py`
- Modify: `plugins/keepass-cred-mgr/tests/unit/test_vault.py` (add audit tests)

**Step 1: Write the failing audit tests**

Append to `tests/unit/test_vault.py` (or create a new `tests/unit/test_audit.py`):

```python
# tests/unit/test_audit.py
import json
from pathlib import Path

import pytest


class TestAuditLogger:
    def test_log_creates_file(self, test_config):
        from server.audit import AuditLogger

        logger = AuditLogger(test_config.audit_log_path)
        logger.log(tool="get_entry", title="Test", group="Servers")
        assert Path(test_config.audit_log_path).exists()

    def test_log_writes_jsonl(self, test_config):
        from server.audit import AuditLogger

        logger = AuditLogger(test_config.audit_log_path)
        logger.log(
            tool="get_entry",
            title="My Server",
            group="Servers",
            secret_returned=True,
        )
        lines = Path(test_config.audit_log_path).read_text().strip().split("\n")
        assert len(lines) == 1
        record = json.loads(lines[0])
        assert record["tool"] == "get_entry"
        assert record["title"] == "My Server"
        assert record["group"] == "Servers"
        assert record["secret_returned"] is True
        assert "timestamp" in record

    def test_log_defaults_secret_false(self, test_config):
        from server.audit import AuditLogger

        logger = AuditLogger(test_config.audit_log_path)
        logger.log(tool="list_entries", title="Test", group="Servers")
        record = json.loads(
            Path(test_config.audit_log_path).read_text().strip()
        )
        assert record["secret_returned"] is False

    def test_log_includes_attachment(self, test_config):
        from server.audit import AuditLogger

        logger = AuditLogger(test_config.audit_log_path)
        logger.log(
            tool="get_attachment",
            title="SSH Key",
            group="SSH Keys",
            secret_returned=True,
            attachment="id_ed25519",
        )
        record = json.loads(
            Path(test_config.audit_log_path).read_text().strip()
        )
        assert record["attachment"] == "id_ed25519"

    def test_log_appends_multiple_records(self, test_config):
        from server.audit import AuditLogger

        logger = AuditLogger(test_config.audit_log_path)
        logger.log(tool="get_entry", title="A", group="Servers")
        logger.log(tool="get_entry", title="B", group="Servers")
        lines = Path(test_config.audit_log_path).read_text().strip().split("\n")
        assert len(lines) == 2

    def test_raises_on_missing_parent_dir(self, tmp_path):
        from server.audit import AuditLogger

        bad_path = str(tmp_path / "nonexistent" / "subdir" / "audit.jsonl")
        with pytest.raises(FileNotFoundError):
            AuditLogger(bad_path)
```

**Step 2: Run tests to verify they fail**

Run: `cd plugins/keepass-cred-mgr && python3 -m pytest tests/unit/test_audit.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'server.audit'`

**Step 3: Implement the audit module**

```python
# server/audit.py
"""Structured audit logging for vault operations.

Writes one JSON record per line to the configured audit log path.
Secret values and attachment content are never logged.
"""

from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path

import structlog


class AuditLogger:
    def __init__(self, audit_log_path: str) -> None:
        path = Path(audit_log_path)
        if not path.parent.exists():
            raise FileNotFoundError(
                f"Audit log parent directory does not exist: {path.parent}"
            )
        self._path = path
        self._logger = structlog.get_logger("keepass-cred-mgr.audit")

    def log(
        self,
        *,
        tool: str,
        title: str,
        group: str | None = None,
        secret_returned: bool = False,
        attachment: str | None = None,
    ) -> None:
        record = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "tool": tool,
            "title": title,
            "group": group,
            "secret_returned": secret_returned,
            "attachment": attachment,
        }
        import json

        with open(self._path, "a") as f:
            f.write(json.dumps(record) + "\n")
```

**Step 4: Run tests to verify they pass**

Run: `cd plugins/keepass-cred-mgr && python3 -m pytest tests/unit/test_audit.py -v`
Expected: All 6 tests PASS

**Step 5: Commit**

```bash
git add plugins/keepass-cred-mgr/server/audit.py plugins/keepass-cred-mgr/tests/unit/test_audit.py
git commit -m "feat(keepass-cred-mgr): add structured JSONL audit logger"
```

---

## Task 6: Implement read tools with TDD

**Files:**
- Create: `plugins/keepass-cred-mgr/server/tools/read.py`
- Create: `plugins/keepass-cred-mgr/tests/unit/test_tools.py`

**Step 1: Write the failing read tool tests**

```python
# tests/unit/test_tools.py
import subprocess
from unittest.mock import patch, MagicMock

import pytest
import yaml

from server.config import load_config
from server.yubikey import MockYubiKey


@pytest.fixture
def unlocked_vault(test_config, mock_yubikey):
    """A vault that's been unlocked (CLI calls are mocked)."""
    from server.vault import Vault
    from server.audit import AuditLogger

    with patch("subprocess.run") as mock_run:
        mock_run.return_value = subprocess.CompletedProcess(
            args=[], returncode=0, stdout="", stderr=""
        )
        vault = Vault(test_config, mock_yubikey)
        vault.unlock()
    audit = AuditLogger(test_config.audit_log_path)
    return vault, audit


class TestReadTools:
    @patch("subprocess.run")
    def test_list_groups(self, mock_run, unlocked_vault):
        from server.tools.read import list_groups

        vault, audit = unlocked_vault
        mock_run.return_value = subprocess.CompletedProcess(
            args=[], returncode=0,
            stdout="Servers/\nSSH Keys/\nAPI Keys/\nBanking/\nRecycle Bin/\n",
            stderr="",
        )
        result = list_groups(vault)
        # Banking and Recycle Bin should be filtered out
        assert set(result) == {"Servers", "SSH Keys", "API Keys"}

    @patch("subprocess.run")
    def test_list_entries_filters_inactive(self, mock_run, unlocked_vault):
        from server.tools.read import list_entries

        vault, audit = unlocked_vault
        # First call: ls to get titles
        # Subsequent calls: show per entry for metadata
        mock_run.side_effect = [
            subprocess.CompletedProcess(
                args=[], returncode=0,
                stdout="Web Server\n[INACTIVE] Old Server\nDB Server\n",
                stderr="",
            ),
            subprocess.CompletedProcess(
                args=[], returncode=0,
                stdout="Title: Web Server\nUserName: admin\nURL: https://web.example.com\n",
                stderr="",
            ),
            subprocess.CompletedProcess(
                args=[], returncode=0,
                stdout="Title: DB Server\nUserName: dba\nURL: https://db.example.com\n",
                stderr="",
            ),
        ]
        result = list_entries(vault, audit, group="Servers")
        assert len(result) == 2
        titles = [e["title"] for e in result]
        assert "Web Server" in titles
        assert "[INACTIVE] Old Server" not in titles

    @patch("subprocess.run")
    def test_list_entries_includes_inactive(self, mock_run, unlocked_vault):
        from server.tools.read import list_entries

        vault, audit = unlocked_vault
        mock_run.side_effect = [
            subprocess.CompletedProcess(
                args=[], returncode=0,
                stdout="Web Server\n[INACTIVE] Old Server\n",
                stderr="",
            ),
            subprocess.CompletedProcess(
                args=[], returncode=0,
                stdout="Title: Web Server\nUserName: admin\nURL: https://web.example.com\n",
                stderr="",
            ),
            subprocess.CompletedProcess(
                args=[], returncode=0,
                stdout="Title: [INACTIVE] Old Server\nUserName: old\nURL: https://old.example.com\n",
                stderr="",
            ),
        ]
        result = list_entries(vault, audit, group="Servers", include_inactive=True)
        assert len(result) == 2

    @patch("subprocess.run")
    def test_get_entry_returns_full_record(self, mock_run, unlocked_vault):
        from server.tools.read import get_entry

        vault, audit = unlocked_vault
        mock_run.return_value = subprocess.CompletedProcess(
            args=[], returncode=0,
            stdout=(
                "Title: Web Server\n"
                "UserName: admin\n"
                "Password: s3cret\n"
                "URL: https://web.example.com\n"
                "Notes: Production server\n"
            ),
            stderr="",
        )
        result = get_entry(vault, audit, title="Web Server", group="Servers")
        assert result["title"] == "Web Server"
        assert result["username"] == "admin"
        assert result["password"] == "s3cret"
        assert result["url"] == "https://web.example.com"
        assert result["notes"] == "Production server"

    @patch("subprocess.run")
    def test_get_entry_raises_on_inactive(self, mock_run, unlocked_vault):
        from server.tools.read import get_entry
        from server.vault import EntryInactive

        vault, audit = unlocked_vault
        with pytest.raises(EntryInactive):
            get_entry(
                vault, audit,
                title="[INACTIVE] Old Server",
                group="Servers",
            )

    @patch("subprocess.run")
    def test_get_entry_audits_secret(self, mock_run, unlocked_vault, test_config):
        import json
        from pathlib import Path
        from server.tools.read import get_entry

        vault, audit = unlocked_vault
        mock_run.return_value = subprocess.CompletedProcess(
            args=[], returncode=0,
            stdout="Title: Web Server\nUserName: admin\nPassword: s3cret\nURL: \nNotes: \n",
            stderr="",
        )
        get_entry(vault, audit, title="Web Server", group="Servers")
        log_line = Path(test_config.audit_log_path).read_text().strip()
        record = json.loads(log_line)
        assert record["tool"] == "get_entry"
        assert record["secret_returned"] is True

    @patch("subprocess.run")
    def test_search_entries(self, mock_run, unlocked_vault):
        from server.tools.read import search_entries

        vault, audit = unlocked_vault
        mock_run.side_effect = [
            # search returns paths
            subprocess.CompletedProcess(
                args=[], returncode=0,
                stdout="Servers/Web Server\nBanking/My Bank\nAPI Keys/Anthropic\n",
                stderr="",
            ),
            # show for allowed entry 1
            subprocess.CompletedProcess(
                args=[], returncode=0,
                stdout="Title: Web Server\nUserName: admin\nURL: https://web.example.com\n",
                stderr="",
            ),
            # show for allowed entry 2
            subprocess.CompletedProcess(
                args=[], returncode=0,
                stdout="Title: Anthropic\nUserName: key\nURL: https://api.anthropic.com\n",
                stderr="",
            ),
        ]
        result = search_entries(vault, audit, query="server")
        # Banking/My Bank should be filtered out (not in allowed_groups)
        assert len(result) == 2
        groups = [e["group"] for e in result]
        assert "Banking" not in groups

    @patch("subprocess.run")
    def test_get_attachment(self, mock_run, unlocked_vault, test_config):
        import json
        from pathlib import Path
        from server.tools.read import get_attachment

        vault, audit = unlocked_vault
        mock_run.return_value = subprocess.CompletedProcess(
            args=[], returncode=0,
            stdout="ssh-ed25519 AAAA... user@host\n",
            stderr="",
        )
        result = get_attachment(
            vault, audit,
            title="SSH Key", attachment_name="id_ed25519.pub", group="SSH Keys",
        )
        assert b"ssh-ed25519" in result

        # Verify audit log
        log_line = Path(test_config.audit_log_path).read_text().strip().split("\n")[-1]
        record = json.loads(log_line)
        assert record["tool"] == "get_attachment"
        assert record["secret_returned"] is True
        assert record["attachment"] == "id_ed25519.pub"

    @patch("subprocess.run")
    def test_get_attachment_raises_on_inactive(self, mock_run, unlocked_vault):
        from server.tools.read import get_attachment
        from server.vault import EntryInactive

        vault, audit = unlocked_vault
        with pytest.raises(EntryInactive):
            get_attachment(
                vault, audit,
                title="[INACTIVE] Old Key",
                attachment_name="id_rsa",
                group="SSH Keys",
            )

    @patch("subprocess.run")
    def test_list_entries_group_not_allowed(self, mock_run, unlocked_vault):
        from server.tools.read import list_entries
        from server.vault import GroupNotAllowed

        vault, audit = unlocked_vault
        with pytest.raises(GroupNotAllowed):
            list_entries(vault, audit, group="Banking")
```

**Step 2: Run tests to verify they fail**

Run: `cd plugins/keepass-cred-mgr && python3 -m pytest tests/unit/test_tools.py::TestReadTools -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'server.tools.read'`

**Step 3: Implement the read tools module**

```python
# server/tools/read.py
"""Read-only vault tools.

All functions take a Vault and AuditLogger, call vault.run_cli internally.
No file lock required for reads.
"""

from __future__ import annotations

import logging
import sys

from server.audit import AuditLogger
from server.vault import (
    INACTIVE_PREFIX,
    EntryInactive,
    GroupNotAllowed,
    Vault,
)

logger = logging.getLogger("keepass-cred-mgr.tools.read")
logger.addHandler(logging.StreamHandler(sys.stderr))


def _parse_show_output(stdout: str) -> dict[str, str]:
    """Parse keepassxc-cli show output into a dict."""
    fields = {}
    for line in stdout.strip().splitlines():
        if ": " in line:
            key, _, value = line.partition(": ")
            key_lower = key.strip().lower()
            if key_lower == "username":
                fields["username"] = value.strip()
            elif key_lower == "password":
                fields["password"] = value.strip()
            elif key_lower == "url":
                fields["url"] = value.strip()
            elif key_lower == "notes":
                fields["notes"] = value.strip()
            elif key_lower == "title":
                fields["title"] = value.strip()
    return fields


def list_groups(vault: Vault) -> list[str]:
    db = vault.config.database_path
    stdout = vault.run_cli("ls", db)
    all_groups = [
        line.rstrip("/")
        for line in stdout.strip().splitlines()
        if line.endswith("/")
    ]
    return [g for g in all_groups if g in vault.config.allowed_groups]


def list_entries(
    vault: Vault,
    audit: AuditLogger,
    *,
    group: str | None = None,
    include_inactive: bool = False,
) -> list[dict]:
    if group is not None:
        vault.check_group_allowed(group)
        groups = [group]
    else:
        groups = list(vault.config.allowed_groups)

    results = []
    for grp in groups:
        db = vault.config.database_path
        stdout = vault.run_cli("ls", db, grp)
        titles = [
            line.strip()
            for line in stdout.strip().splitlines()
            if line.strip() and not line.strip().endswith("/")
        ]

        for title in titles:
            if not include_inactive and title.startswith(INACTIVE_PREFIX):
                continue
            if len(results) >= vault.config.page_size:
                logger.warning("Results truncated at page_size=%d", vault.config.page_size)
                return results

            path = vault.entry_path(title, grp)
            show_out = vault.run_cli("show", db, path)
            fields = _parse_show_output(show_out)
            results.append({
                "title": title,
                "group": grp,
                "username": fields.get("username", ""),
                "url": fields.get("url", ""),
            })

    return results


def search_entries(
    vault: Vault,
    audit: AuditLogger,
    *,
    query: str,
    group: str | None = None,
    include_inactive: bool = False,
) -> list[dict]:
    if group is not None:
        vault.check_group_allowed(group)

    db = vault.config.database_path
    stdout = vault.run_cli("search", db, query)
    paths = [line.strip() for line in stdout.strip().splitlines() if line.strip()]

    results = []
    for entry_path in paths:
        if "/" in entry_path:
            grp, _, title = entry_path.partition("/")
        else:
            grp, title = None, entry_path

        # Filter to allowed groups
        if grp and grp not in vault.config.allowed_groups:
            continue
        if group and grp != group:
            continue
        if not include_inactive and title.startswith(INACTIVE_PREFIX):
            continue
        if len(results) >= vault.config.page_size:
            logger.warning("Search results truncated at page_size=%d", vault.config.page_size)
            return results

        show_out = vault.run_cli("show", db, entry_path)
        fields = _parse_show_output(show_out)
        results.append({
            "title": title,
            "group": grp,
            "username": fields.get("username", ""),
            "url": fields.get("url", ""),
        })

    return results


def get_entry(
    vault: Vault,
    audit: AuditLogger,
    *,
    title: str,
    group: str | None = None,
) -> dict:
    if title.startswith(INACTIVE_PREFIX):
        raise EntryInactive(f"Entry '{title}' is deactivated")

    if group is not None:
        vault.check_group_allowed(group)

    db = vault.config.database_path
    path = vault.entry_path(title, group)
    stdout = vault.run_cli("show", "--show-protected", db, path)
    fields = _parse_show_output(stdout)

    audit.log(
        tool="get_entry",
        title=title,
        group=group,
        secret_returned=True,
    )

    return {
        "title": fields.get("title", title),
        "username": fields.get("username", ""),
        "password": fields.get("password", ""),
        "url": fields.get("url", ""),
        "notes": fields.get("notes", ""),
    }


def get_attachment(
    vault: Vault,
    audit: AuditLogger,
    *,
    title: str,
    attachment_name: str,
    group: str | None = None,
) -> bytes:
    if title.startswith(INACTIVE_PREFIX):
        raise EntryInactive(f"Entry '{title}' is deactivated")

    if group is not None:
        vault.check_group_allowed(group)

    db = vault.config.database_path
    path = vault.entry_path(title, group)
    stdout = vault.run_cli(
        "attachment-export", "--stdout", db, path, attachment_name
    )

    audit.log(
        tool="get_attachment",
        title=title,
        group=group,
        secret_returned=True,
        attachment=attachment_name,
    )

    return stdout.encode("utf-8")
```

**Step 4: Run tests to verify they pass**

Run: `cd plugins/keepass-cred-mgr && python3 -m pytest tests/unit/test_tools.py::TestReadTools -v`
Expected: All 10 tests PASS

**Step 5: Commit**

```bash
git add plugins/keepass-cred-mgr/server/tools/read.py plugins/keepass-cred-mgr/tests/unit/test_tools.py
git commit -m "feat(keepass-cred-mgr): add read tools (list_groups, list_entries, search, get_entry, get_attachment)"
```

---

## Task 7: Implement write tools with TDD

**Files:**
- Create: `plugins/keepass-cred-mgr/server/tools/write.py`
- Modify: `plugins/keepass-cred-mgr/tests/unit/test_tools.py` (add TestWriteTools)

**Step 1: Write the failing write tool tests**

Append to `tests/unit/test_tools.py`:

```python
class TestWriteTools:
    @patch("subprocess.run")
    def test_create_entry(self, mock_run, unlocked_vault, test_config):
        from server.tools.write import create_entry

        vault, audit = unlocked_vault
        # ls to check for duplicates, then add
        mock_run.side_effect = [
            subprocess.CompletedProcess(
                args=[], returncode=0, stdout="Existing Entry\n", stderr=""
            ),
            subprocess.CompletedProcess(
                args=[], returncode=0, stdout="", stderr=""
            ),
        ]
        create_entry(
            vault, audit,
            title="New Server",
            group="Servers",
            username="admin",
            password="pass123",
            url="https://new.example.com",
            notes="Test notes",
        )
        # Verify the add command was called
        add_call = mock_run.call_args_list[-1]
        assert "add" in add_call.args[0] or "add" in str(add_call)

    @patch("subprocess.run")
    def test_create_entry_rejects_duplicate(self, mock_run, unlocked_vault):
        from server.tools.write import create_entry
        from server.vault import DuplicateEntry

        vault, audit = unlocked_vault
        mock_run.return_value = subprocess.CompletedProcess(
            args=[], returncode=0, stdout="Existing Entry\n", stderr=""
        )
        with pytest.raises(DuplicateEntry):
            create_entry(
                vault, audit,
                title="Existing Entry",
                group="Servers",
            )

    @patch("subprocess.run")
    def test_create_entry_rejects_slash_in_title(self, mock_run, unlocked_vault):
        from server.tools.write import create_entry

        vault, audit = unlocked_vault
        with pytest.raises(ValueError, match="slash"):
            create_entry(
                vault, audit,
                title="Bad/Title",
                group="Servers",
            )

    @patch("subprocess.run")
    def test_create_entry_group_not_allowed(self, mock_run, unlocked_vault):
        from server.tools.write import create_entry
        from server.vault import GroupNotAllowed

        vault, audit = unlocked_vault
        with pytest.raises(GroupNotAllowed):
            create_entry(
                vault, audit,
                title="New Entry",
                group="Banking",
            )

    @patch("subprocess.run")
    def test_deactivate_entry(self, mock_run, unlocked_vault):
        from server.tools.write import deactivate_entry

        vault, audit = unlocked_vault
        mock_run.side_effect = [
            # show to read existing notes
            subprocess.CompletedProcess(
                args=[], returncode=0,
                stdout="Title: Web Server\nNotes: Production server\n",
                stderr="",
            ),
            # edit --title to rename
            subprocess.CompletedProcess(
                args=[], returncode=0, stdout="", stderr=""
            ),
            # edit --notes to append deactivation timestamp
            subprocess.CompletedProcess(
                args=[], returncode=0, stdout="", stderr=""
            ),
        ]
        deactivate_entry(vault, audit, title="Web Server", group="Servers")

        # Check that the title edit used [INACTIVE] prefix
        title_edit_call = mock_run.call_args_list[1]
        cmd = title_edit_call.args[0] if title_edit_call.args else title_edit_call[0][0]
        cmd_str = " ".join(cmd) if isinstance(cmd, list) else str(cmd)
        assert "[INACTIVE]" in cmd_str

    @patch("subprocess.run")
    def test_deactivate_already_inactive(self, mock_run, unlocked_vault):
        from server.tools.write import deactivate_entry
        from server.vault import EntryInactive

        vault, audit = unlocked_vault
        with pytest.raises(EntryInactive):
            deactivate_entry(
                vault, audit,
                title="[INACTIVE] Old Server",
                group="Servers",
            )

    @patch("subprocess.run")
    def test_add_attachment(self, mock_run, unlocked_vault):
        from server.tools.write import add_attachment

        vault, audit = unlocked_vault
        mock_run.return_value = subprocess.CompletedProcess(
            args=[], returncode=0, stdout="", stderr=""
        )
        add_attachment(
            vault, audit,
            title="SSH Key",
            attachment_name="id_ed25519",
            content=b"ssh-ed25519 AAAA...",
            group="SSH Keys",
        )

    @patch("subprocess.run")
    def test_add_attachment_cleans_temp_file(self, mock_run, unlocked_vault):
        import os
        from server.tools.write import add_attachment

        vault, audit = unlocked_vault
        mock_run.return_value = subprocess.CompletedProcess(
            args=[], returncode=0, stdout="", stderr=""
        )
        # We need to verify no temp file remains; patch tempfile to track
        from unittest.mock import ANY
        import tempfile
        original_ntf = tempfile.NamedTemporaryFile

        created_paths = []

        def tracking_ntf(**kwargs):
            f = original_ntf(**kwargs)
            created_paths.append(f.name)
            return f

        with patch("tempfile.NamedTemporaryFile", side_effect=tracking_ntf):
            add_attachment(
                vault, audit,
                title="SSH Key",
                attachment_name="id_ed25519",
                content=b"ssh-ed25519 AAAA...",
                group="SSH Keys",
            )

        for path in created_paths:
            assert not os.path.exists(path), f"Temp file not cleaned up: {path}"

    @patch("subprocess.run")
    def test_add_attachment_inactive_rejected(self, mock_run, unlocked_vault):
        from server.tools.write import add_attachment
        from server.vault import EntryInactive

        vault, audit = unlocked_vault
        with pytest.raises(EntryInactive):
            add_attachment(
                vault, audit,
                title="[INACTIVE] Old Key",
                attachment_name="id_rsa",
                content=b"key data",
                group="SSH Keys",
            )
```

**Step 2: Run tests to verify they fail**

Run: `cd plugins/keepass-cred-mgr && python3 -m pytest tests/unit/test_tools.py::TestWriteTools -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'server.tools.write'`

**Step 3: Implement the write tools module**

```python
# server/tools/write.py
"""Write vault tools.

All write operations acquire a FileLock on the database before executing.
Temp files for attachment import are overwritten with zeros then unlinked.
"""

from __future__ import annotations

import logging
import os
import stat
import sys
import tempfile
from datetime import datetime, timezone

from filelock import FileLock, Timeout

from server.audit import AuditLogger
from server.vault import (
    INACTIVE_PREFIX,
    DuplicateEntry,
    EntryInactive,
    GroupNotAllowed,
    Vault,
    WriteLockTimeout,
)

logger = logging.getLogger("keepass-cred-mgr.tools.write")
logger.addHandler(logging.StreamHandler(sys.stderr))


def _acquire_lock(vault: Vault) -> FileLock:
    lock_path = vault.config.database_path + ".lock"
    lock = FileLock(lock_path, timeout=vault.config.write_lock_timeout_seconds)
    try:
        lock.acquire()
    except Timeout:
        raise WriteLockTimeout(
            f"Could not acquire write lock within {vault.config.write_lock_timeout_seconds}s"
        )
    return lock


def _shred_file(path: str) -> None:
    """Overwrite file with zeros, then unlink."""
    try:
        size = os.path.getsize(path)
        with open(path, "r+b") as f:
            f.write(b"\x00" * size)
            f.flush()
            os.fsync(f.fileno())
    except OSError:
        pass
    finally:
        try:
            os.unlink(path)
        except OSError:
            pass


def create_entry(
    vault: Vault,
    audit: AuditLogger,
    *,
    title: str,
    group: str,
    username: str | None = None,
    password: str | None = None,
    url: str | None = None,
    notes: str | None = None,
) -> None:
    if "/" in title:
        raise ValueError("Entry titles cannot contain a slash (/)")

    vault.check_group_allowed(group)

    # Check for duplicate active entry
    db = vault.config.database_path
    stdout = vault.run_cli("ls", db, group)
    existing = [
        line.strip()
        for line in stdout.strip().splitlines()
        if line.strip() and not line.strip().endswith("/")
    ]
    active_titles = [t for t in existing if not t.startswith(INACTIVE_PREFIX)]
    if title in active_titles:
        raise DuplicateEntry(f"Active entry '{title}' already exists in {group}")

    lock = _acquire_lock(vault)
    try:
        path = vault.entry_path(title, group)
        cmd = ["add", db, path]
        if username:
            cmd.extend(["--username", username])
        if password:
            cmd.extend(["--password", password])
        if url:
            cmd.extend(["--url", url])
        if notes:
            cmd.extend(["--notes", notes])
        vault.run_cli(*cmd)
    finally:
        lock.release()

    audit.log(tool="create_entry", title=title, group=group)


def deactivate_entry(
    vault: Vault,
    audit: AuditLogger,
    *,
    title: str,
    group: str | None = None,
) -> None:
    if title.startswith(INACTIVE_PREFIX):
        raise EntryInactive(f"Entry '{title}' is already deactivated")

    if group is not None:
        vault.check_group_allowed(group)

    db = vault.config.database_path
    path = vault.entry_path(title, group)

    # Read existing notes
    show_out = vault.run_cli("show", db, path)
    existing_notes = ""
    for line in show_out.strip().splitlines():
        if line.startswith("Notes: "):
            existing_notes = line[len("Notes: "):]
            break

    timestamp = datetime.now(timezone.utc).isoformat()
    new_notes = f"{existing_notes}\n[DEACTIVATED: {timestamp}]".strip()
    new_title = f"{INACTIVE_PREFIX}{title}"

    lock = _acquire_lock(vault)
    try:
        # Rename — path changes after this
        vault.run_cli("edit", "--title", new_title, db, path)
        # Update notes using new path
        new_path = vault.entry_path(new_title, group)
        vault.run_cli("edit", "--notes", new_notes, db, new_path)
    finally:
        lock.release()

    audit.log(tool="deactivate_entry", title=title, group=group)


def add_attachment(
    vault: Vault,
    audit: AuditLogger,
    *,
    title: str,
    attachment_name: str,
    content: bytes | str,
    group: str | None = None,
) -> None:
    if title.startswith(INACTIVE_PREFIX):
        raise EntryInactive(f"Entry '{title}' is deactivated")

    if group is not None:
        vault.check_group_allowed(group)

    db = vault.config.database_path
    path = vault.entry_path(title, group)

    if isinstance(content, str):
        content = content.encode("utf-8")

    tmp = tempfile.NamedTemporaryFile(delete=False, prefix="keepass-cred-mgr-")
    tmp_path = tmp.name
    try:
        tmp.write(content)
        tmp.close()
        os.chmod(tmp_path, stat.S_IRUSR | stat.S_IWUSR)  # 600

        lock = _acquire_lock(vault)
        try:
            vault.run_cli("attachment-import", db, path, attachment_name, tmp_path)
        finally:
            lock.release()
    finally:
        _shred_file(tmp_path)

    audit.log(
        tool="add_attachment",
        title=title,
        group=group,
        attachment=attachment_name,
    )
```

**Step 4: Run tests to verify they pass**

Run: `cd plugins/keepass-cred-mgr && python3 -m pytest tests/unit/test_tools.py::TestWriteTools -v`
Expected: All 9 tests PASS

**Step 5: Run the full test suite**

Run: `cd plugins/keepass-cred-mgr && python3 -m pytest tests/unit/ -v`
Expected: All tests across all unit test files PASS

**Step 6: Commit**

```bash
git add plugins/keepass-cred-mgr/server/tools/write.py plugins/keepass-cred-mgr/tests/unit/test_tools.py
git commit -m "feat(keepass-cred-mgr): add write tools (create_entry, deactivate_entry, add_attachment)"
```

---

## Task 8: Implement MCP server entry point

**Files:**
- Create: `plugins/keepass-cred-mgr/server/main.py`

**Step 1: Implement the FastMCP server**

```python
# server/main.py
"""keepass-cred-mgr — MCP server entry point.

Wires config, YubiKey, vault, audit, and all 8 tools into a FastMCP server.
Runs over stdio transport. All logging goes to stderr.
"""

from __future__ import annotations

import asyncio
import logging
import sys
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from dataclasses import dataclass

from mcp.server.fastmcp import Context, FastMCP
from mcp.server.session import ServerSession

from server.audit import AuditLogger
from server.config import load_config
from server.tools import read as read_tools
from server.tools import write as write_tools
from server.vault import (
    DuplicateEntry,
    EntryInactive,
    EntryNotFound,
    GroupNotAllowed,
    KeePassCLIError,
    Vault,
    VaultLocked,
    WriteLockTimeout,
    YubiKeyNotPresent,
)
from server.yubikey import RealYubiKey

# All logging to stderr — stdout is MCP stdio protocol
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    stream=sys.stderr,
)
logger = logging.getLogger("keepass-cred-mgr")


@dataclass
class AppContext:
    vault: Vault
    audit: AuditLogger
    poll_task: asyncio.Task


@asynccontextmanager
async def app_lifespan(server: FastMCP) -> AsyncIterator[AppContext]:
    config = load_config()
    yubikey = RealYubiKey(slot=config.yubikey_slot)
    vault = Vault(config, yubikey)
    audit = AuditLogger(config.audit_log_path)

    poll_task = asyncio.create_task(vault.start_polling())
    try:
        yield AppContext(vault=vault, audit=audit, poll_task=poll_task)
    finally:
        poll_task.cancel()
        try:
            await poll_task
        except asyncio.CancelledError:
            pass


mcp = FastMCP("keepass", lifespan=app_lifespan)


def _get_ctx(ctx: Context) -> AppContext:
    return ctx.request_context.lifespan_context


def _error_text(e: Exception) -> str:
    return f"{type(e).__name__}: {e}"


# --- Read Tools ---


@mcp.tool()
def list_groups(ctx: Context) -> list[str]:
    """List accessible KeePass groups (filtered by allowlist)."""
    app = _get_ctx(ctx)
    try:
        return read_tools.list_groups(app.vault)
    except (VaultLocked, YubiKeyNotPresent, KeePassCLIError) as e:
        raise ValueError(_error_text(e))


@mcp.tool()
def list_entries(
    ctx: Context,
    group: str | None = None,
    include_inactive: bool = False,
) -> list[dict]:
    """List entries in a group. Hides [INACTIVE] entries by default."""
    app = _get_ctx(ctx)
    try:
        return read_tools.list_entries(
            app.vault, app.audit, group=group, include_inactive=include_inactive
        )
    except (VaultLocked, GroupNotAllowed, KeePassCLIError) as e:
        raise ValueError(_error_text(e))


@mcp.tool()
def search_entries(
    ctx: Context,
    query: str,
    group: str | None = None,
    include_inactive: bool = False,
) -> list[dict]:
    """Search entries by keyword. Filters to allowed groups only."""
    app = _get_ctx(ctx)
    try:
        return read_tools.search_entries(
            app.vault, app.audit,
            query=query, group=group, include_inactive=include_inactive,
        )
    except (VaultLocked, GroupNotAllowed, KeePassCLIError) as e:
        raise ValueError(_error_text(e))


@mcp.tool()
def get_entry(ctx: Context, title: str, group: str | None = None) -> dict:
    """Get full entry details including password. Logs to audit trail."""
    app = _get_ctx(ctx)
    try:
        return read_tools.get_entry(app.vault, app.audit, title=title, group=group)
    except (VaultLocked, EntryInactive, GroupNotAllowed, KeePassCLIError) as e:
        raise ValueError(_error_text(e))


@mcp.tool()
def get_attachment(
    ctx: Context, title: str, attachment_name: str, group: str | None = None
) -> str:
    """Export an attachment from an entry. Returns base64-encoded content."""
    app = _get_ctx(ctx)
    try:
        data = read_tools.get_attachment(
            app.vault, app.audit,
            title=title, attachment_name=attachment_name, group=group,
        )
        import base64
        return base64.b64encode(data).decode("ascii")
    except (VaultLocked, EntryInactive, GroupNotAllowed, KeePassCLIError) as e:
        raise ValueError(_error_text(e))


# --- Write Tools ---


@mcp.tool()
def create_entry(
    ctx: Context,
    title: str,
    group: str,
    username: str | None = None,
    password: str | None = None,
    url: str | None = None,
    notes: str | None = None,
) -> str:
    """Create a new entry in the vault. Rejects duplicates and titles with slashes."""
    app = _get_ctx(ctx)
    try:
        write_tools.create_entry(
            app.vault, app.audit,
            title=title, group=group,
            username=username, password=password, url=url, notes=notes,
        )
        return f"Created entry '{title}' in {group}"
    except (
        VaultLocked, GroupNotAllowed, DuplicateEntry,
        WriteLockTimeout, KeePassCLIError, ValueError,
    ) as e:
        raise ValueError(_error_text(e))


@mcp.tool()
def deactivate_entry(
    ctx: Context, title: str, group: str | None = None
) -> str:
    """Deactivate an entry by adding [INACTIVE] prefix and deactivation timestamp."""
    app = _get_ctx(ctx)
    try:
        write_tools.deactivate_entry(
            app.vault, app.audit, title=title, group=group,
        )
        return f"Deactivated entry '{title}'"
    except (
        VaultLocked, EntryInactive, GroupNotAllowed,
        WriteLockTimeout, KeePassCLIError,
    ) as e:
        raise ValueError(_error_text(e))


@mcp.tool()
def add_attachment(
    ctx: Context,
    title: str,
    attachment_name: str,
    content: str,
    group: str | None = None,
) -> str:
    """Attach a file to an entry. Content is base64-encoded. Temp files are shredded."""
    app = _get_ctx(ctx)
    try:
        import base64
        decoded = base64.b64decode(content)
        write_tools.add_attachment(
            app.vault, app.audit,
            title=title, attachment_name=attachment_name,
            content=decoded, group=group,
        )
        return f"Attached '{attachment_name}' to '{title}'"
    except (
        VaultLocked, EntryInactive, GroupNotAllowed,
        WriteLockTimeout, KeePassCLIError,
    ) as e:
        raise ValueError(_error_text(e))


def main():
    mcp.run(transport="stdio")


if __name__ == "__main__":
    main()
```

**Step 2: Verify server module loads without errors**

Run: `cd plugins/keepass-cred-mgr && python3 -c "from server.main import mcp; print(f'Tools: {len(mcp._tool_manager._tools)}')"` (exact attribute path may vary — adjust if needed)
Expected: Prints tool count (8) or loads without import errors

**Step 3: Run the full unit test suite to verify no regressions**

Run: `cd plugins/keepass-cred-mgr && python3 -m pytest tests/unit/ -v`
Expected: All tests PASS

**Step 4: Commit**

```bash
git add plugins/keepass-cred-mgr/server/main.py
git commit -m "feat(keepass-cred-mgr): add FastMCP server entry point with all 8 tools"
```

---

## Task 9: Create test database and integration tests

**Files:**
- Create: `plugins/keepass-cred-mgr/tests/fixtures/test.kdbx` (via keepassxc-cli)
- Create: `plugins/keepass-cred-mgr/tests/fixtures/create_test_db.sh`
- Create: `plugins/keepass-cred-mgr/tests/integration/test_integration.py`

**Step 1: Create the test database setup script**

```bash
#!/usr/bin/env bash
# tests/fixtures/create_test_db.sh
# Creates and seeds the test.kdbx database for integration tests.
# Password: testpassword, no YubiKey.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB="$SCRIPT_DIR/test.kdbx"

rm -f "$DB"

echo "testpassword" | keepassxc-cli db-create --set-password "$DB"

# Create groups
for group in "Servers" "SSH Keys" "API Keys"; do
    echo "testpassword" | keepassxc-cli mkdir "$DB" "$group"
done

# Seed Servers group
echo "testpassword" | keepassxc-cli add "$DB" "Servers/Web Server" \
    --username admin --url "https://web.example.com" --password-prompt <<< "webpass123"
echo "testpassword" | keepassxc-cli add "$DB" "Servers/DB Server" \
    --username dba --url "https://db.example.com" --password-prompt <<< "dbpass456"
echo "testpassword" | keepassxc-cli add "$DB" "Servers/[INACTIVE] Old Server" \
    --username legacy --url "https://old.example.com" --password-prompt <<< "oldpass"

# Seed SSH Keys group
echo "testpassword" | keepassxc-cli add "$DB" "SSH Keys/SSH - webserver" \
    --username root --password-prompt <<< "keypass1"
echo "testpassword" | keepassxc-cli add "$DB" "SSH Keys/SSH - dbserver" \
    --username deploy --password-prompt <<< "keypass2"

# Seed API Keys group
echo "testpassword" | keepassxc-cli add "$DB" "API Keys/Anthropic API - main" \
    --username apikey --url "https://api.anthropic.com" --password-prompt <<< "sk-ant-test123"
echo "testpassword" | keepassxc-cli add "$DB" "API Keys/Brave Search API - dev" \
    --username apikey --url "https://api.search.brave.com" --password-prompt <<< "BSA-test456"

echo "Test database created at $DB"
```

**Step 2: Run the script to create the test database**

Run: `cd plugins/keepass-cred-mgr && bash tests/fixtures/create_test_db.sh`
Expected: "Test database created at .../test.kdbx"

NOTE: If `keepassxc-cli` is not available, skip integration tests with `pytest.importorskip` or `@pytest.mark.skipif`. The script may need adjustments based on the exact `keepassxc-cli` version and argument format — adapt the commands during execution.

**Step 3: Write integration tests**

```python
# tests/integration/test_integration.py
"""Integration tests against real test.kdbx.

Requires keepassxc-cli installed. No YubiKey needed (test db uses password only).
"""

import json
import os
import shutil
import subprocess
from pathlib import Path

import pytest
import yaml

# Skip entire module if keepassxc-cli not available
pytestmark = pytest.mark.integration

KEEPASSXC_CLI = shutil.which("keepassxc-cli")
if not KEEPASSXC_CLI:
    pytest.skip("keepassxc-cli not installed", allow_module_level=True)

FIXTURES_DIR = Path(__file__).parent.parent / "fixtures"
TEST_DB = FIXTURES_DIR / "test.kdbx"

if not TEST_DB.exists():
    pytest.skip("test.kdbx not found — run create_test_db.sh", allow_module_level=True)


@pytest.fixture
def integration_setup(tmp_path):
    """Copy test db to tmp, create config, return vault + audit."""
    from server.config import load_config
    from server.vault import Vault
    from server.audit import AuditLogger
    from server.yubikey import MockYubiKey

    # Copy db so writes don't pollute the fixture
    db_copy = tmp_path / "test.kdbx"
    shutil.copy(TEST_DB, db_copy)

    audit_path = tmp_path / "audit.jsonl"
    cfg = {
        "database_path": str(db_copy),
        "yubikey_slot": 2,
        "grace_period_seconds": 2,
        "yubikey_poll_interval_seconds": 1,
        "write_lock_timeout_seconds": 5,
        "page_size": 50,
        "allowed_groups": ["Servers", "SSH Keys", "API Keys"],
        "audit_log_path": str(audit_path),
    }
    config_file = tmp_path / "config.yaml"
    config_file.write_text(yaml.dump(cfg))
    config = load_config(str(config_file))

    # Use MockYubiKey — integration tests don't need real YubiKey
    # BUT we need a vault that can talk to keepassxc-cli without --yubikey
    # This requires overriding run_cli to not pass --yubikey flag
    yk = MockYubiKey(present=True, slot=2)
    vault = Vault(config, yk)

    # For password-only db, we need to override unlock and run_cli
    # to use password-based auth instead of YubiKey
    vault._unlocked = True  # Force unlock state for password-only db
    audit = AuditLogger(str(audit_path))

    return vault, audit, config, db_copy


# NOTE: Integration tests are skipped if keepassxc-cli unavailable.
# The exact CLI invocations may need adaptation based on keepassxc-cli version.
# The implementer should adjust the Vault.run_cli override or create a
# PasswordVault subclass for integration testing with password-only databases.

class TestIntegrationReadCycle:
    def test_list_groups_returns_allowed(self, integration_setup):
        """list_groups → returns only allowed groups."""
        # Implementation depends on actual keepassxc-cli invocation
        # This is a template — the implementer should adapt based on
        # how the password-only vault override works
        pass  # Implement during execution


class TestIntegrationWriteCycle:
    def test_create_then_list(self, integration_setup):
        """create_entry → list_entries confirms presence."""
        pass  # Implement during execution


class TestIntegrationRotation:
    def test_rotation_cycle(self, integration_setup):
        """create → deactivate → confirm [INACTIVE] → create same title."""
        pass  # Implement during execution


class TestIntegrationDuplicatePrevention:
    def test_duplicate_raises(self, integration_setup):
        """create_entry twice → DuplicateEntry on second."""
        pass  # Implement during execution


class TestIntegrationInactiveFiltering:
    def test_inactive_hidden_by_default(self, integration_setup):
        """list_entries hides [INACTIVE]; shows with flag."""
        pass  # Implement during execution


class TestIntegrationGroupAllowlist:
    def test_disallowed_group_raises(self, integration_setup):
        """Request for unlisted group raises GroupNotAllowed."""
        pass  # Implement during execution
```

NOTE TO IMPLEMENTER: Integration tests are structured as templates here because the exact `keepassxc-cli` password-mode invocation depends on runtime behavior. During execution, create a `PasswordVault` test helper that overrides `run_cli` to pass `--no-password` or pipe the password via stdin instead of using `--yubikey`. Fill in each test body based on the actual CLI behavior observed.

**Step 4: Run integration tests**

Run: `cd plugins/keepass-cred-mgr && python3 -m pytest tests/integration/ -v -m integration`
Expected: All integration tests PASS (or skip cleanly if keepassxc-cli unavailable)

**Step 5: Commit**

```bash
git add plugins/keepass-cred-mgr/tests/fixtures/ plugins/keepass-cred-mgr/tests/integration/
git commit -m "feat(keepass-cred-mgr): add integration test framework and test database"
```

---

## Task 10: Create plugin manifest files

**Files:**
- Create: `plugins/keepass-cred-mgr/.claude-plugin/plugin.json`
- Create: `plugins/keepass-cred-mgr/.mcp.json`

**Step 1: Create plugin.json**

```json
{
  "name": "keepass-cred-mgr",
  "description": "MCP server for secure KeePass vault access from Claude Code via YubiKey authentication",
  "version": "1.0.0",
  "author": {
    "name": "L3Digital",
    "url": "https://github.com/l3digital"
  }
}
```

**Step 2: Create .mcp.json**

```json
{
  "mcpServers": {
    "keepass": {
      "command": "python3",
      "args": ["-m", "server.main"],
      "cwd": "${CLAUDE_PLUGIN_ROOT}",
      "env": {
        "KEEPASS_CRED_MGR_CONFIG": "${HOME}/.config/keepass-cred-mgr/config.yaml"
      }
    }
  }
}
```

**Step 3: Add marketplace entry**

Modify: `.claude-plugin/marketplace.json` — append to the `plugins` array:

```json
{
  "name": "keepass-cred-mgr",
  "description": "MCP server for secure KeePass vault access from Claude Code via YubiKey authentication. Exposes 8 tools for listing, searching, reading, and writing KeePass entries with audit logging.",
  "version": "1.0.0",
  "author": {
    "name": "L3DigitalNet",
    "url": "https://github.com/L3DigitalNet"
  },
  "category": "security",
  "homepage": "https://github.com/L3DigitalNet/Claude-Code-Plugins/tree/main/plugins/keepass-cred-mgr",
  "source": "./plugins/keepass-cred-mgr"
}
```

**Step 4: Validate marketplace**

Run: `cd /home/chris/projects/Claude-Code-Plugins && ./scripts/validate-marketplace.sh`
Expected: Validation passes

**Step 5: Commit**

```bash
git add plugins/keepass-cred-mgr/.claude-plugin/ plugins/keepass-cred-mgr/.mcp.json .claude-plugin/marketplace.json
git commit -m "feat(keepass-cred-mgr): add plugin manifest and marketplace entry"
```

---

## Task 11: Create slash commands

**Files:**
- Create: `plugins/keepass-cred-mgr/commands/keepass-status.md`
- Create: `plugins/keepass-cred-mgr/commands/keepass-rotate.md`
- Create: `plugins/keepass-cred-mgr/commands/keepass-audit.md`

**Step 1: Create keepass-status.md**

```markdown
---
description: Show KeePass vault status, accessible groups, and inactive entries pending review.
allowed-tools: mcp__keepass__list_groups, mcp__keepass__list_entries
---

# KeePass Vault Status

Execute these steps in order. Report results inline.

## 1. Check Vault State

Call `list_groups`.
- If it succeeds: the vault is **unlocked**. Report the list of accessible groups.
- If it raises VaultLocked: the vault is **locked**. Report this and stop.

## 2. Inactive Entry Audit

For each accessible group, call `list_entries` with `include_inactive=true`.

Filter to entries whose title starts with `[INACTIVE]`. Collect them into a summary table:

| Group | Title | Status |
|-------|-------|--------|
| ... | ... (without [INACTIVE] prefix) | Pending review |

If no inactive entries exist, report "No inactive entries pending review."

## 3. Summary

Report:
- Vault state (locked/unlocked)
- Number of accessible groups
- Total inactive entries pending review
```

**Step 2: Create keepass-rotate.md**

```markdown
---
argument-hint: [title] [group]
description: Rotate a KeePass credential with safe deactivation of the old entry.
allowed-tools: mcp__keepass__create_entry, mcp__keepass__deactivate_entry, mcp__keepass__get_entry, mcp__keepass__list_entries
---

# KeePass Credential Rotation

## 1. Identify Target

If arguments were provided, use them as the title and group.
Otherwise, ask the user:
- Which credential to rotate? (title and group)

## 2. Collect New Values

Ask the user for the new credential values:
- Username (or keep existing)
- Password (new value)
- URL (or keep existing)
- Notes (or keep existing)

## 3. Create New Entry

Call `create_entry` with the new values using the **same title** (the old entry will be renamed).

**CRITICAL**: Confirm `create_entry` succeeded before proceeding. If it fails (e.g., DuplicateEntry because the old one still has the same title), deactivate the old entry first, then retry.

Alternative flow if title collision:
1. Call `deactivate_entry` on the old entry first
2. Call `create_entry` with the original title

## 4. Deactivate Old Entry

If the old entry was not already deactivated in step 3:
Call `deactivate_entry` on the old entry.
Confirm success.

## 5. Report

Report completion:
- New entry is active with the original title
- Old entry has been renamed with `[INACTIVE]` prefix and deactivation timestamp
- Remind the user: "Delete the [INACTIVE] entry manually in KeePassXC when ready."
```

**Step 3: Create keepass-audit.md**

```markdown
---
description: List all deactivated KeePass entries with their deactivation timestamps.
allowed-tools: mcp__keepass__list_groups, mcp__keepass__list_entries, mcp__keepass__get_entry
---

# KeePass Deactivated Entry Audit

## 1. Gather All Inactive Entries

Call `list_groups` to get accessible groups.

For each group, call `list_entries` with `include_inactive=true`.
Filter to entries whose title starts with `[INACTIVE]`.

## 2. Retrieve Deactivation Details

For each inactive entry, call `get_entry` to retrieve the notes field.
Parse the deactivation timestamp from the notes (look for `[DEACTIVATED: <ISO timestamp>]`).

**IMPORTANT**: Do NOT display the password field. Only use get_entry to extract the notes.

## 3. Present Results

Display a table:

| Group | Original Title | Deactivated On |
|-------|---------------|----------------|
| ... | ... (title without [INACTIVE] prefix) | ISO timestamp or "unknown" |

## 4. Guidance

After the table, remind the user:
"To permanently remove these entries, delete them in the KeePassXC GUI. This plugin does not support entry deletion as a safety measure."
```

**Step 4: Commit**

```bash
git add plugins/keepass-cred-mgr/commands/
git commit -m "feat(keepass-cred-mgr): add slash commands (status, rotate, audit)"
```

---

## Task 12: Create skills

**Files:**
- Create: `plugins/keepass-cred-mgr/skills/keepass-hygiene/SKILL.md`
- Create: `plugins/keepass-cred-mgr/skills/keepass-credential-cpanel/SKILL.md`
- Create: `plugins/keepass-cred-mgr/skills/keepass-credential-ftp/SKILL.md`
- Create: `plugins/keepass-cred-mgr/skills/keepass-credential-ssh/SKILL.md`
- Create: `plugins/keepass-cred-mgr/skills/keepass-credential-brave-search/SKILL.md`
- Create: `plugins/keepass-cred-mgr/skills/keepass-credential-anthropic/SKILL.md`

**Step 1: Create all 6 skill files**

Content for each skill is specified verbatim in the implementation brief (Phase 11). Each file needs YAML frontmatter added:

**keepass-hygiene/SKILL.md:**
```yaml
---
name: keepass-hygiene
description: >
  KeePass credential hygiene rules. Apply whenever interacting with KeePass via MCP tools,
  handling secrets, or performing credential rotation. Loaded automatically on any vault operation.
---
```
Then the content from the brief.

**keepass-credential-cpanel/SKILL.md:**
```yaml
---
name: keepass-credential-cpanel
description: >
  cPanel credential handling. Use when storing, retrieving, or rotating cPanel hosting credentials.
  Triggers on mentions of cPanel, hosting panel, WHM, or web hosting credentials.
---
```

**keepass-credential-ftp/SKILL.md:**
```yaml
---
name: keepass-credential-ftp
description: >
  FTP/SFTP credential handling. Use when storing, retrieving, or rotating FTP, FTPS, or SFTP credentials.
  Triggers on mentions of FTP, SFTP, file transfer, or lftp connection strings.
---
```

**keepass-credential-ssh/SKILL.md:**
```yaml
---
name: keepass-credential-ssh
description: >
  SSH key handling with agent-first resolution. Use when retrieving SSH keys, provisioning SSH access,
  or storing SSH key material. Triggers on mentions of SSH, ssh-agent, ssh-add, or key provisioning.
---
```

**keepass-credential-brave-search/SKILL.md:**
```yaml
---
name: keepass-credential-brave-search
description: >
  Brave Search API credential handling. Use when storing or retrieving Brave Search API keys.
  Triggers on mentions of Brave Search, web search API keys, or BSA- prefixed keys.
---
```

**keepass-credential-anthropic/SKILL.md:**
```yaml
---
name: keepass-credential-anthropic
description: >
  Anthropic API credential handling with elevated sensitivity. Use when storing, retrieving,
  or rotating Anthropic API keys. Triggers on mentions of Anthropic API, Claude API keys,
  sk-ant- prefixed keys, or ANTHROPIC_API_KEY environment variable.
---
```

Each SKILL.md body is the content from the implementation brief Phase 11, verbatim.

**Step 2: Commit**

```bash
git add plugins/keepass-cred-mgr/skills/
git commit -m "feat(keepass-cred-mgr): add 6 credential-handling skills"
```

---

## Task 13: Write README.md and CHANGELOG.md

**Files:**
- Create: `plugins/keepass-cred-mgr/README.md`
- Create: `plugins/keepass-cred-mgr/CHANGELOG.md`

**Step 1: Write README.md**

Follow the template at `docs/plugin-readme-template.md`. Required sections: Summary, Principles, Requirements, Installation, How It Works (Mermaid), Usage, Tools, Commands, Skills, Configuration, Planned Features, Known Issues, Links.

The README must cover all items specified in Phase 12 of the brief:
- What the plugin does and why
- Prerequisites: KeePassXC, ykman, Python 3.12+, YubiKey 5C Nano or compatible
- Installation commands
- YAML config setup with field reference table
- Complete tool surface reference table (all 8 tools, parameters, return values)
- Slash commands reference
- Security model summary
- Known limitations (N+1 CLI calls on list, page_size cap, no delete/overwrite)

Writing style: follow the CLAUDE.md writing rules (no em dashes, no vague superlatives, no filler openers).

**Step 2: Write CHANGELOG.md**

```markdown
# Changelog

All notable changes to this plugin are documented here.

## [1.0.0] - 2026-02-27

### Added
- MCP server with 8 tools: list_groups, list_entries, search_entries, get_entry, get_attachment, create_entry, deactivate_entry, add_attachment
- YubiKey HMAC-SHA1 challenge-response authentication via ykman polling
- Grace period auto-lock on YubiKey removal
- JSONL audit logging for all secret-returning operations
- Group allowlist enforcement on all operations
- File locking for write operations
- Secure temp file shredding for attachment imports
- Slash commands: /keepass-status, /keepass-rotate, /keepass-audit
- 6 credential-handling skills: hygiene, cPanel, FTP/SFTP, SSH, Brave Search, Anthropic
- Soft-delete via [INACTIVE] prefix (no destructive deletes)
```

**Step 3: Commit**

```bash
git add plugins/keepass-cred-mgr/README.md plugins/keepass-cred-mgr/CHANGELOG.md
git commit -m "docs(keepass-cred-mgr): add README and CHANGELOG"
```

---

## Task 14: Final verification

**Step 1: Run full unit test suite**

Run: `cd plugins/keepass-cred-mgr && python3 -m pytest tests/unit/ -v`
Expected: All tests PASS

**Step 2: Run integration tests (if keepassxc-cli available)**

Run: `cd plugins/keepass-cred-mgr && python3 -m pytest tests/integration/ -v -m integration`
Expected: All tests PASS or skip cleanly

**Step 3: Verify server starts**

Run: `cd plugins/keepass-cred-mgr && timeout 3 python3 -m server.main 2>/dev/null; echo "Exit: $?"`
Expected: Exits with timeout (143) or clean exit — no import errors

**Step 4: Validate marketplace**

Run: `cd /home/chris/projects/Claude-Code-Plugins && ./scripts/validate-marketplace.sh`
Expected: Validation passes

**Step 5: Verify file structure matches spec**

Run: `cd plugins/keepass-cred-mgr && find . -type f | sort`
Expected: All files from the repository structure in the brief are present

**Step 6: Verify no secrets in test output or fixtures**

Run: `cd plugins/keepass-cred-mgr && grep -r "s3cret\|sk-ant-\|BSA-test\|webpass\|dbpass\|oldpass\|keypass" tests/ --include="*.py" -l`
Expected: Only `test_tools.py` (mock data in tests) and `create_test_db.sh` — no real secrets

**Step 7: Final commit if any fixups needed**

```bash
git add -A plugins/keepass-cred-mgr/
git commit -m "fix(keepass-cred-mgr): final verification fixups"
```

---

## Dependency Map

```
Task 1  (skeleton)
  ├─► Task 2  (config)
  │     └─► Task 4  (vault) ◄── Task 3 (yubikey)
  │           ├─► Task 5  (audit)
  │           ├─► Task 6  (read tools)
  │           │     └─► Task 7  (write tools)
  │           │           └─► Task 8  (MCP server)
  │           │                 └─► Task 9  (integration tests)
  │           └─► Task 10 (manifest) — independent of tools
  ├─► Task 11 (commands) — independent of server code
  ├─► Task 12 (skills) — independent of server code
  └─► Task 13 (README) — after all code tasks
        └─► Task 14 (final verification) — after everything
```

Tasks 10, 11, 12 can run in parallel once Task 1 is done.
Tasks 2 and 3 can run in parallel.
Task 13 should wait for Tasks 8-12 to be complete.
