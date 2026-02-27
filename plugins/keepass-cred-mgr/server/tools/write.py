"""Write vault tools.

All write operations acquire a FileLock on the database before executing.
Temp files for attachment import are overwritten with zeros then unlinked.
"""

from __future__ import annotations

import logging
import os
import stat
import sys
import tempfile
from datetime import UTC, datetime

from filelock import FileLock, Timeout

from server.audit import AuditLogger
from server.vault import (
    INACTIVE_PREFIX,
    DuplicateEntry,
    EntryInactive,
    Vault,
    WriteLockTimeout,
)

logger = logging.getLogger("keepass-cred-mgr.tools.write")
logger.addHandler(logging.StreamHandler(sys.stderr))


def _acquire_lock(vault: Vault) -> FileLock:
    lock_path = vault.config.database_path + ".lock"
    lock = FileLock(lock_path, timeout=vault.config.write_lock_timeout_seconds)
    try:
        lock.acquire()
    except Timeout:
        raise WriteLockTimeout(
            f"Could not acquire write lock within {vault.config.write_lock_timeout_seconds}s"
        )
    return lock


def _shred_file(path: str) -> None:
    """Overwrite file with zeros, then unlink."""
    try:
        size = os.path.getsize(path)
        with open(path, "r+b") as f:
            f.write(b"\x00" * size)
            f.flush()
            os.fsync(f.fileno())
    except OSError:
        pass
    finally:
        try:
            os.unlink(path)
        except OSError:
            pass


def create_entry(
    vault: Vault,
    audit: AuditLogger,
    *,
    title: str,
    group: str,
    username: str | None = None,
    password: str | None = None,
    url: str | None = None,
    notes: str | None = None,
) -> None:
    if "/" in title:
        raise ValueError("Entry titles cannot contain a slash (/)")

    vault.check_group_allowed(group)

    # Check for duplicate active entry
    db = vault.config.database_path
    stdout = vault.run_cli("ls", db, group)
    existing = [
        line.strip()
        for line in stdout.strip().splitlines()
        if line.strip() and not line.strip().endswith("/")
    ]
    active_titles = [t for t in existing if not t.startswith(INACTIVE_PREFIX)]
    if title in active_titles:
        raise DuplicateEntry(f"Active entry '{title}' already exists in {group}")

    lock = _acquire_lock(vault)
    try:
        path = vault.entry_path(title, group)
        cmd = ["add", db, path]
        if username:
            cmd.extend(["--username", username])
        if password:
            cmd.extend(["--password", password])
        if url:
            cmd.extend(["--url", url])
        if notes:
            cmd.extend(["--notes", notes])
        vault.run_cli(*cmd)
    finally:
        lock.release()

    audit.log(tool="create_entry", title=title, group=group)


def deactivate_entry(
    vault: Vault,
    audit: AuditLogger,
    *,
    title: str,
    group: str | None = None,
) -> None:
    if title.startswith(INACTIVE_PREFIX):
        raise EntryInactive(f"Entry '{title}' is already deactivated")

    if group is not None:
        vault.check_group_allowed(group)

    db = vault.config.database_path
    path = vault.entry_path(title, group)

    # Read existing notes
    show_out = vault.run_cli("show", db, path)
    existing_notes = ""
    for line in show_out.strip().splitlines():
        if line.startswith("Notes: "):
            existing_notes = line[len("Notes: "):]
            break

    timestamp = datetime.now(UTC).isoformat()
    new_notes = f"{existing_notes}\n[DEACTIVATED: {timestamp}]".strip()
    new_title = f"{INACTIVE_PREFIX}{title}"

    lock = _acquire_lock(vault)
    try:
        # Rename: path changes after this
        vault.run_cli("edit", "--title", new_title, db, path)
        # Update notes using new path
        new_path = vault.entry_path(new_title, group)
        vault.run_cli("edit", "--notes", new_notes, db, new_path)
    finally:
        lock.release()

    audit.log(tool="deactivate_entry", title=title, group=group)


def add_attachment(
    vault: Vault,
    audit: AuditLogger,
    *,
    title: str,
    attachment_name: str,
    content: bytes | str,
    group: str | None = None,
) -> None:
    if title.startswith(INACTIVE_PREFIX):
        raise EntryInactive(f"Entry '{title}' is deactivated")

    if group is not None:
        vault.check_group_allowed(group)

    db = vault.config.database_path
    path = vault.entry_path(title, group)

    if isinstance(content, str):
        content = content.encode("utf-8")

    tmp = tempfile.NamedTemporaryFile(delete=False, prefix="keepass-cred-mgr-")
    tmp_path = tmp.name
    try:
        tmp.write(content)
        tmp.close()
        os.chmod(tmp_path, stat.S_IRUSR | stat.S_IWUSR)  # 600

        lock = _acquire_lock(vault)
        try:
            vault.run_cli("attachment-import", db, path, attachment_name, tmp_path)
        finally:
            lock.release()
    finally:
        _shred_file(tmp_path)

    audit.log(
        tool="add_attachment",
        title=title,
        group=group,
        attachment=attachment_name,
    )
