"""Comprehensive structural validation of the HA Dev Plugin.

Validates plugin structure without requiring an LLM or Home Assistant instance.
Automates the non-LLM parts of self-test Categories 1 (Plugin Structure) and
4 (Cross-Reference Validation).
"""
from __future__ import annotations

import json
import re
from pathlib import Path

import pytest

try:
    import yaml
except ImportError:
    yaml = None  # type: ignore[assignment]


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

EXPECTED_SKILLS = sorted([
    "ha-architecture",
    "ha-async-patterns",
    "ha-blueprints",
    "ha-config-flow",
    "ha-config-migration",
    "ha-coordinator",
    "ha-debugging",
    "ha-deprecation-fixes",
    "ha-device-conditions-actions",
    "ha-device-triggers",
    "ha-diagnostics",
    "ha-documentation",
    "ha-entity-lifecycle",
    "ha-entity-platforms",
    "ha-hacs",
    "ha-hacs-publishing",
    "ha-integration-scaffold",
    "ha-migration",
    "ha-options-flow",
    "ha-quality-review",
    "ha-recorder",
    "ha-repairs",
    "ha-scripts",
    "ha-service-actions",
    "ha-testing",
    "ha-websocket-api",
    "ha-yaml-automations",
])

EXPECTED_AGENTS = sorted([
    "ha-integration-dev",
    "ha-integration-reviewer",
    "ha-integration-debugger",
])

EXPECTED_EXAMPLES = sorted([
    "polling-hub",
    "minimal-sensor",
    "push-integration",
])

VALID_AGENT_TOOLS = {
    "Read", "Write", "Edit", "Bash", "Grep", "Glob", "WebSearch", "WebFetch",
}

EXPECTED_MCP_SOURCES = [
    "index.ts",
    "ha-client.ts",
    "safety.ts",
    "config.ts",
    "types.ts",
]

EXPECTED_MCP_TOOLS = [
    "check-patterns.ts",
    "docs-examples.ts",
    "docs-fetch.ts",
    "docs-search.ts",
    "ha-call-service.ts",
    "ha-connect.ts",
    "ha-devices.ts",
    "ha-logs.ts",
    "ha-services.ts",
    "ha-states.ts",
    "validate-manifest.ts",
    "validate-strings.ts",
]

EXPECTED_HOOK_SCRIPTS = [
    "validate-manifest.py",
    "validate-strings.py",
    "check-patterns.py",
]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def parse_frontmatter(text: str) -> tuple[dict, str]:
    """Parse YAML frontmatter from a markdown file.

    Returns (frontmatter_dict, body_content).
    Falls back to regex-based parsing if PyYAML is unavailable.
    """
    if not text.startswith("---"):
        raise ValueError("File does not start with YAML frontmatter delimiter '---'")

    # Split on the second '---' delimiter
    parts = text.split("---", 2)
    if len(parts) < 3:
        raise ValueError("Missing closing '---' delimiter for frontmatter")

    raw_yaml = parts[1].strip()
    body = parts[2].strip()

    if yaml is not None:
        frontmatter = yaml.safe_load(raw_yaml)
        if not isinstance(frontmatter, dict):
            raise ValueError(f"Frontmatter parsed to {type(frontmatter)}, expected dict")
        return frontmatter, body

    # Fallback: simple regex-based key-value parser
    result: dict[str, str | list[str]] = {}
    current_key: str | None = None
    current_list: list[str] = []

    for line in raw_yaml.splitlines():
        # List item under a key
        list_match = re.match(r"^\s+-\s+(.+)$", line)
        if list_match and current_key is not None:
            current_list.append(list_match.group(1).strip())
            continue

        # Flush any pending list
        if current_key is not None and current_list:
            result[current_key] = current_list
            current_list = []
            current_key = None

        # Key-value pair
        kv_match = re.match(r"^(\w[\w-]*):\s*(.*)$", line)
        if kv_match:
            key = kv_match.group(1)
            value = kv_match.group(2).strip()
            if value:
                result[key] = value
            else:
                # Value might be a list on subsequent lines
                current_key = key
                current_list = []

    # Flush final list
    if current_key is not None and current_list:
        result[current_key] = current_list

    return result, body


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def plugin_root() -> Path:
    """Return Path to the HA Dev Plugin root directory."""
    return Path(__file__).parent.parent


