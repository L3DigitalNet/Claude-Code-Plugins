#!/usr/bin/env bats
# Tests for inventory-tests.sh
# Validates test file discovery, categorization, and counting.

load helpers

setup() {
    setup_test_env
}

teardown() {
    teardown_test_env
}

@test "empty directory returns total_tests: 0" {
    mkdir -p "$TEST_TMPDIR/empty-tests"
    run "$SCRIPTS_DIR/inventory-tests.sh" python "$TEST_TMPDIR/empty-tests"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['total_tests'] == 0, f'expected 0, got {d[\"total_tests\"]}'
assert d['total_files'] == 0
"
}

@test "python project with test files returns correct count" {
    mkdir -p "$TEST_TMPDIR/py-tests"
    cat > "$TEST_TMPDIR/py-tests/test_app.py" <<'EOF'
def test_one():
    assert True

def test_two():
    assert True
EOF
    cat > "$TEST_TMPDIR/py-tests/test_utils.py" <<'EOF'
def test_helper():
    assert True
EOF
    run "$SCRIPTS_DIR/inventory-tests.sh" python "$TEST_TMPDIR/py-tests"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['total_files'] == 2, f'expected 2 test files, got {d[\"total_files\"]}'
assert d['total_tests'] == 3, f'expected 3 tests, got {d[\"total_tests\"]}'
"
}

@test "files in tests/unit/ classified as unit" {
    mkdir -p "$TEST_TMPDIR/cat-tests/tests/unit"
    cat > "$TEST_TMPDIR/cat-tests/tests/unit/test_core.py" <<'EOF'
def test_core_logic():
    assert True
EOF
    run "$SCRIPTS_DIR/inventory-tests.sh" python "$TEST_TMPDIR/cat-tests"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
unit_files = [f for f in d['test_files'] if f['category'] == 'unit']
assert len(unit_files) == 1, f'expected 1 unit file, got {len(unit_files)}'
assert d['by_category']['unit']['files'] == 1
"
}

@test "by_category always includes unit, integration, e2e keys" {
    mkdir -p "$TEST_TMPDIR/cat-keys"
    run "$SCRIPTS_DIR/inventory-tests.sh" python "$TEST_TMPDIR/cat-keys"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
for cat in ('unit', 'integration', 'e2e'):
    assert cat in d['by_category'], f'missing category key: {cat}'
    assert 'files' in d['by_category'][cat]
    assert 'tests' in d['by_category'][cat]
"
}

@test "pytest marker in file content categorizes as that marker type" {
    mkdir -p "$TEST_TMPDIR/marker-tests"
    cat > "$TEST_TMPDIR/marker-tests/test_slow.py" <<'EOF'
import pytest

@pytest.mark.integration
def test_db_connection():
    assert True
EOF
    run "$SCRIPTS_DIR/inventory-tests.sh" python "$TEST_TMPDIR/marker-tests"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['total_files'] == 1
# The marker @pytest.mark.integration should categorize this as integration
f = d['test_files'][0]
assert f['category'] == 'integration', f'expected integration from marker, got {f[\"category\"]}'
assert d['by_category']['integration']['files'] == 1
"
}

@test "file named test_integration_foo.py categorized as integration" {
    mkdir -p "$TEST_TMPDIR/integ-tests"
    cat > "$TEST_TMPDIR/integ-tests/test_integration_foo.py" <<'EOF'
def test_api_call():
    assert True
EOF
    run "$SCRIPTS_DIR/inventory-tests.sh" python "$TEST_TMPDIR/integ-tests"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['total_files'] == 1
f = d['test_files'][0]
assert f['category'] == 'integration', f'expected integration from filename, got {f[\"category\"]}'
"
}

@test "typescript test files detected" {
    mkdir -p "$TEST_TMPDIR/ts-tests"
    cat > "$TEST_TMPDIR/ts-tests/app.test.ts" <<'EOF'
import { expect } from 'vitest';

it('works', () => {
    expect(true).toBe(true);
});

test('also works', () => {
    expect(1).toBe(1);
});
EOF
    run "$SCRIPTS_DIR/inventory-tests.sh" typescript "$TEST_TMPDIR/ts-tests"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['total_files'] == 1, f'expected 1 test file, got {d[\"total_files\"]}'
assert d['total_tests'] == 2, f'expected 2 tests (it + test), got {d[\"total_tests\"]}'
paths = [f['path'] for f in d['test_files']]
assert any('app.test.ts' in p for p in paths), f'expected app.test.ts in {paths}'
"
}

@test "go test files detected" {
    mkdir -p "$TEST_TMPDIR/go-tests"
    cat > "$TEST_TMPDIR/go-tests/handler_test.go" <<'EOF'
package main

import "testing"

func TestFoo(t *testing.T) {
    if 1 != 1 {
        t.Fatal("math is broken")
    }
}
EOF
    run "$SCRIPTS_DIR/inventory-tests.sh" go "$TEST_TMPDIR/go-tests"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['total_files'] == 1, f'expected 1 test file, got {d[\"total_files\"]}'
assert d['total_tests'] >= 1, f'expected >= 1 test, got {d[\"total_tests\"]}'
paths = [f['path'] for f in d['test_files']]
assert any('handler_test.go' in p for p in paths), f'expected handler_test.go in {paths}'
"
}

@test "rust test detection" {
    mkdir -p "$TEST_TMPDIR/rust-tests"
    cat > "$TEST_TMPDIR/rust-tests/lib_test.rs" <<'EOF'
#[test]
fn test_add() {
    assert_eq!(2 + 2, 4);
}

#[test]
fn test_sub() {
    assert_eq!(4 - 2, 2);
}
EOF
    run "$SCRIPTS_DIR/inventory-tests.sh" rust "$TEST_TMPDIR/rust-tests"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['total_files'] == 1, f'expected 1 test file, got {d[\"total_files\"]}'
assert d['total_tests'] == 2, f'expected 2 tests, got {d[\"total_tests\"]}'
paths = [f['path'] for f in d['test_files']]
assert any('lib_test.rs' in p for p in paths), f'expected lib_test.rs in {paths}'
"
}

@test "conftest.py counted as test file" {
    mkdir -p "$TEST_TMPDIR/conftest-tests/tests"
    cat > "$TEST_TMPDIR/conftest-tests/tests/conftest.py" <<'EOF'
import pytest

@pytest.fixture
def sample_data():
    return {"key": "value"}
EOF
    run "$SCRIPTS_DIR/inventory-tests.sh" python "$TEST_TMPDIR/conftest-tests"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['total_files'] >= 1, f'expected >= 1 test file, got {d[\"total_files\"]}'
paths = [f['path'] for f in d['test_files']]
assert any('conftest.py' in p for p in paths), f'expected conftest.py in {paths}'
"
}

@test "output is valid JSON with required fields" {
    mkdir -p "$TEST_TMPDIR/json-check"
    run "$SCRIPTS_DIR/inventory-tests.sh" python "$TEST_TMPDIR/json-check"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
required = ['test_files', 'by_category', 'total_files', 'total_tests']
for key in required:
    assert key in d, f'missing required field: {key}'
assert isinstance(d['test_files'], list)
assert isinstance(d['by_category'], dict)
"
}
