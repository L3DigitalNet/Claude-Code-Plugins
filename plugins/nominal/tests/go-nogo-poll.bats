#!/usr/bin/env bats
# Tests for go-nogo-poll.sh — preflight go/no-go poll.

load helpers

FIXTURE_DIR=""

setup() {
    setup_test_env
    FIXTURE_DIR="$TEST_TMPDIR/.claude/nominal"
    mkdir -p "$FIXTURE_DIR"
    cat > "$FIXTURE_DIR/environment.json" << 'FIXTURE'
{
  "_schema_version": "1.0.0",
  "test": {
    "description": "test env",
    "first_discovered": "2026-04-09T00:00:00Z",
    "last_validated": "2026-04-09T00:00:00Z",
    "host": {"hostname": "localhost", "os_name": "Linux", "os_version": "6.0", "architecture": "x86_64", "kernel_version": "6.0.0", "virtualization_type": "bare_metal", "_discovery_note": null},
    "network": {"topology": "flat", "private_bridge_or_overlay": null, "private_subnet": null, "vpn_tool": null, "firewall_tool": null, "_discovery_note": null},
    "ingress": {"reverse_proxy_tool": null, "config_path": null, "access_model": null, "_discovery_note": null},
    "ssl": {"cert_tool": null, "config_path": null, "renewal_mechanism": null, "_discovery_note": null},
    "monitoring": {"metrics_tool": null, "metrics_status_check": null, "uptime_tool": null, "uptime_status_check": null, "log_aggregation_tool": null, "log_status_check": null, "_discovery_note": null},
    "backup": {"backup_tool": null, "targets": null, "pre_dump_scripts": null, "last_run_check": null, "_discovery_note": null},
    "secrets": {"approach": null, "canonical_location": null, "_discovery_note": null},
    "security_tooling": {"fim_tool": null, "fim_baseline_update_method": null, "ips_tool": null, "ips_status_check": null, "_discovery_note": null},
    "vcs": {"tool": null, "remote": null, "config_tracked_paths": null, "_discovery_note": null},
    "services": []
  }
}
FIXTURE
}

teardown() { teardown_test_env; }

@test "missing argument exits 1" {
    run bash -c "'$SCRIPTS_DIR/go-nogo-poll.sh' 2>&1"
    [ "$status" -eq 1 ]
}

@test "with minimal fixture, returns valid JSON with checks array and all_passed" {
    run bash "$SCRIPTS_DIR/go-nogo-poll.sh" "$FIXTURE_DIR/environment.json"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
data = json.load(sys.stdin)
assert 'checks' in data, 'missing checks key'
assert isinstance(data['checks'], list), 'checks is not a list'
assert 'all_passed' in data, 'missing all_passed key'
assert isinstance(data['all_passed'], bool), 'all_passed is not a boolean'
"
}

@test "nonexistent profile exits 1" {
    run bash -c "'$SCRIPTS_DIR/go-nogo-poll.sh' '/tmp/nonexistent_profile_$$' 2>&1"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Profile not found"* ]]
}

@test "with service health_endpoint: checks array has service_health entry" {
    cat > "$FIXTURE_DIR/env_with_svc.json" << 'FIXTURE'
{
  "_schema_version": "1.0.0",
  "test": {
    "host": {"hostname": "localhost", "os_name": "Linux", "os_version": "6.0", "architecture": "x86_64", "kernel_version": "6.0.0", "virtualization_type": "bare_metal", "_discovery_note": null},
    "network": {"topology": "flat", "private_bridge_or_overlay": null, "private_subnet": null, "vpn_tool": null, "firewall_tool": null, "_discovery_note": null},
    "ingress": {"reverse_proxy_tool": null, "config_path": null, "access_model": null, "_discovery_note": null},
    "ssl": {"cert_tool": null, "config_path": null, "renewal_mechanism": null, "_discovery_note": null},
    "monitoring": {"metrics_tool": null, "metrics_status_check": null, "uptime_tool": null, "uptime_status_check": null, "log_aggregation_tool": null, "log_status_check": null, "_discovery_note": null},
    "backup": {"backup_tool": null, "targets": null, "pre_dump_scripts": null, "last_run_check": null, "_discovery_note": null},
    "secrets": {"approach": null, "canonical_location": null, "_discovery_note": null},
    "security_tooling": {"fim_tool": null, "fim_baseline_update_method": null, "ips_tool": null, "ips_status_check": null, "_discovery_note": null},
    "vcs": {"tool": null, "remote": null, "config_tracked_paths": null, "_discovery_note": null},
    "services": [{"name": "test-svc", "host_address": "127.0.0.1", "ports": [22], "health_endpoint": "http://127.0.0.1:22/health", "access_tier": "private"}]
  }
}
FIXTURE

    run bash "$SCRIPTS_DIR/go-nogo-poll.sh" "$FIXTURE_DIR/env_with_svc.json"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
data = json.load(sys.stdin)
checks = data['checks']
health_checks = [c for c in checks if c['check'] == 'service_health']
assert len(health_checks) >= 1, f'expected service_health check, got checks: {[c[\"check\"] for c in checks]}'
assert health_checks[0]['target'] == 'test-svc'
"
}

