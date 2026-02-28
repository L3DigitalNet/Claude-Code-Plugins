import asyncio
import contextlib
from datetime import UTC
from unittest.mock import AsyncMock, patch

import pytest

from server.yubikey import MockYubiKey


def _mock_async_proc(stdout: bytes = b"", stderr: bytes = b"", returncode: int = 0) -> AsyncMock:
    """Create a mock async subprocess process."""
    proc = AsyncMock()
    proc.communicate.return_value = (stdout, stderr)
    proc.returncode = returncode
    return proc


class TestVaultExceptions:
    def test_all_exceptions_exist(self):
        from server.vault import (
            DuplicateEntry,
            EntryInactive,
            EntryNotFound,
            GroupNotAllowed,
            KeePassCLIError,
            VaultLocked,
            WriteLockTimeout,
            YubiKeyNotPresent,
        )
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

    @pytest.mark.asyncio
    async def test_unlock_raises_when_yubikey_absent(self, test_config):
        from server.vault import Vault, YubiKeyNotPresent

        yk = MockYubiKey(present=False)
        vault = Vault(test_config, yk)
        with pytest.raises(YubiKeyNotPresent):
            await vault.unlock()

    @pytest.mark.asyncio
    @patch("asyncio.create_subprocess_exec")
    async def test_unlock_succeeds_with_yubikey(self, mock_exec, test_config, mock_yubikey):
        mock_exec.return_value = _mock_async_proc()
        from server.vault import Vault

        vault = Vault(test_config, mock_yubikey)
        await vault.unlock()
        assert vault.is_unlocked is True

    @pytest.mark.asyncio
    @patch("asyncio.create_subprocess_exec")
    async def test_unlock_raises_on_cli_error(self, mock_exec, test_config, mock_yubikey):
        mock_exec.return_value = _mock_async_proc(
            stderr=b"Error: Invalid credentials", returncode=1
        )
        from server.vault import KeePassCLIError, Vault

        vault = Vault(test_config, mock_yubikey)
        with pytest.raises(KeePassCLIError):
            await vault.unlock()

    @pytest.mark.asyncio
    async def test_run_cli_raises_when_locked(self, test_config, mock_yubikey):
        from server.vault import Vault, VaultLocked

        vault = Vault(test_config, mock_yubikey)
        with pytest.raises(VaultLocked):
            await vault.run_cli("ls", test_config.database_path)


class TestVaultGroupAllowlist:
    def test_check_group_allowed(self, test_config, mock_yubikey):
        from server.vault import Vault

        vault = Vault(test_config, mock_yubikey)
        vault._unlocked = True
        vault.check_group_allowed("Servers")  # Should not raise

    def test_check_group_not_allowed(self, test_config, mock_yubikey):
        from server.vault import GroupNotAllowed, Vault

        vault = Vault(test_config, mock_yubikey)
        vault._unlocked = True
        with pytest.raises(GroupNotAllowed):
            vault.check_group_allowed("Banking")


class TestVaultRunCli:
    @pytest.mark.asyncio
    @patch("asyncio.create_subprocess_exec")
    async def test_run_cli_returns_stdout(self, mock_exec, test_config, mock_yubikey):
        mock_exec.return_value = _mock_async_proc(stdout=b"Group1/\nGroup2/\n")
        from server.vault import Vault

        vault = Vault(test_config, mock_yubikey)
        vault._unlocked = True
        result = await vault.run_cli("ls", test_config.database_path)
        assert "Group1/" in result

    @pytest.mark.asyncio
    @patch("asyncio.create_subprocess_exec")
    async def test_run_cli_raises_on_error(self, mock_exec, test_config, mock_yubikey):
        mock_exec.return_value = _mock_async_proc(
            stderr=b"Error: entry not found", returncode=1
        )
        from server.vault import KeePassCLIError, Vault

        vault = Vault(test_config, mock_yubikey)
        vault._unlocked = True
        with pytest.raises(KeePassCLIError):
            await vault.run_cli("show", test_config.database_path, "Nonexistent")

    @pytest.mark.asyncio
    @patch("asyncio.create_subprocess_exec")
    async def test_run_cli_raises_on_timeout(self, mock_exec, test_config, mock_yubikey):
        """asyncio.wait_for raises TimeoutError when subprocess exceeds timeout."""
        mock_proc = AsyncMock()
        mock_proc.communicate = AsyncMock(side_effect=asyncio.TimeoutError)
        mock_exec.return_value = mock_proc
        from server.vault import Vault

        vault = Vault(test_config, mock_yubikey)
        vault._unlocked = True
        with pytest.raises(TimeoutError):
            await vault.run_cli("show", test_config.database_path, "Servers/Entry")

    @pytest.mark.asyncio
    async def test_run_cli_no_args_error_message(self, test_config, mock_yubikey):
        """Error message uses 'unknown' when run_cli is called with no args."""
        from server.vault import KeePassCLIError, Vault

        vault = Vault(test_config, mock_yubikey)
        vault._unlocked = True
        with patch("asyncio.create_subprocess_exec") as mock_exec:
            mock_exec.return_value = _mock_async_proc(stderr=b"error", returncode=1)
            with pytest.raises(KeePassCLIError, match="unknown"):
                await vault.run_cli()

    @pytest.mark.asyncio
    @patch("asyncio.create_subprocess_exec")
    async def test_run_cli_binary_returns_bytes(self, mock_exec, test_config, mock_yubikey):
        """run_cli_binary returns raw bytes, not decoded text."""
        raw = b"\x00\x01\xff\xfe binary data"
        mock_exec.return_value = _mock_async_proc(stdout=raw)
        from server.vault import Vault

        vault = Vault(test_config, mock_yubikey)
        vault._unlocked = True
        result = await vault.run_cli_binary("attachment-export", "--stdout", "db", "path", "file")
        assert result == raw

    @pytest.mark.asyncio
    async def test_run_cli_binary_raises_when_locked(self, test_config, mock_yubikey):
        from server.vault import Vault, VaultLocked

        vault = Vault(test_config, mock_yubikey)
        with pytest.raises(VaultLocked):
            await vault.run_cli_binary("attachment-export")


