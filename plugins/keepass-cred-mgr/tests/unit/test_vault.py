"""Tests for Vault: state machine, REPL I/O, locking, grace timer."""

import asyncio
import contextlib
from datetime import UTC
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from server.yubikey import MockYubiKey
from tests.helpers import _mock_async_proc, _mock_repl_proc, _repl_resp

pytestmark = pytest.mark.unit


def _mock_unlock_proc(
    *,
    fail: type[Exception] | None = None,
) -> MagicMock:
    """Create a mock subprocess suitable for vault.unlock() testing.

    fail=asyncio.IncompleteReadError → process exits before emitting the prompt.
    fail=asyncio.TimeoutError        → process times out waiting for the prompt.
    None                             → success, returns the initial b"> " prompt.
    """
    proc = MagicMock()
    proc.stdin = MagicMock()
    proc.stdin.write = MagicMock()
    proc.stdin.drain = AsyncMock(return_value=None)
    proc.stdout = MagicMock()
    proc.stderr = MagicMock()
    # Drain loop exits immediately when readline returns empty bytes
    proc.stderr.readline = AsyncMock(return_value=b"")
    proc.kill = MagicMock()
    proc.wait = AsyncMock(return_value=None)

    if fail is asyncio.IncompleteReadError:
        proc.stdout.readuntil = AsyncMock(
            side_effect=asyncio.IncompleteReadError(b"", 2)
        )
    elif fail is asyncio.TimeoutError:
        proc.stdout.readuntil = AsyncMock(side_effect=asyncio.TimeoutError())
    else:
        # Successful unlock: return the initial "> " prompt
        proc.stdout.readuntil = AsyncMock(return_value=b"> ")
    return proc


# ---------------------------------------------------------------------------
# Exception inventory
# ---------------------------------------------------------------------------

class TestVaultExceptions:
    def test_all_exceptions_exist(self):
        from server.vault import (
            DuplicateEntry,
            EntryInactive,
            EntryNotFound,
            EntryReadOnly,
            EntryRestricted,
            KeePassCLIError,
            VaultLocked,
            WriteLockTimeout,
            YubiKeyNotPresent,
        )
        for exc_cls in (
            VaultLocked, YubiKeyNotPresent, EntryNotFound,
            EntryRestricted, EntryReadOnly, DuplicateEntry,
            EntryInactive, WriteLockTimeout, KeePassCLIError,
        ):
            assert issubclass(exc_cls, Exception)


# ---------------------------------------------------------------------------
# Vault state: unlock / lock
# ---------------------------------------------------------------------------

class TestVaultState:
    def test_starts_locked(self, test_config, mock_yubikey):
        from server.vault import Vault

        vault = Vault(test_config, mock_yubikey)
        assert vault.is_unlocked is False


    async def test_unlock_raises_when_yubikey_absent(self, test_config):
        from server.vault import Vault, YubiKeyNotPresent

        yk = MockYubiKey(present=False)
        vault = Vault(test_config, yk)
        with pytest.raises(YubiKeyNotPresent):
            await vault.unlock()


    @patch("asyncio.create_subprocess_exec")
    async def test_unlock_succeeds_with_yubikey(self, mock_exec, test_config, mock_yubikey):
        """unlock() opens a REPL process and waits for the initial '> ' prompt."""
        mock_exec.return_value = _mock_unlock_proc()
        from server.vault import Vault

        vault = Vault(test_config, mock_yubikey)
        await vault.unlock()
        assert vault.is_unlocked is True
        assert vault._repl_proc is not None


    @patch("asyncio.create_subprocess_exec")
    async def test_unlock_raises_on_cli_error(self, mock_exec, test_config, mock_yubikey):
        """IncompleteReadError from stdout (process exited) → KeePassCLIError."""
        mock_exec.return_value = _mock_unlock_proc(fail=asyncio.IncompleteReadError)
        from server.vault import KeePassCLIError, Vault

        vault = Vault(test_config, mock_yubikey)
        with pytest.raises(KeePassCLIError):
            await vault.unlock()


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
        assert "\u2014" not in str(exc_info.value)

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


    async def test_run_cli_raises_when_locked(self, test_config, mock_yubikey):
        from server.vault import Vault, VaultLocked

        vault = Vault(test_config, mock_yubikey)
        with pytest.raises(VaultLocked):
            await vault.run_cli("ls", test_config.database_path)


