"""keepass-cred-mgr: MCP server entry point.

Wires config, YubiKey, vault, audit, and all 8 tools into a FastMCP server.
Runs over stdio transport. All logging goes to stderr.
"""

from __future__ import annotations

import asyncio
import base64
import binascii
import logging
import subprocess
import sys
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from dataclasses import dataclass
from typing import Any

from mcp.server.fastmcp import Context, FastMCP

from server.audit import AuditLogger
from server.config import load_config
from server.tools import read as read_tools
from server.tools import write as write_tools
from server.vault import (
    DuplicateEntry,
    EntryInactive,
    GroupNotAllowed,
    KeePassCLIError,
    Vault,
    VaultLocked,
    WriteLockTimeout,
    YubiKeyNotPresent,
)
from server.yubikey import RealYubiKey

# All logging to stderr; stdout is MCP stdio protocol
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    stream=sys.stderr,
)
logger = logging.getLogger("keepass-cred-mgr")


@dataclass
class AppContext:
    vault: Vault
    audit: AuditLogger
    poll_task: asyncio.Task[None]


@asynccontextmanager
async def app_lifespan(server: FastMCP) -> AsyncIterator[AppContext]:
    config = load_config()
    yubikey = RealYubiKey(slot=config.yubikey_slot)
    vault = Vault(config, yubikey)
    audit = AuditLogger(config.audit_log_path)

    poll_task = asyncio.create_task(vault.start_polling())
    try:
        yield AppContext(vault=vault, audit=audit, poll_task=poll_task)
    finally:
        poll_task.cancel()
        try:
            await poll_task
        except asyncio.CancelledError:
            pass


mcp = FastMCP("keepass", lifespan=app_lifespan)


def _get_ctx(ctx: Context[Any, Any, Any]) -> AppContext:
    app_ctx: AppContext = ctx.request_context.lifespan_context
    return app_ctx


def _error_text(e: Exception) -> str:
    return f"{type(e).__name__}: {e}"


# --- Read Tools ---


@mcp.tool()
def list_groups(ctx: Context[Any, Any, Any]) -> list[str]:
    """List accessible KeePass groups (filtered by allowlist)."""
    app = _get_ctx(ctx)
    try:
        return read_tools.list_groups(app.vault)
    except (VaultLocked, YubiKeyNotPresent, KeePassCLIError, subprocess.TimeoutExpired) as e:
        raise ValueError(_error_text(e))


@mcp.tool()
def list_entries(
    ctx: Context[Any, Any, Any],
    group: str | None = None,
    include_inactive: bool = False,
) -> list[dict[str, str]]:
    """List entries in a group. Hides [INACTIVE] entries by default."""
    app = _get_ctx(ctx)
    try:
        return read_tools.list_entries(
            app.vault, app.audit, group=group, include_inactive=include_inactive
        )
    except (VaultLocked, GroupNotAllowed, KeePassCLIError, subprocess.TimeoutExpired) as e:
        raise ValueError(_error_text(e))


@mcp.tool()
def search_entries(
    ctx: Context[Any, Any, Any],
    query: str,
    group: str | None = None,
    include_inactive: bool = False,
) -> list[dict[str, str | None]]:
    """Search entries by keyword. Filters to allowed groups only."""
    app = _get_ctx(ctx)
    try:
        return read_tools.search_entries(
            app.vault, app.audit,
            query=query, group=group, include_inactive=include_inactive,
        )
    except (VaultLocked, GroupNotAllowed, KeePassCLIError, subprocess.TimeoutExpired) as e:
        raise ValueError(_error_text(e))


@mcp.tool()
def get_entry(ctx: Context[Any, Any, Any], title: str, group: str | None = None) -> dict[str, str]:
    """Get full entry details including password. Logs to audit trail."""
    app = _get_ctx(ctx)
    try:
        return read_tools.get_entry(app.vault, app.audit, title=title, group=group)
    except (
        VaultLocked, EntryInactive, GroupNotAllowed,
        KeePassCLIError, subprocess.TimeoutExpired,
    ) as e:
        raise ValueError(_error_text(e))


@mcp.tool()
def get_attachment(
    ctx: Context[Any, Any, Any], title: str, attachment_name: str, group: str | None = None
) -> str:
    """Export an attachment from an entry. Returns base64-encoded content."""
    app = _get_ctx(ctx)
    try:
        data = read_tools.get_attachment(
            app.vault, app.audit,
            title=title, attachment_name=attachment_name, group=group,
        )
        return base64.b64encode(data).decode("ascii")
    except (
        VaultLocked, EntryInactive, GroupNotAllowed,
        KeePassCLIError, subprocess.TimeoutExpired,
    ) as e:
        raise ValueError(_error_text(e))


# --- Write Tools ---


@mcp.tool()
def create_entry(
    ctx: Context[Any, Any, Any],
    title: str,
    group: str,
    username: str | None = None,
    password: str | None = None,
    url: str | None = None,
    notes: str | None = None,
) -> str:
    """Create a new entry in the vault. Rejects duplicates and titles with slashes."""
    app = _get_ctx(ctx)
    try:
        write_tools.create_entry(
            app.vault, app.audit,
            title=title, group=group,
            username=username, password=password, url=url, notes=notes,
        )
        return f"Created entry '{title}' in {group}"
    except (
        VaultLocked, GroupNotAllowed, DuplicateEntry,
        WriteLockTimeout, KeePassCLIError, ValueError,
        subprocess.TimeoutExpired,
    ) as e:
        raise ValueError(_error_text(e))


@mcp.tool()
def deactivate_entry(
    ctx: Context[Any, Any, Any], title: str, group: str | None = None
) -> str:
    """Deactivate an entry by adding [INACTIVE] prefix and deactivation timestamp."""
    app = _get_ctx(ctx)
    try:
        write_tools.deactivate_entry(
            app.vault, app.audit, title=title, group=group,
        )
        return f"Deactivated entry '{title}'"
    except (
        VaultLocked, EntryInactive, GroupNotAllowed,
        WriteLockTimeout, KeePassCLIError,
        subprocess.TimeoutExpired,
    ) as e:
        raise ValueError(_error_text(e))


@mcp.tool()
def add_attachment(
    ctx: Context[Any, Any, Any],
    title: str,
    attachment_name: str,
    content: str,
    group: str | None = None,
) -> str:
    """Attach a file to an entry. Content is base64-encoded. Temp files are shredded."""
    app = _get_ctx(ctx)
    try:
        decoded = base64.b64decode(content)
        write_tools.add_attachment(
            app.vault, app.audit,
            title=title, attachment_name=attachment_name,
            content=decoded, group=group,
        )
        return f"Attached '{attachment_name}' to '{title}'"
    except (
        VaultLocked, EntryInactive, GroupNotAllowed,
        WriteLockTimeout, KeePassCLIError,
        binascii.Error, subprocess.TimeoutExpired,
    ) as e:
        raise ValueError(_error_text(e))


def main() -> None:
    mcp.run(transport="stdio")


if __name__ == "__main__":
    main()
