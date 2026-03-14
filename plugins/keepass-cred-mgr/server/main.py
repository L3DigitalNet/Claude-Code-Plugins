"""keepass-cred-mgr: MCP server entry point.

Wires config, YubiKey, vault, audit, and all 10 tools into a FastMCP server.
Runs over stdio transport. All logging goes to stderr.
"""

from __future__ import annotations

import asyncio
import base64
import binascii
import logging
import sys
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager, suppress
from dataclasses import dataclass
from typing import Any

import structlog
from mcp.server.fastmcp import Context, FastMCP

from server.audit import AuditLogger
from server.config import load_config
from server.tools import read as read_tools
from server.tools import write as write_tools
from server.vault import (
    DuplicateEntry,
    EntryInactive,
    EntryReadOnly,
    EntryRestricted,
    KeePassCLIError,
    Vault,
    VaultLocked,
    WriteLockTimeout,
    YubiKeyNotPresent,
)
from server.yubikey import RealYubiKey

log: structlog.stdlib.BoundLogger = structlog.get_logger("keepass-cred-mgr")


def _configure_logging(level: str) -> None:
    """Configure structlog with stdlib integration, output to stderr."""
    logging.basicConfig(
        format="%(message)s",
        stream=sys.stderr,
        level=getattr(logging, level),
    )
    structlog.configure(
        processors=[
            structlog.contextvars.merge_contextvars,
            structlog.stdlib.filter_by_level,
            structlog.stdlib.add_logger_name,
            structlog.stdlib.add_log_level,
            structlog.stdlib.PositionalArgumentsFormatter(),
            structlog.processors.TimeStamper(fmt="iso"),
            structlog.processors.StackInfoRenderer(),
            structlog.processors.format_exc_info,
            structlog.dev.ConsoleRenderer(),
        ],
        wrapper_class=structlog.stdlib.BoundLogger,
        context_class=dict,
        logger_factory=structlog.stdlib.LoggerFactory(),
        cache_logger_on_first_use=True,
    )


@dataclass
class AppContext:
    vault: Vault
    audit: AuditLogger
    poll_task: asyncio.Task[None]


@asynccontextmanager
async def app_lifespan(server: FastMCP) -> AsyncIterator[AppContext]:
    config = load_config()
    _configure_logging(config.log_level)
    yubikey = RealYubiKey(slot=config.yubikey_slot)
    vault = Vault(config, yubikey)
    audit = AuditLogger(config.audit_log_path)

    poll_task = asyncio.create_task(vault.start_polling())
    try:
        yield AppContext(vault=vault, audit=audit, poll_task=poll_task)
    finally:
        poll_task.cancel()
        with suppress(asyncio.CancelledError):
            await poll_task


mcp = FastMCP("keepass", lifespan=app_lifespan)


def _get_ctx(ctx: Context[Any, Any, Any]) -> AppContext:
    app_ctx: AppContext = ctx.request_context.lifespan_context
    return app_ctx


def _error_text(e: Exception) -> str:
    return f"{type(e).__name__}: {e}"


# --- Auth ---


@mcp.tool()
async def unlock_vault(ctx: Context[Any, Any, Any]) -> str:
    """Unlock the vault with the connected YubiKey. Must be called before any other vault tool."""
    log.info("tool_invoked", tool="unlock_vault")
    app = _get_ctx(ctx)
    if app.vault.is_unlocked:
        return "Vault is already unlocked"
    try:
        await app.vault.unlock()
        return "Vault unlocked successfully"
    except (YubiKeyNotPresent, KeePassCLIError) as e:
        raise ValueError(_error_text(e)) from e


# --- Read Tools ---


@mcp.tool()
async def list_groups(ctx: Context[Any, Any, Any]) -> list[str]:
    """List all KeePass groups."""
    log.info("tool_invoked", tool="list_groups")
    app = _get_ctx(ctx)
    try:
        return await read_tools.list_groups(app.vault)
    except (VaultLocked, YubiKeyNotPresent, KeePassCLIError, TimeoutError) as e:
        raise ValueError(_error_text(e)) from e


@mcp.tool()
async def list_entries(
    ctx: Context[Any, Any, Any],
    group: str | None = None,
    include_inactive: bool = False,
) -> list[dict[str, str]]:
    """List entries in a group. Hides [INACTIVE] entries by default."""
    log.info("tool_invoked", tool="list_entries")
    app = _get_ctx(ctx)
    try:
        return await read_tools.list_entries(
            app.vault, group=group, include_inactive=include_inactive
        )
    except (VaultLocked, KeePassCLIError, TimeoutError) as e:
        raise ValueError(_error_text(e)) from e


@mcp.tool()
async def search_entries(
    ctx: Context[Any, Any, Any],
    query: str,
    group: str | None = None,
    include_inactive: bool = False,
) -> list[dict[str, str | None]]:
    """Search entries vault-wide by keyword."""
    log.info("tool_invoked", tool="search_entries")
    app = _get_ctx(ctx)
    try:
        return await read_tools.search_entries(
            app.vault,
            query=query, group=group, include_inactive=include_inactive,
        )
    except (VaultLocked, KeePassCLIError, TimeoutError) as e:
        raise ValueError(_error_text(e)) from e


