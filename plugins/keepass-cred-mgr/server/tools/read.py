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
    Vault,
)

log: structlog.stdlib.BoundLogger = structlog.get_logger("keepass-cred-mgr.tools.read")

type EntryFields = dict[str, str]
type EntrySummary = dict[str, str]
type SearchResult = dict[str, str | None]


def _parse_show_output(stdout: str) -> EntryFields:
    """Parse keepassxc-cli show output into a dict."""
    fields: dict[str, str] = {}
    for line in stdout.strip().splitlines():
        if ": " in line:
            key, _, value = line.partition(": ")
            key_lower = key.strip().lower()
            if key_lower == "username":
                fields["username"] = value.strip()
            elif key_lower == "password":
                fields["password"] = value.strip()
            elif key_lower == "url":
                fields["url"] = value.strip()
            elif key_lower == "notes":
                fields["notes"] = value.strip()
            elif key_lower == "title":
                fields["title"] = value.strip()
    return fields


async def list_groups(vault: Vault) -> list[str]:
    db = vault.config.database_path
    stdout = await vault.run_cli("ls", db)
    all_groups = [
        line.rstrip("/")
        for line in stdout.strip().splitlines()
        if line.endswith("/")
    ]
    return [g for g in all_groups if g in vault.config.allowed_groups]


async def list_entries(
    vault: Vault,
    audit: AuditLogger,
    *,
    group: str | None = None,
    include_inactive: bool = False,
) -> list[EntrySummary]:
    if group is not None:
        vault.check_group_allowed(group)
        groups = [group]
    else:
        groups = list(vault.config.allowed_groups)

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
    if group is not None:
        vault.check_group_allowed(group)

    db = vault.config.database_path
    stdout = await vault.run_cli("search", db, query)
    paths = [line.strip() for line in stdout.strip().splitlines() if line.strip()]

    results: list[SearchResult] = []
    for entry_path in paths:
        if "/" in entry_path:
            grp, _, title = entry_path.partition("/")
        else:
            grp, title = None, entry_path

        # Filter to allowed groups
        if grp and grp not in vault.config.allowed_groups:
            continue
        if group and grp != group:
            continue
        if not include_inactive and title.startswith(INACTIVE_PREFIX):
            continue
        if len(results) >= vault.config.page_size:
            log.warning("search_results_truncated", page_size=vault.config.page_size)
            return results

        show_out = await vault.run_cli("show", db, entry_path)
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
) -> EntryFields:
    if title.startswith(INACTIVE_PREFIX):
        raise EntryInactive(f"Entry '{title}' is deactivated")

    if group is not None:
        vault.check_group_allowed(group)

    db = vault.config.database_path
    path = vault.entry_path(title, group)
    stdout = await vault.run_cli("show", "--show-protected", db, path)
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

    if group is not None:
        vault.check_group_allowed(group)

    db = vault.config.database_path
    path = vault.entry_path(title, group)
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
