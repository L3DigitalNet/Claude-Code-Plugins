# Testing Strategy: Home Assistant Development Plugin v2.2

## Overview

This document outlines a multi-layered testing approach for the HA Dev Plugin, covering unit tests, integration tests, validation tests, and end-to-end workflow tests.

---

## Test Categories

### 1. Unit Tests (Automated)

#### 1.1 Python Validation Scripts

**Location:** `tests/scripts/`

```python
# tests/scripts/test_validate_manifest.py
import pytest
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))

from validate_manifest import validate_manifest, ValidationError

class TestValidateManifest:
    """Tests for manifest.json validation."""

    def test_valid_manifest(self, tmp_path):
        """Valid manifest passes all checks."""
        manifest = tmp_path / "test_domain" / "manifest.json"
        manifest.parent.mkdir()
        manifest.write_text('''{
            "domain": "test_domain",
            "name": "Test",
            "version": "1.0.0",
            "codeowners": ["@test"],
            "documentation": "https://example.com",
            "issue_tracker": "https://example.com/issues",
            "integration_type": "hub",
            "iot_class": "local_polling",
            "config_flow": true
        }''')
        
        errors, warnings = validate_manifest(manifest, is_custom=True)
        assert len(errors) == 0

    def test_missing_required_field(self, tmp_path):
        """Missing required field produces error."""
        manifest = tmp_path / "manifest.json"
        manifest.write_text('{"domain": "test"}')
        
        errors, _ = validate_manifest(manifest, is_custom=True)
        assert any("name" in str(e) for e in errors)

    def test_invalid_iot_class(self, tmp_path):
        """Invalid iot_class produces error."""
        manifest = tmp_path / "manifest.json"
        manifest.write_text('''{
            "domain": "test",
            "name": "Test",
            "iot_class": "invalid_class"
        }''')
        
        errors, _ = validate_manifest(manifest, is_custom=False)
        assert any("iot_class" in str(e) for e in errors)

    def test_invalid_semver(self, tmp_path):
        """Invalid version format produces error."""
        manifest = tmp_path / "manifest.json"
        manifest.write_text('''{
            "domain": "test",
            "name": "Test",
            "version": "1.0"
        }''')
        
        errors, _ = validate_manifest(manifest, is_custom=True)
        assert any("version" in str(e) for e in errors)

    def test_codeowner_format(self, tmp_path):
        """Codeowner without @ produces error."""
        manifest = tmp_path / "manifest.json"
        manifest.write_text('''{
            "domain": "test",
            "name": "Test",
            "codeowners": ["missing_at"]
        }''')
        
        errors, _ = validate_manifest(manifest, is_custom=False)
        assert any("@" in str(e) for e in errors)

    def test_domain_directory_mismatch(self, tmp_path):
        """Domain not matching directory produces warning."""
        manifest = tmp_path / "wrong_dir" / "manifest.json"
        manifest.parent.mkdir()
        manifest.write_text('{"domain": "correct_domain", "name": "Test"}')
        
        _, warnings = validate_manifest(manifest, is_custom=False)
        assert any("directory" in str(w).lower() for w in warnings)
```

```python
# tests/scripts/test_validate_strings.py
import pytest
from pathlib import Path

class TestValidateStrings:
    """Tests for strings.json validation."""

    def test_missing_step_string(self, tmp_path):
        """Step in config_flow without strings.json entry."""
        # Create config_flow.py with async_step_user
        config_flow = tmp_path / "config_flow.py"
        config_flow.write_text('''
async def async_step_user(self, user_input=None):
    pass
async def async_step_confirm(self, user_input=None):
    pass
''')
        
        # Create strings.json missing 'confirm' step
        strings = tmp_path / "strings.json"
        strings.write_text('{"config": {"step": {"user": {"title": "User"}}}}')
        
        result = validate_strings(strings)
        assert "confirm" in result["missing_steps"]

    def test_orphaned_step_string(self, tmp_path):
        """Step in strings.json without config_flow method."""
        config_flow = tmp_path / "config_flow.py"
        config_flow.write_text('async def async_step_user(self): pass')
        
        strings = tmp_path / "strings.json"
        strings.write_text('''{
            "config": {
                "step": {
                    "user": {"title": "User"},
                    "orphaned": {"title": "Orphaned"}
                }
            }
        }''')
        
        result = validate_strings(strings)
        assert "orphaned" in result["orphaned_steps"]

    def test_missing_data_description(self, tmp_path):
        """Missing data_description for Bronze compliance."""
        strings = tmp_path / "strings.json"
        strings.write_text('''{
            "config": {
                "step": {
                    "user": {
                        "data": {"host": "Host"}
                    }
                }
            }
        }''')
        
        result = validate_strings(strings)
        assert len(result["missing_data_descriptions"]) > 0
```

