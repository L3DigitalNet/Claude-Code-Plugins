"""Write vault tools.

All write operations acquire a FileLock on the database before executing.
Temp files for attachment import are overwritten with zeros then unlinked.
"""

from __future__ import annotations

import asyncio
import base64
import io
import os
import stat
import subprocess
import tempfile
import uuid
import xml.etree.ElementTree as ET
from collections.abc import Generator
from contextlib import contextmanager, suppress
from datetime import UTC, datetime, timezone
from pathlib import Path

import structlog
from filelock import FileLock, Timeout

from server.audit import AuditLogger
from server.vault import (
    INACTIVE_PREFIX,
    DuplicateEntry,
    EntryInactive,
    EntryReadOnly,
    KeePassCLIError,
    Vault,
    WriteLockTimeout,
)
from server.tools.read import _parse_tags

log: structlog.stdlib.BoundLogger = structlog.get_logger("keepass-cred-mgr.tools.write")


@contextmanager
def _write_lock(vault: Vault) -> Generator[FileLock]:
    """Acquire and release a file lock around database writes."""
    lock_path = vault.config.database_path + ".lock"
    lock = FileLock(lock_path, timeout=vault.config.write_lock_timeout_seconds)
    try:
        lock.acquire()
    except Timeout as exc:
        raise WriteLockTimeout(
            f"Could not acquire write lock within {vault.config.write_lock_timeout_seconds}s"
        ) from exc
    try:
        yield lock
    finally:
        lock.release()


def _shred_file(path: str) -> None:
    """Overwrite file with zeros, then unlink."""
    try:
        size = os.path.getsize(path)
        with open(path, "r+b") as f:
            f.write(b"\x00" * size)
            f.flush()
            os.fsync(f.fileno())
    except OSError:
        log.warning("shred_failed", path=path)
    finally:
        with suppress(OSError):
            os.unlink(path)


