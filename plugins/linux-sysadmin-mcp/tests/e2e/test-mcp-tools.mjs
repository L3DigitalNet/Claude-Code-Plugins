#!/usr/bin/env node
/**
 * E2E MCP Tool Tests — linux-sysadmin-mcp
 *
 * Tests ALL MCP tools by sending real JSON-RPC protocol messages to
 * the server running inside the linux-sysadmin-test container.
 *
 * Usage:  node tests/e2e/test-mcp-tools.mjs
 */

import { spawn } from "node:child_process";
import { createInterface } from "node:readline";

// ────────────────────────────────────────────────────────────────────
// MCP Test Client
// ────────────────────────────────────────────────────────────────────

class McpTestClient {
  #proc;
  #rl;
  #nextId = 1;
  /** @type {Map<number, {resolve: Function, reject: Function, timer: NodeJS.Timeout}>} */
  #pending = new Map();
  #ready = false;
  #buffer = "";

  constructor() {
    this.#proc = spawn("podman", [
      "exec", "-i", "linux-sysadmin-test",
      "node", "/plugin/dist/server.bundle.cjs",
    ], { stdio: ["pipe", "pipe", "pipe"] });

    // Read stdout line-by-line. Ignore pino log lines (they have "level" and "msg").
    this.#rl = createInterface({ input: this.#proc.stdout });
    this.#rl.on("line", (line) => this.#handleLine(line));

    // Silence stderr (pino logs may also go here)
    this.#proc.stderr.on("data", () => {});

    this.#proc.on("error", (err) => {
      for (const [id, p] of this.#pending) {
        clearTimeout(p.timer);
        p.reject(new Error(`Process error: ${err.message}`));
      }
      this.#pending.clear();
    });

    this.#proc.on("exit", (code) => {
      for (const [id, p] of this.#pending) {
        clearTimeout(p.timer);
        p.reject(new Error(`Process exited with code ${code}`));
      }
      this.#pending.clear();
    });
  }

  #handleLine(line) {
    const trimmed = line.trim();
    if (!trimmed) return;

    // Try to parse as JSON
    let msg;
    try {
      msg = JSON.parse(trimmed);
    } catch {
      return; // Not JSON — skip (pino log line with text prefix, etc.)
    }

    // Only process JSON-RPC messages (have jsonrpc field)
    if (msg.jsonrpc !== "2.0") return;

    // Match response to pending request by id
    if (msg.id !== undefined && this.#pending.has(msg.id)) {
      const p = this.#pending.get(msg.id);
      this.#pending.delete(msg.id);
      clearTimeout(p.timer);
      p.resolve(msg);
    }
  }

  /** Send a JSON-RPC message (no response expected) */
  #send(msg) {
    const data = JSON.stringify(msg) + "\n";
    this.#proc.stdin.write(data);
  }

  /** Send a JSON-RPC request and wait for the response */
  #request(method, params, timeoutMs = 30000) {
    return new Promise((resolve, reject) => {
      const id = this.#nextId++;
      const timer = setTimeout(() => {
        this.#pending.delete(id);
        reject(new Error(`Timeout waiting for response to ${method} (id=${id}) after ${timeoutMs}ms`));
      }, timeoutMs);
      this.#pending.set(id, { resolve, reject, timer });
      this.#send({ jsonrpc: "2.0", id, method, params });
    });
  }

  /** Perform MCP handshake (initialize + initialized notification) */
  async connect() {
    const response = await this.#request("initialize", {
      protocolVersion: "2025-03-26",
      capabilities: {},
      clientInfo: { name: "e2e-test", version: "1.0.0" },
    }, 15000);

    if (!response.result || !response.result.serverInfo) {
      throw new Error("Invalid initialize response: " + JSON.stringify(response));
    }

    // Send initialized notification (no response expected)
    this.#send({ jsonrpc: "2.0", method: "notifications/initialized" });

    // Small delay to let the notification be processed
    await new Promise((r) => setTimeout(r, 200));
    this.#ready = true;

    return response.result;
  }

  /** Call an MCP tool and return the parsed result */
  async callTool(name, args = {}, timeoutMs = 30000) {
    if (!this.#ready) throw new Error("Client not connected. Call connect() first.");

    const response = await this.#request("tools/call", { name, arguments: args }, timeoutMs);

    if (response.error) {
      return { _rpcError: true, code: response.error.code, message: response.error.message };
    }

    const result = response.result;
    if (!result || !Array.isArray(result.content) || result.content.length === 0) {
      return { _emptyContent: true, raw: result };
    }

    // Parse the text content as JSON (ToolResponse)
    const text = result.content[0].text;
    try {
      return JSON.parse(text);
    } catch {
      return { _parseError: true, text };
    }
  }

  /** List all registered tools */
  async listTools() {
    const response = await this.#request("tools/list", {}, 10000);
    return response.result?.tools ?? [];
  }

  close() {
    this.#rl.close();
    try { this.#proc.stdin.end(); } catch {}
    try { this.#proc.kill("SIGTERM"); } catch {}
    // Force kill after 2s
    setTimeout(() => { try { this.#proc.kill("SIGKILL"); } catch {} }, 2000);
  }
}

// ────────────────────────────────────────────────────────────────────
// Test Harness
// ────────────────────────────────────────────────────────────────────

let passed = 0;
let failed = 0;
let skipped = 0;
const failures = [];

function assert(condition, message) {
  if (condition) {
    passed++;
  } else {
    failed++;
    failures.push(message);
    console.log(`    FAIL: ${message}`);
  }
}

function assertEqual(actual, expected, message) {
  if (actual === expected) {
    passed++;
  } else {
    failed++;
    failures.push(`${message} — expected: ${JSON.stringify(expected)}, got: ${JSON.stringify(actual)}`);
    console.log(`    FAIL: ${message} — expected: ${JSON.stringify(expected)}, got: ${JSON.stringify(actual)}`);
  }
}

function assertIn(actual, allowed, message) {
  if (allowed.includes(actual)) {
    passed++;
  } else {
    failed++;
    failures.push(`${message} — got ${JSON.stringify(actual)}, expected one of: ${JSON.stringify(allowed)}`);
    console.log(`    FAIL: ${message} — got ${JSON.stringify(actual)}, expected one of: ${JSON.stringify(allowed)}`);
  }
}

function skip(name, reason) {
  skipped++;
  console.log(`    SKIP: ${name} — ${reason}`);
}

/**
 * Validates that a response conforms to the ToolResponse schema.
 * Returns true if valid, false otherwise.
 */
function validateToolResponse(resp, toolName) {
  if (!resp || typeof resp !== "object") {
    assert(false, `${toolName}: response is not an object`);
    return false;
  }
  if (resp._rpcError) {
    // JSON-RPC level error — still counts as a valid protocol response
    assert(true, `${toolName}: got RPC-level error (code=${resp.code})`);
    return true;
  }
  if (resp._emptyContent) {
    assert(false, `${toolName}: empty content in result`);
    return false;
  }
  if (resp._parseError) {
    assert(false, `${toolName}: could not parse content text as JSON`);
    return false;
  }

  // Check base fields
  assertIn(resp.status, ["success", "error", "blocked", "confirmation_required"],
    `${toolName}: valid status`);
  assert(typeof resp.tool === "string", `${toolName}: has tool field`);
  assert(typeof resp.target_host === "string", `${toolName}: has target_host`);
  assert(typeof resp.duration_ms === "number", `${toolName}: has duration_ms`);
  assert(resp.command_executed === null || typeof resp.command_executed === "string",
    `${toolName}: command_executed is string or null`);

  // Status-specific checks
  if (resp.status === "success") {
    assert(typeof resp.data === "object" && resp.data !== null, `${toolName}: success has data`);
  } else if (resp.status === "error") {
    assert(typeof resp.error_code === "string", `${toolName}: error has error_code`);
    assert(typeof resp.error_category === "string", `${toolName}: error has error_category`);
    assert(typeof resp.message === "string", `${toolName}: error has message`);
  } else if (resp.status === "confirmation_required") {
    assert(typeof resp.risk_level === "string", `${toolName}: confirmation has risk_level`);
    assert(typeof resp.preview === "object", `${toolName}: confirmation has preview`);
  }

  return true;
}

// ────────────────────────────────────────────────────────────────────
// Tool Test Definitions (grouped by module)
// ────────────────────────────────────────────────────────────────────

/** @type {Array<{module: string, tools: Array<{name: string, args?: object, expectStatus?: string|string[], confirmed?: object, confirmExpect?: string|string[], timeout?: number}>}>} */
const modules = [
  // ── SESSION ──
  {
    module: "Session",
    tools: [
      { name: "sysadmin_session_info", args: {} },
      { name: "sysadmin_session_info", args: { show_sudoers_reference: true }, label: "with_sudoers" },
    ],
  },

  // ── PACKAGES (read-only) ──
  {
    module: "Packages (read-only)",
    tools: [
      { name: "pkg_list_installed", args: {} },
      { name: "pkg_list_installed", args: { filter: "bash", limit: 5 }, label: "filtered", expectStatus: ["success", "error"] },
      { name: "pkg_search", args: { query: "nginx" } },
      { name: "pkg_info", args: { package: "bash" } },
      { name: "pkg_check_updates", args: {} },
      { name: "pkg_history", args: {} },
    ],
  },

  // ── PACKAGES (state-changing — test confirmation gate, then confirmed) ──
  {
    module: "Packages (state-changing)",
    tools: [
      {
        name: "pkg_install",
        args: { packages: ["cowsay"] },
        expectStatus: "confirmation_required",
        confirmed: { packages: ["cowsay"], confirmed: true },
        confirmExpect: ["success", "error"],
      },
      {
        // dry_run: true bypasses the safety gate (dry_run_bypass_confirmation)
        // so test without dry_run first to hit confirmation gate, then confirm
        name: "pkg_update",
        args: { packages: ["bash"] },
        expectStatus: "confirmation_required",
        confirmed: { packages: ["bash"], dry_run: true, confirmed: true },
        confirmExpect: ["success", "error"],
      },
      {
        name: "pkg_remove",
        args: { packages: ["cowsay"] },
        expectStatus: "confirmation_required",
        confirmed: { packages: ["cowsay"], confirmed: true },
        confirmExpect: ["success", "error"],
      },
      {
        name: "pkg_purge",
        args: { packages: ["cowsay"] },
        expectStatus: "confirmation_required",
        confirmed: { packages: ["cowsay"], confirmed: true },
        confirmExpect: ["success", "error"],
      },
      {
        name: "pkg_rollback",
        args: { package: "bash" },
        expectStatus: "confirmation_required",
        confirmed: { package: "bash", confirmed: true },
        confirmExpect: ["success", "error"],
      },
    ],
  },

  // ── SERVICES (read-only) ──
  {
    module: "Services (read-only)",
    tools: [
      { name: "svc_list", args: {} },
      { name: "svc_list", args: { filter: "running", limit: 5 }, label: "filtered" },
      { name: "svc_status", args: { service: "sshd" } },
      { name: "svc_logs", args: { service: "sshd", lines: 10 }, timeout: 60000 },
      { name: "timer_list", args: {} },
    ],
  },

  // ── SERVICES (state-changing) ──
  {
    module: "Services (state-changing)",
    tools: [
      {
        name: "svc_start",
        args: { service: "nginx" },
        expectStatus: "confirmation_required",
        confirmed: { service: "nginx", confirmed: true },
        confirmExpect: ["success", "error"],
      },
      {
        name: "svc_stop",
        args: { service: "nginx" },
        expectStatus: "confirmation_required",
        confirmed: { service: "nginx", confirmed: true },
        confirmExpect: ["success", "error"],
      },
      {
        name: "svc_restart",
        args: { service: "nginx" },
        expectStatus: "confirmation_required",
        confirmed: { service: "nginx", confirmed: true },
        confirmExpect: ["success", "error"],
      },
      {
        name: "svc_enable",
        args: { service: "nginx" },
        expectStatus: "confirmation_required",
        confirmed: { service: "nginx", confirmed: true },
        confirmExpect: ["success", "error"],
      },
      {
        name: "svc_disable",
        args: { service: "nginx" },
        expectStatus: "confirmation_required",
        confirmed: { service: "nginx", confirmed: true },
        confirmExpect: ["success", "error"],
      },
    ],
  },

  // ── PERFORMANCE ──
  {
    module: "Performance",
    tools: [
      { name: "perf_overview", args: {} },
      { name: "perf_top_processes", args: {} },
      { name: "perf_top_processes", args: { sort_by: "memory", limit: 5 }, label: "by_memory" },
      { name: "perf_memory", args: {} },
      { name: "perf_disk_io", args: {} },
      { name: "perf_network_io", args: {} },
      { name: "perf_uptime", args: {} },
      { name: "perf_bottleneck", args: {} },
    ],
  },

  // ── LOGS ──
  {
    module: "Logs",
    tools: [
      { name: "log_query", args: { limit: 10 } },
      { name: "log_query", args: { unit: "sshd", limit: 5, priority: "info" }, label: "filtered" },
      { name: "log_search", args: { pattern: "error", limit: 10 } },
      { name: "log_summary", args: {} },
      { name: "log_disk_usage", args: {} },
    ],
  },

  // ── SECURITY ──
  {
    module: "Security (read-only)",
    tools: [
      { name: "sec_audit", args: {} },
      { name: "sec_check_ssh", args: {} },
      { name: "sec_update_check", args: {} },
      { name: "sec_mac_status", args: {} },
      { name: "sec_check_listening", args: {} },
      { name: "sec_check_suid", args: { path: "/usr/bin" }, timeout: 45000 },
    ],
  },

  // ── SECURITY (state-changing) ──
  {
    module: "Security (state-changing)",
    tools: [
      {
        name: "sec_harden_ssh",
        args: { actions: ["disable_x11"] },
        expectStatus: "confirmation_required",
        confirmed: { actions: ["disable_x11"], confirmed: true },
        confirmExpect: ["success", "error"],
      },
    ],
  },

  // ── STORAGE (read-only) ──
  {
    module: "Storage (read-only)",
    tools: [
      { name: "disk_usage", args: {} },
      { name: "disk_usage", args: { path: "/" }, label: "with_path" },
      { name: "disk_usage_top", args: { path: "/var", limit: 5, depth: 1 } },
      { name: "mount_list", args: {} },
      { name: "lvm_status", args: {} },
    ],
  },

  // ── STORAGE (state-changing) ──
  {
    module: "Storage (state-changing)",
    tools: [
      {
        name: "mount_add",
        args: { device: "/dev/null", mount_point: "/mnt/test", fs_type: "tmpfs" },
        expectStatus: "confirmation_required",
        confirmed: { device: "tmpfs", mount_point: "/mnt/test-e2e", fs_type: "tmpfs", options: "size=1M", confirmed: true },
        confirmExpect: ["success", "error"],
      },
      {
        name: "mount_remove",
        args: { mount_point: "/mnt/test-e2e" },
        expectStatus: "confirmation_required",
        confirmed: { mount_point: "/mnt/test-e2e", confirmed: true },
        confirmExpect: ["success", "error"],
      },
      {
        name: "lvm_create_lv",
        args: { name: "testlv", vg: "testvg", size: "10M" },
        expectStatus: "confirmation_required",
        confirmed: { name: "testlv", vg: "testvg", size: "10M", confirmed: true },
        confirmExpect: ["success", "error"],
      },
      {
        name: "lvm_resize",
        args: { lv_path: "/dev/testvg/testlv", size: "20M" },
        expectStatus: "confirmation_required",
        confirmed: { lv_path: "/dev/testvg/testlv", size: "20M", confirmed: true },
        confirmExpect: ["success", "error"],
      },
    ],
  },

  // ── USERS (read-only) ──
  {
    module: "Users (read-only)",
    tools: [
      { name: "user_list", args: {} },
      { name: "user_list", args: { include_system: true }, label: "with_system" },
      { name: "user_info", args: { username: "root" } },
      { name: "group_list", args: {} },
      { name: "group_list", args: { filter: "root" }, label: "filtered" },
      { name: "perms_check", args: { path: "/etc/passwd" } },
    ],
  },

  // ── USERS (state-changing) ──
  {
    module: "Users (state-changing)",
    tools: [
      {
        name: "user_create",
        args: { username: "e2etestuser" },
        expectStatus: "confirmation_required",
        confirmed: { username: "e2etestuser", confirmed: true },
        confirmExpect: ["success", "error"],
      },
      {
        name: "user_modify",
        args: { username: "e2etestuser", comment: "E2E Test" },
        expectStatus: "confirmation_required",
        confirmed: { username: "e2etestuser", comment: "E2E Test", confirmed: true },
        confirmExpect: ["success", "error"],
      },
      {
        name: "group_create",
        args: { name: "e2etestgroup" },
        expectStatus: "confirmation_required",
        confirmed: { name: "e2etestgroup", confirmed: true },
        confirmExpect: ["success", "error"],
      },
      {
        name: "perms_set",
        args: { path: "/tmp/e2e-test-perms", mode: "644" },
        expectStatus: "confirmation_required",
        confirmed: { path: "/tmp/e2e-test-perms", mode: "644", confirmed: true },
        confirmExpect: ["success", "error"],
      },
    ],
  },

  // ── FIREWALL (read-only) ──
  {
    module: "Firewall (read-only)",
    tools: [
      { name: "fw_status", args: {} },
      { name: "fw_list_rules", args: {} },
    ],
  },

  // ── FIREWALL (state-changing) ──
  {
    module: "Firewall (state-changing)",
    tools: [
      {
        name: "fw_add_rule",
        args: { action: "allow", direction: "in", port: 9999, protocol: "tcp" },
        expectStatus: "confirmation_required",
        confirmed: { action: "allow", direction: "in", port: 9999, protocol: "tcp", confirmed: true },
        confirmExpect: ["success", "error"],
      },
      {
        name: "fw_remove_rule",
        args: { action: "allow", direction: "in", port: 9999, protocol: "tcp" },
        expectStatus: "confirmation_required",
        confirmed: { action: "allow", direction: "in", port: 9999, protocol: "tcp", confirmed: true },
        confirmExpect: ["success", "error"],
      },
      {
        name: "fw_enable",
        args: {},
        expectStatus: "confirmation_required",
        confirmed: { confirmed: true },
        confirmExpect: ["success", "error"],
      },
      {
        name: "fw_disable",
        args: {},
        expectStatus: "confirmation_required",
        confirmed: { confirmed: true },
        confirmExpect: ["success", "error"],
      },
    ],
  },

  // ── NETWORKING (read-only) ──
  {
    module: "Networking (read-only)",
    tools: [
      { name: "net_interfaces", args: {} },
      { name: "net_connections", args: {} },
      { name: "net_connections", args: { listening_only: true }, label: "listening" },
      { name: "net_dns_show", args: {} },
      { name: "net_routes_show", args: {} },
      { name: "net_test", args: { target: "127.0.0.1", test: "ping" } },
    ],
  },

  // ── NETWORKING (state-changing) ──
  {
    module: "Networking (state-changing)",
    tools: [
      {
        name: "net_dns_modify",
        args: { nameservers: ["8.8.8.8"] },
        expectStatus: "confirmation_required",
        confirmed: { nameservers: ["8.8.8.8", "8.8.4.4"], confirmed: true },
        confirmExpect: ["success", "error"],
      },
      {
        name: "net_routes_modify",
        args: { action: "add", destination: "10.99.99.0/24", gateway: "127.0.0.1" },
        expectStatus: "confirmation_required",
        confirmed: { action: "add", destination: "10.99.99.0/24", gateway: "127.0.0.1", confirmed: true },
        confirmExpect: ["success", "error"],
      },
    ],
  },

  // ── CONTAINERS (read-only — will likely error since no nested runtime) ──
  {
    module: "Containers (read-only)",
    tools: [
      { name: "ctr_list", args: {}, expectStatus: ["success", "error"] },
      { name: "ctr_images", args: {}, expectStatus: ["success", "error"] },
      { name: "ctr_inspect", args: { container: "nonexistent" }, expectStatus: ["success", "error"] },
      { name: "ctr_logs", args: { container: "nonexistent", tail: 10 }, expectStatus: ["success", "error"] },
      { name: "ctr_compose_status", args: {}, expectStatus: ["success", "error"] },
    ],
  },

  // ── CONTAINERS (state-changing — will likely error) ──
  {
    module: "Containers (state-changing)",
    tools: [
      {
        name: "ctr_start",
        args: { container: "nonexistent" },
        expectStatus: "confirmation_required",
        confirmed: { container: "nonexistent", confirmed: true },
        confirmExpect: ["success", "error"],
      },
      {
        name: "ctr_stop",
        args: { container: "nonexistent" },
        expectStatus: "confirmation_required",
        confirmed: { container: "nonexistent", confirmed: true },
        confirmExpect: ["success", "error"],
      },
      {
        name: "ctr_restart",
        args: { container: "nonexistent" },
        expectStatus: "confirmation_required",
        confirmed: { container: "nonexistent", confirmed: true },
        confirmExpect: ["success", "error"],
      },
      {
        name: "ctr_remove",
        args: { container: "nonexistent" },
        expectStatus: "confirmation_required",
        confirmed: { container: "nonexistent", confirmed: true },
        confirmExpect: ["success", "error"],
      },
      {
        name: "ctr_image_pull",
        args: { image: "alpine:latest" },
        expectStatus: "confirmation_required",
        // skip confirmed for image_pull — no container runtime
      },
      {
        name: "ctr_image_remove",
        args: { image: "alpine:latest" },
        expectStatus: "confirmation_required",
        // skip confirmed — no container runtime
      },
      {
        name: "ctr_compose_up",
        args: { project_dir: "/tmp/nodir" },
        expectStatus: "confirmation_required",
        confirmed: { project_dir: "/tmp/nodir", confirmed: true },
        confirmExpect: ["success", "error"],
      },
      {
        name: "ctr_compose_down",
        args: { project_dir: "/tmp/nodir" },
        expectStatus: "confirmation_required",
        confirmed: { project_dir: "/tmp/nodir", confirmed: true },
        confirmExpect: ["success", "error"],
      },
    ],
  },

  // ── CRON (read-only) ──
  {
    module: "Cron (read-only)",
    tools: [
      { name: "cron_list", args: {} },
      { name: "cron_list", args: { user: "root" }, label: "root" },
      { name: "cron_validate", args: { expression: "0 * * * *" } },
      { name: "cron_next_runs", args: { expression: "0 * * * *", count: 3 } },
    ],
  },

  // ── CRON (state-changing) ──
  {
    module: "Cron (state-changing)",
    tools: [
      {
        name: "cron_add",
        args: { schedule: "0 3 * * *", command: "/bin/echo e2e-test" },
        expectStatus: "confirmation_required",
        confirmed: { schedule: "0 3 * * *", command: "/bin/echo e2e-test", comment: "e2e test", confirmed: true },
        confirmExpect: ["success", "error"],
      },
      {
        name: "cron_remove",
        args: { pattern: "e2e-test" },
        expectStatus: "confirmation_required",
        confirmed: { pattern: "e2e-test", confirmed: true },
        confirmExpect: ["success", "error"],
      },
    ],
  },

  // ── BACKUP (read-only) ──
  {
    module: "Backup (read-only)",
    tools: [
      { name: "bak_list", args: {} },
      { name: "bak_verify", args: { path: "/var/backups" } },
    ],
  },

  // ── BACKUP (state-changing) ──
  {
    module: "Backup (state-changing)",
    tools: [
      {
        name: "bak_create",
        args: { paths: ["/etc/hostname"], destination: "/tmp" },
        expectStatus: "confirmation_required",
        confirmed: { paths: ["/etc/hostname"], destination: "/tmp", method: "tar", confirmed: true },
        confirmExpect: ["success", "error"],
      },
      {
        name: "bak_restore",
        args: { source: "/tmp/nonexistent.tar.gz", destination: "/tmp" },
        expectStatus: "confirmation_required",
        confirmed: { source: "/tmp/nonexistent.tar.gz", destination: "/tmp", confirmed: true },
        confirmExpect: ["success", "error"],
      },
      {
        name: "bak_schedule",
        args: { paths: ["/etc/hostname"], destination: "/tmp", schedule: "0 2 * * *" },
        expectStatus: "confirmation_required",
        confirmed: { paths: ["/etc/hostname"], destination: "/tmp", schedule: "0 2 * * *", confirmed: true },
        confirmExpect: ["success", "error"],
      },
    ],
  },

  // ── SSH ──
  {
    module: "SSH",
    tools: [
      { name: "ssh_session_info", args: {} },
      { name: "ssh_config_list", args: {} },
      { name: "ssh_key_list", args: {} },
      { name: "ssh_test_connection", args: { host: "127.0.0.1", port: 22 }, timeout: 15000 },
      { name: "ssh_key_generate", args: { type: "ed25519", filename: "/tmp/e2e-test-key" } },
      { name: "ssh_authorized_keys", args: {} },
    ],
  },

  // ── DOCS ──
  {
    module: "Docs",
    tools: [
      { name: "doc_status", args: {}, expectStatus: ["success", "error"] },
      { name: "doc_init", args: { path: "/tmp/e2e-doc-repo" }, expectStatus: ["success", "error"] },
      { name: "doc_generate_host", args: { rationale: "E2E test host" }, expectStatus: ["success", "error"] },
      { name: "doc_generate_service", args: { service: "sshd", rationale: "SSH access" }, expectStatus: ["success", "error"] },
      { name: "doc_backup_config", args: { service: "sshd", paths: ["/etc/ssh/sshd_config"] }, expectStatus: ["success", "error"] },
      { name: "doc_diff", args: {}, expectStatus: ["success", "error"] },
      { name: "doc_history", args: {}, expectStatus: ["success", "error"] },
      { name: "doc_restore_guide", args: {}, expectStatus: ["success", "error"] },
    ],
  },

  // ── CLEANUP (user/group deletion — must be last) ──
  {
    module: "Cleanup",
    tools: [
      {
        name: "group_delete",
        args: { name: "e2etestgroup" },
        expectStatus: "confirmation_required",
        confirmed: { name: "e2etestgroup", confirmed: true },
        confirmExpect: ["success", "error"],
      },
      {
        name: "user_delete",
        args: { username: "e2etestuser", remove_home: true },
        expectStatus: "confirmation_required",
        confirmed: { username: "e2etestuser", remove_home: true, confirmed: true },
        confirmExpect: ["success", "error"],
      },
    ],
  },
];

// ────────────────────────────────────────────────────────────────────
// Main test runner
// ────────────────────────────────────────────────────────────────────

async function main() {
  console.log("=".repeat(72));
  console.log("  MCP Tool E2E Tests — linux-sysadmin-mcp");
  console.log("=".repeat(72));
  console.log("");

  // Create prerequisite files in container for testing
  try {
    await new Promise((resolve, reject) => {
      const p = spawn("podman", [
        "exec", "linux-sysadmin-test",
        "bash", "-c",
        "touch /tmp/e2e-test-perms && rm -f /tmp/e2e-test-key /tmp/e2e-test-key.pub",
      ]);
      p.on("close", resolve);
      p.on("error", reject);
    });
  } catch (e) {
    console.log("Warning: Could not create prerequisite files:", e.message);
  }

  const client = new McpTestClient();

  try {
    // ── Connect ──
    console.log("[1/3] Connecting to MCP server...");
    const serverInfo = await client.connect();
    console.log(`  Server: ${serverInfo.serverInfo.name} v${serverInfo.serverInfo.version}`);
    console.log(`  Protocol: ${serverInfo.protocolVersion}`);
    console.log("");

    // ── Discover tools ──
    console.log("[2/3] Discovering registered tools...");
    const tools = await client.listTools();
    console.log(`  Found ${tools.length} tools registered on server`);

    // Build a set of discovered tool names
    const toolNames = new Set(tools.map((t) => t.name));

    // Count unique tool names in our test plan
    const testToolNames = new Set();
    for (const m of modules) {
      for (const t of m.tools) {
        testToolNames.add(t.name);
      }
    }
    console.log(`  Test plan covers ${testToolNames.size} unique tools`);

    // Check for tools we're not testing
    const untested = [...toolNames].filter((n) => !testToolNames.has(n));
    if (untested.length > 0) {
      console.log(`  WARNING: ${untested.length} tools not in test plan: ${untested.join(", ")}`);
    }

    // Check for test entries that don't match a registered tool
    const unregistered = [...testToolNames].filter((n) => !toolNames.has(n));
    if (unregistered.length > 0) {
      console.log(`  WARNING: ${unregistered.length} test tools not registered: ${unregistered.join(", ")}`);
    }
    console.log("");

    // ── Run tests ──
    console.log("[3/3] Running tool tests...");
    console.log("");

    let toolTestCount = 0;

    for (const mod of modules) {
      console.log(`--- ${mod.module} ${"─".repeat(Math.max(0, 56 - mod.module.length))}`);

      for (const t of mod.tools) {
        const label = t.label ? `${t.name} (${t.label})` : t.name;
        const timeout = t.timeout ?? 30000;
        toolTestCount++;

        // Skip tools not registered on the server
        if (!toolNames.has(t.name)) {
          skip(label, "tool not registered");
          continue;
        }

        try {
          // Primary invocation
          const resp = await client.callTool(t.name, t.args ?? {}, timeout);

          // Validate schema
          const valid = validateToolResponse(resp, label);

          // Check expected status
          if (valid && t.expectStatus) {
            const allowed = Array.isArray(t.expectStatus) ? t.expectStatus : [t.expectStatus];
            assertIn(resp.status, allowed, `${label}: expected status`);
          } else if (valid && !t.expectStatus) {
            // Default: tools without explicit expectStatus should succeed
            assertEqual(resp.status, "success", `${label}: status is success`);
          }

          console.log(`  [${resp.status?.toUpperCase?.() ?? "???"}] ${label}`);

          // If this tool requires confirmation, also test the confirmed path
          if (t.confirmed) {
            const confLabel = `${t.name} (confirmed)`;
            try {
              const confResp = await client.callTool(t.name, t.confirmed, timeout);
              validateToolResponse(confResp, confLabel);

              if (t.confirmExpect) {
                const allowed = Array.isArray(t.confirmExpect) ? t.confirmExpect : [t.confirmExpect];
                assertIn(confResp.status, allowed, `${confLabel}: expected status`);
              }
              console.log(`  [${confResp.status?.toUpperCase?.() ?? "???"}] ${confLabel}`);
            } catch (err) {
              failed++;
              failures.push(`${confLabel}: ${err.message}`);
              console.log(`  [ERROR] ${confLabel}: ${err.message}`);
            }
          }
        } catch (err) {
          failed++;
          failures.push(`${label}: ${err.message}`);
          console.log(`  [ERROR] ${label}: ${err.message}`);
        }
      }

      console.log("");
    }

    // ── Summary ──
    console.log("=".repeat(72));
    console.log("  SUMMARY");
    console.log("=".repeat(72));
    console.log(`  Tools on server:    ${tools.length}`);
    console.log(`  Unique tools tested: ${testToolNames.size}`);
    console.log(`  Test invocations:    ${toolTestCount}`);
    console.log(`  Assertions passed:  ${passed}`);
    console.log(`  Assertions failed:  ${failed}`);
    console.log(`  Skipped:            ${skipped}`);
    console.log("");

    if (failures.length > 0) {
      console.log("  FAILURES:");
      for (const f of failures) {
        console.log(`    - ${f}`);
      }
      console.log("");
    }

    if (failed === 0) {
      console.log("  RESULT: ALL TESTS PASSED");
    } else {
      console.log(`  RESULT: ${failed} ASSERTION(S) FAILED`);
    }
    console.log("=".repeat(72));

  } finally {
    client.close();
  }

  process.exit(failed > 0 ? 1 : 0);
}

main().catch((err) => {
  console.error("Fatal error:", err);
  process.exit(2);
});
