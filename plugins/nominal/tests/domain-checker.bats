#!/usr/bin/env bats
# Tests for domain-checker.sh — parameterized verification domain checker.

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
    run bash -c "'$SCRIPTS_DIR/domain-checker.sh' 2>&1"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage"* ]]
}

@test "invalid domain number 0 outputs error" {
    run bash -c "'$SCRIPTS_DIR/domain-checker.sh' 0 '$FIXTURE_DIR/environment.json' 2>&1"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Invalid domain"* ]]
}

@test "invalid domain number 12 outputs error" {
    run bash -c "'$SCRIPTS_DIR/domain-checker.sh' 12 '$FIXTURE_DIR/environment.json' 2>&1"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Invalid domain"* ]]
}

@test "invalid domain number 99 outputs error" {
    run bash -c "'$SCRIPTS_DIR/domain-checker.sh' 99 '$FIXTURE_DIR/environment.json' 2>&1"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Invalid domain"* ]]
}

@test "domain 6 (performance) returns valid JSON with summary" {
    run bash "$SCRIPTS_DIR/domain-checker.sh" 6 "$FIXTURE_DIR/environment.json"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
data = json.load(sys.stdin)
assert 'summary' in data, 'missing summary'
assert 'total' in data['summary']
assert 'pass' in data['summary']
assert 'fail' in data['summary']
assert 'skip' in data['summary']
"
}

@test "domain 1 returns JSON with domain field matching input" {
    run bash "$SCRIPTS_DIR/domain-checker.sh" 1 "$FIXTURE_DIR/environment.json"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['domain']==1"
}

@test "domain 2 returns JSON with domain field matching input" {
    run bash "$SCRIPTS_DIR/domain-checker.sh" 2 "$FIXTURE_DIR/environment.json"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['domain']==2"
}

@test "domain 3 returns JSON with domain field matching input" {
    run bash "$SCRIPTS_DIR/domain-checker.sh" 3 "$FIXTURE_DIR/environment.json"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['domain']==3"
}

@test "domain 4 returns JSON with domain field matching input" {
    run bash "$SCRIPTS_DIR/domain-checker.sh" 4 "$FIXTURE_DIR/environment.json"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['domain']==4"
}

@test "domain 5 returns JSON with domain field matching input" {
    run bash "$SCRIPTS_DIR/domain-checker.sh" 5 "$FIXTURE_DIR/environment.json"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['domain']==5"
}

@test "domain 6 returns JSON with domain field matching input" {
    run bash "$SCRIPTS_DIR/domain-checker.sh" 6 "$FIXTURE_DIR/environment.json"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['domain']==6"
}

@test "domain 7 returns JSON with domain field matching input" {
    run bash "$SCRIPTS_DIR/domain-checker.sh" 7 "$FIXTURE_DIR/environment.json"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['domain']==7"
}

@test "domain 8 returns JSON with domain field matching input" {
    run bash "$SCRIPTS_DIR/domain-checker.sh" 8 "$FIXTURE_DIR/environment.json"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['domain']==8"
}

@test "domain 9 returns JSON with domain field matching input" {
    run bash "$SCRIPTS_DIR/domain-checker.sh" 9 "$FIXTURE_DIR/environment.json"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['domain']==9"
}

@test "domain 10 returns JSON with domain field matching input" {
    run bash "$SCRIPTS_DIR/domain-checker.sh" 10 "$FIXTURE_DIR/environment.json"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['domain']==10"
}

@test "domain 11 returns JSON with domain field matching input" {
    run bash "$SCRIPTS_DIR/domain-checker.sh" 11 "$FIXTURE_DIR/environment.json"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['domain']==11"
}

@test "domain 6 with --since-time flag includes oom_events check" {
    run bash "$SCRIPTS_DIR/domain-checker.sh" 6 "$FIXTURE_DIR/environment.json" --since-time "2026-04-09T00:00:00Z"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
data = json.load(sys.stdin)
check_names = [c['name'] for c in data['checks']]
assert 'oom_events' in check_names, f'expected oom_events check, got: {check_names}'
"
}

