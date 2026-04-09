#!/usr/bin/env bats
# Tests for check-readme-refs.sh

load helpers

setup() { setup_test_env; }
teardown() { teardown_test_env; }

@test "check-readme-refs: outputs valid JSON" {
    run bash "$SCRIPTS_DIR/check-readme-refs.sh"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "import sys,json; json.load(sys.stdin)"
}

@test "check-readme-refs: JSON contains check field set to readme-refs" {
    run bash "$SCRIPTS_DIR/check-readme-refs.sh"
    [ "$status" -eq 0 ]
    result=$(echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['check'])")
    [ "$result" = "readme-refs" ]
}

@test "check-readme-refs: findings is an array" {
    run bash "$SCRIPTS_DIR/check-readme-refs.sh"
    [ "$status" -eq 0 ]
    is_list=$(echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); print(type(d['findings']).__name__)")
    [ "$is_list" = "list" ]
}

@test "check-readme-refs: each finding has severity, path, detail, auto_fix" {
    run bash "$SCRIPTS_DIR/check-readme-refs.sh"
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

@test "check-readme-refs: nominal README produces zero broken ref findings" {
    run bash "$SCRIPTS_DIR/check-readme-refs.sh"
    [ "$status" -eq 0 ]
    count=$(echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
matches = [f for f in d['findings'] if 'plugins/nominal/README.md' in f['path']]
print(len(matches))
")
    [ "$count" -eq 0 ]
}

@test "check-readme-refs: all finding paths start with plugins/" {
    run bash "$SCRIPTS_DIR/check-readme-refs.sh"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for f in d['findings']:
    assert f['path'].startswith('plugins/'), \
        f'finding path does not start with plugins/: {f[\"path\"]}'
print('ok')
"
}

@test "check-readme-refs: test-driver findings reference genuinely broken paths" {
    run bash "$SCRIPTS_DIR/check-readme-refs.sh"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import sys, json, os

d = json.load(sys.stdin)
repo_root = os.popen('git rev-parse --show-toplevel').read().strip()
matches = [f for f in d['findings'] if 'plugins/test-driver/README.md' in f['path']]
# If there are findings for test-driver, each referenced path must genuinely not exist
plugin_dir = os.path.join(repo_root, 'plugins', 'test-driver')
import re
for f in matches:
    # Extract the referenced path from the detail string
    ref_match = re.search(r'\x60([^\x60]+)\x60', f['detail'])
    if ref_match:
        ref = ref_match.group(1)
        abs_path = os.path.join(plugin_dir, ref)
        assert not os.path.exists(abs_path), \
            f'Finding claims \"{ref}\" does not exist, but it does at {abs_path}'
print('ok')
"
}

@test "check-readme-refs: findings do not flag references inside fenced code blocks" {
    run bash "$SCRIPTS_DIR/check-readme-refs.sh"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import sys, json, os, re

d = json.load(sys.stdin)
if not d['findings']:
    print('ok — no findings to validate')
    sys.exit(0)

repo_root = os.popen('git rev-parse --show-toplevel').read().strip()

# For each finding, verify the referenced path does NOT appear only inside
# fenced code blocks in the source README
for f in d['findings']:
    readme_abs = os.path.join(repo_root, f['path'])
    if not os.path.isfile(readme_abs):
        continue

    with open(readme_abs) as fh:
        readme_text = fh.read()

    # Extract the referenced path from the finding detail
    # Patterns: 'References \`path\`', 'Relative link [path]', 'commands/name.md'
    ref_match = re.search(r'\x60([^\x60]+)\x60', f['detail'])
    if not ref_match:
        ref_match = re.search(r'\[([^\]]+)\]', f['detail'])
    if not ref_match:
        continue

    ref = ref_match.group(1)

    # Strip fenced code blocks and check that the reference appears outside them
    stripped = re.sub(r'\x60\x60\x60[^\n]*\n.*?\x60\x60\x60', '', readme_text, flags=re.DOTALL)
    assert ref in stripped, \
        f'Finding references \"{ref}\" which only appears inside fenced code blocks in {f[\"path\"]}'
print('ok')
"
}
