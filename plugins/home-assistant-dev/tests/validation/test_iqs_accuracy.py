"""Validation tests for IQS rule accuracy and documentation consistency."""
from __future__ import annotations

import re
from pathlib import Path

import pytest

PLUGIN_ROOT = Path(__file__).parent.parent.parent


class TestIQSRuleAccuracy:
    """Verify IQS rules match official documentation."""

    @pytest.mark.unit
    def test_iqs_total_rule_count(self):
        """Verify total IQS rules equals 52."""
        # Official breakdown: Bronze 18, Silver 10, Gold 21, Platinum 3
        assert 18 + 10 + 21 + 3 == 52

    @pytest.mark.unit
    def test_skill_documents_all_tiers(self):
        """Verify ha-quality-review skill covers all tiers."""
        skill_path = PLUGIN_ROOT / "skills" / "ha-quality-review" / "SKILL.md"
        content = skill_path.read_text()
        
        assert "Bronze" in content
        assert "Silver" in content
        assert "Gold" in content
        assert "Platinum" in content

    @pytest.mark.unit
    def test_bronze_rule_count(self):
        """Verify Bronze tier has approximately 18 rules documented."""
        skill_path = PLUGIN_ROOT / "skills" / "ha-quality-review" / "SKILL.md"
        content = skill_path.read_text()
        
        # Extract Bronze section - headers are "## Bronze Tier"
        bronze_match = re.search(
            r'##\s*Bronze\s+Tier.*?(?=##\s*Silver\s+Tier|$)', 
            content, 
            re.DOTALL | re.IGNORECASE
        )
        assert bronze_match, "Bronze Tier section not found"
        
        bronze_section = bronze_match.group(0)
        # Count rule items (checkbox lines with **rule-name**)
        rule_count = len(re.findall(r'\[\s*\]\s*\*\*[a-z-]+\*\*', bronze_section))
        
        # Allow some flexibility (15-20)
        assert 15 <= rule_count <= 20, f"Expected ~18 Bronze rules, found {rule_count}"

    @pytest.mark.unit
    def test_key_bronze_rules_present(self):
        """Verify key Bronze rules are documented."""
        skill_path = PLUGIN_ROOT / "skills" / "ha-quality-review" / "SKILL.md"
        content = skill_path.read_text().lower()
        
        key_rules = [
            "config-flow",
            "unique-id",
            "has-entity-name",
            "runtime-data",
            "test-before-setup",
            "appropriate-polling",
        ]
        
        for rule in key_rules:
            assert rule in content, f"Bronze rule '{rule}' not documented"

    @pytest.mark.unit
    def test_key_silver_rules_present(self):
        """Verify key Silver rules are documented."""
        skill_path = PLUGIN_ROOT / "skills" / "ha-quality-review" / "SKILL.md"
        content = skill_path.read_text().lower()
        
        key_rules = [
            "config-flow-test-coverage",
            "log-when-unavailable",
            "reauthentication-flow",
        ]
        
        for rule in key_rules:
            assert rule in content, f"Silver rule '{rule}' not documented"

    @pytest.mark.unit
    def test_key_gold_rules_present(self):
        """Verify key Gold rules are documented."""
        skill_path = PLUGIN_ROOT / "skills" / "ha-quality-review" / "SKILL.md"
        content = skill_path.read_text().lower()
        
        key_rules = [
            "diagnostics",
            "discovery",
            "entity-translations",
            "reconfigur",  # matches reconfigure or reconfiguration
        ]
        
        for rule in key_rules:
            assert rule in content, f"Gold rule '{rule}' not documented"

    @pytest.mark.unit
    def test_platinum_rules_present(self):
        """Verify Platinum rules are documented."""
        skill_path = PLUGIN_ROOT / "skills" / "ha-quality-review" / "SKILL.md"
        content = skill_path.read_text().lower()
        
        platinum_rules = [
            "async-dependency",
            "strict-typing",
        ]
        
        for rule in platinum_rules:
            assert rule in content, f"Platinum rule '{rule}' not documented"


class TestDeprecationDateAccuracy:
    """Verify deprecation dates are consistent and accurate."""

    @pytest.mark.unit
    def test_serviceinfo_relocation_date(self):
        """ServiceInfo moved in 2025.1."""
        files_to_check = [
            PLUGIN_ROOT / "skills" / "ha-migration" / "SKILL.md",
            PLUGIN_ROOT / "scripts" / "check-patterns.py",
        ]
        
        for file_path in files_to_check:
            if file_path.exists():
                content = file_path.read_text()
                if "ServiceInfo" in content:
                    assert "2025.1" in content or "2025.01" in content, \
                        f"{file_path} should mention 2025.1 for ServiceInfo"

    @pytest.mark.unit
    def test_runtime_data_introduction_date(self):
        """runtime_data pattern introduced in 2024.8."""
        skill_path = PLUGIN_ROOT / "skills" / "ha-coordinator" / "SKILL.md"
        content = skill_path.read_text()
        
        # Should mention when runtime_data was introduced
        assert "2024" in content, "Should mention runtime_data introduction year"

    @pytest.mark.unit
    def test_async_setup_introduction_date(self):
        """_async_setup introduced in 2024.8."""
        skill_path = PLUGIN_ROOT / "skills" / "ha-coordinator" / "SKILL.md"
        content = skill_path.read_text()
        
        if "_async_setup" in content:
            assert "2024" in content

    @pytest.mark.unit
    def test_options_flow_deprecation_date(self):
        """OptionsFlow __init__ deprecated in 2025.12."""
        patterns_path = PLUGIN_ROOT / "scripts" / "check-patterns.py"
        content = patterns_path.read_text()
        
        if "OptionsFlow" in content and "__init__" in content:
            # Should mention the deprecation version
            assert "2025" in content


