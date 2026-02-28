"""Structured audit logging for vault operations.

Writes one JSON record per line to the configured audit log path.
Secret values and attachment content are never logged.
"""

from __future__ import annotations

import json
from datetime import UTC, datetime
from pathlib import Path

import structlog

log: structlog.stdlib.BoundLogger = structlog.get_logger("keepass-cred-mgr.audit")


class AuditLogger:
    def __init__(self, audit_log_path: str) -> None:
        path = Path(audit_log_path)
        if not path.parent.exists():
            raise FileNotFoundError(
                f"Audit log parent directory does not exist: {path.parent}"
            )
        self._path = path

    def log(
        self,
        *,
        tool: str,
        title: str,
        group: str | None = None,
        secret_returned: bool = False,
        attachment: str | None = None,
    ) -> None:
        record = {
            "timestamp": datetime.now(UTC).isoformat(),
            "tool": tool,
            "title": title,
            "group": group,
            "secret_returned": secret_returned,
            "attachment": attachment,
        }
        try:
            with open(self._path, "a") as f:
                f.write(json.dumps(record) + "\n")
        except OSError:
            log.warning("audit_write_failed", path=str(self._path), tool=tool)
