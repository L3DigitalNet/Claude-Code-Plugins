"""
Layer 1 — Structural Validation (pytest)

Validates the linux-sysadmin-mcp plugin is correctly assembled:
manifest, MCP config, bundle, source tree, knowledge profiles, and cross-references.

Runs anywhere with just Python — no Node.js, no container, no sudo needed.
"""

from __future__ import annotations

import json
from pathlib import Path

import pytest

# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture(scope="session")
def plugin_root() -> Path:
    """Return the plugin root directory (one level above tests/)."""
    return Path(__file__).parent.parent


# ---------------------------------------------------------------------------
# TestPluginManifest
# ---------------------------------------------------------------------------

@pytest.mark.unit
class TestPluginManifest:
    """Validate .claude-plugin/plugin.json."""

    def test_manifest_exists(self, plugin_root: Path) -> None:
        path = plugin_root / ".claude-plugin" / "plugin.json"
        assert path.exists(), f"Missing manifest: {path}"

    def test_manifest_valid_json(self, plugin_root: Path) -> None:
        path = plugin_root / ".claude-plugin" / "plugin.json"
        data = json.loads(path.read_text())
        assert isinstance(data, dict)

    def test_manifest_required_fields(self, plugin_root: Path) -> None:
        data = json.loads(
            (plugin_root / ".claude-plugin" / "plugin.json").read_text()
        )
        for field in ("name", "version", "description"):
            assert field in data, f"Manifest missing required field: {field}"

    def test_manifest_name(self, plugin_root: Path) -> None:
        data = json.loads(
            (plugin_root / ".claude-plugin" / "plugin.json").read_text()
        )
        assert data["name"] == "linux-sysadmin-mcp"


# ---------------------------------------------------------------------------
# TestMCPConfig
# ---------------------------------------------------------------------------

@pytest.mark.unit
class TestMCPConfig:
    """Validate .mcp.json MCP server configuration."""

    def test_mcp_json_exists(self, plugin_root: Path) -> None:
        path = plugin_root / ".mcp.json"
        assert path.exists(), f"Missing MCP config: {path}"

    def test_mcp_json_has_server_key(self, plugin_root: Path) -> None:
        data = json.loads((plugin_root / ".mcp.json").read_text())
        assert "linux-sysadmin-mcp" in data, (
            "MCP config missing 'linux-sysadmin-mcp' server key"
        )

    def test_mcp_json_points_to_bundle(self, plugin_root: Path) -> None:
        data = json.loads((plugin_root / ".mcp.json").read_text())
        args = data["linux-sysadmin-mcp"].get("args", [])
        joined = " ".join(args)
        assert "server.bundle.cjs" in joined, (
            f"MCP args should reference server.bundle.cjs, got: {args}"
        )

    def test_mcp_json_uses_plugin_root_var(self, plugin_root: Path) -> None:
        text = (plugin_root / ".mcp.json").read_text()
        assert "${CLAUDE_PLUGIN_ROOT}" in text, (
            "MCP config should use ${CLAUDE_PLUGIN_ROOT} path variable"
        )


# ---------------------------------------------------------------------------
# TestBundleExists
# ---------------------------------------------------------------------------

@pytest.mark.unit
class TestBundleExists:
    """Validate the distributable bundle."""

    def test_bundle_file_exists(self, plugin_root: Path) -> None:
        path = plugin_root / "dist" / "server.bundle.cjs"
        assert path.exists(), f"Missing bundle: {path}"

    def test_bundle_file_size(self, plugin_root: Path) -> None:
        path = plugin_root / "dist" / "server.bundle.cjs"
        size = path.stat().st_size
        min_size = 500_000  # 500 KB
        assert size > min_size, (
            f"Bundle too small: {size:,} bytes (expected > {min_size:,})"
        )


# ---------------------------------------------------------------------------
# TestTypeScriptSources
# ---------------------------------------------------------------------------

TOOL_MODULES = [
    "backup",
    "containers",
    "cron",
    "docs",
    "firewall",
    "logs",
    "networking",
    "packages",
    "performance",
    "security",
    "services",
    "session",
    "ssh",
    "storage",
    "users",
]

