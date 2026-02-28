"""Tests for the MCP server entry point (main.py).

Tests the handler layer: context extraction, error translation,
base64 encode/decode, and app_lifespan lifecycle.
"""

import base64
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from server.vault import (
    DuplicateEntry,
    EntryInactive,
    GroupNotAllowed,
    KeePassCLIError,
    VaultLocked,
    WriteLockTimeout,
    YubiKeyNotPresent,
)


def _app(vault=None):
    """Helper: build AppContext + MagicMock ctx in one call."""
    from server.main import AppContext
    ctx = MagicMock()
    app = AppContext(
        vault=vault or MagicMock(),
        audit=MagicMock(),
        poll_task=MagicMock(),
    )
    ctx.request_context.lifespan_context = app
    return ctx, app


class TestHelpers:
    def test_error_text_formats_exception(self):
        from server.main import _error_text
        e = VaultLocked("unlock first")
        assert _error_text(e) == "VaultLocked: unlock first"

    def test_error_text_with_generic_exception(self):
        from server.main import _error_text
        e = ValueError("bad input")
        assert _error_text(e) == "ValueError: bad input"

    def test_get_ctx_extracts_app_context(self):
        from server.main import AppContext, _get_ctx
        mock_ctx = MagicMock()
        app = AppContext(vault=MagicMock(), audit=MagicMock(), poll_task=MagicMock())
        mock_ctx.request_context.lifespan_context = app
        assert _get_ctx(mock_ctx) is app


class TestUnlockVaultHandler:
    @pytest.mark.asyncio
    async def test_already_unlocked(self):
        from server.main import unlock_vault
        mock_vault = MagicMock()
        mock_vault.is_unlocked = True
        ctx, app = _app(vault=mock_vault)
        result = await unlock_vault(ctx)
        assert "already unlocked" in result

    @pytest.mark.asyncio
    async def test_unlock_success(self):
        from server.main import unlock_vault
        mock_vault = MagicMock()
        mock_vault.is_unlocked = False
        mock_vault.unlock = AsyncMock()
        ctx, app = _app(vault=mock_vault)
        result = await unlock_vault(ctx)
        assert "successfully" in result
        mock_vault.unlock.assert_awaited_once()

    @pytest.mark.asyncio
    async def test_yubikey_not_present_maps_to_value_error(self):
        from server.main import unlock_vault
        mock_vault = MagicMock()
        mock_vault.is_unlocked = False
        mock_vault.unlock = AsyncMock(side_effect=YubiKeyNotPresent("missing"))
        ctx, app = _app(vault=mock_vault)
        with pytest.raises(ValueError, match="YubiKeyNotPresent"):
            await unlock_vault(ctx)


class TestListGroupsHandler:
    @pytest.mark.asyncio
    async def test_happy_path(self):
        from server.main import list_groups
        ctx, app = _app()
        mock_lg = AsyncMock(return_value=["Servers"])
        with patch("server.tools.read.list_groups", mock_lg):
            result = await list_groups(ctx)
            assert result == ["Servers"]
            mock_lg.assert_called_once_with(app.vault)

    @pytest.mark.asyncio
    async def test_vault_locked_maps_to_value_error(self):
        from server.main import list_groups
        ctx, app = _app()
        mock_lg = AsyncMock(side_effect=VaultLocked("locked"))
        with patch("server.tools.read.list_groups", mock_lg), \
             pytest.raises(ValueError, match="VaultLocked"):
            await list_groups(ctx)

    @pytest.mark.asyncio
    async def test_timeout_maps_to_value_error(self):
        from server.main import list_groups
        ctx, app = _app()
        mock_lg = AsyncMock(side_effect=TimeoutError("timeout"))
        with patch("server.tools.read.list_groups", mock_lg), \
             pytest.raises(ValueError, match="TimeoutError"):
            await list_groups(ctx)


class TestGetEntryHandler:
    @pytest.mark.asyncio
    async def test_happy_path(self):
        from server.main import get_entry
        ctx, app = _app()
        entry = {"title": "Test", "username": "u", "password": "p", "url": "", "notes": ""}
        mock_ge = AsyncMock(return_value=entry)
        with patch("server.tools.read.get_entry", mock_ge):
            result = await get_entry(ctx, title="Test", group="Servers")
            assert result["password"] == "p"
            mock_ge.assert_called_once()

    @pytest.mark.asyncio
    async def test_entry_inactive_maps_to_value_error(self):
        from server.main import get_entry
        ctx, app = _app()
        mock_ge = AsyncMock(side_effect=EntryInactive("inactive"))
        with patch("server.tools.read.get_entry", mock_ge), \
             pytest.raises(ValueError, match="EntryInactive"):
            await get_entry(ctx, title="[INACTIVE] Old", group="Servers")