@test "domain 5 returns undeclared_ports check in output" {
    run bash "$SCRIPTS_DIR/domain-checker.sh" 5 "$FIXTURE_DIR/environment.json"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
data = json.load(sys.stdin)
check_names = [c['name'] for c in data['checks']]
assert 'undeclared_ports' in check_names, f'expected undeclared_ports check, got: {check_names}'
"
}

@test "domain 3 returns secrets_process_scan check in output" {
    # Domain 3 requires a canonical_location to run the process scan checks
    cat > "$FIXTURE_DIR/env_with_secrets.json" << 'FIXTURE'
{
  "_schema_version": "1.0.0",
  "test": {
    "host": {"hostname": "localhost", "os_name": "Linux", "os_version": "6.0", "architecture": "x86_64", "kernel_version": "6.0.0", "virtualization_type": "bare_metal", "_discovery_note": null},
    "network": {"topology": "flat", "private_bridge_or_overlay": null, "private_subnet": null, "vpn_tool": null, "firewall_tool": null, "_discovery_note": null},
    "ingress": {"reverse_proxy_tool": null, "config_path": null, "access_model": null, "_discovery_note": null},
    "ssl": {"cert_tool": null, "config_path": null, "renewal_mechanism": null, "_discovery_note": null},
    "monitoring": {"metrics_tool": null, "metrics_status_check": null, "uptime_tool": null, "uptime_status_check": null, "log_aggregation_tool": null, "log_status_check": null, "_discovery_note": null},
    "backup": {"backup_tool": null, "targets": null, "pre_dump_scripts": null, "last_run_check": null, "_discovery_note": null},
    "secrets": {"approach": "vault", "canonical_location": "vault://secret/data"},
    "security_tooling": {"fim_tool": null, "fim_baseline_update_method": null, "ips_tool": null, "ips_status_check": null, "_discovery_note": null},
    "vcs": {"tool": null, "remote": null, "config_tracked_paths": null, "_discovery_note": null},
    "services": []
  }
}
FIXTURE
    run bash "$SCRIPTS_DIR/domain-checker.sh" 3 "$FIXTURE_DIR/env_with_secrets.json"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
data = json.load(sys.stdin)
check_names = [c['name'] for c in data['checks']]
assert 'secrets_process_scan' in check_names, f'expected secrets_process_scan check, got: {check_names}'
"
}

@test "domain 11 returns config_uncommitted check in output" {
    run bash "$SCRIPTS_DIR/domain-checker.sh" 11 "$FIXTURE_DIR/environment.json"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
data = json.load(sys.stdin)
check_names = [c['name'] for c in data['checks']]
assert 'config_uncommitted' in check_names, f'expected config_uncommitted check, got: {check_names}'
"
}

@test "domain 6 reports cpu_load check" {
    run bash "$SCRIPTS_DIR/domain-checker.sh" 6 "$FIXTURE_DIR/environment.json"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
data = json.load(sys.stdin)
check_names = [c['name'] for c in data['checks']]
assert 'cpu_load' in check_names, f'expected cpu_load check, got: {check_names}'
"
}

@test "domain 6 reports memory check" {
    run bash "$SCRIPTS_DIR/domain-checker.sh" 6 "$FIXTURE_DIR/environment.json"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
data = json.load(sys.stdin)
check_names = [c['name'] for c in data['checks']]
assert 'memory' in check_names, f'expected memory check, got: {check_names}'
"
}

@test "domain 6 reports disk check" {
    run bash "$SCRIPTS_DIR/domain-checker.sh" 6 "$FIXTURE_DIR/environment.json"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
data = json.load(sys.stdin)
check_names = [c['name'] for c in data['checks']]
assert 'disk' in check_names, f'expected disk check, got: {check_names}'
"
}