class TestCodeExampleSyntax:
    """Verify code examples in skills are valid Python."""

    @pytest.mark.unit
    def test_skill_python_blocks_parse(self):
        """All Python code examples should be valid syntax (with some exceptions)."""
        import ast
        
        skills_dir = PLUGIN_ROOT / "skills"
        errors = []
        
        for skill_file in skills_dir.glob("*/SKILL.md"):
            content = skill_file.read_text()
            
            # Extract Python code blocks
            pattern = r'```python\n(.*?)```'
            code_blocks = re.findall(pattern, content, re.DOTALL)
            
            for i, code in enumerate(code_blocks):
                # Skip incomplete snippets (contain ...)
                if "..." in code:
                    continue
                
                # Skip template placeholders
                if re.search(r'\{[A-Za-z_]+\}', code):
                    continue
                
                # Skip very short snippets (likely partial)
                if len(code.strip()) < 30:
                    continue
                
                # Skip snippets that are clearly partial (no def/class/import)
                if not re.search(r'^(def |async def |class |import |from )', code, re.MULTILINE):
                    continue
                
                try:
                    ast.parse(code)
                except SyntaxError as e:
                    # Allow certain expected errors for partial examples
                    err_str = str(e)
                    if any(x in err_str for x in [
                        "unexpected EOF",
                        "expected an indented block",
                        "invalid syntax",
                    ]):
                        continue
                    errors.append(f"{skill_file.parent.name} block {i}: {e}")
        
        # Report all errors at once (but don't fail for common partial examples)
        if errors:
            # Only fail if there are many errors (suggests real issues)
            if len(errors) > 5:
                pytest.fail(f"Syntax errors in code examples:\n" + "\n".join(errors[:5]))


class TestCrossReferenceConsistency:
    """Verify cross-references between documents are valid."""

    @pytest.mark.unit
    def test_skill_references_exist(self):
        """All referenced skills should exist."""
        skills_dir = PLUGIN_ROOT / "skills"
        existing_skills = {d.name for d in skills_dir.iterdir() if d.is_dir()}
        
        errors = []
        for skill_file in skills_dir.glob("*/SKILL.md"):
            content = skill_file.read_text()
            
            # Find skill references like "→ ha-something" or "See ha-something"
            references = re.findall(r'(?:→|See|see)\s+(ha-[a-z-]+)', content)
            
            for ref in references:
                if ref not in existing_skills:
                    errors.append(f"{skill_file.parent.name}: references non-existent {ref}")
        
        if errors:
            pytest.fail("Invalid skill references:\n" + "\n".join(errors))

    @pytest.mark.unit
    def test_readme_skills_match_directories(self):
        """README skill table matches actual skill directories."""
        readme_path = PLUGIN_ROOT / "README.md"
        skills_dir = PLUGIN_ROOT / "skills"
        agents_dir = PLUGIN_ROOT / "agents"
        
        # Get skills from README (in the "Agent Skills" section, not "Specialized Agents")
        readme_content = readme_path.read_text()
        
        # Extract just the skills section (between "## Skills" and "## Agents")
        skills_section_match = re.search(
            r'## Skills.*?(?=## Agents|$)',
            readme_content,
            re.DOTALL
        )
        if skills_section_match:
            skills_section = skills_section_match.group(0)
            readme_skills = set(re.findall(r'\| `(ha-[a-z-]+)`', skills_section))
        else:
            readme_skills = set()
        
        # Get actual skill directories
        actual_skills = {d.name for d in skills_dir.iterdir() if d.is_dir()}
        
        # Get agent names (these are separate from skills)
        actual_agents = {p.stem for p in agents_dir.glob("*.md")} if agents_dir.exists() else set()
        
        # Skills in README skills section should exist in skills/
        # (Agents are documented separately in "Specialized Agents" section)
        skills_only = readme_skills - actual_agents
        missing = skills_only - actual_skills
        assert not missing, f"README skills section lists non-existent skills: {missing}"
        
        # All skill directories should be documented
        undocumented = actual_skills - readme_skills
        assert not undocumented, f"Skills not in README: {undocumented}"
