"""Configuration loader for keepass-cred-mgr.

Reads YAML config from a file path or the KEEPASS_CRED_MGR_CONFIG env var.
Required fields: database_path, allowed_groups, audit_log_path.
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
    allowed_groups: list[str]
    audit_log_path: str
    yubikey_slot: int = 2
    grace_period_seconds: int = 10
    yubikey_poll_interval_seconds: int = 5
    write_lock_timeout_seconds: int = 10
    page_size: int = 50
    log_level: str = "INFO"


_REQUIRED_FIELDS = ("database_path", "allowed_groups", "audit_log_path")

# Single source of truth for optional field defaults — mirrors the dataclass
_DEFAULTS: dict[str, int | str] = {
    "yubikey_slot": 2,
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

    groups = raw["allowed_groups"]
    if not isinstance(groups, list) or not all(isinstance(g, str) for g in groups):
        raise ValueError("Config field 'allowed_groups' must be a list of strings")

    for key in ("yubikey_slot", "grace_period_seconds", "yubikey_poll_interval_seconds",
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

    # Apply defaults for optional fields
    for key, default in _DEFAULTS.items():
        raw.setdefault(key, default)

    return Config(
        database_path=raw["database_path"],
        allowed_groups=raw["allowed_groups"],
        audit_log_path=raw["audit_log_path"],
        yubikey_slot=raw["yubikey_slot"],
        grace_period_seconds=raw["grace_period_seconds"],
        yubikey_poll_interval_seconds=raw["yubikey_poll_interval_seconds"],
        write_lock_timeout_seconds=raw["write_lock_timeout_seconds"],
        page_size=raw["page_size"],
        log_level=raw["log_level"],
    )