class TestVaultEntryPath:
    def test_with_group(self, test_config, mock_yubikey):
        from server.vault import Vault

        vault = Vault(test_config, mock_yubikey)
        assert vault.entry_path("My Entry", "Servers") == "Servers/My Entry"

    def test_without_group(self, test_config, mock_yubikey):
        from server.vault import Vault

        vault = Vault(test_config, mock_yubikey)
        assert vault.entry_path("My Entry", None) == "My Entry"


class TestVaultProperties:
    @pytest.mark.asyncio
    @patch("asyncio.create_subprocess_exec")
    async def test_unlock_time_set_after_unlock(self, mock_exec, test_config, mock_yubikey):
        """unlock_time is a UTC datetime after successful unlock."""
        from datetime import datetime

        from server.vault import Vault

        mock_exec.return_value = _mock_async_proc()
        vault = Vault(test_config, mock_yubikey)
        assert vault.unlock_time is None
        await vault.unlock()
        assert isinstance(vault.unlock_time, datetime)
        assert vault.unlock_time.tzinfo == UTC

    def test_config_property(self, test_config, mock_yubikey):
        """config property returns the Config object."""
        from server.vault import Vault

        vault = Vault(test_config, mock_yubikey)
        assert vault.config is test_config
        assert vault.config.database_path == test_config.database_path


class TestVaultLock:
    def test_lock_resets_state(self, test_config, mock_yubikey):
        """_lock() sets is_unlocked to False."""
        from server.vault import Vault

        vault = Vault(test_config, mock_yubikey)
        vault._unlocked = True
        assert vault.is_unlocked is True
        vault._lock()
        assert vault.is_unlocked is False


class TestVaultGraceTimer:
    @pytest.mark.asyncio
    async def test_lock_after_grace_period(self, test_config):
        from server.vault import Vault

        yk = MockYubiKey(present=True)
        vault = Vault(test_config, yk)
        vault._unlocked = True

        assert vault.is_unlocked is True

        poll_task = asyncio.create_task(vault.start_polling())
        await asyncio.sleep(0.1)
        yk.present = False
        # Grace period is 2s in test_config — wait for it plus buffer
        await asyncio.sleep(3)
        assert vault.is_unlocked is False
        poll_task.cancel()
        with contextlib.suppress(asyncio.CancelledError):
            await poll_task

    @pytest.mark.asyncio
    async def test_reinsertion_cancels_grace(self, test_config):
        from server.vault import Vault

        yk = MockYubiKey(present=True)
        vault = Vault(test_config, yk)
        vault._unlocked = True

        poll_task = asyncio.create_task(vault.start_polling())
        await asyncio.sleep(0.1)
        yk.present = False
        await asyncio.sleep(0.5)  # Within grace period
        yk.present = True  # Reinsert before grace expires
        await asyncio.sleep(2)  # Wait past original grace period
        assert vault.is_unlocked is True  # Should still be unlocked
        poll_task.cancel()
        with contextlib.suppress(asyncio.CancelledError):
            await poll_task

    @pytest.mark.asyncio
    async def test_cancel_polling_during_grace_timer(self, test_config):
        """Cancelling poll task while grace timer is active cleans up both tasks."""
        from server.vault import Vault

        yk = MockYubiKey(present=True)
        vault = Vault(test_config, yk)
        vault._unlocked = True

        poll_task = asyncio.create_task(vault.start_polling())
        await asyncio.sleep(0.1)
        yk.present = False
        # Wait for poll to detect removal and start grace timer (poll interval=1s)
        await asyncio.sleep(1.5)
        assert vault._grace_timer is not None
        # Cancel polling while grace timer is mid-countdown (grace=2s, ~0.5s left)
        poll_task.cancel()
        with contextlib.suppress(asyncio.CancelledError):
            await poll_task
        # Vault should still be unlocked (grace didn't finish)
        assert vault.is_unlocked is True

    @pytest.mark.asyncio
    async def test_poll_noop_when_locked_and_yubikey_removed(self, test_config):
        """No grace timer starts when vault is already locked."""
        from server.vault import Vault

        yk = MockYubiKey(present=False)
        vault = Vault(test_config, yk)
        # Vault starts locked, YubiKey absent
        poll_task = asyncio.create_task(vault.start_polling())
        await asyncio.sleep(1.5)
        assert vault._grace_timer is None
        assert vault.is_unlocked is False
        poll_task.cancel()
        with contextlib.suppress(asyncio.CancelledError):
            await poll_task
