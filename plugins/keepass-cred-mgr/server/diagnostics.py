"""YubiKey unlock failure diagnostics.

Called from vault.unlock() on any unlock error. Checks pcscd status, hidraw
device presence, and slot:serial config. Returns a human-readable diagnostic
string, or empty string if no diagnosis matches.
"""

from __future__ import annotations

import glob
import os
import subprocess
from collections.abc import Callable

import structlog

from server.config import Config

log: structlog.stdlib.BoundLogger = structlog.get_logger("keepass-cred-mgr.diagnostics")

_SUBPROCESS_TIMEOUT = 5


def _check_pcscd() -> str | None:
    """Return diagnostic message if pcscd is active, None otherwise."""
    try:
        result = subprocess.run(
            ["systemctl", "is-active", "pcscd"],
            capture_output=True, text=True, timeout=_SUBPROCESS_TIMEOUT,
        )
        if result.returncode == 0:
            return (
                "pcscd (PC/SC Smart Card Daemon) is running and holds an exclusive lock "
                "on the YubiKey CCID interface, blocking HMAC-SHA1 challenge-response. "
                "Fix: sudo systemctl stop pcscd pcscd.socket && "
                "sudo systemctl mask pcscd.socket"
            )
    except (OSError, subprocess.TimeoutExpired):
        log.debug("diagnostics_pcscd_check_skipped", reason="subprocess failed")
    return None


def _check_hidraw() -> str | None:
    """Return diagnostic message if YubiKey OTP hidraw device is missing, None otherwise."""
    try:
        hidraw_nodes = glob.glob("/dev/hidraw*")
        for node in hidraw_nodes:
            result = subprocess.run(
                ["udevadm", "info", f"--name={node}"],
                capture_output=True, text=True, timeout=_SUBPROCESS_TIMEOUT,
            )
            if result.returncode != 0:
                continue
            stdout = result.stdout
            is_yubico = "ID_VENDOR=Yubico" in stdout or "ID_VENDOR_ID=1050" in stdout
            is_otp_interface = "ID_USB_INTERFACE_NUM=00" in stdout
            if is_yubico and is_otp_interface:
                if not os.access(node, os.R_OK):
                    break  # node exists but not readable — treat as missing
                return None  # OTP interface found and accessible
    except (OSError, subprocess.TimeoutExpired):
        log.debug("diagnostics_hidraw_check_skipped", reason="subprocess failed")
        return None

    return (
        "YubiKey OTP HID device not found (/dev/hidraw* has no Yubico interface 00 node). "
        "The device node may have disappeared after a failed access attempt. "
        "Fix: identify the USB bus ID with 'lsusb -d 1050:' then run: "
        "echo <BUS-ID> | sudo tee /sys/bus/usb/drivers/usb/unbind && sleep 1 && "
        "echo <BUS-ID> | sudo tee /sys/bus/usb/drivers/usb/bind"
    )


def _check_serial(config: Config) -> str | None:
    """Return diagnostic if config uses slot-only format (no serial), None otherwise."""
    if ":" not in config.yubikey_slot:
        return (
            "yubikey_slot is set to slot-only format without a serial number. "
            "Some systems cannot auto-detect the serial without pcscd. "
            "Find your serial with: ykman list --serials  "
            "Then set yubikey_slot to \"<slot>:<serial>\" in config "
            "(e.g., \"2:36834370\")"
        )
    return None


def diagnose_unlock_failure(config: Config) -> str:
    """Run sequential diagnostics and return the first matching message.

    Returns empty string if no diagnosis matches.
    """
    checks: list[tuple[str, Callable[[], str | None]]] = [
        ("pcscd", _check_pcscd),
        ("hidraw", _check_hidraw),
        ("serial", lambda: _check_serial(config)),
    ]
    for name, check in checks:
        try:
            result = check()
            if result is not None:
                return result
        except Exception:
            log.debug("diagnostics_check_failed", check=name)
            continue
    return ""
