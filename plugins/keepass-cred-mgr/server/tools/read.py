"""Read-only vault tools.

All functions take a Vault and AuditLogger, call vault.run_cli internally.
No file lock required for reads.
"""

from __future__ import annotations

import structlog

from server.audit import AuditLogger
from server.vault import (
    INACTIVE_PREFIX,
    EntryInactive,
    EntryRestricted,
    Vault,
)

log: structlog.stdlib.BoundLogger = structlog.get_logger("keepass-cred-mgr.tools.read")

type EntryFields = dict[str, str]
type EntrySummary = dict[str, str]
type SearchResult = dict[str, str | None]


# Known field prefixes that terminate a multi-line notes block.
_KNOWN_FIELDS = {"username", "password", "url", "notes", "title", "tags"}


def _parse_show_output(stdout: str) -> EntryFields:
    """Parse keepassxc-cli show output into a string field dict.

    Notes can span multiple lines; continuation lines have no 'Key: ' prefix.
    Continuation stops when a line starts with a known field key followed by ': '.
    """
    fields: dict[str, str] = {}
    in_notes = False
    notes_lines: list[str] = []

    for line in stdout.strip().splitlines():
        if ": " in line:
            key, _, value = line.partition(": ")
            key_lower = key.strip().lower()
            if key_lower in _KNOWN_FIELDS:
                if in_notes:
                    fields["notes"] = "\n".join(notes_lines)
                    in_notes = False
                if key_lower == "notes":
                    notes_lines = [value.strip()]
                    in_notes = True
                elif key_lower == "username":
                    fields["username"] = value.strip()
                elif key_lower == "password":
                    fields["password"] = value.strip()
                elif key_lower == "url":
                    fields["url"] = value.strip()
                elif key_lower == "title":
                    fields["title"] = value.strip()
                continue
        if in_notes:
            notes_lines.append(line)

    if in_notes:
        fields["notes"] = "\n".join(notes_lines)

    return fields


def _parse_tags(stdout: str) -> set[str]:
    """Extract the Tags field from keepassxc-cli show output as a lowercase set.

    keepassxc-cli show outputs tags as: Tags: tag1;tag2
    Returns an empty set when the Tags line is absent.
    """
    for line in stdout.strip().splitlines():
        if line.lower().startswith("tags: "):
            raw = line.partition(": ")[2].strip()
            return {t.strip().lower() for t in raw.split(";") if t.strip()}
    return set()


async def list_groups(vault: Vault) -> list[str]:
    db = vault.config.database_path
    stdout = await vault.run_cli("ls", db)
    return [
        line.rstrip("/")
        for line in stdout.strip().splitlines()
        if line.endswith("/")
    ]


async def list_entries(
    vault: Vault,
    audit: AuditLogger,
    *,
    group: str | None = None,
    include_inactive: bool = False,
) -> list[EntrySummary]:
    groups = [group] if group is not None else await list_groups(vault)

    results: list[EntrySummary] = []
    for grp in groups:
        db = vault.config.database_path
        stdout = await vault.run_cli("ls", db, grp)
        titles = [
            line.strip()
            for line in stdout.strip().splitlines()
            if line.strip() and not line.strip().endswith("/")
        ]

        for title in titles:
            if not include_inactive and title.startswith(INACTIVE_PREFIX):
                continue
            if len(results) >= vault.config.page_size:
                log.warning("results_truncated", page_size=vault.config.page_size)
                return results

            path = vault.entry_path(title, grp)
            show_out = await vault.run_cli("show", db, path)
            tags = _parse_tags(show_out)
            if "ai restricted" in tags:
                continue
            fields = _parse_show_output(show_out)
            results.append({
                "title": title,
                "group": grp,
                "username": fields.get("username", ""),
                "url": fields.get("url", ""),
            })

    return results


async def search_entries(
    vault: Vault,
    audit: AuditLogger,
    *,
    query: str,
    group: str | None = None,
    include_inactive: bool = False,
) -> list[SearchResult]:
    db = vault.config.database_path
    stdout = await vault.run_cli("search", db, query)
    paths = [line.strip() for line in stdout.strip().splitlines() if line.strip()]

    results: list[SearchResult] = []
    for entry_path in paths:
        # rsplit handles multi-level paths: "SSH Keys/Personal/SSH - laptop"
        # → grp="SSH Keys/Personal", title="SSH - laptop"
        if "/" in entry_path:
            grp, title = entry_path.rsplit("/", 1)
        else:
            grp, title = None, entry_path

        if group and grp != group:
            continue
        if not include_inactive and title.startswith(INACTIVE_PREFIX):
            continue
        if len(results) >= vault.config.page_size:
            log.warning("search_results_truncated", page_size=vault.config.page_size)
            return results

        show_out = await vault.run_cli("show", db, entry_path)
        tags = _parse_tags(show_out)
        if "ai restricted" in tags:
            continue
        fields = _parse_show_output(show_out)
        results.append({
            "title": title,
            "group": grp,
            "username": fields.get("username", ""),
            "url": fields.get("url", ""),
        })

    return results


async def get_entry(
    vault: Vault,
    audit: AuditLogger,
    *,
    title: str,
    group: str | None = None,
    allow_inactive: bool = False,
) -> EntryFields:
    if not allow_inactive and title.startswith(INACTIVE_PREFIX):
        raise EntryInactive(f"Entry '{title}' is deactivated")

    db = vault.config.database_path
    path = vault.entry_path(title, group)
    stdout = await vault.run_cli("show", "--show-protected", db, path)

    tags = _parse_tags(stdout)
    if "ai restricted" in tags:
        raise EntryRestricted(f"Entry '{title}' is tagged AI RESTRICTED; access denied")

    fields = _parse_show_output(stdout)

    audit.log(
        tool="get_entry",
        title=title,
        group=group,
        secret_returned=True,
    )

    return {
        "title": fields.get("title", title),
        "username": fields.get("username", ""),
        "password": fields.get("password", ""),
        "url": fields.get("url", ""),
        "notes": fields.get("notes", ""),
    }


async def get_attachment(
    vault: Vault,
    audit: AuditLogger,
    *,
    title: str,
    attachment_name: str,
    group: str | None = None,
) -> bytes:
    if title.startswith(INACTIVE_PREFIX):
        raise EntryInactive(f"Entry '{title}' is deactivated")

    db = vault.config.database_path
    path = vault.entry_path(title, group)

    # Fetch entry metadata first to check the AI RESTRICTED tag before exporting.
    show_out = await vault.run_cli("show", db, path)
    tags = _parse_tags(show_out)
    if "ai restricted" in tags:
        raise EntryRestricted(f"Entry '{title}' is tagged AI RESTRICTED; access denied")

    # Use run_cli_binary to preserve raw bytes (avoids UTF-8 corruption)
    raw_bytes = await vault.run_cli_binary(
        "attachment-export", "--stdout", db, path, attachment_name
    )

    audit.log(
        tool="get_attachment",
        title=title,
        group=group,
        secret_returned=True,
        attachment=attachment_name,
    )

    return raw_bytes
