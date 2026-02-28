"""Vault manager: mediates all keepassxc-cli interactions.

State machine: locked <-> unlocked via YubiKey touch.
Background polling of ykman with grace period before auto-lock.
Group allowlist enforced on all operations.
"""

from __future__ import annotations

import asyncio
from contextlib import suppress
from datetime import UTC, datetime

import structlog

from server.config import Config
from server.yubikey import YubiKeyInterface

log: structlog.stdlib.BoundLogger = structlog.get_logger("keepass-cred-mgr.vault")

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

    async def unlock(self) -> None:
        if not self._yubikey.is_present():
            raise YubiKeyNotPresent("Insert YubiKey and try again")

        proc = await asyncio.create_subprocess_exec(
            "keepassxc-cli", "open",
            "--yubikey", str(self._yubikey.slot()),
            self._config.database_path,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        stdout_bytes, stderr_bytes = await asyncio.wait_for(
            proc.communicate(), timeout=30
        )
        if proc.returncode != 0:
            stderr = stderr_bytes.decode("utf-8", errors="replace")
            raise KeePassCLIError(
                f"keepassxc-cli open failed: {stderr.strip()}"
            )
        self._unlocked = True
        self._unlock_time = datetime.now(UTC)
        log.info("vault_unlocked")

    def _lock(self) -> None:
        self._unlocked = False
        log.info("vault_locked", reason="yubikey_removed")

    def check_group_allowed(self, group: str) -> None:
        if group not in self._config.allowed_groups:
            raise GroupNotAllowed(
                f"Group '{group}' is not in allowed_groups: {self._config.allowed_groups}"
            )

    def entry_path(self, title: str, group: str | None) -> str:
        if group:
            return f"{group}/{title}"
        return title

    async def run_cli(self, *args: str) -> str:
        if not self._unlocked:
            raise VaultLocked("Vault is locked; call unlock() first")

        cmd = [
            "keepassxc-cli",
            "--yubikey", str(self._yubikey.slot()),
            *args,
        ]
        proc = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        stdout_bytes, stderr_bytes = await asyncio.wait_for(
            proc.communicate(), timeout=30
        )
        stdout = stdout_bytes.decode("utf-8", errors="replace")
        if proc.returncode != 0:
            subcmd = args[0] if args else "unknown"
            stderr = stderr_bytes.decode("utf-8", errors="replace")
            raise KeePassCLIError(
                f"keepassxc-cli {subcmd} failed: {stderr.strip()}"
            )
        return stdout

    async def run_cli_binary(self, *args: str) -> bytes:
        """Run keepassxc-cli and return raw stdout bytes (for binary content)."""
        if not self._unlocked:
            raise VaultLocked("Vault is locked; call unlock() first")

        cmd = [
            "keepassxc-cli",
            "--yubikey", str(self._yubikey.slot()),
            *args,
        ]
        proc = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        stdout_bytes, stderr_bytes = await asyncio.wait_for(
            proc.communicate(), timeout=30
        )
        if proc.returncode != 0:
            subcmd = args[0] if args else "unknown"
            stderr = stderr_bytes.decode("utf-8", errors="replace")
            raise KeePassCLIError(
                f"keepassxc-cli {subcmd} failed: {stderr.strip()}"
            )
        return stdout_bytes

    async def start_polling(self) -> None:
        interval = self._config.yubikey_poll_interval_seconds
        while True:
            try:
                present = await asyncio.to_thread(self._yubikey.is_present)

                if not present and self._unlocked and self._grace_timer is None:
                    log.info("grace_timer_started")
                    self._grace_timer = asyncio.create_task(self._grace_countdown())

                if present and self._grace_timer is not None:
                    log.info("grace_timer_cancelled")
                    self._grace_timer.cancel()
                    with suppress(asyncio.CancelledError):
                        await self._grace_timer
                    self._grace_timer = None

                await asyncio.sleep(interval)
            except asyncio.CancelledError:
                if self._grace_timer:
                    self._grace_timer.cancel()
                raise
            except Exception:
                log.exception("polling_error")
                await asyncio.sleep(interval)

    async def _grace_countdown(self) -> None:
        await asyncio.sleep(self._config.grace_period_seconds)
        self._lock()
        self._grace_timer = None
