import subprocess
from unittest.mock import patch

import pytest

pytestmark = pytest.mark.unit


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

    @patch("subprocess.run")
    def test_not_present_on_os_error(self, mock_run):
        """OSError (e.g., ykman not installed) returns False."""
        from server.yubikey import RealYubiKey

        mock_run.side_effect = OSError("No such file or directory")
        yk = RealYubiKey(slot=2)
        assert yk.is_present() is False

    @patch("subprocess.run")
    def test_non_zero_returncode_with_stdout(self, mock_run):
        """Non-zero returncode with stdout still returns True (stdout check only)."""
        from server.yubikey import RealYubiKey

        mock_run.return_value = subprocess.CompletedProcess(
            args=[], returncode=1, stdout="YubiKey 5C Nano\n", stderr="warning"
        )
        yk = RealYubiKey(slot=2)
        # The code checks bool(stdout.strip()), not returncode
        assert yk.is_present() is True


class TestYubiKeyInterface:
    def test_mock_implements_interface(self):
        from server.yubikey import MockYubiKey, YubiKeyInterface

        yk = MockYubiKey()
        assert isinstance(yk, YubiKeyInterface)

    def test_real_implements_interface(self):
        from server.yubikey import RealYubiKey, YubiKeyInterface

        yk = RealYubiKey(slot=2)
        assert isinstance(yk, YubiKeyInterface)
