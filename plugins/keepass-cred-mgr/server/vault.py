"""Vault manager: mediates all keepassxc-cli interactions.

State machine: locked <-> unlocked via YubiKey touch.
Background polling of ykman with grace period before auto-lock.
Group allowlist enforced on all operations.

REPL mode: unlock() starts a persistent `keepassxc-cli open` process (one YubiKey
touch per session). run_cli() dispatches all subsequent commands through that
process's stdin/stdout — no re-authentication per call. run_cli_binary() is
exempt: binary attachment exports use a direct subprocess because raw bytes
cannot pass through the text REPL without corruption.

Why not communicate(): asyncio.Process.communicate() closes stdin then waits for
stdout EOF. The REPL never closes stdout, so communicate() blocks forever. We use
readuntil() on stdout instead, which returns as soon as each prompt appears.
"""

from __future__ import annotations

import asyncio
from contextlib import suppress
from datetime import UTC, datetime

import structlog

from server.config import Config
from server.diagnostics import diagnose_unlock_failure
from server.yubikey import YubiKeyInterface

log: structlog.stdlib.BoundLogger = structlog.get_logger("keepass-cred-mgr.vault")

INACTIVE_PREFIX = "[INACTIVE] "

# keepassxc-cli REPL prompt format. The initial prompt has no leading newline
# (printed with Qt flush immediately after unlock). Subsequent prompts follow
# command output that always ends with \n, so \n> is the correct separator.
_REPL_INITIAL_PROMPT = b"> "
_REPL_PROMPT = b"\n> "
_REPL_TIMEOUT = 30

# Characters that require double-quoting in the keepassxc-cli REPL.
# The REPL uses Qt's QProcess::splitCommand (double-quote style),
# NOT POSIX quoting — single quotes are NOT treated as delimiters.
_REPL_NEEDS_QUOTING = frozenset(' \t"\\')


def _repl_quote(arg: str) -> str:
    """Quote one argument for keepassxc-cli REPL (double-quote style).

    Qt's argument parser recognises double-quoted strings but not single-quoted
    strings.  shlex.quote() prefers single quotes, which silently pass through
    the REPL as literal characters — breaking any argument that contains spaces.
    """
    if not arg or any(c in _REPL_NEEDS_QUOTING for c in arg):
        return '"' + arg.replace("\\", "\\\\").replace('"', '\\"') + '"'
    return arg


def _repl_join(args: list[str]) -> str:
    """Join args into a REPL command string using Qt-compatible double-quoting."""
    return " ".join(_repl_quote(a) for a in args)


# --- Exceptions ---


class VaultLocked(Exception):
    """Vault is locked; unlock with YubiKey touch first."""


class YubiKeyNotPresent(Exception):
    """YubiKey not detected; insert key and retry."""


class EntryNotFound(Exception):
    """No entry matches the given title/path."""


class EntryRestricted(Exception):
    """Entry is tagged AI RESTRICTED; access denied."""


class EntryReadOnly(Exception):
    """Entry is tagged READ ONLY; write operations are not permitted."""


class DuplicateEntry(Exception):
    """An active entry with this title already exists in the group."""


class EntryInactive(Exception):
    """This entry is deactivated; create a new entry instead."""


class WriteLockTimeout(Exception):
    """Could not acquire the write lock within the timeout."""


class KeePassCLIError(Exception):
    """keepassxc-cli returned a non-zero exit code or an error response."""


# --- Vault ---


