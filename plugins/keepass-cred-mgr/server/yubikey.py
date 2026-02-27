"""YubiKey presence detection interface.

Uses `ykman list` for polling, NOT keepassxc-cli (which requires touch every call).
Treat any subprocess error as "not present" to avoid blocking the polling loop.
"""

from __future__ import annotations

import subprocess
from abc import ABC, abstractmethod


class YubiKeyInterface(ABC):
    @abstractmethod
    def is_present(self) -> bool: ...

    @abstractmethod
    def slot(self) -> int: ...


class RealYubiKey(YubiKeyInterface):
    def __init__(self, slot: int = 2) -> None:
        self._slot = slot

    def is_present(self) -> bool:
        try:
            result = subprocess.run(
                ["ykman", "list"], capture_output=True, text=True, timeout=5
            )
            return bool(result.stdout.strip())
        except (subprocess.SubprocessError, subprocess.TimeoutExpired, OSError):
            return False

    def slot(self) -> int:
        return self._slot


class MockYubiKey(YubiKeyInterface):
    def __init__(self, present: bool = True, slot: int = 2) -> None:
        self.present = present
        self._slot = slot

    def is_present(self) -> bool:
        return self.present

    def slot(self) -> int:
        return self._slot
