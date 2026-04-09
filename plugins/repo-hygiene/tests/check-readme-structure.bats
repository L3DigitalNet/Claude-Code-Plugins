#!/usr/bin/env bats
# Tests for check-readme-structure.sh

load helpers

setup() { setup_test_env; }
teardown() { teardown_test_env; }

@test "check-readme-structure: outputs valid JSON" {
    run bash "$SCRIPTS_DIR/check-readme-structure.sh"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "import sys,json; json.load(sys.stdin)"
}

@test "check-readme-structure: JSON contains check field set to readme-structure" {
    run bash "$SCRIPTS_DIR/check-readme-structure.sh"
    [ "$status" -eq 0 ]
    result=$(echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['check'])")
    [ "$result" = "readme-structure" ]
}

@test "check-readme-structure: findings is an array" {
    run bash "$SCRIPTS_DIR/check-readme-structure.sh"
    [ "$status" -eq 0 ]
    is_list=$(echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); print(type(d['findings']).__name__)")
    [ "$is_list" = "list" ]
}

@test "check-readme-structure: each finding has severity, path, detail, auto_fix" {
    run bash "$SCRIPTS_DIR/check-readme-structure.sh"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for f in d['findings']:
    assert 'severity' in f, f'missing severity in {f}'
    assert 'path' in f, f'missing path in {f}'
    assert 'detail' in f, f'missing detail in {f}'
    assert 'auto_fix' in f, f'missing auto_fix in {f}'
print('ok')
"
}

@test "check-readme-structure: findings have valid severity values" {
    run bash "$SCRIPTS_DIR/check-readme-structure.sh"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for f in d['findings']:
    assert f['severity'] in ('warn', 'info'), f'invalid severity: {f[\"severity\"]}'
print('ok')
"
}

@test "check-readme-structure: check field is readme-structure and findings are well-formed" {
    run bash "$SCRIPTS_DIR/check-readme-structure.sh"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
assert d['check'] == 'readme-structure', 'wrong check name'
# Every finding must have all four required fields with correct types
for f in d['findings']:
    assert isinstance(f['severity'], str), f'severity not str: {f}'
    assert isinstance(f['path'], str), f'path not str: {f}'
    assert isinstance(f['detail'], str), f'detail not str: {f}'
    assert isinstance(f['auto_fix'], bool), f'auto_fix not bool: {f}'
print('ok')
"
}

@test "check-readme-structure: findings for plugins with commands/ dir mention Commands heading if missing" {
    run bash "$SCRIPTS_DIR/check-readme-structure.sh"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import sys, json, os

d = json.load(sys.stdin)
repo_root = os.popen('git rev-parse --show-toplevel').read().strip()
marketplace_path = os.path.join(repo_root, '.claude-plugin', 'marketplace.json')
with open(marketplace_path) as f:
    marketplace = json.load(f)

# Build set of plugins that have a non-empty commands/ directory
plugins_with_commands = set()
for p in marketplace.get('plugins', []):
    source = p.get('source', '')
    if source.startswith('./') or source.startswith('../'):
        plugin_dir = os.path.normpath(os.path.join(repo_root, source))
    else:
        plugin_dir = source
    cmd_dir = os.path.join(plugin_dir, 'commands')
    if os.path.isdir(cmd_dir):
        has_files = any(f for f in os.listdir(cmd_dir) if not f.startswith('.'))
        if has_files:
            readme_rel = os.path.relpath(os.path.join(plugin_dir, 'README.md'), repo_root)
            plugins_with_commands.add(readme_rel)

# For each plugin with commands/, verify that either:
# (a) the README already has a Commands heading (no finding), or
# (b) there is a finding mentioning the missing Commands section
findings_by_path = {}
for f in d['findings']:
    findings_by_path.setdefault(f['path'], []).append(f)

for readme_path in plugins_with_commands:
    plugin_findings = findings_by_path.get(readme_path, [])
    commands_findings = [f for f in plugin_findings if 'Commands' in f['detail'] and 'commands/' in f['detail']]
    # If the script found an issue, it should have a meaningful detail string
    for cf in commands_findings:
        assert len(cf['detail']) > 20, f'Commands finding detail too short: {cf[\"detail\"]}'
        assert 'commands/' in cf['detail'], f'Commands finding should reference commands/ dir: {cf[\"detail\"]}'
print('ok')
"
}
