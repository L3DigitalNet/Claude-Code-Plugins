"""Test helpers for unit and integration tests.

PasswordVault overrides the YubiKey-based auth with a password piped via stdin,
enabling integration tests against a password-only test.kdbx.

The REPL protocol: keepassxc-cli open starts a persistent REPL that prints "> "
after the initial password prompt succeeds. PasswordVault sends the password and
waits for that prompt with readuntil(), then delegates run_cli() to the parent
class (which sends commands via stdin/stdout). run_cli_binary() uses a separate
subprocess per call — binary data can't transit the text REPL.

_repl_resp / _mock_repl_proc / _mock_async_proc are shared mock helpers for
unit tests in test_vault.py and test_tools.py.
"""

from __future__ import annotations

import asyncio
from datetime import UTC, datetime
from unittest.mock import AsyncMock, MagicMock

from server.config import Config
from server.vault import KeePassCLIError, Vault, VaultLocked
from server.yubikey import MockYubiKey


# ---------------------------------------------------------------------------
# Shared REPL mock helpers (used by test_vault.py and test_tools.py)
# ---------------------------------------------------------------------------

def _repl_resp(data: bytes = b"") -> bytes:
    """Wrap output bytes with the REPL prompt sentinel b"\\n> ".

    Each value in readuntil.side_effect must include the sentinel because
    run_cli() strips the last len(b"\\n> ") = 3 bytes to recover command output.
    """
    return data + b"\n> "


def _mock_repl_proc(responses: list[bytes] | None = None) -> MagicMock:
    """Create a mock REPL process for vault.run_cli() calls.

    responses: readuntil return values, one per run_cli() call.
    None → returns empty response (_repl_resp()) for every call.
    """
    proc = MagicMock()
    proc.stdin = MagicMock()
    proc.stdin.write = MagicMock()
    proc.stdin.drain = AsyncMock(return_value=None)
    proc.stdout = MagicMock()
    proc.stdout.readuntil = (
        AsyncMock(side_effect=responses)
        if responses is not None
        else AsyncMock(return_value=_repl_resp())
    )
    proc.kill = MagicMock()
    proc.wait = AsyncMock(return_value=None)
    return proc


def _mock_async_proc(
    stdout: bytes = b"", stderr: bytes = b"", returncode: int = 0
) -> AsyncMock:
    """Mock subprocess for run_cli_binary() which uses communicate()."""
    proc = AsyncMock()
    proc.communicate.return_value = (stdout, stderr)
    proc.returncode = returncode
    return proc

_REPL_INITIAL_PROMPT = b"> "
_REPL_TIMEOUT = 30


class PasswordVault(Vault):
    """Vault subclass that uses password auth instead of YubiKey.

    For integration testing only. Overrides unlock() to pipe the database
    password via stdin and wait for the REPL prompt. All subsequent run_cli()
    calls go through the parent's REPL session — no re-authentication per call.
    """

    def __init__(self, config: Config, password: str) -> None:
        super().__init__(config, MockYubiKey(present=True, slot=config.yubikey_slot))
        self._password = password

    async def unlock(self) -> None:
        proc = await asyncio.create_subprocess_exec(
            "keepassxc-cli", "open", self._config.database_path,
            stdin=asyncio.subprocess.PIPE,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )

        # Drain stderr in background so the pipe buffer can't fill and stall the REPL.
        self._stderr_drain_task = asyncio.create_task(self._drain_stderr(proc))

        # Send password and wait for the REPL prompt — same pattern as real unlock().
        proc.stdin.write((self._password + "\n").encode())
        await proc.stdin.drain()

        try:
            prompt_data = await asyncio.wait_for(
                proc.stdout.readuntil(_REPL_INITIAL_PROMPT),
                timeout=_REPL_TIMEOUT,
            )
        except asyncio.TimeoutError:
            proc.kill()
            await proc.wait()
            raise KeePassCLIError("keepassxc-cli open timed out")
        except asyncio.IncompleteReadError:
            await proc.wait()
            raise KeePassCLIError(
                "keepassxc-cli open exited before showing prompt"
                " — check database_path in config and password"
            )

        self._repl_prompt_bytes = prompt_data  # e.g., b"test.kdbx> "
        self._repl_proc = proc
        self._unlocked = True
        self._unlock_time = datetime.now(UTC)

    async def run_cli_binary(self, *args: str) -> bytes:
        """Run keepassxc-cli as a one-shot subprocess with password auth.

        Binary exports need a direct subprocess (raw bytes can't transit the text
        REPL). Password is piped via stdin instead of --no-password + YubiKey.
        """
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
            timeout=_REPL_TIMEOUT,
        )
        if proc.returncode != 0:
            subcmd = args[0] if args else "unknown"
            stderr = stderr_bytes.decode("utf-8", errors="replace").strip()
            raise KeePassCLIError(f"keepassxc-cli {subcmd} failed: {stderr}")
        return stdout_bytes
