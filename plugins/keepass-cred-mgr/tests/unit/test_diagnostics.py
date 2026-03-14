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
    def test_subprocess_failure_falls_through_gracefully(self, mock_run):
        """When subprocess fails, pcscd and hidraw checks skip; serial check still runs."""
        from server.diagnostics import diagnose_unlock_failure

        # With serial in config, all checks produce no match → empty
        result = diagnose_unlock_failure(_make_config(yubikey_slot="2:36834370"))
        assert result == ""

    @patch("subprocess.run", side_effect=subprocess.TimeoutExpired("cmd", 5))
    def test_subprocess_timeout_falls_through_gracefully(self, mock_run):
        """When subprocess times out, pcscd and hidraw checks skip; serial check still runs."""
        from server.diagnostics import diagnose_unlock_failure

        result = diagnose_unlock_failure(_make_config(yubikey_slot="2:36834370"))
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
