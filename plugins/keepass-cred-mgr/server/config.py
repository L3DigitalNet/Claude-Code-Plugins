"""Configuration loader for keepass-cred-mgr.

Reads YAML config from a file path or the KEEPASS_CRED_MGR_CONFIG env var.
Required fields: database_path, audit_log_path.
Optional fields get defaults (see Config dataclass).
"""

from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import yaml


@dataclass(frozen=True)
class Config:
    database_path: str
    audit_log_path: str
    yubikey_slot: str
    grace_period_seconds: int
    yubikey_poll_interval_seconds: int
    write_lock_timeout_seconds: int
    page_size: int
    log_level: str


_REQUIRED_FIELDS = ("database_path", "audit_log_path")

# Defaults for optional fields — applied by load_config() before constructing Config.
_DEFAULTS: dict[str, int | str] = {
    "yubikey_slot": "2",
    "grace_period_seconds": 10,
    "yubikey_poll_interval_seconds": 5,
    "write_lock_timeout_seconds": 10,
    "page_size": 50,
    "log_level": "INFO",
}

_VALID_LOG_LEVELS = {"DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"}


def _validate_config(raw: dict[str, Any]) -> None:
    """Type-check config values before constructing the frozen dataclass."""
    for key in ("database_path", "audit_log_path"):
        if not isinstance(raw[key], str):
            actual = type(raw[key]).__name__
            raise ValueError(f"Config field '{key}' must be a string, got {actual}")

    # yubikey_slot accepts "slot" or "slot:serial" (e.g., "2" or "2:36834370").
    # Integer values from YAML are coerced to str for backward compatibility.
    yk_slot = raw.get("yubikey_slot")
    if yk_slot is not None:
        raw["yubikey_slot"] = str(yk_slot)
        slot_str = raw["yubikey_slot"]
        parts = slot_str.split(":", 1)
        if not parts[0].isdigit() or int(parts[0]) < 1:
            raise ValueError(
                f"Config field 'yubikey_slot' must be 'slot' or 'slot:serial', got '{slot_str}'"
            )

    for key in ("grace_period_seconds", "yubikey_poll_interval_seconds",
                "write_lock_timeout_seconds", "page_size"):
        val = raw.get(key)
        if val is not None:
            if not isinstance(val, int):
                actual = type(val).__name__
                raise ValueError(f"Config field '{key}' must be an integer, got {actual}")
            if val < 1:
                raise ValueError(f"Config field '{key}' must be >= 1, got {val}")

    log_level = raw.get("log_level")
    if log_level is not None and log_level not in _VALID_LOG_LEVELS:
        raise ValueError(
            f"Config field 'log_level' must be one of {_VALID_LOG_LEVELS}, got '{log_level}'"
        )


def load_config(path: str | None = None) -> Config:
    if path is None:
        path = os.environ.get("KEEPASS_CRED_MGR_CONFIG")
    if path is None:
        raise FileNotFoundError(
            "No config path provided and KEEPASS_CRED_MGR_CONFIG is not set"
        )

    config_path = Path(path)
    if not config_path.exists():
        raise FileNotFoundError(f"Config file not found: {config_path}")

    with open(config_path) as f:
        raw = yaml.safe_load(f) or {}

    for field_name in _REQUIRED_FIELDS:
        if field_name not in raw:
            raise ValueError(f"Missing required config field: {field_name}")

    _validate_config(raw)

    # Expand ~ in path fields
    for key in ("database_path", "audit_log_path"):
        if isinstance(raw[key], str):
            raw[key] = os.path.expanduser(raw[key])

    # Fail fast on wrong database path — a missing file produces a confusing
    # keepassxc-cli error at first unlock rather than a clear config error.
    db_path = Path(raw["database_path"])
    if not db_path.exists():
        raise FileNotFoundError(
            f"KeePass database not found: {raw['database_path']}"
        )

    # Apply defaults for optional fields
    for key, default in _DEFAULTS.items():
        raw.setdefault(key, default)

    return Config(
        database_path=raw["database_path"],
        audit_log_path=raw["audit_log_path"],
        yubikey_slot=raw["yubikey_slot"],
        grace_period_seconds=raw["grace_period_seconds"],
        yubikey_poll_interval_seconds=raw["yubikey_poll_interval_seconds"],
        write_lock_timeout_seconds=raw["write_lock_timeout_seconds"],
        page_size=raw["page_size"],
        log_level=raw["log_level"],
    )