# ---------------------------------------------------------------------------
# Category 1: Skill Validation (19 skills)
# ---------------------------------------------------------------------------

@pytest.mark.unit
class TestSkillValidation:
    """Validate all 19 skill directories and their SKILL.md files."""

    def test_skill_count(self, plugin_root: Path) -> None:
        """Exactly 27 skill directories exist."""
        skills_dir = plugin_root / "skills"
        skill_dirs = sorted([
            d.name for d in skills_dir.iterdir()
            if d.is_dir() and not d.name.startswith(".")
        ])
        assert len(skill_dirs) == 27, (
            f"Expected 27 skill directories, found {len(skill_dirs)}: {skill_dirs}"
        )
        assert skill_dirs == EXPECTED_SKILLS, (
            f"Skill directories do not match expected.\n"
            f"  Missing: {sorted(set(EXPECTED_SKILLS) - set(skill_dirs))}\n"
            f"  Extra:   {sorted(set(skill_dirs) - set(EXPECTED_SKILLS))}"
        )

    @pytest.mark.parametrize("skill_name", EXPECTED_SKILLS)
    def test_skill_files_exist(self, plugin_root: Path, skill_name: str) -> None:
        """Each skill directory has a SKILL.md file."""
        skill_md = plugin_root / "skills" / skill_name / "SKILL.md"
        assert skill_md.is_file(), f"Missing SKILL.md in skills/{skill_name}/"

    @pytest.mark.parametrize("skill_name", EXPECTED_SKILLS)
    def test_skill_frontmatter_valid(self, plugin_root: Path, skill_name: str) -> None:
        """Each SKILL.md starts with --- and has valid YAML frontmatter with name and description."""
        skill_md = plugin_root / "skills" / skill_name / "SKILL.md"
        text = skill_md.read_text(encoding="utf-8")

        assert text.startswith("---"), (
            f"skills/{skill_name}/SKILL.md does not start with YAML frontmatter delimiter '---'"
        )

        fm, _ = parse_frontmatter(text)

        assert "name" in fm, (
            f"skills/{skill_name}/SKILL.md frontmatter missing 'name' field"
        )
        assert "description" in fm, (
            f"skills/{skill_name}/SKILL.md frontmatter missing 'description' field"
        )

    @pytest.mark.parametrize("skill_name", EXPECTED_SKILLS)
    def test_skill_names_match_dirs(self, plugin_root: Path, skill_name: str) -> None:
        """Frontmatter name field matches the directory name."""
        skill_md = plugin_root / "skills" / skill_name / "SKILL.md"
        text = skill_md.read_text(encoding="utf-8")
        fm, _ = parse_frontmatter(text)

        assert fm.get("name") == skill_name, (
            f"skills/{skill_name}/SKILL.md frontmatter name is '{fm.get('name')}', "
            f"expected '{skill_name}'"
        )

    @pytest.mark.parametrize("skill_name", EXPECTED_SKILLS)
    def test_skill_descriptions_nonempty(self, plugin_root: Path, skill_name: str) -> None:
        """Description field is at least 20 characters (meaningful)."""
        skill_md = plugin_root / "skills" / skill_name / "SKILL.md"
        text = skill_md.read_text(encoding="utf-8")
        fm, _ = parse_frontmatter(text)

        desc = fm.get("description", "")
        assert len(desc) >= 20, (
            f"skills/{skill_name}/SKILL.md description is only {len(desc)} chars "
            f"(minimum 20): '{desc}'"
        )

    @pytest.mark.parametrize("skill_name", EXPECTED_SKILLS)
    def test_skill_content_nonempty(self, plugin_root: Path, skill_name: str) -> None:
        """Content after frontmatter is at least 100 characters."""
        skill_md = plugin_root / "skills" / skill_name / "SKILL.md"
        text = skill_md.read_text(encoding="utf-8")
        _, body = parse_frontmatter(text)

        assert len(body) >= 100, (
            f"skills/{skill_name}/SKILL.md body content is only {len(body)} chars "
            f"(minimum 100)"
        )