@mcp.tool()
async def get_entry(
    ctx: Context[Any, Any, Any], title: str, group: str | None = None,
    allow_inactive: bool = False,
) -> dict[str, str]:
    """Get full entry details including password. Logs to audit trail.
    Set allow_inactive=True to read [INACTIVE] entries (used by /keepass-audit)."""
    log.info("tool_invoked", tool="get_entry")
    app = _get_ctx(ctx)
    try:
        return await read_tools.get_entry(
            app.vault, app.audit, title=title, group=group,
            allow_inactive=allow_inactive,
        )
    except (
        VaultLocked, EntryInactive, EntryRestricted,
        KeePassCLIError, TimeoutError,
    ) as e:
        raise ValueError(_error_text(e)) from e


@mcp.tool()
async def get_attachment(
    ctx: Context[Any, Any, Any], title: str, attachment_name: str, group: str | None = None,
) -> str:
    """Export an attachment from an entry. Returns base64-encoded content."""
    log.info("tool_invoked", tool="get_attachment")
    app = _get_ctx(ctx)
    try:
        data = await read_tools.get_attachment(
            app.vault, app.audit,
            title=title, attachment_name=attachment_name, group=group,
        )
        return base64.b64encode(data).decode("ascii")
    except (
        VaultLocked, EntryInactive, EntryRestricted,
        KeePassCLIError, TimeoutError,
    ) as e:
        raise ValueError(_error_text(e)) from e


# --- Write Tools ---


@mcp.tool()
async def create_entry(
    ctx: Context[Any, Any, Any],
    title: str,
    group: str,
    username: str | None = None,
    password: str | None = None,
    url: str | None = None,
    notes: str | None = None,
) -> str:
    """Create a new entry in the vault. Rejects duplicates and titles with slashes."""
    log.info("tool_invoked", tool="create_entry")
    app = _get_ctx(ctx)
    try:
        await write_tools.create_entry(
            app.vault, app.audit,
            title=title, group=group,
            username=username, password=password, url=url, notes=notes,
        )
        return f"Created entry '{title}' in {group}"
    except (
        VaultLocked, DuplicateEntry,
        WriteLockTimeout, KeePassCLIError, ValueError,
        TimeoutError,
    ) as e:
        raise ValueError(_error_text(e)) from e


@mcp.tool()
async def deactivate_entry(
    ctx: Context[Any, Any, Any], title: str, group: str | None = None,
) -> str:
    """Deactivate an entry by adding [INACTIVE] prefix and deactivation timestamp."""
    log.info("tool_invoked", tool="deactivate_entry")
    app = _get_ctx(ctx)
    try:
        await write_tools.deactivate_entry(
            app.vault, app.audit, title=title, group=group,
        )
        return f"Deactivated entry '{title}'"
    except (
        VaultLocked, EntryInactive, EntryReadOnly,
        WriteLockTimeout, KeePassCLIError,
        TimeoutError,
    ) as e:
        raise ValueError(_error_text(e)) from e


@mcp.tool()
async def add_attachment(
    ctx: Context[Any, Any, Any],
    title: str,
    attachment_name: str,
    content: str,
    group: str | None = None,
) -> str:
    """Attach a file to an entry. Content is base64-encoded. Temp files are shredded."""
    log.info("tool_invoked", tool="add_attachment")
    app = _get_ctx(ctx)
    try:
        decoded = base64.b64decode(content)
        await write_tools.add_attachment(
            app.vault, app.audit,
            title=title, attachment_name=attachment_name,
            content=decoded, group=group,
        )
        return f"Attached '{attachment_name}' to '{title}'"
    except (
        VaultLocked, EntryInactive, EntryReadOnly,
        WriteLockTimeout, KeePassCLIError,
        binascii.Error, TimeoutError,
    ) as e:
        raise ValueError(_error_text(e)) from e


@mcp.tool()
async def import_entries(
    ctx: Context[Any, Any, Any],
    entries: list[dict[str, str]],
) -> str:
    """Bulk import multiple entries via XML merge. Two YubiKey touches regardless of entry
    count — more efficient than create_entry in a loop. Vault is locked after import;
    call unlock_vault to continue.

    Each entry requires 'group' and 'title'. Optional: 'username', 'password', 'url',
    'notes'."""
    log.info("tool_invoked", tool="import_entries")
    app = _get_ctx(ctx)
    try:
        return await write_tools.import_entries(
            app.vault, app.audit, entries=entries,
        )
    except (VaultLocked, KeePassCLIError, ValueError) as e:
        raise ValueError(_error_text(e)) from e


def main() -> None:
    mcp.run(transport="stdio")


if __name__ == "__main__":
    main()