async def create_entry(
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

    # Check for duplicate active entry
    db = vault.config.database_path
    stdout = await vault.run_cli("ls", db, group)
    existing = [
        line.strip()
        for line in stdout.strip().splitlines()
        if line.strip() and not line.strip().endswith("/")
    ]
    active_titles = [t for t in existing if not t.startswith(INACTIVE_PREFIX)]
    if title in active_titles:
        raise DuplicateEntry(f"Active entry '{title}' already exists in {group}")

    with _write_lock(vault):
        path = vault.entry_path(title, group)
        cmd = ["add", db, path]
        if username:
            cmd.extend(["--username", username])
        if url:
            cmd.extend(["--url", url])
        if notes:
            cmd.extend(["--notes", notes])
        if password:
            # keepassxc-cli add has no --password flag; -p prompts stdin.
            # Write the password to stdin upfront so run_cli() doesn't deadlock.
            cmd.append("-p")
            await vault.run_cli(*cmd, stdin_lines=[password])
        else:
            await vault.run_cli(*cmd)

    audit.log(tool="create_entry", title=title, group=group)


async def deactivate_entry(
    vault: Vault,
    audit: AuditLogger,
    *,
    title: str,
    group: str | None = None,
) -> None:
    if title.startswith(INACTIVE_PREFIX):
        raise EntryInactive(f"Entry '{title}' is already deactivated")

    db = vault.config.database_path
    path = vault.entry_path(title, group)

    # Read existing entry to check tags and capture notes
    show_out = await vault.run_cli("show", db, path)
    tags = _parse_tags(show_out)
    if "read only" in tags:
        raise EntryReadOnly(f"Entry '{title}' is tagged READ ONLY; write operations are not permitted")

    existing_notes = ""
    for line in show_out.strip().splitlines():
        if line.startswith("Notes: "):
            existing_notes = line[len("Notes: "):]
            break

    timestamp = datetime.now(UTC).isoformat()
    new_notes = f"{existing_notes}\n[DEACTIVATED: {timestamp}]".strip()
    new_title = f"{INACTIVE_PREFIX}{title}"

    with _write_lock(vault):
        # Rename: path changes after this
        await vault.run_cli("edit", "--title", new_title, db, path)
        # Update notes using new path — non-critical, log and continue on failure
        new_path = vault.entry_path(new_title, group)
        try:
            await vault.run_cli("edit", "--notes", new_notes, db, new_path)
        except KeePassCLIError:
            log.warning("deactivate_notes_update_failed", title=title, group=group)

    audit.log(tool="deactivate_entry", title=title, group=group)


async def add_attachment(
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

    db = vault.config.database_path
    path = vault.entry_path(title, group)

    # Check READ ONLY tag before writing
    show_out = await vault.run_cli("show", db, path)
    tags = _parse_tags(show_out)
    if "read only" in tags:
        raise EntryReadOnly(f"Entry '{title}' is tagged READ ONLY; write operations are not permitted")

    if isinstance(content, str):
        content = content.encode("utf-8")

    tmp = tempfile.NamedTemporaryFile(delete=False, prefix="keepass-cred-mgr-")  # noqa: SIM115
    tmp_path = tmp.name
    try:
        tmp.write(content)
        tmp.close()
        os.chmod(tmp_path, stat.S_IRUSR | stat.S_IWUSR)  # 600

        with _write_lock(vault):
            await vault.run_cli("attachment-import", db, path, attachment_name, tmp_path)
    finally:
        _shred_file(tmp_path)

    audit.log(
        tool="add_attachment",
        title=title,
        group=group,
        attachment=attachment_name,
    )


# --- Bulk import helpers ---


def _b64uuid() -> str:
    return base64.b64encode(uuid.uuid4().bytes).decode()


def _now_kp() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _make_times() -> ET.Element:
    t = ET.Element("Times")
    for tag in ("LastModificationTime", "CreationTime", "LastAccessTime",
                "LocationChanged", "ExpiryTime"):
        ET.SubElement(t, tag).text = _now_kp()
    ET.SubElement(t, "Expires").text = "False"
    ET.SubElement(t, "UsageCount").text = "0"
    return t


def _xml_entry(
    title: str,
    username: str = "",
    password: str = "",
    url: str = "",
    notes: str = "",
) -> ET.Element:
    e = ET.Element("Entry")
    ET.SubElement(e, "UUID").text = _b64uuid()
    ET.SubElement(e, "IconID").text = "0"
    ET.SubElement(e, "ForegroundColor")
    ET.SubElement(e, "BackgroundColor")
    ET.SubElement(e, "OverrideURL")
    ET.SubElement(e, "Tags")
    e.append(_make_times())
    for key, val in (("Title", title), ("UserName", username),
                     ("Password", password), ("URL", url), ("Notes", notes)):
        s = ET.SubElement(e, "String")
        ET.SubElement(s, "Key").text = key
        v = ET.SubElement(s, "Value")
        v.text = val
        if key == "Password":
            v.set("ProtectInMemory", "True")
    at = ET.SubElement(e, "AutoType")
    ET.SubElement(at, "Enabled").text = "True"
    ET.SubElement(at, "DataTransferObfuscation").text = "0"
    ET.SubElement(e, "History")
    return e


def _xml_group(name: str, entries: list[ET.Element]) -> ET.Element:
    g = ET.Element("Group")
    ET.SubElement(g, "UUID").text = _b64uuid()
    ET.SubElement(g, "Name").text = name
    ET.SubElement(g, "Notes")
    ET.SubElement(g, "IconID").text = "48"
    g.append(_make_times())
    ET.SubElement(g, "IsExpanded").text = "True"
    ET.SubElement(g, "DefaultAutoTypeSequence")
    # "null" is the KeePassXC XML value for inherit-from-parent; "inherit" is rejected.
    ET.SubElement(g, "EnableAutoType").text = "null"
    ET.SubElement(g, "EnableSearching").text = "null"
    ET.SubElement(g, "LastTopVisibleEntry").text = "AAAAAAAAAAAAAAAAAAAAAA=="
    for entry in entries:
        g.append(entry)
    return g


def _build_import_xml(entries_by_group: dict[str, list[dict[str, str]]]) -> str:
    """Build a KeePassXC-compatible XML string from a group → entries mapping."""
    root_el = ET.Element("KeePassFile")

    meta = ET.SubElement(root_el, "Meta")
    ET.SubElement(meta, "Generator").text = "KeePassXC"
    ET.SubElement(meta, "DatabaseName").text = "keepass-cred-mgr-import"
    ET.SubElement(meta, "DatabaseDescription")
    ET.SubElement(meta, "DefaultUserName")
    ET.SubElement(meta, "MaintenanceHistoryDays").text = "365"
    ET.SubElement(meta, "Color")
    ET.SubElement(meta, "MasterKeyChanged").text = _now_kp()
    ET.SubElement(meta, "MasterKeyChangeRec").text = "-1"
    ET.SubElement(meta, "MasterKeyChangeForce").text = "-1"
    mp = ET.SubElement(meta, "MemoryProtection")
    for field, val in (("ProtectTitle", "False"), ("ProtectUserName", "False"),
                       ("ProtectPassword", "True"), ("ProtectURL", "False"),
                       ("ProtectNotes", "False")):
        ET.SubElement(mp, field).text = val
    ET.SubElement(meta, "CustomIcons")
    ET.SubElement(meta, "RecycleBinEnabled").text = "True"
    ET.SubElement(meta, "RecycleBinUUID").text = "AAAAAAAAAAAAAAAAAAAAAA=="
    ET.SubElement(meta, "RecycleBinChanged").text = _now_kp()
    ET.SubElement(meta, "EntryTemplatesGroup").text = "AAAAAAAAAAAAAAAAAAAAAA=="
    ET.SubElement(meta, "EntryTemplatesGroupChanged").text = _now_kp()
    ET.SubElement(meta, "HistoryMaxItems").text = "10"
    ET.SubElement(meta, "HistoryMaxSize").text = "6291456"
    ET.SubElement(meta, "LastSelectedGroup").text = "AAAAAAAAAAAAAAAAAAAAAA=="
    ET.SubElement(meta, "LastTopVisibleGroup").text = "AAAAAAAAAAAAAAAAAAAAAA=="
    ET.SubElement(meta, "Binaries")
    ET.SubElement(meta, "CustomData")

    root_group = ET.SubElement(ET.SubElement(root_el, "Root"), "Group")
    ET.SubElement(root_group, "UUID").text = _b64uuid()
    ET.SubElement(root_group, "Name").text = "keepass"
    ET.SubElement(root_group, "Notes")
    ET.SubElement(root_group, "IconID").text = "48"
    root_group.append(_make_times())
    ET.SubElement(root_group, "IsExpanded").text = "True"
    ET.SubElement(root_group, "DefaultAutoTypeSequence")
    ET.SubElement(root_group, "EnableAutoType").text = "null"
    ET.SubElement(root_group, "EnableSearching").text = "null"
    ET.SubElement(root_group, "LastTopVisibleEntry").text = "AAAAAAAAAAAAAAAAAAAAAA=="

    for group_name, entry_dicts in entries_by_group.items():
        xml_entries = [
            _xml_entry(
                title=e["title"],
                username=e.get("username", ""),
                password=e.get("password", ""),
                url=e.get("url", ""),
                notes=e.get("notes", ""),
            )
            for e in entry_dicts
        ]
        root_group.append(_xml_group(group_name, xml_entries))

    tree = ET.ElementTree(root_el)
    ET.indent(tree, space="    ")
    buf = io.StringIO()
    tree.write(buf, encoding="unicode", xml_declaration=True)
    return buf.getvalue()


async def import_entries(
    vault: Vault,
    audit: AuditLogger,
    *,
    entries: list[dict[str, str]],
) -> str:
    """Bulk-import multiple entries via XML → temp KDBX → merge.

    More efficient than calling create_entry in a loop when adding many entries:
    two YubiKey touches regardless of count (merge open + save).

    The vault is locked after import to prevent the in-memory REPL state from
    becoming stale relative to the merged database. Call unlock_vault again
    to continue using the vault.

    Each entry dict requires 'group' and 'title'. Optional: 'username',
    'password', 'url', 'notes'.
    """
    if not entries:
        return "No entries provided"

    # Validate groups and title uniqueness before doing any I/O.
    for e in entries:
        if "group" not in e or "title" not in e:
            raise ValueError("Each entry must have 'group' and 'title'")
        if "/" in e["title"]:
            raise ValueError(f"Entry title cannot contain a slash: {e['title']!r}")

    # Group entries by group name for the XML builder.
    by_group: dict[str, list[dict[str, str]]] = {}
    for e in entries:
        by_group.setdefault(e["group"], []).append(e)

    xml_fd, tmp_xml = tempfile.mkstemp(prefix="keepass-cred-mgr-import-", suffix=".xml")
    os.close(xml_fd)
    kdbx_dir = tempfile.mkdtemp(prefix="keepass-cred-mgr-")
    tmp_db = os.path.join(kdbx_dir, "staging.kdbx")
    tmp_pass = uuid.uuid4().hex  # random one-time password for the staging database

    try:
        # Step 1: write XML
        xml_content = _build_import_xml(by_group)
        Path(tmp_xml).write_text(xml_content, encoding="utf-8")
        os.chmod(tmp_xml, stat.S_IRUSR | stat.S_IWUSR)

        # Step 2: create staging KDBX from XML (password-only, no YubiKey).
        # asyncio.to_thread prevents blocking the event loop during the CLI call.
        result = await asyncio.to_thread(
            subprocess.run,
            ["keepassxc-cli", "import", "--set-password", tmp_xml, tmp_db],
            input=f"{tmp_pass}\n{tmp_pass}\n",
            capture_output=True,
            text=True,
            timeout=60,
        )
        if result.returncode != 0:
            raise KeePassCLIError(
                f"keepassxc-cli import failed: {result.stderr.strip()}"
            )

        # Step 3: lock the vault before merging so the REPL's in-memory state
        # doesn't diverge from what the merge writes to disk.
        await vault.lock(reason="import_complete")

        # Step 4: merge staging KDBX into production (two YubiKey touches)
        db = vault.config.database_path
        slot = vault.config.yubikey_slot
        result = await asyncio.to_thread(
            subprocess.run,
            [
                "keepassxc-cli", "merge",
                "--yubikey", slot,
                "--no-password",
                db, tmp_db,
            ],
            input=tmp_pass + "\n",
            capture_output=True,
            text=True,
            timeout=60,
        )
        if result.returncode != 0:
            raise KeePassCLIError(
                f"keepassxc-cli merge failed: {result.stderr.strip()}"
            )

    finally:
        _shred_file(tmp_xml)
        _shred_file(tmp_db)
        with suppress(OSError):
            os.rmdir(kdbx_dir)

    total = sum(len(v) for v in by_group.values())
    group_summary = ", ".join(f"{g} ({len(v)})" for g, v in by_group.items())
    audit.log(tool="import_entries", total=total, groups=list(by_group.keys()))
    return (
        f"Imported {total} entries: {group_summary}. "
        "Vault is now locked — call unlock_vault to continue."
    )
