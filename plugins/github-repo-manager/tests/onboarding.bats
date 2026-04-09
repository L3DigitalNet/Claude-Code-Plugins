#!/usr/bin/env bats
# Tests for onboarding.sh

load helpers

setup() { setup_test_env; }
teardown() { teardown_test_env; }

@test "onboarding: missing plugin-root argument exits 1" {
    run bash "$SCRIPTS_DIR/onboarding.sh"
    [ "$status" -eq 1 ]
}

@test "onboarding: outputs valid JSON" {
    run bash "$SCRIPTS_DIR/onboarding.sh" "$PLUGIN_ROOT"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "import sys,json; json.load(sys.stdin)"
}

@test "onboarding: output has deps_installed field" {
    run bash "$SCRIPTS_DIR/onboarding.sh" "$PLUGIN_ROOT"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); assert 'deps_installed' in d, 'missing deps_installed'"
}

@test "onboarding: output has pat_verified field" {
    run bash "$SCRIPTS_DIR/onboarding.sh" "$PLUGIN_ROOT"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); assert 'pat_verified' in d, 'missing pat_verified'"
}

@test "onboarding: output has ready field" {
    run bash "$SCRIPTS_DIR/onboarding.sh" "$PLUGIN_ROOT"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); assert 'ready' in d, 'missing ready'"
}

@test "onboarding: output has errors field as array" {
    run bash "$SCRIPTS_DIR/onboarding.sh" "$PLUGIN_ROOT"
    [ "$status" -eq 0 ]
    is_list=$(echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); print(type(d['errors']).__name__)")
    [ "$is_list" = "list" ]
}

@test "onboarding: output has all required top-level fields" {
    run bash "$SCRIPTS_DIR/onboarding.sh" "$PLUGIN_ROOT"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
required = ['deps_installed', 'pat_verified', 'tier_detected', 'config', 'labels', 'ready', 'errors', 'skipped']
missing = [k for k in required if k not in d]
assert not missing, f'missing top-level fields: {missing}'
print('ok')
"
}