class TestGetAttachmentHandler:
    @pytest.mark.asyncio
    async def test_returns_base64_encoded(self):
        from server.main import get_attachment
        ctx, app = _app()
        raw_bytes = b"ssh-ed25519 AAAA..."
        mock_ga = AsyncMock(return_value=raw_bytes)
        with patch("server.tools.read.get_attachment", mock_ga):
            result = await get_attachment(
                ctx, title="SSH Key", attachment_name="id_ed25519.pub", group="SSH Keys",
            )
            assert base64.b64decode(result) == raw_bytes


class TestCreateEntryHandler:
    @pytest.mark.asyncio
    async def test_returns_confirmation_string(self):
        from server.main import create_entry
        ctx, app = _app()
        with patch("server.tools.write.create_entry", AsyncMock()):
            result = await create_entry(ctx, title="New", group="Servers")
            assert "Created entry" in result

    @pytest.mark.asyncio
    async def test_duplicate_maps_to_value_error(self):
        from server.main import create_entry
        ctx, app = _app()
        mock_ce = AsyncMock(side_effect=DuplicateEntry("exists"))
        with patch("server.tools.write.create_entry", mock_ce), \
             pytest.raises(ValueError, match="DuplicateEntry"):
            await create_entry(ctx, title="Dup", group="Servers")


class TestDeactivateEntryHandler:
    @pytest.mark.asyncio
    async def test_returns_confirmation_string(self):
        from server.main import deactivate_entry
        ctx, app = _app()
        with patch("server.tools.write.deactivate_entry", AsyncMock()):
            result = await deactivate_entry(ctx, title="Old", group="Servers")
            assert "Deactivated" in result


class TestAddAttachmentHandler:
    @pytest.mark.asyncio
    async def test_happy_path_decodes_base64(self):
        from server.main import add_attachment
        ctx, app = _app()
        content = base64.b64encode(b"key data").decode("ascii")
        mock_aa = AsyncMock()
        with patch("server.tools.write.add_attachment", mock_aa):
            result = await add_attachment(
                ctx, title="Key", attachment_name="id", content=content, group="SSH Keys",
            )
            assert "Attached" in result
            call_kwargs = mock_aa.call_args.kwargs
            assert call_kwargs["content"] == b"key data"

    @pytest.mark.asyncio
    async def test_malformed_base64_raises_value_error(self):
        """Regression test: binascii.Error must be caught."""
        from server.main import add_attachment
        ctx, app = _app()
        with pytest.raises(ValueError, match="Error"):
            await add_attachment(
                ctx, title="Key", attachment_name="id",
                content="!!!NOT-BASE64!!!", group="SSH Keys",
            )


class TestAppLifespan:
    @pytest.mark.asyncio
    async def test_lifespan_starts_and_stops_polling(self):
        """app_lifespan creates vault, audit, polling task; cleanup cancels task."""
        from server.main import AppContext, app_lifespan

        with patch("server.main.load_config") as mock_cfg, \
             patch("server.main.RealYubiKey") as mock_yk_cls, \
             patch("server.main.Vault") as mock_vault_cls, \
             patch("server.main.AuditLogger") as mock_audit_cls, \
             patch("server.main._configure_logging"):

            mock_cfg.return_value = MagicMock(log_level="INFO")
            mock_yk_cls.return_value = MagicMock()
            mock_vault = MagicMock()
            mock_vault.start_polling = AsyncMock()
            mock_vault_cls.return_value = mock_vault
            mock_audit_cls.return_value = MagicMock()

            server = MagicMock()
            async with app_lifespan(server) as ctx:
                assert isinstance(ctx, AppContext)
                assert ctx.vault is mock_vault
                assert ctx.poll_task is not None


class TestListEntriesHandler:
    @pytest.mark.asyncio
    async def test_happy_path(self):
        from server.main import list_entries
        ctx, app = _app()
        entries = [{"title": "Test", "group": "Servers", "username": "u", "url": ""}]
        mock_le = AsyncMock(return_value=entries)
        with patch("server.tools.read.list_entries", mock_le):
            result = await list_entries(ctx, group="Servers", include_inactive=False)
            assert result == entries
            mock_le.assert_called_once_with(
                app.vault, app.audit, group="Servers", include_inactive=False,
            )

    @pytest.mark.asyncio
    async def test_group_not_allowed_maps_to_value_error(self):
        from server.main import list_entries
        ctx, app = _app()
        mock_le = AsyncMock(side_effect=GroupNotAllowed("nope"))
        with patch("server.tools.read.list_entries", mock_le), \
             pytest.raises(ValueError, match="GroupNotAllowed"):
            await list_entries(ctx, group="Banking")


