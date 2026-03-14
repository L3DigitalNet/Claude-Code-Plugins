"""YubiKey presence detection interface.

Uses `ykman list` for polling, NOT keepassxc-cli (which requires touch every call).
Treat any subprocess error as "not present" to avoid blocking the polling loop.
"""

from __future__ import annotations

import subprocess
from typing import Protocol, runtime_checkable


@runtime_checkable
class YubiKeyInterface(Protocol):
    def is_present(self) -> bool: ...

    def slot(self) -> str: ...


class RealYubiKey(YubiKeyInterface):
    def __init__(self, slot: str = "2") -> None:
        self._slot = slot

    def is_present(self) -> bool:
        try:
            result = subprocess.run(
                ["ykman", "list"], capture_output=True, text=True, timeout=5
            )
            return bool(result.stdout.strip())
        except (subprocess.SubprocessError, subprocess.TimeoutExpired, OSError):
            return False

    def slot(self) -> str:
        return self._slot


class MockYubiKey(YubiKeyInterface):
    def __init__(self, present: bool = True, slot: str = "2") -> None:
        self.present = present
        self._slot = slot

    def is_present(self) -> bool:
        return self.present

    def slot(self) -> str:
        return self._slot