# ---------------------------------------------------------------------------
# Tag-based access control
# ---------------------------------------------------------------------------

class TestVaultTagEnforcement:
    def test_entry_restricted_exception_is_exception(self):
        from server.vault import EntryRestricted

        assert issubclass(EntryRestricted, Exception)
        e = EntryRestricted("test")
        assert str(e) == "test"

    def test_entry_read_only_exception_is_exception(self):
        from server.vault import EntryReadOnly

        assert issubclass(EntryReadOnly, Exception)
        e = EntryReadOnly("test")
        assert str(e) == "test"


# ---------------------------------------------------------------------------
# run_cli: REPL-based I/O
# ---------------------------------------------------------------------------

class TestVaultRunCli:

    async def test_run_cli_returns_stdout(self, test_config, mock_yubikey):
        """run_cli strips the trailing REPL prompt and returns decoded output."""
        from server.vault import Vault

        vault = Vault(test_config, mock_yubikey)
        vault._unlocked = True
        vault._repl_proc = _mock_repl_proc([_repl_resp(b"Group1/\nGroup2/\n")])
        result = await vault.run_cli("ls", test_config.database_path)
        assert "Group1/" in result


    async def test_run_cli_strips_command_echo(self, test_config, mock_yubikey):
        """Real keepassxc-cli echoes the command text; run_cli strips it."""
        from server.vault import Vault

        vault = Vault(test_config, mock_yubikey)
        vault._unlocked = True
        # Simulate keepassxc-cli echoing "ls" as the first output line
        vault._repl_proc = _mock_repl_proc([_repl_resp(b"ls\nGroup1/\n")])
        result = await vault.run_cli("ls", test_config.database_path)
        # Echo "ls" must be stripped; only actual output returned
        assert result.startswith("Group1/")
        assert not result.startswith("ls")


    async def test_run_cli_strips_echo_only_output(self, test_config, mock_yubikey):
        """Echo with no following output produces empty string (not the echo itself)."""
        from server.vault import Vault

        vault = Vault(test_config, mock_yubikey)
        vault._unlocked = True
        # Simulate a command that only echoes with no output (output == cmd_str)
        vault._repl_proc = _mock_repl_proc([_repl_resp(b"ls")])
        result = await vault.run_cli("ls", test_config.database_path)
        assert result == ""


    async def test_run_cli_raises_on_error(self, test_config, mock_yubikey):
        """Output starting with 'Error:' is converted to KeePassCLIError."""
        from server.vault import KeePassCLIError, Vault

        vault = Vault(test_config, mock_yubikey)
        vault._unlocked = True
        vault._repl_proc = _mock_repl_proc([_repl_resp(b"Error: entry not found\n")])
        with pytest.raises(KeePassCLIError, match="entry not found"):
            await vault.run_cli("show", test_config.database_path, "Nonexistent")


    async def test_run_cli_raises_on_invalid_prefix(self, test_config, mock_yubikey):
        """Output starting with 'Invalid ' is also converted to KeePassCLIError."""
        from server.vault import KeePassCLIError, Vault

        vault = Vault(test_config, mock_yubikey)
        vault._unlocked = True
        vault._repl_proc = _mock_repl_proc([_repl_resp(b"Invalid credentials\n")])
        with pytest.raises(KeePassCLIError, match="Invalid"):
            await vault.run_cli("show", test_config.database_path, "X")


    async def test_run_cli_raises_on_timeout(self, test_config, mock_yubikey):
        """TimeoutError from readuntil wraps to KeePassCLIError (no pcscd hint)."""
        from server.vault import KeePassCLIError, Vault

        vault = Vault(test_config, mock_yubikey)
        vault._unlocked = True
        vault._repl_proc = _mock_repl_proc([asyncio.TimeoutError()])
        with pytest.raises(KeePassCLIError, match="timed out") as exc_info:
            await vault.run_cli("show", test_config.database_path, "Servers/Entry")
        assert "pcscd" not in str(exc_info.value)


    async def test_run_cli_empty_args_raises(self, test_config, mock_yubikey):
        """run_cli() with no args raises KeePassCLIError mentioning 'unknown'."""
        from server.vault import KeePassCLIError, Vault

        vault = Vault(test_config, mock_yubikey)
        vault._unlocked = True
        vault._repl_proc = _mock_repl_proc()
        with pytest.raises(KeePassCLIError, match="unknown"):
            await vault.run_cli()


    async def test_run_cli_strips_db_path_from_repl_args(self, test_config, mock_yubikey):
        """Database path is filtered out before sending to the REPL stdin."""
        from server.vault import Vault

        vault = Vault(test_config, mock_yubikey)
        vault._unlocked = True
        vault._repl_proc = _mock_repl_proc([_repl_resp(b"Servers/\n")])
        await vault.run_cli("ls", test_config.database_path)

        written = vault._repl_proc.stdin.write.call_args[0][0]
        # REPL stdin should receive "ls\n" (not "ls <db_path>\n")
        assert test_config.database_path.encode() not in written
        assert written.startswith(b"ls")


    async def test_repl_interrupted_mid_command_marks_vault_locked(
        self, test_config, mock_yubikey
    ):
        """IncompleteReadError during a command marks the vault as locked."""
        from server.vault import KeePassCLIError, Vault

        vault = Vault(test_config, mock_yubikey)
        vault._unlocked = True
        vault._repl_proc = _mock_repl_proc(
            [asyncio.IncompleteReadError(b"partial", 100)]
        )
        with pytest.raises(KeePassCLIError):
            await vault.run_cli("show", test_config.database_path, "X")

        assert vault.is_unlocked is False
        assert vault._repl_proc is None


    @patch("asyncio.create_subprocess_exec")
    async def test_run_cli_binary_returns_bytes(self, mock_exec, test_config, mock_yubikey):
        """run_cli_binary returns raw bytes, not decoded text."""
        raw = b"\x00\x01\xff\xfe binary data"
        mock_exec.return_value = _mock_async_proc(stdout=raw)
        from server.vault import Vault

        vault = Vault(test_config, mock_yubikey)
        vault._unlocked = True
        result = await vault.run_cli_binary(
            "attachment-export", "--stdout", "db", "path", "file"
        )
        assert result == raw


    async def test_run_cli_binary_raises_when_locked(self, test_config, mock_yubikey):
        from server.vault import Vault, VaultLocked

        vault = Vault(test_config, mock_yubikey)
        with pytest.raises(VaultLocked):
            await vault.run_cli_binary("attachment-export")


    @patch("asyncio.create_subprocess_exec")
    async def test_run_cli_binary_raises_on_nonzero_returncode(
        self, mock_exec, test_config, mock_yubikey
    ):
        """Non-zero exit from run_cli_binary raises KeePassCLIError."""
        mock_exec.return_value = _mock_async_proc(
            stderr=b"Error: not found", returncode=1
        )
        from server.vault import KeePassCLIError, Vault

        vault = Vault(test_config, mock_yubikey)
        vault._unlocked = True
        with pytest.raises(KeePassCLIError, match="not found"):
            await vault.run_cli_binary("attachment-export", "db", "path", "file")