class TestSearchEntriesHandler:
    @pytest.mark.asyncio
    async def test_happy_path(self):
        from server.main import search_entries
        ctx, app = _app()
        entries = [{"title": "Match", "group": "Servers", "username": "u", "url": ""}]
        mock_se = AsyncMock(return_value=entries)
        with patch("server.tools.read.search_entries", mock_se):
            result = await search_entries(
                ctx, query="Match", group=None, include_inactive=False,
            )
            assert result == entries
            mock_se.assert_called_once()

    @pytest.mark.asyncio
    async def test_cli_error_maps_to_value_error(self):
        from server.main import search_entries
        from server.vault import KeePassCLIError
        ctx, app = _app()
        mock_se = AsyncMock(side_effect=KeePassCLIError("timed out"))
        with patch("server.tools.read.search_entries", mock_se), \
             pytest.raises(ValueError, match="KeePassCLIError"):
            await search_entries(ctx, query="x", group=None, include_inactive=False)


class TestGetAttachmentErrors:
    @pytest.mark.asyncio
    async def test_group_not_allowed_maps_to_value_error(self):
        from server.main import get_attachment
        ctx, app = _app()
        mock_ga = AsyncMock(side_effect=GroupNotAllowed("nope"))
        with patch("server.tools.read.get_attachment", mock_ga), \
             pytest.raises(ValueError, match="GroupNotAllowed"):
            await get_attachment(
                ctx, title="Test", attachment_name="file.txt", group="Banking",
            )


class TestDeactivateEntryErrors:
    @pytest.mark.asyncio
    async def test_vault_locked_maps_to_value_error(self):
        from server.main import deactivate_entry
        ctx, app = _app()
        mock_de = AsyncMock(side_effect=VaultLocked("locked"))
        with patch("server.tools.write.deactivate_entry", mock_de), \
             pytest.raises(ValueError, match="VaultLocked"):
            await deactivate_entry(ctx, title="Test", group="Servers")

    @pytest.mark.asyncio
    async def test_write_lock_timeout_maps_to_value_error(self):
        from server.main import deactivate_entry
        ctx, app = _app()
        mock_de = AsyncMock(side_effect=WriteLockTimeout("timeout"))
        with patch("server.tools.write.deactivate_entry", mock_de), \
             pytest.raises(ValueError, match="WriteLockTimeout"):
            await deactivate_entry(ctx, title="Test", group="Servers")


class TestImportEntriesHandler:
    @pytest.mark.asyncio
    async def test_happy_path(self):
        from server.main import import_entries
        ctx, app = _app()
        mock_ie = AsyncMock(return_value="Imported 2 entries across 1 group(s)")
        with patch("server.tools.write.import_entries", mock_ie):
            result = await import_entries(
                ctx,
                entries=[
                    {"group": "Servers", "title": "A"},
                    {"group": "Servers", "title": "B"},
                ],
            )
        assert "Imported 2" in result

    @pytest.mark.asyncio
    async def test_vault_locked_maps_to_value_error(self):
        from server.main import import_entries
        ctx, app = _app()
        mock_ie = AsyncMock(side_effect=VaultLocked("locked"))
        with patch("server.tools.write.import_entries", mock_ie), \
             pytest.raises(ValueError, match="VaultLocked"):
            await import_entries(ctx, entries=[{"group": "Servers", "title": "X"}])

    @pytest.mark.asyncio
    async def test_group_not_allowed_maps_to_value_error(self):
        from server.main import import_entries
        ctx, app = _app()
        mock_ie = AsyncMock(side_effect=GroupNotAllowed("Banking not allowed"))
        with patch("server.tools.write.import_entries", mock_ie), \
             pytest.raises(ValueError, match="GroupNotAllowed"):
            await import_entries(ctx, entries=[{"group": "Banking", "title": "X"}])

    @pytest.mark.asyncio
    async def test_value_error_propagates(self):
        from server.main import import_entries
        ctx, app = _app()
        mock_ie = AsyncMock(side_effect=ValueError("missing title"))
        with patch("server.tools.write.import_entries", mock_ie), \
             pytest.raises(ValueError, match="missing title"):
            await import_entries(ctx, entries=[{"group": "Servers"}])
