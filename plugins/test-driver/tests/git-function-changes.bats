#!/usr/bin/env bats
# Tests for git-function-changes.sh
# Validates git diff parsing and function change detection.

load helpers

setup() {
    setup_test_env
}

teardown() {
    teardown_test_env
}

@test "non-git directory returns error field" {
    mkdir -p "$TEST_TMPDIR/no-git"
    cd "$TEST_TMPDIR/no-git"
    run "$SCRIPTS_DIR/git-function-changes.sh" "2024-01-01" "$TEST_TMPDIR/no-git"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert 'error' in d, 'expected error field for non-git directory'
"
}

@test "output is valid JSON with required fields" {
    mkdir -p "$TEST_TMPDIR/git-proj"
    cd "$TEST_TMPDIR/git-proj"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"
    # Need at least one commit for HEAD to exist
    echo "x = 1" > init.py
    git add init.py
    git commit -q -m "init"
    run "$SCRIPTS_DIR/git-function-changes.sh" "2024-01-01" "$TEST_TMPDIR/git-proj"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
required = ['since', 'changed_functions', 'changed_files', 'total_functions_changed', 'total_files_changed']
for key in required:
    assert key in d, f'missing required field: {key}'
assert isinstance(d['changed_functions'], list)
assert isinstance(d['changed_files'], list)
"
}

@test "--extensions filter limits to specified extensions" {
    mkdir -p "$TEST_TMPDIR/ext-filter"
    cd "$TEST_TMPDIR/ext-filter"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"
    echo "x = 1" > init.py
    echo "const x = 1;" > init.ts
    git add . && git commit -q -m "initial"
    # Add functions to both file types
    cat > init.py <<'EOF'
def hello():
    pass
def world():
    pass
EOF
    cat > init.ts <<'EOF'
export function greet(): void {}
export function farewell(): void {}
EOF
    git add . && git commit -q -m "add functions"
    run "$SCRIPTS_DIR/git-function-changes.sh" "2020-01-01" "$TEST_TMPDIR/ext-filter" --extensions .py
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
# Only .py files should appear
for f in d['changed_files']:
    assert f.endswith('.py'), f'expected only .py files, got {f}'
for fn in d['changed_functions']:
    assert fn['file'].endswith('.py'), f'expected only .py functions, got {fn[\"file\"]}'
assert d['total_files_changed'] >= 1, 'expected at least 1 .py file'
assert d['total_functions_changed'] >= 1, 'expected at least 1 .py function'
"
}

@test "detects modified function" {
    mkdir -p "$TEST_TMPDIR/git-mod"
    cd "$TEST_TMPDIR/git-mod"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"
    # Initial: function with one signature
    cat > app.py <<'EOF'
def hello(name):
    return f"hi {name}"
EOF
    git add . && git commit -q -m "initial"
    # Modify: change the signature itself so both -def and +def appear in diff
    cat > app.py <<'EOF'
def hello(name, greeting):
    return f"{greeting} {name}"
EOF
    git add . && git commit -q -m "modify hello signature"
    run "$SCRIPTS_DIR/git-function-changes.sh" "2020-01-01" "$TEST_TMPDIR/git-mod"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
funcs = {fn['function']: fn['change_type'] for fn in d['changed_functions'] if fn['file'] == 'app.py'}
assert 'hello' in funcs, f'expected hello in changed functions, got {list(funcs.keys())}'
assert funcs['hello'] == 'modified', f'expected hello to be modified, got {funcs[\"hello\"]}'
"
}

@test "function added in commit detected as added" {
    mkdir -p "$TEST_TMPDIR/git-add"
    cd "$TEST_TMPDIR/git-add"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"
    echo "def hello(): pass" > test.py
    git add . && git commit -q -m "initial"
    printf "def hello(): pass\ndef world(): pass\n" > test.py
    git add . && git commit -q -m "add world"
    run "$SCRIPTS_DIR/git-function-changes.sh" "2020-01-01" "$TEST_TMPDIR/git-add"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
funcs = {fn['function']: fn['change_type'] for fn in d['changed_functions'] if fn['file'] == 'test.py'}
assert 'world' in funcs, f'expected world in changed functions, got {list(funcs.keys())}'
assert funcs['world'] == 'added', f'expected world to be added, got {funcs[\"world\"]}'
"
}