class Vault:
    def __init__(self, config: Config, yubikey: YubiKeyInterface) -> None:
        self._config = config
        self._yubikey = yubikey
        self._unlocked = False
        self._unlock_time: datetime | None = None
        self._grace_timer: asyncio.Task[None] | None = None
        # Persistent REPL process — one keepassxc-cli open process per session
        self._repl_proc: asyncio.subprocess.Process | None = None
        self._repl_lock: asyncio.Lock = asyncio.Lock()
        self._stderr_drain_task: asyncio.Task[None] | None = None
        # Prompt bytes captured from unlock() — used as the run_cli() separator.
        # Defaults to b"> " (fake-tools). Real keepassxc-cli sets it to b"dbname> ".
        self._repl_prompt_bytes: bytes = b"> "

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

        # Start a persistent REPL. The YubiKey challenge happens here once;
        # all run_cli() calls reuse the open session without re-authenticating.
        proc = await asyncio.create_subprocess_exec(
            "keepassxc-cli", "open",
            "--yubikey", self._yubikey.slot(),
            "--no-password",
            self._config.database_path,
            stdin=asyncio.subprocess.PIPE,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )

        # Drain stderr in background — prevents the 64 KB pipe buffer from
        # filling and stalling the REPL when keepassxc-cli emits verbose output.
        self._stderr_drain_task = asyncio.create_task(self._drain_stderr(proc))

        # The initial prompt on stdout appears only after YubiKey challenge succeeds —
        # waiting for it implicitly waits for the touch.
        # The real keepassxc-cli uses "dbname> " (e.g., "test.kdbx> "); fake-tools use "> ".
        # readuntil("> ") finds either format; the returned bytes become _repl_prompt_bytes
        # so run_cli() can build the correct separator ("\n" + prompt) for subsequent reads.
        try:
            prompt_data = await asyncio.wait_for(
                proc.stdout.readuntil(_REPL_INITIAL_PROMPT),
                timeout=_REPL_TIMEOUT,
            )
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

        self._repl_prompt_bytes = prompt_data  # e.g., b"test.kdbx> " or b"> "
        self._repl_proc = proc
        self._unlocked = True
        self._unlock_time = datetime.now(UTC)
        log.info("vault_unlocked", mode="repl")

    async def _drain_stderr(self, proc: asyncio.subprocess.Process) -> None:
        """Drain stderr from the REPL process in the background."""
        try:
            while True:
                line = await proc.stderr.readline()
                if not line:
                    break
                log.debug(
                    "repl_stderr",
                    line=line.decode("utf-8", errors="replace").strip(),
                )
        except Exception as e:
            log.debug("repl_stderr_drain_error", error=type(e).__name__)

    async def lock(self, *, reason: str = "yubikey_removed") -> None:
        self._unlocked = False
        if self._repl_proc is not None:
            self._repl_proc.kill()
            with suppress(Exception):
                await asyncio.wait_for(self._repl_proc.wait(), timeout=5)
            self._repl_proc = None
        if self._stderr_drain_task is not None:
            self._stderr_drain_task.cancel()
            with suppress(asyncio.CancelledError):
                await self._stderr_drain_task
            self._stderr_drain_task = None
        log.info("vault_locked", reason=reason)

    def entry_path(self, title: str, group: str | None) -> str:
        if group:
            return f"{group}/{title}"
        return title

    async def run_cli(self, *args: str, stdin_lines: list[str] | None = None) -> str:
        """Send a command to the persistent REPL and return its stdout output.

        args[0] is the keepassxc-cli subcommand. The database path (conventionally
        args[1] in callers) is stripped before sending — the REPL already has it
        open. Arguments with spaces are double-quoted (Qt-style, not POSIX).

        stdin_lines: extra lines written to stdin immediately after the command.
        Use when the subcommand prompts for input (e.g., -p/--password-prompt):
        write the response lines upfront so the REPL reads them without deadlocking
        on the readuntil() call waiting for the separator.
        """
        if not self._unlocked:
            raise VaultLocked("Vault is locked; call unlock() first")

        if not args:
            raise KeePassCLIError("keepassxc-cli unknown failed: no subcommand given")

        # Strip the database path — the REPL has it open, does not take it as an arg.
        repl_args = [a for a in args[1:] if a != self._config.database_path]
        cmd_str = _repl_join([args[0], *repl_args])
        cmd_bytes = (cmd_str + "\n").encode()

        # Separator between command output and next prompt.
        # "\n" comes from the last output line; the prompt follows immediately.
        # e.g., b"\ntest.kdbx> " for real keepassxc-cli, b"\n> " for fake-tools.
        separator = b"\n" + self._repl_prompt_bytes

        async with self._repl_lock:
            if self._repl_proc is None:
                raise VaultLocked("REPL process is not running; call unlock() again")

            self._repl_proc.stdin.write(cmd_bytes)
            if stdin_lines:
                for line in stdin_lines:
                    self._repl_proc.stdin.write((line + "\n").encode())
            await self._repl_proc.stdin.drain()

            try:
                data = await asyncio.wait_for(
                    self._repl_proc.stdout.readuntil(separator),
                    timeout=_REPL_TIMEOUT,
                )
            except asyncio.TimeoutError:
                raise KeePassCLIError(
                    f"keepassxc-cli {args[0]} timed out"
                )
            except asyncio.IncompleteReadError:
                # REPL died mid-command — mark vault locked so callers get clear errors.
                self._unlocked = False
                self._repl_proc = None
                raise KeePassCLIError(
                    f"keepassxc-cli REPL terminated unexpectedly during {args[0]}"
                )

        # Strip the trailing separator ("\n" + prompt) to isolate command output.
        output = data[: -len(separator)].decode("utf-8", errors="replace")

        # Real keepassxc-cli echoes the command text as the first output line (no prompt
        # prefix). Fake-tools don't echo. Strip echo when present by matching cmd_str.
        if output.startswith(cmd_str + "\n"):
            output = output[len(cmd_str) + 1:]
        elif output == cmd_str:
            output = ""

        # Raise on in-REPL error text so callers handle errors uniformly regardless
        # of whether we're in REPL or direct mode.
        stripped = output.strip()
        if stripped.startswith("Error:") or stripped.startswith("Invalid "):
            raise KeePassCLIError(f"keepassxc-cli {args[0]} failed: {stripped}")

        return output

    async def run_cli_binary(self, *args: str) -> bytes:
        """Run keepassxc-cli as a direct subprocess and return raw stdout bytes.

        Used for attachment-export only. Binary content can't pass through the
        text REPL without corruption, so this spawns its own process — one
        additional YubiKey touch per call.
        """
        if not self._unlocked:
            raise VaultLocked("Vault is locked; call unlock() first")

        cmd = [
            "keepassxc-cli",
            args[0],
            "--yubikey", self._yubikey.slot(),
            "--no-password",
            *args[1:],
        ]
        proc = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        stdout_bytes, stderr_bytes = await asyncio.wait_for(
            proc.communicate(), timeout=_REPL_TIMEOUT
        )
        if proc.returncode != 0:
            subcmd = args[0] if args else "unknown"
            stderr = stderr_bytes.decode("utf-8", errors="replace")
            raise KeePassCLIError(f"keepassxc-cli {subcmd} failed: {stderr.strip()}")
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
        await self.lock()
        self._grace_timer = None