# ---------------------------------------------------------------------------
# entry_path helper
# ---------------------------------------------------------------------------

class TestVaultEntryPath:
    def test_with_group(self, test_config, mock_yubikey):
        from server.vault import Vault

        vault = Vault(test_config, mock_yubikey)
        assert vault.entry_path("My Entry", "Servers") == "Servers/My Entry"

    def test_without_group(self, test_config, mock_yubikey):
        from server.vault import Vault

        vault = Vault(test_config, mock_yubikey)
        assert vault.entry_path("My Entry", None) == "My Entry"


# ---------------------------------------------------------------------------
# Properties
# ---------------------------------------------------------------------------

class TestVaultProperties:

    @patch("asyncio.create_subprocess_exec")
    async def test_unlock_time_set_after_unlock(self, mock_exec, test_config, mock_yubikey):
        """unlock_time is a UTC datetime after successful unlock."""
        from datetime import datetime

        from server.vault import Vault

        mock_exec.return_value = _mock_unlock_proc()
        vault = Vault(test_config, mock_yubikey)
        assert vault.unlock_time is None
        await vault.unlock()
        assert isinstance(vault.unlock_time, datetime)
        assert vault.unlock_time.tzinfo == UTC

    def test_config_property(self, test_config, mock_yubikey):
        from server.vault import Vault

        vault = Vault(test_config, mock_yubikey)
        assert vault.config is test_config
        assert vault.config.database_path == test_config.database_path


