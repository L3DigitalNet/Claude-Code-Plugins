"""Configuration loader for keepass-cred-mgr.

Reads YAML config from a file path or the KEEPASS_CRED_MGR_CONFIG env var.
Required fields: database_path, allowed_groups, audit_log_path.
Optional fields get defaults (see Config dataclass).
"""

from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path

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


_REQUIRED_FIELDS = ("database_path", "allowed_groups", "audit_log_path")


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

    # Expand ~ in path fields
    for key in ("database_path", "audit_log_path"):
        if key in raw and isinstance(raw[key], str):
            raw[key] = os.path.expanduser(raw[key])

    return Config(
        database_path=raw["database_path"],
        allowed_groups=raw["allowed_groups"],
        audit_log_path=raw["audit_log_path"],
        yubikey_slot=raw.get("yubikey_slot", 2),
        grace_period_seconds=raw.get("grace_period_seconds", 10),
        yubikey_poll_interval_seconds=raw.get("yubikey_poll_interval_seconds", 5),
        write_lock_timeout_seconds=raw.get("write_lock_timeout_seconds", 10),
        page_size=raw.get("page_size", 50),
    )
