#!/usr/bin/env bats
# Tests for environment-discover.sh — environment profile discovery.

load helpers

setup() { setup_test_env; }
teardown() { teardown_test_env; }

@test "outputs valid JSON" {
    run bash "$SCRIPTS_DIR/environment-discover.sh"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "import json, sys; json.load(sys.stdin)"
}

@test "contains _schema_version field" {
    run bash "$SCRIPTS_DIR/environment-discover.sh"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
data = json.load(sys.stdin)
assert '_schema_version' in data, 'missing _schema_version'
assert data['_schema_version'] == '1.0.0'
"
}

@test "environment object has all 10 required categories" {
    run bash "$SCRIPTS_DIR/environment-discover.sh"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
data = json.load(sys.stdin)
# Find the environment key (not _schema_version)
env_keys = [k for k in data if k != '_schema_version']
assert len(env_keys) == 1, f'expected 1 environment key, got {len(env_keys)}: {env_keys}'
env = data[env_keys[0]]
required = ['host', 'network', 'ingress', 'ssl', 'monitoring', 'backup', 'secrets', 'security_tooling', 'vcs', 'services']
for cat in required:
    assert cat in env, f'missing required category: {cat}'
"
}

@test "host.hostname is non-null" {
    run bash "$SCRIPTS_DIR/environment-discover.sh"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
data = json.load(sys.stdin)
env_key = [k for k in data if k != '_schema_version'][0]
hostname = data[env_key]['host']['hostname']
assert hostname is not None, 'hostname is null'
assert len(hostname) > 0, 'hostname is empty'
"
}

@test "services is an array" {
    run bash "$SCRIPTS_DIR/environment-discover.sh"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
data = json.load(sys.stdin)
env_key = [k for k in data if k != '_schema_version'][0]
services = data[env_key]['services']
assert isinstance(services, list), f'services is {type(services).__name__}, expected list'
"
}

@test "host.os_name is non-null" {
    run bash "$SCRIPTS_DIR/environment-discover.sh"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
data = json.load(sys.stdin)
env_key = [k for k in data if k != '_schema_version'][0]
os_name = data[env_key]['host']['os_name']
assert os_name is not None, 'os_name is null'
assert len(os_name) > 0, 'os_name is empty'
"
}

@test "services array entries have name field" {
    run bash "$SCRIPTS_DIR/environment-discover.sh"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
data = json.load(sys.stdin)
env_key = [k for k in data if k != '_schema_version'][0]
services = data[env_key]['services']
# If there are services, each must have a name field
for i, svc in enumerate(services):
    assert 'name' in svc, f'service at index {i} missing name field'
    assert svc['name'] is not None, f'service at index {i} has null name'
# Pass even if services is empty — the contract is about shape, not count
"
}

@test "host.architecture is non-null" {
    run bash "$SCRIPTS_DIR/environment-discover.sh"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
data = json.load(sys.stdin)
env_key = [k for k in data if k != '_schema_version'][0]
arch = data[env_key]['host']['architecture']
assert arch is not None, 'architecture is null'
assert len(arch) > 0, 'architecture is empty'
"
}

@test "network category has expected fields" {
    run bash "$SCRIPTS_DIR/environment-discover.sh"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
data = json.load(sys.stdin)
env_key = [k for k in data if k != '_schema_version'][0]
network = data[env_key]['network']
for field in ['topology', 'firewall_tool', 'vpn_tool']:
    assert field in network, f'network missing expected field: {field}'
"
}