# ---------------------------------------------------------------------------
# Lock behaviour
# ---------------------------------------------------------------------------

class TestVaultLock:
    async def test_lock_resets_unlocked_flag(self, test_config, mock_yubikey):
        from server.vault import Vault

        vault = Vault(test_config, mock_yubikey)
        vault._unlocked = True
        await vault.lock()
        assert vault.is_unlocked is False

    async def test_lock_kills_repl_proc(self, test_config, mock_yubikey):
        """lock() kills the REPL process and clears the reference."""
        from server.vault import Vault

        vault = Vault(test_config, mock_yubikey)
        vault._unlocked = True
        mock_proc = MagicMock()
        mock_proc.wait = AsyncMock(return_value=None)
        vault._repl_proc = mock_proc

        await vault.lock()

        mock_proc.kill.assert_called_once()
        assert vault._repl_proc is None

    async def test_lock_cancels_stderr_drain_task(self, test_config, mock_yubikey):
        """lock() cancels the stderr drain task."""
        from server.vault import Vault

        vault = Vault(test_config, mock_yubikey)
        vault._unlocked = True
        drain_task = asyncio.create_task(asyncio.sleep(100))
        vault._stderr_drain_task = drain_task

        await vault.lock()

        assert drain_task.cancelled()
        assert vault._stderr_drain_task is None

    async def test_lock_noop_when_no_repl_proc(self, test_config, mock_yubikey):
        """lock() is safe when _repl_proc is None (already locked)."""
        from server.vault import Vault

        vault = Vault(test_config, mock_yubikey)
        vault._unlocked = True
        await vault.lock()  # _repl_proc is None, should not raise
        assert vault.is_unlocked is False


# ---------------------------------------------------------------------------
# Grace timer
# ---------------------------------------------------------------------------