# ---------------------------------------------------------------------------
# Category 1: Agent Validation (3 agents)
# ---------------------------------------------------------------------------

@pytest.mark.unit
class TestAgentValidation:
    """Validate all 3 agent markdown files."""

    def test_agent_count(self, plugin_root: Path) -> None:
        """Exactly 3 agent files exist."""
        agents_dir = plugin_root / "agents"
        agent_files = sorted([
            f.stem for f in agents_dir.iterdir()
            if f.is_file() and f.suffix == ".md" and not f.name.startswith(".")
        ])
        assert len(agent_files) == 3, (
            f"Expected 3 agent files, found {len(agent_files)}: {agent_files}"
        )
        assert agent_files == EXPECTED_AGENTS, (
            f"Agent files do not match expected.\n"
            f"  Missing: {sorted(set(EXPECTED_AGENTS) - set(agent_files))}\n"
            f"  Extra:   {sorted(set(agent_files) - set(EXPECTED_AGENTS))}"
        )

    @pytest.mark.parametrize("agent_name", EXPECTED_AGENTS)
    def test_agent_frontmatter_valid(self, plugin_root: Path, agent_name: str) -> None:
        """Each agent has valid YAML frontmatter with name, description, and tools."""
        agent_md = plugin_root / "agents" / f"{agent_name}.md"
        assert agent_md.is_file(), f"Missing agents/{agent_name}.md"

        text = agent_md.read_text(encoding="utf-8")
        assert text.startswith("---"), (
            f"agents/{agent_name}.md does not start with YAML frontmatter delimiter '---'"
        )

        fm, _ = parse_frontmatter(text)

        for field in ("name", "description", "tools"):
            assert field in fm, (
                f"agents/{agent_name}.md frontmatter missing '{field}' field"
            )

    @pytest.mark.parametrize("agent_name", EXPECTED_AGENTS)
    def test_agent_tools_valid(self, plugin_root: Path, agent_name: str) -> None:
        """Tools field contains only valid tool names."""
        agent_md = plugin_root / "agents" / f"{agent_name}.md"
        text = agent_md.read_text(encoding="utf-8")
        fm, _ = parse_frontmatter(text)

        tools_raw = fm.get("tools", "")
        # Tools can be a comma-separated string or a list
        if isinstance(tools_raw, list):
            tools = [t.strip() for t in tools_raw]
        else:
            tools = [t.strip() for t in str(tools_raw).split(",")]

        invalid_tools = [t for t in tools if t not in VALID_AGENT_TOOLS]
        assert not invalid_tools, (
            f"agents/{agent_name}.md has invalid tools: {invalid_tools}. "
            f"Valid tools: {sorted(VALID_AGENT_TOOLS)}"
        )

    @pytest.mark.parametrize("agent_name", EXPECTED_AGENTS)
    def test_agent_skills_exist(self, plugin_root: Path, agent_name: str) -> None:
        """Each skill referenced in agent frontmatter exists as a skill directory."""
        agent_md = plugin_root / "agents" / f"{agent_name}.md"
        text = agent_md.read_text(encoding="utf-8")
        fm, _ = parse_frontmatter(text)

        skills_raw = fm.get("skills", [])
        if isinstance(skills_raw, str):
            skills = [s.strip() for s in skills_raw.split(",")]
        elif isinstance(skills_raw, list):
            skills = [str(s).strip() for s in skills_raw]
        else:
            pytest.fail(f"agents/{agent_name}.md 'skills' field has unexpected type: {type(skills_raw)}")

        for skill_name in skills:
            skill_dir = plugin_root / "skills" / skill_name
            assert skill_dir.is_dir(), (
                f"agents/{agent_name}.md references skill '{skill_name}' "
                f"but skills/{skill_name}/ does not exist"
            )


# ---------------------------------------------------------------------------
# Category 1: Hooks Validation
# ---------------------------------------------------------------------------