INFRASTRUCTURE_FILES = [
    "src/server.ts",
    "src/logger.ts",
    "src/config/loader.ts",
    "src/distro/detector.ts",
    "src/execution/executor.ts",
    "src/safety/gate.ts",
    "src/knowledge/loader.ts",
    "src/tools/registry.ts",
    "src/tools/context.ts",
    "src/tools/helpers.ts",
]

TYPE_FILES = [
    "src/types/command.ts",
    "src/types/config.ts",
    "src/types/distro.ts",
    "src/types/firewall.ts",
    "src/types/index.ts",
    "src/types/response.ts",
    "src/types/risk.ts",
    "src/types/tool.ts",
]


@pytest.mark.unit
class TestTypeScriptSources:
    """Validate the TypeScript source tree is complete."""

    def test_server_entry_point(self, plugin_root: Path) -> None:
        assert (plugin_root / "src" / "server.ts").exists()

    @pytest.mark.parametrize("module", TOOL_MODULES)
    def test_tool_module_index(self, plugin_root: Path, module: str) -> None:
        path = plugin_root / "src" / "tools" / module / "index.ts"
        assert path.exists(), f"Missing tool module index: {path}"

    def test_tool_module_count(self, plugin_root: Path) -> None:
        tools_dir = plugin_root / "src" / "tools"
        modules = sorted(
            d.name
            for d in tools_dir.iterdir()
            if d.is_dir() and (d / "index.ts").exists()
        )
        assert len(modules) == 15, (
            f"Expected 15 tool modules, found {len(modules)}: {modules}"
        )

    @pytest.mark.parametrize("relpath", INFRASTRUCTURE_FILES)
    def test_infrastructure_file(self, plugin_root: Path, relpath: str) -> None:
        path = plugin_root / relpath
        assert path.exists(), f"Missing infrastructure file: {path}"

    @pytest.mark.parametrize("relpath", TYPE_FILES)
    def test_type_file(self, plugin_root: Path, relpath: str) -> None:
        path = plugin_root / relpath
        assert path.exists(), f"Missing type file: {path}"


# ---------------------------------------------------------------------------
# TestKnowledgeProfiles
# ---------------------------------------------------------------------------

KNOWLEDGE_PROFILES = [
    "crowdsec",
    "docker",
    "fail2ban",
    "nginx",
    "pihole",
    "sshd",
    "ufw",
    "unbound",
]

yaml = pytest.importorskip("yaml", reason="PyYAML not installed")


@pytest.mark.unit
class TestKnowledgeProfiles:
    """Validate YAML knowledge profiles."""

    def test_profile_count(self, plugin_root: Path) -> None:
        knowledge_dir = plugin_root / "knowledge"
        yamls = sorted(knowledge_dir.glob("*.yaml"))
        assert len(yamls) == 8, (
            f"Expected 8 YAML profiles, found {len(yamls)}: "
            f"{[y.name for y in yamls]}"
        )

    @pytest.mark.parametrize("profile_name", KNOWLEDGE_PROFILES)
    def test_profile_exists(self, plugin_root: Path, profile_name: str) -> None:
        path = plugin_root / "knowledge" / f"{profile_name}.yaml"
        assert path.exists(), f"Missing knowledge profile: {path}"

    @pytest.mark.parametrize("profile_name", KNOWLEDGE_PROFILES)
    def test_profile_parses(self, plugin_root: Path, profile_name: str) -> None:
        path = plugin_root / "knowledge" / f"{profile_name}.yaml"
        data = yaml.safe_load(path.read_text())
        assert isinstance(data, dict), f"Profile {profile_name} did not parse as dict"

    @pytest.mark.parametrize("profile_name", KNOWLEDGE_PROFILES)
    def test_profile_required_fields(
        self, plugin_root: Path, profile_name: str
    ) -> None:
        path = plugin_root / "knowledge" / f"{profile_name}.yaml"
        data = yaml.safe_load(path.read_text())
        for field in ("id", "name", "schema_version", "category"):
            assert field in data, (
                f"Profile {profile_name} missing required field: {field}"
            )
        assert "service" in data, (
            f"Profile {profile_name} missing 'service' section"
        )
        assert "unit_names" in data["service"], (
            f"Profile {profile_name} missing 'service.unit_names'"
        )

    @pytest.mark.parametrize("profile_name", KNOWLEDGE_PROFILES)
    def test_profile_id_matches_filename(
        self, plugin_root: Path, profile_name: str
    ) -> None:
        path = plugin_root / "knowledge" / f"{profile_name}.yaml"
        data = yaml.safe_load(path.read_text())
        assert data["id"] == profile_name, (
            f"Profile id '{data['id']}' does not match filename '{profile_name}'"
        )

    def test_no_duplicate_profile_ids(self, plugin_root: Path) -> None:
        knowledge_dir = plugin_root / "knowledge"
        ids: list[str] = []
        for yf in sorted(knowledge_dir.glob("*.yaml")):
            data = yaml.safe_load(yf.read_text())
            ids.append(data["id"])
        assert len(ids) == len(set(ids)), (
            f"Duplicate profile IDs detected: {ids}"
        )