@test "domain 7 reports autostart check" {
    cat > "$FIXTURE_DIR/env_enriched.json" << 'FIXTURE'
{
  "_schema_version": "1.0.0",
  "test": {
    "host": {"hostname": "localhost", "os_name": "Linux", "os_version": "6.0", "architecture": "x86_64", "kernel_version": "6.0.0", "virtualization_type": "bare_metal", "_discovery_note": null},
    "network": {"topology": "flat", "private_bridge_or_overlay": null, "private_subnet": null, "vpn_tool": null, "firewall_tool": null, "_discovery_note": null},
    "ingress": {"reverse_proxy_tool": null, "config_path": null, "access_model": null, "_discovery_note": null},
    "ssl": {"cert_tool": "certbot", "config_path": null, "renewal_mechanism": null, "_discovery_note": null},
    "monitoring": {"metrics_tool": null, "metrics_status_check": null, "uptime_tool": null, "uptime_status_check": null, "log_aggregation_tool": null, "log_status_check": null, "_discovery_note": null},
    "backup": {"backup_tool": "restic", "targets": null, "pre_dump_scripts": null, "last_run_check": null, "_discovery_note": null},
    "secrets": {"approach": null, "canonical_location": null, "_discovery_note": null},
    "security_tooling": {"fim_tool": null, "fim_baseline_update_method": null, "ips_tool": null, "ips_status_check": null, "_discovery_note": null},
    "vcs": {"tool": null, "remote": null, "config_tracked_paths": null, "_discovery_note": null},
    "services": [{"name": "test-svc", "host_address": "127.0.0.1", "ports": [8080], "health_endpoint": "http://127.0.0.1:8080/health", "access_tier": "public", "dependencies": null, "role": null, "monitoring_collector": null}]
  }
}
FIXTURE
    run bash "$SCRIPTS_DIR/domain-checker.sh" 7 "$FIXTURE_DIR/env_enriched.json"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
data = json.load(sys.stdin)
check_names = [c['name'] for c in data['checks']]
assert 'autostart' in check_names, f'expected autostart check, got: {check_names}'
"
}

@test "domain 2 with backup_tool configured reports backup_installed" {
    cat > "$FIXTURE_DIR/env_backup.json" << 'FIXTURE'
{
  "_schema_version": "1.0.0",
  "test": {
    "host": {"hostname": "localhost", "os_name": "Linux", "os_version": "6.0", "architecture": "x86_64", "kernel_version": "6.0.0", "virtualization_type": "bare_metal", "_discovery_note": null},
    "network": {"topology": "flat", "private_bridge_or_overlay": null, "private_subnet": null, "vpn_tool": null, "firewall_tool": null, "_discovery_note": null},
    "ingress": {"reverse_proxy_tool": null, "config_path": null, "access_model": null, "_discovery_note": null},
    "ssl": {"cert_tool": null, "config_path": null, "renewal_mechanism": null, "_discovery_note": null},
    "monitoring": {"metrics_tool": null, "metrics_status_check": null, "uptime_tool": null, "uptime_status_check": null, "log_aggregation_tool": null, "log_status_check": null, "_discovery_note": null},
    "backup": {"backup_tool": "restic", "targets": null, "pre_dump_scripts": null, "last_run_check": null, "_discovery_note": null},
    "secrets": {"approach": null, "canonical_location": null, "_discovery_note": null},
    "security_tooling": {"fim_tool": null, "fim_baseline_update_method": null, "ips_tool": null, "ips_status_check": null, "_discovery_note": null},
    "vcs": {"tool": null, "remote": null, "config_tracked_paths": null, "_discovery_note": null},
    "services": []
  }
}
FIXTURE
    run bash "$SCRIPTS_DIR/domain-checker.sh" 2 "$FIXTURE_DIR/env_backup.json"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
data = json.load(sys.stdin)
check_names = [c['name'] for c in data['checks']]
assert 'backup_installed' in check_names, f'expected backup_installed check, got: {check_names}'
"
}

