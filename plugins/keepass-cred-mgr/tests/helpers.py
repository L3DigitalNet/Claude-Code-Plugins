"""Test helpers for integration tests.

PasswordVault overrides the YubiKey-based auth with a password piped via stdin,
enabling integration tests against a password-only test.kdbx.
"""

from __future__ import annotations

import asyncio
from datetime import UTC

from server.config import Config
from server.vault import KeePassCLIError, Vault, VaultLocked
from server.yubikey import MockYubiKey


class PasswordVault(Vault):
    """Vault subclass that uses password auth instead of YubiKey.

    For integration testing only. Overrides unlock() and run_cli()
    to pipe the database password via stdin.
    """

    def __init__(self, config: Config, password: str) -> None:
        super().__init__(config, MockYubiKey(present=True, slot=config.yubikey_slot))
        self._password = password

    async def unlock(self) -> None:
        from datetime import datetime

        proc = await asyncio.create_subprocess_exec(
            "keepassxc-cli", "open", self._config.database_path,
            stdin=asyncio.subprocess.PIPE,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        stdout_bytes, stderr_bytes = await asyncio.wait_for(
            proc.communicate(input=(self._password + "\n").encode()),
            timeout=30,
        )
        if proc.returncode != 0:
            stderr = stderr_bytes.decode("utf-8", errors="replace").strip()
            raise KeePassCLIError(f"keepassxc-cli open failed: {stderr}")
        self._unlocked = True
        self._unlock_time = datetime.now(UTC)

    async def run_cli(self, *args: str) -> str:
        if not self._unlocked:
            raise VaultLocked("Vault is locked; call unlock() first")

        cmd = ["keepassxc-cli", *args]
        proc = await asyncio.create_subprocess_exec(
            *cmd,
            stdin=asyncio.subprocess.PIPE,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        stdout_bytes, stderr_bytes = await asyncio.wait_for(
            proc.communicate(input=(self._password + "\n").encode()),
            timeout=30,
        )
        if proc.returncode != 0:
            subcmd = args[0] if args else "unknown"
            stderr = stderr_bytes.decode("utf-8", errors="replace").strip()
            raise KeePassCLIError(
                f"keepassxc-cli {subcmd} failed: {stderr}"
            )
        return stdout_bytes.decode("utf-8", errors="replace")

    async def run_cli_binary(self, *args: str) -> bytes:
        """Run keepassxc-cli and return raw stdout bytes."""
        if not self._unlocked:
            raise VaultLocked("Vault is locked; call unlock() first")

        cmd = ["keepassxc-cli", *args]
        proc = await asyncio.create_subprocess_exec(
            *cmd,
            stdin=asyncio.subprocess.PIPE,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        stdout_bytes, stderr_bytes = await asyncio.wait_for(
            proc.communicate(input=(self._password + "\n").encode()),
            timeout=30,
        )
        if proc.returncode != 0:
            subcmd = args[0] if args else "unknown"
            stderr = stderr_bytes.decode("utf-8", errors="replace").strip()
            raise KeePassCLIError(
                f"keepassxc-cli {subcmd} failed: {stderr}"
            )
        return stdout_bytes