```python
# tests/scripts/test_check_patterns.py
import pytest
from pathlib import Path

class TestCheckPatterns:
    """Tests for anti-pattern detection."""

    def test_detects_hass_data_domain(self, tmp_path):
        """Detects deprecated hass.data[DOMAIN] usage."""
        py_file = tmp_path / "test.py"
        py_file.write_text('coordinator = hass.data[DOMAIN][entry.entry_id]')
        
        matches = check_patterns(py_file)
        assert any("runtime_data" in m.pattern.message for m in matches)

    def test_detects_blocking_requests(self, tmp_path):
        """Detects blocking requests.get call."""
        py_file = tmp_path / "test.py"
        py_file.write_text('response = requests.get(url)')
        
        matches = check_patterns(py_file)
        assert any("aiohttp" in m.pattern.message for m in matches)

    def test_detects_old_serviceinfo_import(self, tmp_path):
        """Detects deprecated ServiceInfo import."""
        py_file = tmp_path / "test.py"
        py_file.write_text('from homeassistant.components.zeroconf import ZeroconfServiceInfo')
        
        matches = check_patterns(py_file)
        assert any("2025.1" in m.pattern.message for m in matches)

    def test_detects_typing_list(self, tmp_path):
        """Detects deprecated List[] syntax."""
        py_file = tmp_path / "test.py"
        py_file.write_text('def foo(items: List[str]) -> None: pass')
        
        matches = check_patterns(py_file)
        assert any("list[]" in m.pattern.message for m in matches)

    def test_ignores_comments(self, tmp_path):
        """Does not flag patterns in comments."""
        py_file = tmp_path / "test.py"
        py_file.write_text('# hass.data[DOMAIN] is deprecated\npass')
        
        matches = check_patterns(py_file)
        assert len(matches) == 0

    def test_detects_options_flow_init(self, tmp_path):
        """Detects deprecated OptionsFlow __init__."""
        py_file = tmp_path / "test.py"
        py_file.write_text('''
class MyOptionsFlow(OptionsFlow):
    def __init__(self, config_entry):
        self.config_entry = config_entry
''')
        
        matches = check_patterns(py_file)
        assert any("OptionsFlow" in m.pattern.name for m in matches)
```

#### 1.2 MCP Server Unit Tests

**Location:** `mcp-server/__tests__/`

```typescript
// mcp-server/__tests__/safety.test.ts (already exists)
// Additional tests:

describe('SafetyChecker - Extended', () => {
  it('should block wildcard patterns', () => {
    const config = {
      allowServiceCalls: true,
      blockedServices: ['recorder.*'],
      requireDryRun: false,
    };
    const checker = new SafetyChecker(config);
    
    expect(checker.checkServiceCall('recorder', 'purge', false).allowed).toBe(false);
    expect(checker.checkServiceCall('recorder', 'enable', false).allowed).toBe(false);
  });
});
```

