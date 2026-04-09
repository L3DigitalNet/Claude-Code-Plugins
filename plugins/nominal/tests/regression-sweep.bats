#!/usr/bin/env bats
# Tests for regression-sweep.sh — lightweight regression checks.

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

@test "missing arguments exits 1" {
    run bash -c "'$SCRIPTS_DIR/regression-sweep.sh' 2>&1"
    [ "$status" -eq 1 ]
}

@test "with fixture environment.json and domains 5,6 returns valid JSON" {
    run bash "$SCRIPTS_DIR/regression-sweep.sh" "$FIXTURE_DIR/environment.json" "5,6"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "import json, sys; json.load(sys.stdin)"
}

@test "clean boolean present in output" {
    run bash "$SCRIPTS_DIR/regression-sweep.sh" "$FIXTURE_DIR/environment.json" "5,6"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
data = json.load(sys.stdin)
assert 'clean' in data, 'missing clean key'
assert isinstance(data['clean'], bool), 'clean is not a boolean'
"
}

@test "domains_checked matches input count" {
    run bash "$SCRIPTS_DIR/regression-sweep.sh" "$FIXTURE_DIR/environment.json" "5,6"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
data = json.load(sys.stdin)
assert data['domains_checked'] == 2, f'expected 2, got {data[\"domains_checked\"]}'
"
}

@test "with firewall_tool=ufw: domain 5 key signal runs and produces evidence" {
    cat > "$FIXTURE_DIR/env_with_fw.json" << 'FIXTURE'
{
  "_schema_version": "1.0.0",
  "test": {
    "description": "test env with firewall",
    "first_discovered": "2026-04-09T00:00:00Z",
    "last_validated": "2026-04-09T00:00:00Z",
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

    run bash "$SCRIPTS_DIR/regression-sweep.sh" "$FIXTURE_DIR/env_with_fw.json" "5"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
data = json.load(sys.stdin)
assert data['domains_checked'] == 1, f'expected 1, got {data[\"domains_checked\"]}'
# Either clean (ufw active) or regression (ufw inactive) — both indicate the check ran
# The key is the output includes domain 5 evidence about the firewall
if not data['clean']:
    regs = data['regressions']
    assert len(regs) == 1
    assert regs[0]['domain'] == 5
    assert 'ufw' in regs[0]['detail'], f'expected ufw in detail: {regs[0][\"detail\"]}'
else:
    assert data['regressions'] == []
"
}

@test "regression sweep with nonexistent firewall tool detects regression" {
    cat > "$FIXTURE_DIR/env_bad_fw.json" << 'FIXTURE'
{
  "_schema_version": "1.0.0",
  "test": {
    "description": "test env with bogus firewall",
    "first_discovered": "2026-04-09T00:00:00Z",
    "last_validated": "2026-04-09T00:00:00Z",
    "host": {"hostname": "localhost", "os_name": "Linux", "os_version": "6.0", "architecture": "x86_64", "kernel_version": "6.0.0", "virtualization_type": "bare_metal", "_discovery_note": null},
    "network": {"topology": "flat", "private_bridge_or_overlay": null, "private_subnet": null, "vpn_tool": null, "firewall_tool": "nonexistent_fw_tool_zzz", "_discovery_note": null},
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

    run bash "$SCRIPTS_DIR/regression-sweep.sh" "$FIXTURE_DIR/env_bad_fw.json" "5"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
data = json.load(sys.stdin)
assert data['domains_checked'] == 1
assert not data['clean'], 'expected regression but sweep reported clean'
assert len(data['regressions']) > 0, 'expected non-empty regressions array'
reg = data['regressions'][0]
assert reg['domain'] == 5
assert 'nonexistent_fw_tool_zzz' in reg['detail'], f'expected firewall tool name in detail: {reg[\"detail\"]}'
"
}
