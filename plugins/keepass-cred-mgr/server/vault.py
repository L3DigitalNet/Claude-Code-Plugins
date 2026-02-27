"""Vault manager: mediates all keepassxc-cli interactions.

State machine: locked <-> unlocked via YubiKey touch.
Background polling of ykman with grace period before auto-lock.
Group allowlist enforced on all operations.
"""

from __future__ import annotations

import asyncio
import logging
import subprocess
import sys
from datetime import UTC, datetime

from server.config import Config
from server.yubikey import YubiKeyInterface

# All logging to stderr; stdout is reserved for MCP stdio protocol
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
        self._grace_timer: asyncio.Task[None] | None = None

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
        self._unlock_time = datetime.now(UTC)
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