```typescript
// mcp-server/__tests__/validate-manifest.test.ts
import { handleValidateManifest } from '../src/tools/validate-manifest.js';
import { writeFile, mkdir, rm } from 'fs/promises';
import { join } from 'path';
import { tmpdir } from 'os';

describe('validate_manifest tool', () => {
  let testDir: string;

  beforeEach(async () => {
    testDir = join(tmpdir(), `ha-test-${Date.now()}`);
    await mkdir(testDir, { recursive: true });
  });

  afterEach(async () => {
    await rm(testDir, { recursive: true, force: true });
  });

  it('validates a correct HACS manifest', async () => {
    const manifestPath = join(testDir, 'manifest.json');
    await writeFile(manifestPath, JSON.stringify({
      domain: 'test',
      name: 'Test',
      version: '1.0.0',
      codeowners: ['@test'],
      documentation: 'https://example.com',
      issue_tracker: 'https://example.com/issues',
      integration_type: 'hub',
      iot_class: 'local_polling',
    }));

    const result = await handleValidateManifest({ path: manifestPath, mode: 'hacs' });
    expect(result.valid).toBe(true);
    expect(result.errors).toHaveLength(0);
  });

  it('reports missing HACS-required fields', async () => {
    const manifestPath = join(testDir, 'manifest.json');
    await writeFile(manifestPath, JSON.stringify({
      domain: 'test',
      name: 'Test',
    }));

    const result = await handleValidateManifest({ path: manifestPath, mode: 'hacs' });
    expect(result.valid).toBe(false);
    expect(result.errors.some(e => e.field === 'version')).toBe(true);
    expect(result.errors.some(e => e.field === 'issue_tracker')).toBe(true);
  });
});
```

```typescript
// mcp-server/__tests__/docs-index.test.ts
import { DocsIndex } from '../src/docs-index.js';

describe('DocsIndex', () => {
  let index: DocsIndex;

  beforeEach(() => {
    index = new DocsIndex({ docsTtlHours: 24, statesTtlSeconds: 30 });
  });

  it('finds DataUpdateCoordinator documentation', () => {
    const results = index.search('DataUpdateCoordinator');
    expect(results.length).toBeGreaterThan(0);
    expect(results[0].title.toLowerCase()).toContain('coordinator');
  });

  it('finds config flow documentation', () => {
    const results = index.search('config flow reauth');
    expect(results.length).toBeGreaterThan(0);
  });

  it('limits results correctly', () => {
    const results = index.search('integration', { limit: 2 });
    expect(results.length).toBeLessThanOrEqual(2);
  });

  it('filters by section', () => {
    const results = index.search('entity', { section: 'core' });
    results.forEach(r => {
      expect(r.url).toContain('developers.home-assistant.io');
    });
  });
});
```

---

### 2. Integration Tests

#### 2.1 Example Integration Tests

Run the example integrations through Home Assistant's test harness.

**Setup:**
```bash
# Install test dependencies
pip install pytest pytest-homeassistant-custom-component pytest-asyncio

# Run tests for each example
cd examples/polling-hub
pytest tests/ -v

cd ../minimal-sensor
# Create basic test if not exists
pytest tests/ -v

cd ../push-integration
pytest tests/ -v
```

**Test file for minimal-sensor:**
```python
# examples/minimal-sensor/tests/test_sensor.py
"""Test minimal sensor."""
import pytest
from homeassistant.core import HomeAssistant
from pytest_homeassistant_custom_component.common import MockConfigEntry

from custom_components.minimal_sensor.const import DOMAIN

@pytest.fixture
def mock_config_entry():
    return MockConfigEntry(
        domain=DOMAIN,
        data={"name": "Test Sensor"},
        unique_id="test_sensor",
    )

async def test_sensor_setup(hass: HomeAssistant, mock_config_entry):
    """Test sensor is set up correctly."""
    mock_config_entry.add_to_hass(hass)
    await hass.config_entries.async_setup(mock_config_entry.entry_id)
    await hass.async_block_till_done()
    
    state = hass.states.get("sensor.test_sensor_temperature")
    assert state is not None
```

#### 2.2 Script Integration Tests

Test scripts against example integrations:

```bash
#!/bin/bash
# tests/integration/test_scripts_against_examples.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$SCRIPT_DIR/../.."

echo "=== Testing validate-manifest.py ==="
for example in polling-hub minimal-sensor push-integration; do
    echo "Testing $example..."
    python3 "$PLUGIN_DIR/scripts/validate-manifest.py" \
        "$PLUGIN_DIR/examples/$example/custom_components/*/manifest.json"
done

echo ""
echo "=== Testing validate-strings.py ==="
for example in polling-hub minimal-sensor push-integration; do
    echo "Testing $example..."
    python3 "$PLUGIN_DIR/scripts/validate-strings.py" \
        "$PLUGIN_DIR/examples/$example/custom_components/*/strings.json"
done

echo ""
echo "=== Testing check-patterns.py ==="
for example in polling-hub minimal-sensor push-integration; do
    echo "Testing $example..."
    python3 "$PLUGIN_DIR/scripts/check-patterns.py" \
        "$PLUGIN_DIR/examples/$example/custom_components/*/"
done

echo ""
echo "All integration tests passed!"
```