class TestVaultGraceTimer:

    async def test_lock_after_grace_period(self, test_config):
        from server.vault import Vault

        yk = MockYubiKey(present=True)
        vault = Vault(test_config, yk)
        vault._unlocked = True

        poll_task = asyncio.create_task(vault.start_polling())
        await asyncio.sleep(0.1)
        yk.present = False
        # grace_period_seconds=2 in test_config; poll_interval=1
        await asyncio.sleep(3.5)
        assert vault.is_unlocked is False
        poll_task.cancel()
        with contextlib.suppress(asyncio.CancelledError):
            await poll_task


    async def test_reinsertion_cancels_grace(self, test_config):
        """Grace timer is cancelled when YubiKey is reinserted before expiry.

        Timing: poll_interval=1s, grace=2s.
        - Remove key at 0.1s; first poll at ~1s sees absent → starts grace timer.
        - Restore key at 1.3s; second poll at ~2s sees present → cancels grace timer.
        - Vault stays unlocked despite the brief absence.
        """
        from server.vault import Vault

        yk = MockYubiKey(present=True)
        vault = Vault(test_config, yk)
        vault._unlocked = True

        poll_task = asyncio.create_task(vault.start_polling())
        await asyncio.sleep(0.1)
        yk.present = False
        await asyncio.sleep(1.3)  # first poll (at ~1s) sees key absent → grace starts
        yk.present = True
        await asyncio.sleep(1.5)  # second poll (at ~2s) sees key present → grace cancels
        assert vault.is_unlocked is True
        poll_task.cancel()
        with contextlib.suppress(asyncio.CancelledError):
            await poll_task


    async def test_cancel_polling_during_grace_timer(self, test_config):
        """Cancelling poll task while grace timer is active cleans up both tasks."""
        from server.vault import Vault

        yk = MockYubiKey(present=True)
        vault = Vault(test_config, yk)
        vault._unlocked = True

        poll_task = asyncio.create_task(vault.start_polling())
        await asyncio.sleep(0.1)
        yk.present = False
        await asyncio.sleep(1.5)
        assert vault._grace_timer is not None
        poll_task.cancel()
        with contextlib.suppress(asyncio.CancelledError):
            await poll_task
        assert vault.is_unlocked is True


    async def test_poll_noop_when_locked_and_yubikey_removed(self, test_config):
        """No grace timer starts when vault is already locked."""
        from server.vault import Vault

        yk = MockYubiKey(present=False)
        vault = Vault(test_config, yk)
        poll_task = asyncio.create_task(vault.start_polling())
        await asyncio.sleep(1.5)
        assert vault._grace_timer is None
        assert vault.is_unlocked is False
        poll_task.cancel()
        with contextlib.suppress(asyncio.CancelledError):
            await poll_task


    async def test_polling_exception_logged_and_loop_continues(self, test_config):
        """An unexpected exception in is_present is logged and polling continues."""
        from server.vault import Vault

        call_count = 0

        def flaky_is_present() -> bool:
            nonlocal call_count
            call_count += 1
            if call_count == 1:
                raise OSError("USB read error")
            return True  # subsequent calls succeed

        yk = MockYubiKey(present=True)
        yk.is_present = flaky_is_present  # type: ignore[method-assign]
        vault = Vault(test_config, yk)
        vault._unlocked = True

        poll_task = asyncio.create_task(vault.start_polling())
        await asyncio.sleep(2.2)  # two poll cycles: error then success
        poll_task.cancel()
        with contextlib.suppress(asyncio.CancelledError):
            await poll_task

        # Loop survived the exception — vault is still unlocked (key returned True)
        assert vault.is_unlocked is True


# ---------------------------------------------------------------------------
# REPL quoting helpers
# ---------------------------------------------------------------------------

class TestReplQuoting:
    """_repl_quote and _repl_join use Qt-style (double-quote) argument quoting.

    Qt's QProcess::splitCommand understands double quotes but NOT single quotes.
    shlex.join() emits single quotes for strings with spaces, which the REPL
    silently ignores — causing entries with spaces to silently fail.
    """

    def test_plain_arg_unquoted(self):
        from server.vault import _repl_quote
        assert _repl_quote("ls") == "ls"

    def test_arg_with_space_double_quoted(self):
        from server.vault import _repl_quote
        assert _repl_quote("New Test Entry") == '"New Test Entry"'

    def test_empty_arg_double_quoted(self):
        from server.vault import _repl_quote
        assert _repl_quote("") == '""'

    def test_arg_with_double_quote_escaped(self):
        from server.vault import _repl_quote
        assert _repl_quote('say "hi"') == '"say \\"hi\\""'

    def test_arg_with_backslash_escaped(self):
        from server.vault import _repl_quote
        assert _repl_quote("a\\b") == '"a\\\\b"'

    def test_join_plain_args(self):
        from server.vault import _repl_join
        assert _repl_join(["ls", "Servers"]) == "ls Servers"

    def test_join_arg_with_spaces(self):
        from server.vault import _repl_join
        result = _repl_join(["add", "Servers/New Test Entry", "--username", "u"])
        assert result == 'add "Servers/New Test Entry" --username u'


