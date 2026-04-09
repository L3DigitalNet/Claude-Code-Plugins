#!/usr/bin/env bats
# Tests for batch-executor.sh

load helpers

setup() { setup_test_env; }
teardown() { teardown_test_env; }

@test "batch-executor: missing arguments exits 1" {
    run bash "$SCRIPTS_DIR/batch-executor.sh"
    [ "$status" -eq 1 ]
}

@test "batch-executor: missing plugin-root argument exits 1" {
    cat > "$TEST_TMPDIR/plan.json" << 'EOF'
{"mutations": [], "dry_run": true}
EOF
    run bash "$SCRIPTS_DIR/batch-executor.sh" "$TEST_TMPDIR/plan.json"
    [ "$status" -eq 1 ]
}

@test "batch-executor: empty mutations array returns clean result" {
    cat > "$TEST_TMPDIR/plan.json" << 'EOF'
{"mutations": []}
EOF
    run bash "$SCRIPTS_DIR/batch-executor.sh" "$TEST_TMPDIR/plan.json" "$PLUGIN_ROOT"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
assert d['total'] == 0, f'expected total=0, got {d[\"total\"]}'
assert d['succeeded'] == 0, f'expected succeeded=0, got {d[\"succeeded\"]}'
print('ok')
"
}

@test "batch-executor: empty mutations output is valid JSON" {
    cat > "$TEST_TMPDIR/plan.json" << 'EOF'
{"mutations": []}
EOF
    run bash "$SCRIPTS_DIR/batch-executor.sh" "$TEST_TMPDIR/plan.json" "$PLUGIN_ROOT"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "import sys,json; json.load(sys.stdin)"
}

@test "batch-executor: nonexistent plan file exits with error" {
    run bash "$SCRIPTS_DIR/batch-executor.sh" "$TEST_TMPDIR/no-such-plan.json" "$PLUGIN_ROOT"
    [ "$status" -ne 0 ]
}

@test "batch-executor: dry_run flag produces dry_run status in results" {
    cat > "$TEST_TMPDIR/dry-plan.json" << 'EOF'
{"mutations": [{"command": "repo labels sync", "args": ["--repo", "fake/repo"], "description": "sync labels"}]}
EOF
    run bash "$SCRIPTS_DIR/batch-executor.sh" "$TEST_TMPDIR/dry-plan.json" "$PLUGIN_ROOT" --dry-run
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
assert d['total'] == 1, f'expected total=1, got {d[\"total\"]}'
assert d['results'][0]['status'] == 'dry_run', \
    f'expected dry_run status, got {d[\"results\"][0][\"status\"]}'
print('ok')
"
}

@test "batch-executor: empty mutations returns succeeded=0 and failed=0" {
    cat > "$TEST_TMPDIR/empty-plan.json" << 'EOF'
{"mutations": []}
EOF
    run bash "$SCRIPTS_DIR/batch-executor.sh" "$TEST_TMPDIR/empty-plan.json" "$PLUGIN_ROOT"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
assert d['succeeded'] == 0, f'expected succeeded=0, got {d[\"succeeded\"]}'
assert d['failed'] == 0, f'expected failed=0, got {d[\"failed\"]}'
assert d['skipped'] == 0, f'expected skipped=0, got {d[\"skipped\"]}'
assert d['total'] == 0, f'expected total=0, got {d[\"total\"]}'
print('ok')
"
}

@test "batch-executor: --min-remaining flag accepted" {
    cat > "$TEST_TMPDIR/min-remain-plan.json" << 'EOF'
{"mutations": []}
EOF
    run bash "$SCRIPTS_DIR/batch-executor.sh" "$TEST_TMPDIR/min-remain-plan.json" "$PLUGIN_ROOT" --min-remaining 50
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "import sys,json; json.load(sys.stdin)"
}