@pytest.mark.unit
class TestHooksValidation:
    """Validate hooks configuration and referenced scripts."""

    def test_hooks_json_valid(self, plugin_root: Path) -> None:
        """hooks/hooks.json is valid JSON."""
        hooks_path = plugin_root / "hooks" / "hooks.json"
        assert hooks_path.is_file(), "Missing hooks/hooks.json"

        text = hooks_path.read_text(encoding="utf-8")
        try:
            data = json.loads(text)
        except json.JSONDecodeError as exc:
            pytest.fail(f"hooks/hooks.json is not valid JSON: {exc}")

        assert isinstance(data, dict), "hooks/hooks.json root must be a JSON object"

    def test_hooks_scripts_exist(self, plugin_root: Path) -> None:
        """Each hook's command references scripts that exist on disk."""
        hooks_path = plugin_root / "hooks" / "hooks.json"
        data = json.loads(hooks_path.read_text(encoding="utf-8"))

        hooks_record = data.get("hooks", {})
        assert isinstance(hooks_record, dict), "hooks must be a record keyed by event name"
        assert len(hooks_record) > 0, "hooks/hooks.json has no hooks defined"

        for event_name, matchers in hooks_record.items():
            for matcher_entry in matchers:
                for hook_def in matcher_entry.get("hooks", []):
                    cmd = hook_def.get("command", "")
                    # Extract script path from command string
                    if "${CLAUDE_PLUGIN_ROOT}/scripts/" in cmd:
                        script_name = cmd.split("${CLAUDE_PLUGIN_ROOT}/scripts/")[-1]
                        script_path = plugin_root / "scripts" / script_name
                        assert script_path.is_file(), (
                            f"Hook '{event_name}' references script "
                            f"'{script_name}' but scripts/{script_name} does not exist"
                        )

        # Also verify all expected hook scripts exist independently
        for script_name in EXPECTED_HOOK_SCRIPTS:
            script_path = plugin_root / "scripts" / script_name
            assert script_path.is_file(), f"Expected hook script scripts/{script_name} not found"

    def test_hooks_have_matchers(self, plugin_root: Path) -> None:
        """Each hook event has matcher entries with tool patterns and hook definitions."""
        hooks_path = plugin_root / "hooks" / "hooks.json"
        data = json.loads(hooks_path.read_text(encoding="utf-8"))

        hooks_record = data.get("hooks", {})
        assert isinstance(hooks_record, dict), "hooks must be a record keyed by event name"

        for event_name, matchers in hooks_record.items():
            assert isinstance(matchers, list) and len(matchers) > 0, (
                f"Hook event '{event_name}' must have at least one matcher entry"
            )
            for matcher_entry in matchers:
                assert "matcher" in matcher_entry, (
                    f"Hook event '{event_name}' entry missing 'matcher' field"
                )
                assert "hooks" in matcher_entry, (
                    f"Hook event '{event_name}' entry missing 'hooks' field"
                )


# ---------------------------------------------------------------------------
# Category 1: Example Integration Validation
# ---------------------------------------------------------------------------

@pytest.mark.unit
class TestExampleIntegrations:
    """Validate all 3 example integration directories."""

    @pytest.mark.parametrize("example_name", EXPECTED_EXAMPLES)
    def test_example_dirs_exist(self, plugin_root: Path, example_name: str) -> None:
        """All 3 example directories exist."""
        example_dir = plugin_root / "examples" / example_name
        assert example_dir.is_dir(), f"Missing examples/{example_name}/"

    @pytest.mark.parametrize("example_name", EXPECTED_EXAMPLES)
    def test_examples_have_manifests(self, plugin_root: Path, example_name: str) -> None:
        """Each example has custom_components/*/manifest.json."""
        example_dir = plugin_root / "examples" / example_name / "custom_components"
        assert example_dir.is_dir(), (
            f"Missing examples/{example_name}/custom_components/"
        )

        # Find manifest.json files under custom_components
        manifests = list(example_dir.glob("*/manifest.json"))
        assert len(manifests) >= 1, (
            f"No manifest.json found under examples/{example_name}/custom_components/*/"
        )

    @pytest.mark.parametrize("example_name", EXPECTED_EXAMPLES)
    def test_example_manifests_valid_json(self, plugin_root: Path, example_name: str) -> None:
        """Each manifest is valid JSON with at least domain and name fields."""
        example_dir = plugin_root / "examples" / example_name / "custom_components"
        manifests = list(example_dir.glob("*/manifest.json"))

        for manifest_path in manifests:
            text = manifest_path.read_text(encoding="utf-8")
            try:
                data = json.loads(text)
            except json.JSONDecodeError as exc:
                pytest.fail(
                    f"Invalid JSON in {manifest_path.relative_to(plugin_root)}: {exc}"
                )

            assert "domain" in data, (
                f"{manifest_path.relative_to(plugin_root)} missing 'domain' field"
            )
            assert "name" in data, (
                f"{manifest_path.relative_to(plugin_root)} missing 'name' field"
            )