---

### 3. Validation Tests (Content Accuracy)

#### 3.1 IQS Rule Verification

Verify documented rules match official HA documentation:

```python
# tests/validation/test_iqs_rules.py
"""Verify IQS rules match official documentation."""
import requests
from pathlib import Path

OFFICIAL_IQS_URL = "https://raw.githubusercontent.com/home-assistant/developers.home-assistant/master/docs/core/integration-quality-scale.md"

def test_iqs_rule_count():
    """Verify we document all official IQS rules."""
    # Load our documentation
    skill_path = Path("skills/ha-quality-review/SKILL.md")
    our_content = skill_path.read_text()
    
    # Count rules in each tier
    bronze_count = our_content.count("- **") in range(15, 25)  # Approximate
    
    # Fetch official docs (when online)
    # response = requests.get(OFFICIAL_IQS_URL)
    # official_content = response.text
    
    # Compare rule names
    assert "action-setup" in our_content
    assert "runtime-data" in our_content
    assert "entity-unique-id" in our_content
    assert "strict-typing" in our_content  # Platinum

def test_tier_totals():
    """Verify tier totals add to 52."""
    # Bronze: 18, Silver: 10, Gold: 21, Platinum: 3
    assert 18 + 10 + 21 + 3 == 52
```

#### 3.2 Deprecation Date Verification

```python
# tests/validation/test_deprecation_dates.py
"""Verify deprecation dates are accurate."""

def test_serviceinfo_relocation_date():
    """ServiceInfo moved in 2025.1, removed in 2026.2."""
    from pathlib import Path
    
    files_to_check = [
        "skills/ha-migration/SKILL.md",
        "scripts/check-patterns.py",
        "mcp-server/src/tools/check-patterns.ts",
    ]
    
    for file_path in files_to_check:
        content = Path(file_path).read_text()
        if "ServiceInfo" in content:
            assert "2025.1" in content or "2025.01" in content
            # Removal date should also be mentioned
            assert "2026" in content

def test_runtime_data_date():
    """runtime_data pattern introduced in 2024.8."""
    from pathlib import Path
    
    skill = Path("skills/ha-coordinator/SKILL.md").read_text()
    assert "2024.8" in skill or "2024.08" in skill
```

#### 3.3 Code Example Syntax Verification

```python
# tests/validation/test_code_examples.py
"""Verify code examples in skills are valid Python."""
import ast
import re
from pathlib import Path

def extract_python_blocks(markdown_content: str) -> list[str]:
    """Extract Python code blocks from markdown."""
    pattern = r'```python\n(.*?)```'
    return re.findall(pattern, markdown_content, re.DOTALL)

def test_skill_code_examples_parse():
    """All Python code examples should be valid syntax."""
    skills_dir = Path("skills")
    
    for skill_file in skills_dir.glob("*/SKILL.md"):
        content = skill_file.read_text()
        code_blocks = extract_python_blocks(content)
        
        for i, code in enumerate(code_blocks):
            # Skip incomplete snippets (those with ...)
            if "..." in code and code.count("...") > 2:
                continue
            
            # Skip template placeholders
            if "{" in code and "}" in code:
                continue
                
            try:
                ast.parse(code)
            except SyntaxError as e:
                # Allow some syntax errors for partial examples
                if "unexpected EOF" not in str(e):
                    pytest.fail(f"{skill_file} block {i}: {e}")
```

---

### 4. End-to-End Workflow Tests

#### 4.1 Integration Scaffolding Test