@test "service_port check for service with ports but no health_endpoint" {
    cat > "$FIXTURE_DIR/env_with_port.json" << 'FIXTURE'
{
  "_schema_version": "1.0.0",
  "test": {
    "host": {"hostname": "localhost", "os_name": "Linux", "os_version": "6.0", "architecture": "x86_64", "kernel_version": "6.0.0", "virtualization_type": "bare_metal", "_discovery_note": null},
    "network": {"topology": "flat", "private_bridge_or_overlay": null, "private_subnet": null, "vpn_tool": null, "firewall_tool": null, "_discovery_note": null},
    "ingress": {"reverse_proxy_tool": null, "config_path": null, "access_model": null, "_discovery_note": null},
    "ssl": {"cert_tool": null, "config_path": null, "renewal_mechanism": null, "_discovery_note": null},
    "monitoring": {"metrics_tool": null, "metrics_status_check": null, "uptime_tool": null, "uptime_status_check": null, "log_aggregation_tool": null, "log_status_check": null, "_discovery_note": null},
    "backup": {"backup_tool": null, "targets": null, "pre_dump_scripts": null, "last_run_check": null, "_discovery_note": null},
    "secrets": {"approach": null, "canonical_location": null, "_discovery_note": null},
    "security_tooling": {"fim_tool": null, "fim_baseline_update_method": null, "ips_tool": null, "ips_status_check": null, "_discovery_note": null},
    "vcs": {"tool": null, "remote": null, "config_tracked_paths": null, "_discovery_note": null},
    "services": [{"name": "ssh-svc", "host_address": "127.0.0.1", "ports": [22]}]
  }
}
FIXTURE

    run bash "$SCRIPTS_DIR/go-nogo-poll.sh" "$FIXTURE_DIR/env_with_port.json"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
data = json.load(sys.stdin)
checks = data['checks']
port_checks = [c for c in checks if c['check'] == 'service_port']
assert len(port_checks) >= 1, f'expected service_port check, got checks: {[c[\"check\"] for c in checks]}'
assert port_checks[0]['target'] == 'ssh-svc'
"
}

@test "with firewall_tool set: checks array has firewall_active entry" {
    cat > "$FIXTURE_DIR/env_with_fw.json" << 'FIXTURE'
{
  "_schema_version": "1.0.0",
  "test": {
    "host": {"hostname": "localhost", "os_name": "Linux", "os_version": "6.0", "architecture": "x86_64", "kernel_version": "6.0.0", "virtualization_type": "bare_metal", "_discovery_note": null},
    "network": {"topology": "flat", "private_bridge_or_overlay": null, "private_subnet": null, "vpn_tool": null, "firewall_tool": "ufw", "_discovery_note": null},
    "ingress": {"reverse_proxy_tool": null, "config_path": null, "access_model": null, "_discovery_note": null},
    "ssl": {"cert_tool": null, "config_path": null, "renewal_mechanism": null, "_discovery_note": null},
    "monitoring": {"metrics_tool": null, "metrics_status_check": null, "uptime_tool": null, "uptime_status_check": null, "log_aggregation_tool": null, "log_status_check": null, "_discovery_note": null},
    "backup": {"backup_tool": null, "targets": null, "pre_dump_scripts": null, "last_run_check": null, "_discovery_note": null},
    "secrets": {"approach": null, "canonical_location": null, "_discovery_note": null},
    "security_tooling": {"fim_tool": null, "fim_baseline_update_method": null, "ips_tool": null, "ips_status_check": null, "_discovery_note": null},
    "vcs": {"tool": null, "remote": null, "config_tracked_paths": null, "_discovery_note": null},
    "services": [{"name": "test-svc", "host_address": "127.0.0.1", "ports": [22]}]
  }
}
FIXTURE

    run bash "$SCRIPTS_DIR/go-nogo-poll.sh" "$FIXTURE_DIR/env_with_fw.json"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
data = json.load(sys.stdin)
checks = data['checks']
fw_checks = [c for c in checks if c['check'] == 'firewall_active']
assert len(fw_checks) == 1, f'expected 1 firewall_active check, got {len(fw_checks)}: {[c[\"check\"] for c in checks]}'
assert fw_checks[0]['target'] == 'ufw'
"
}