# ---------------------------------------------------------------------------
# TestPackageJson
# ---------------------------------------------------------------------------

@pytest.mark.unit
class TestPackageJson:
    """Validate package.json configuration."""

    def test_package_json_exists(self, plugin_root: Path) -> None:
        assert (plugin_root / "package.json").exists()

    def test_package_json_valid(self, plugin_root: Path) -> None:
        data = json.loads((plugin_root / "package.json").read_text())
        assert isinstance(data, dict)

    def test_build_script_bundles(self, plugin_root: Path) -> None:
        data = json.loads((plugin_root / "package.json").read_text())
        build = data.get("scripts", {}).get("build", "")
        assert "bundle" in build, (
            f"Build script should include 'bundle', got: {build}"
        )

    def test_start_script_uses_bundle(self, plugin_root: Path) -> None:
        data = json.loads((plugin_root / "package.json").read_text())
        start = data.get("scripts", {}).get("start", "")
        assert "server.bundle.cjs" in start, (
            f"Start script should reference server.bundle.cjs, got: {start}"
        )

    @pytest.mark.parametrize(
        "dep",
        ["@modelcontextprotocol/sdk", "pino", "yaml", "zod"],
    )
    def test_required_dependency(self, plugin_root: Path, dep: str) -> None:
        data = json.loads((plugin_root / "package.json").read_text())
        deps = data.get("dependencies", {})
        assert dep in deps, f"Missing required dependency: {dep}"

    def test_no_ssh2_dependency(self, plugin_root: Path) -> None:
        data = json.loads((plugin_root / "package.json").read_text())
        deps = data.get("dependencies", {})
        dev_deps = data.get("devDependencies", {})
        assert "ssh2" not in deps, "ssh2 should NOT be a production dependency"
        assert "ssh2" not in dev_deps, "ssh2 should NOT be a dev dependency"


# ---------------------------------------------------------------------------
# TestCrossReferences
# ---------------------------------------------------------------------------

@pytest.mark.unit
class TestCrossReferences:
    """Validate cross-file consistency."""

    def test_readme_mentions_module_count(self, plugin_root: Path) -> None:
        readme = (plugin_root / "README.md").read_text()
        assert "15" in readme, (
            "README should mention 15 modules"
        )

    def test_readme_mentions_all_profiles(self, plugin_root: Path) -> None:
        readme = (plugin_root / "README.md").read_text().lower()
        for profile in KNOWLEDGE_PROFILES:
            assert profile in readme, (
                f"README should mention knowledge profile: {profile}"
            )

    def test_gitignore_preserves_bundle(self, plugin_root: Path) -> None:
        gitignore = (plugin_root / ".gitignore").read_text()
        assert "!dist/server.bundle.cjs" in gitignore, (
            ".gitignore should have '!dist/server.bundle.cjs' exception"
        )

    def test_gitignore_ignores_node_modules(self, plugin_root: Path) -> None:
        gitignore = (plugin_root / ".gitignore").read_text()
        assert "node_modules/" in gitignore, (
            ".gitignore should ignore node_modules/"
        )