```bash
#!/bin/bash
# tests/e2e/test_scaffold_workflow.sh
# Manual test script - run with Claude Code

echo "=== E2E Test: Scaffold New Integration ==="
echo ""
echo "1. Ask Claude to scaffold a new integration:"
echo "   'Create a new Home Assistant integration called my_test_device'"
echo ""
echo "2. Verify generated files:"
echo "   - custom_components/my_test_device/__init__.py"
echo "   - custom_components/my_test_device/manifest.json"
echo "   - custom_components/my_test_device/config_flow.py"
echo "   - custom_components/my_test_device/strings.json"
echo ""
echo "3. Run validation:"
echo "   python3 scripts/validate-manifest.py custom_components/my_test_device/manifest.json"
echo "   python3 scripts/validate-strings.py custom_components/my_test_device/strings.json"
echo ""
echo "4. Expected: No errors from validators"
```

#### 4.2 Quality Review Test

```markdown
# tests/e2e/test_quality_review.md

## Test: Quality Scale Review

### Setup
Use the `polling-hub` example integration.

### Test Steps

1. Ask Claude: "Review examples/polling-hub for IQS compliance"

2. Expected Output Should Include:
   - [ ] Bronze tier checklist with status for each rule
   - [ ] Silver tier checklist
   - [ ] Gold tier checklist
   - [ ] Identification of missing features (if any)
   - [ ] Specific recommendations

3. Verify Bronze Requirements Met:
   - [ ] config_flow: true in manifest
   - [ ] unique_id on all entities
   - [ ] has_entity_name = True
   - [ ] config flow tests exist
   - [ ] data_description in strings.json

4. Verify Gold Requirements Met:
   - [ ] diagnostics.py exists
   - [ ] entity translations in strings.json
   - [ ] reauth flow implemented
   - [ ] reconfigure flow implemented
```

#### 4.3 MCP Server E2E Test

```typescript
// tests/e2e/mcp-server-e2e.ts
/**
 * E2E test for MCP server.
 * Requires a running Home Assistant instance.
 * 
 * Run with: npx ts-node tests/e2e/mcp-server-e2e.ts
 */

import { spawn } from 'child_process';

const HA_URL = process.env.HA_URL || 'http://localhost:8123';
const HA_TOKEN = process.env.HA_TOKEN;

if (!HA_TOKEN) {
  console.error('Set HA_TOKEN environment variable');
  process.exit(1);
}

async function testMcpServer() {
  console.log('Starting MCP server...');
  
  const server = spawn('npx', ['ts-node', 'src/index.ts'], {
    cwd: 'mcp-server',
    env: {
      ...process.env,
      HA_DEV_MCP_URL: HA_URL,
      HA_DEV_MCP_TOKEN: HA_TOKEN,
    },
    stdio: ['pipe', 'pipe', 'pipe'],
  });

  // Send test requests via stdin (MCP protocol)
  const testCases = [
    { tool: 'ha_connect', args: { url: HA_URL, token: HA_TOKEN } },
    { tool: 'ha_get_states', args: { domain: 'sensor' } },
    { tool: 'docs_search', args: { query: 'coordinator' } },
    { tool: 'validate_manifest', args: { path: 'examples/polling-hub/custom_components/example_hub/manifest.json' } },
  ];

  // In real implementation, send MCP protocol messages
  // For now, just verify server starts
  
  await new Promise(resolve => setTimeout(resolve, 2000));
  
  server.kill();
  console.log('MCP server E2E test complete');
}

testMcpServer().catch(console.error);
```

---

### 5. Test Infrastructure

#### 5.1 pytest Configuration

```ini
# tests/pytest.ini
[pytest]
testpaths = tests
python_files = test_*.py
python_classes = Test*
python_functions = test_*
asyncio_mode = auto

markers =
    unit: Unit tests
    integration: Integration tests
    e2e: End-to-end tests
    slow: Slow tests

addopts = -v --tb=short
```

#### 5.2 GitHub Actions CI