@test "domain 4 with service having health_endpoint reports service_reachable" {
    cat > "$FIXTURE_DIR/env_health.json" << 'FIXTURE'
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
    "services": [{"name": "test-svc", "host_address": "127.0.0.1", "ports": [8080], "health_endpoint": "http://127.0.0.1:8080/health", "access_tier": "public", "dependencies": null, "role": null, "monitoring_collector": null}]
  }
}
FIXTURE
    run bash "$SCRIPTS_DIR/domain-checker.sh" 4 "$FIXTURE_DIR/env_health.json"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
data = json.load(sys.stdin)
check_names = [c['name'] for c in data['checks']]
assert 'service_reachable' in check_names, f'expected service_reachable check, got: {check_names}'
"
}

@test "domain 9 with cert_tool reports cert_renewal check" {
    cat > "$FIXTURE_DIR/env_cert.json" << 'FIXTURE'
{
  "_schema_version": "1.0.0",
  "test": {
    "host": {"hostname": "localhost", "os_name": "Linux", "os_version": "6.0", "architecture": "x86_64", "kernel_version": "6.0.0", "virtualization_type": "bare_metal", "_discovery_note": null},
    "network": {"topology": "flat", "private_bridge_or_overlay": null, "private_subnet": null, "vpn_tool": null, "firewall_tool": null, "_discovery_note": null},
    "ingress": {"reverse_proxy_tool": null, "config_path": null, "access_model": null, "_discovery_note": null},
    "ssl": {"cert_tool": "certbot", "config_path": null, "renewal_mechanism": null, "_discovery_note": null},
    "monitoring": {"metrics_tool": null, "metrics_status_check": null, "uptime_tool": null, "uptime_status_check": null, "log_aggregation_tool": null, "log_status_check": null, "_discovery_note": null},
    "backup": {"backup_tool": null, "targets": null, "pre_dump_scripts": null, "last_run_check": null, "_discovery_note": null},
    "secrets": {"approach": null, "canonical_location": null, "_discovery_note": null},
    "security_tooling": {"fim_tool": null, "fim_baseline_update_method": null, "ips_tool": null, "ips_status_check": null, "_discovery_note": null},
    "vcs": {"tool": null, "remote": null, "config_tracked_paths": null, "_discovery_note": null},
    "services": []
  }
}
FIXTURE
    run bash "$SCRIPTS_DIR/domain-checker.sh" 9 "$FIXTURE_DIR/env_cert.json"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
data = json.load(sys.stdin)
check_names = [c['name'] for c in data['checks']]
assert 'cert_renewal' in check_names, f'expected cert_renewal check, got: {check_names}'
"
}

@test "domain 10 reports wildcard_bindings check" {
    run bash "$SCRIPTS_DIR/domain-checker.sh" 10 "$FIXTURE_DIR/environment.json"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
data = json.load(sys.stdin)
check_names = [c['name'] for c in data['checks']]
assert 'wildcard_bindings' in check_names, f'expected wildcard_bindings check, got: {check_names}'
"
}

@test "domain 11 reports commits_not_pushed check" {
    run bash "$SCRIPTS_DIR/domain-checker.sh" 11 "$FIXTURE_DIR/environment.json"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
data = json.load(sys.stdin)
check_names = [c['name'] for c in data['checks']]
assert 'commits_not_pushed' in check_names, f'expected commits_not_pushed check, got: {check_names}'
"
}

@test "domain 5 reports firewall_active check" {
    run bash "$SCRIPTS_DIR/domain-checker.sh" 5 "$FIXTURE_DIR/environment.json"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
data = json.load(sys.stdin)
check_names = [c['name'] for c in data['checks']]
assert 'firewall_active' in check_names, f'expected firewall_active check, got: {check_names}'
"
}