# ---------------------------------------------------------------------------
# run_cli: stdin_lines for interactive prompts
# ---------------------------------------------------------------------------

class TestRunCliStdinLines:

    async def test_stdin_lines_written_before_drain(self, test_config, mock_yubikey):
        """stdin_lines are written to stdin before the drain() call."""
        from server.vault import Vault

        vault = Vault(test_config, mock_yubikey)
        vault._unlocked = True
        vault._repl_proc = _mock_repl_proc([_repl_resp(b"Successfully added entry X.\n")])

        written_calls = []
        vault._repl_proc.stdin.write = lambda data: written_calls.append(data)

        await vault.run_cli("add", test_config.database_path, "Servers/X", "-p",
                            stdin_lines=["mysecret"])

        # First call is the command, second is the password line
        assert len(written_calls) == 2
        assert written_calls[0].startswith(b"add")
        assert written_calls[1] == b"mysecret\n"


    async def test_stdin_lines_multiple(self, test_config, mock_yubikey):
        """Multiple stdin_lines are all written in order."""
        from server.vault import Vault

        vault = Vault(test_config, mock_yubikey)
        vault._unlocked = True
        vault._repl_proc = _mock_repl_proc([_repl_resp(b"Done.\n")])

        written_calls = []
        vault._repl_proc.stdin.write = lambda data: written_calls.append(data)

        await vault.run_cli("cmd", test_config.database_path, stdin_lines=["line1", "line2"])

        assert written_calls[1] == b"line1\n"
        assert written_calls[2] == b"line2\n"


# ---------------------------------------------------------------------------
# run_cli: REPL proc None guard
# ---------------------------------------------------------------------------

class TestVaultReplProcNoneGuard:

    async def test_run_cli_raises_when_repl_proc_is_none_despite_unlocked(
        self, test_config, mock_yubikey
    ):
        """run_cli raises VaultLocked when _unlocked is True but _repl_proc is None.

        This can happen if the REPL died mid-command and _repl_proc was cleared,
        but _unlocked was separately set (a transient inconsistency).
        """
        from server.vault import Vault, VaultLocked

        vault = Vault(test_config, mock_yubikey)
        vault._unlocked = True
        vault._repl_proc = None  # proc is gone but flag was not cleared
        with pytest.raises(VaultLocked, match="REPL process is not running"):
            await vault.run_cli("ls", test_config.database_path)


# ---------------------------------------------------------------------------
# _drain_stderr exception handling
# ---------------------------------------------------------------------------

class TestDrainStderr:

    async def test_drain_stderr_exception_is_swallowed(self, test_config, mock_yubikey):
        """_drain_stderr catches any exception and exits silently (keeps REPL alive)."""
        from server.vault import Vault

        vault = Vault(test_config, mock_yubikey)
        proc = MagicMock()
        proc.stderr = MagicMock()
        proc.stderr.readline = AsyncMock(side_effect=OSError("pipe broken"))

        # Should complete without raising
        await vault._drain_stderr(proc)


    async def test_drain_stderr_exits_on_empty_line(self, test_config, mock_yubikey):
        """_drain_stderr stops when readline() returns empty bytes (EOF)."""
        from server.vault import Vault

        vault = Vault(test_config, mock_yubikey)
        proc = MagicMock()
        proc.stderr = MagicMock()
        proc.stderr.readline = AsyncMock(side_effect=[b"some log line\n", b""])

        await vault._drain_stderr(proc)  # must terminate, not loop forever