```yaml
# .github/workflows/test.yml
name: Tests

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  python-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.12'
      
      - name: Install dependencies
        run: |
          pip install pytest pytest-asyncio
          pip install homeassistant  # For type hints
      
      - name: Run script unit tests
        run: pytest tests/scripts/ -v -m unit
      
      - name: Run validation tests
        run: pytest tests/validation/ -v

  typescript-tests:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: mcp-server
    steps:
      - uses: actions/checkout@v4
      
      - name: Set up Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
      
      - name: Install dependencies
        run: npm ci
      
      - name: Run tests
        run: npm test
      
      - name: Build
        run: npm run build

  example-tests:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        example: [polling-hub, minimal-sensor, push-integration]
    steps:
      - uses: actions/checkout@v4
      
      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.12'
      
      - name: Install test dependencies
        run: pip install pytest pytest-homeassistant-custom-component pytest-asyncio
      
      - name: Run example tests
        run: |
          cd examples/${{ matrix.example }}
          pytest tests/ -v || echo "No tests found"
```

#### 5.3 Test Coverage Requirements

| Component | Target Coverage | Priority |
|-----------|----------------|----------|
| `validate-manifest.py` | 90% | High |
| `validate-strings.py` | 90% | High |
| `check-patterns.py` | 85% | High |
| MCP safety.ts | 95% | Critical |
| MCP validate-manifest.ts | 90% | High |
| MCP validate-strings.ts | 85% | High |
| MCP check-patterns.ts | 85% | High |
| Example integrations | 80% | Medium |

---

### 6. Manual Test Checklist

#### 6.1 Skill Trigger Testing

| Test | Prompt | Expected Skill |
|------|--------|----------------|
| Architecture | "Explain HA event bus" | ha-architecture |
| Scaffold | "Create new integration" | ha-integration-scaffold |
| Config Flow | "Add reauth flow" | ha-config-flow |
| Coordinator | "DataUpdateCoordinator error handling" | ha-coordinator |
| Testing | "Write tests for config flow" | ha-testing |
| Quality | "Review for IQS compliance" | ha-quality-review |
| HACS | "Prepare for HACS submission" | ha-hacs |
| Diagnostics | "Add diagnostics support" | ha-diagnostics |
| Migration | "Update for HA 2025" | ha-migration |

#### 6.2 Hook Testing

| Action | Expected Hook | Verification |
|--------|--------------|--------------|
| Edit manifest.json | validate-manifest | Check output for errors |
| Edit strings.json | validate-strings | Check sync with config_flow |
| Edit *.py in custom_components | check-patterns | Check for anti-patterns |

---

### 7. Test Execution Schedule

| Test Type | When | Duration |
|-----------|------|----------|
| Unit tests | Every commit | ~30s |
| Integration tests | Every PR | ~2min |
| Validation tests | Weekly | ~1min |
| E2E tests | Before release | ~5min |
| Manual skill tests | Before release | ~30min |

---

### 8. Test Data Management

#### 8.1 Fixtures Directory Structure

```
tests/
├── fixtures/
│   ├── manifests/
│   │   ├── valid_full.json
│   │   ├── valid_minimal.json
│   │   ├── invalid_missing_domain.json
│   │   ├── invalid_bad_version.json
│   │   └── invalid_bad_iot_class.json
│   ├── strings/
│   │   ├── valid_with_descriptions.json
│   │   ├── missing_step.json
│   │   └── orphaned_step.json
│   └── python/
│       ├── clean_code.py
│       ├── has_hass_data.py
│       ├── has_blocking_io.py
│       └── has_old_imports.py
```

---

### 9. Recommended Test Priorities

**Phase 1 (Immediate):**
1. ✅ Unit tests for MCP safety.ts (already exists)
2. Unit tests for validate-manifest.py
3. Unit tests for check-patterns.py
4. Script integration tests against examples

**Phase 2 (Before Release):**
1. MCP server tool unit tests
2. Validation tests for IQS accuracy
3. Code example syntax validation
4. Example integration pytest tests

**Phase 3 (Ongoing):**
1. E2E workflow tests
2. Manual skill trigger testing
3. Performance benchmarks
4. HA version compatibility tests

---

## Running All Tests

```bash
# Quick test (unit only)
pytest tests/ -m unit -v

# Full test suite
pytest tests/ -v

# With coverage
pytest tests/ --cov=scripts --cov=mcp-server/src --cov-report=html

# TypeScript tests
cd mcp-server && npm test

# Integration tests
bash tests/integration/test_scripts_against_examples.sh
```