# ---------------------------------------------------------------------------
# Category 1: MCP Server Structure
# ---------------------------------------------------------------------------

@pytest.mark.unit
class TestMCPServerStructure:
    """Validate MCP server source files and configuration."""

    def test_mcp_package_json_exists(self, plugin_root: Path) -> None:
        """mcp-server/package.json exists."""
        pkg_json = plugin_root / "mcp-server" / "package.json"
        assert pkg_json.is_file(), "Missing mcp-server/package.json"

        # Verify it is valid JSON
        try:
            json.loads(pkg_json.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            pytest.fail(f"mcp-server/package.json is not valid JSON: {exc}")

    @pytest.mark.parametrize("source_file", EXPECTED_MCP_SOURCES)
    def test_mcp_source_files_exist(self, plugin_root: Path, source_file: str) -> None:
        """Key source files exist in mcp-server/src/."""
        src_path = plugin_root / "mcp-server" / "src" / source_file
        assert src_path.is_file(), f"Missing mcp-server/src/{source_file}"

    @pytest.mark.parametrize("tool_file", EXPECTED_MCP_TOOLS)
    def test_mcp_tools_exist(self, plugin_root: Path, tool_file: str) -> None:
        """All expected tool files exist in mcp-server/src/tools/."""
        tool_path = plugin_root / "mcp-server" / "src" / "tools" / tool_file
        assert tool_path.is_file(), f"Missing mcp-server/src/tools/{tool_file}"


# ---------------------------------------------------------------------------
# Category 4: Cross-Reference Validation
# ---------------------------------------------------------------------------

@pytest.mark.unit
class TestCrossReferenceValidation:
    """Validate cross-references between plugin components."""

    def test_readme_skill_count_matches(self, plugin_root: Path) -> None:
        """If README.md mentions a skill count, it matches actual count."""
        readme_path = plugin_root / "README.md"
        if not readme_path.is_file():
            pytest.skip("No README.md found")

        text = readme_path.read_text(encoding="utf-8")

        # Look for patterns like "19 Agent Skills" or "19 skills"
        match = re.search(r"(\d+)\s+(?:Agent\s+)?Skills?", text, re.IGNORECASE)
        if match is None:
            pytest.skip("README.md does not mention a skill count")

        readme_count = int(match.group(1))
        skills_dir = plugin_root / "skills"
        actual_count = len([
            d for d in skills_dir.iterdir()
            if d.is_dir() and not d.name.startswith(".")
        ])

        assert readme_count == actual_count, (
            f"README.md claims {readme_count} skills but {actual_count} skill "
            f"directories exist"
        )

    def test_manifest_references_hooks(self, plugin_root: Path) -> None:
        """Plugin manifest (.claude-plugin/plugin.json) exists and is valid JSON."""
        manifest_path = plugin_root / ".claude-plugin" / "plugin.json"
        assert manifest_path.is_file(), "Missing .claude-plugin/plugin.json"

        try:
            data = json.loads(manifest_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            pytest.fail(f".claude-plugin/plugin.json is not valid JSON: {exc}")

        # Verify essential fields
        assert "name" in data, ".claude-plugin/plugin.json missing 'name' field"
        assert "version" in data, ".claude-plugin/plugin.json missing 'version' field"
        assert "description" in data, ".claude-plugin/plugin.json missing 'description' field"
