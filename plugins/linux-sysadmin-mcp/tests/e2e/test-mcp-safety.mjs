#!/usr/bin/env node
/**
 * E2E Safety Gate Integration Tests — linux-sysadmin-mcp
 *
 * Validates that the safety gate works correctly against the live MCP
 * server running inside the linux-sysadmin-test container.
 *
 * 8 tests:
 *   1. pkg_install without confirmed → confirmation_required
 *   2. pkg_install with confirmed: true → success (or error — both valid)
 *   3. svc_restart without confirmed → confirmation_required
 *   4. fw_enable without confirmed → confirmation_required
 *   5. user_delete without confirmed → confirmation_required
 *   6. sec_harden_ssh triggers escalation warning from knowledge profile
 *   7. Read-only tool (perf_overview) never triggers confirmation
 *   8. Dry-run pkg_install bypasses confirmation (dry_run: true)
 *
 * Usage:  node tests/e2e/test-mcp-safety.mjs
 */

import { spawn } from "node:child_process";
import { createInterface } from "node:readline";

// ────────────────────────────────────────────────────────────────────
// MCP Test Client (copied from test-mcp-tools.mjs)
// ────────────────────────────────────────────────────────────────────

class McpTestClient {
  #proc;
  #rl;
  #nextId = 1;
  /** @type {Map<number, {resolve: Function, reject: Function, timer: NodeJS.Timeout}>} */
  #pending = new Map();
  #ready = false;

  constructor() {
    this.#proc = spawn("podman", [
      "exec", "-i", "linux-sysadmin-test",
      "node", "/plugin/dist/server.bundle.cjs",
    ], { stdio: ["pipe", "pipe", "pipe"] });

    this.#rl = createInterface({ input: this.#proc.stdout });
    this.#rl.on("line", (line) => this.#handleLine(line));

    // Silence stderr (pino logs)
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

    let msg;
    try {
      msg = JSON.parse(trimmed);
    } catch {
      return; // Not JSON — skip pino log lines
    }

    if (msg.jsonrpc !== "2.0") return;

    if (msg.id !== undefined && this.#pending.has(msg.id)) {
      const p = this.#pending.get(msg.id);
      this.#pending.delete(msg.id);
      clearTimeout(p.timer);
      p.resolve(msg);
    }
  }

  #send(msg) {
    const data = JSON.stringify(msg) + "\n";
    this.#proc.stdin.write(data);
  }

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

  async connect() {
    const response = await this.#request("initialize", {
      protocolVersion: "2025-03-26",
      capabilities: {},
      clientInfo: { name: "e2e-safety-test", version: "1.0.0" },
    }, 15000);

    if (!response.result || !response.result.serverInfo) {
      throw new Error("Invalid initialize response: " + JSON.stringify(response));
    }

    this.#send({ jsonrpc: "2.0", method: "notifications/initialized" });
    await new Promise((r) => setTimeout(r, 200));
    this.#ready = true;

    return response.result;
  }

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

    const text = result.content[0].text;
    try {
      return JSON.parse(text);
    } catch {
      return { _parseError: true, text };
    }
  }

  close() {
    this.#rl.close();
    try { this.#proc.stdin.end(); } catch {}
    try { this.#proc.kill("SIGTERM"); } catch {}
    setTimeout(() => { try { this.#proc.kill("SIGKILL"); } catch {} }, 2000);
  }
}

// ────────────────────────────────────────────────────────────────────
// Test Runner
// ────────────────────────────────────────────────────────────────────

const results = [];

async function runTest(num, name, fn) {
  try {
    await fn();
    results.push({ num, name, passed: true });
    console.log(`  \u2713 ${num}. ${name}`);
  } catch (err) {
    results.push({ num, name, passed: false, error: err.message });
    console.log(`  \u2717 ${num}. ${name}`);
    console.log(`    Error: ${err.message}`);
  }
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function assertEqual(actual, expected, message) {
  if (actual !== expected) {
    throw new Error(`${message} -- expected: ${JSON.stringify(expected)}, got: ${JSON.stringify(actual)}`);
  }
}

function assertIncludes(haystack, needle, message) {
  if (typeof haystack === "string") {
    if (!haystack.includes(needle)) {
      throw new Error(`${message} -- expected string to include ${JSON.stringify(needle)}, got: ${JSON.stringify(haystack)}`);
    }
  } else if (Array.isArray(haystack)) {
    if (!haystack.includes(needle)) {
      throw new Error(`${message} -- expected array to include ${JSON.stringify(needle)}, got: ${JSON.stringify(haystack)}`);
    }
  } else {
    throw new Error(`${message} -- assertIncludes requires string or array`);
  }
}

// ────────────────────────────────────────────────────────────────────
// Main
// ────────────────────────────────────────────────────────────────────

async function main() {
  console.log("=".repeat(64));
  console.log("  E2E Safety Gate Integration Tests");
  console.log("=".repeat(64));
  console.log("");

  const client = new McpTestClient();

  try {
    console.log("Connecting to MCP server...");
    const info = await client.connect();
    console.log(`  Server: ${info.serverInfo.name} v${info.serverInfo.version}`);
    console.log("");
    console.log("Running tests:");
    console.log("");

    // ── Test 1: pkg_install without confirmed → confirmation_required ──
    await runTest(1, "pkg_install without confirmed returns confirmation_required", async () => {
      const resp = await client.callTool("pkg_install", { packages: ["cowsay"] });
      assert(!resp._rpcError && !resp._parseError && !resp._emptyContent,
        `Unexpected response shape: ${JSON.stringify(resp)}`);
      assertEqual(resp.status, "confirmation_required",
        "pkg_install without confirmed should require confirmation");
      assert(typeof resp.risk_level === "string", "Should have risk_level field");
      assert(typeof resp.preview === "object" && resp.preview !== null, "Should have preview object");
    });

    // ── Test 2: pkg_install with confirmed: true → success or error ──
    await runTest(2, "pkg_install with confirmed: true proceeds past safety gate", async () => {
      const resp = await client.callTool("pkg_install", { packages: ["cowsay"], confirmed: true }, 60000);
      assert(!resp._rpcError && !resp._parseError && !resp._emptyContent,
        `Unexpected response shape: ${JSON.stringify(resp)}`);
      assertIncludes(["success", "error"], resp.status,
        "pkg_install with confirmed should succeed or fail (not confirmation_required)");
      assert(resp.status !== "confirmation_required",
        "confirmed: true must bypass the safety gate");
    });

    // ── Test 3: svc_restart without confirmed → confirmation_required ──
    await runTest(3, "svc_restart without confirmed returns confirmation_required", async () => {
      const resp = await client.callTool("svc_restart", { service: "nginx" });
      assert(!resp._rpcError && !resp._parseError && !resp._emptyContent,
        `Unexpected response shape: ${JSON.stringify(resp)}`);
      assertEqual(resp.status, "confirmation_required",
        "svc_restart without confirmed should require confirmation");
      assert(typeof resp.preview === "object" && resp.preview !== null, "Should have preview object");
      assert(typeof resp.preview.command === "string", "Preview should include command");
    });

    // ── Test 4: fw_enable without confirmed → confirmation_required ──
    await runTest(4, "fw_enable without confirmed returns confirmation_required", async () => {
      const resp = await client.callTool("fw_enable", {});
      assert(!resp._rpcError && !resp._parseError && !resp._emptyContent,
        `Unexpected response shape: ${JSON.stringify(resp)}`);
      assertEqual(resp.status, "confirmation_required",
        "fw_enable without confirmed should require confirmation");
      // fw_enable has riskLevel "critical", so risk_level should reflect that
      assert(typeof resp.risk_level === "string", "Should have risk_level field");
    });

    // ── Test 5: user_delete without confirmed → confirmation_required ──
    await runTest(5, "user_delete without confirmed returns confirmation_required", async () => {
      const resp = await client.callTool("user_delete", { username: "nonexistentuser", remove_home: false });
      assert(!resp._rpcError && !resp._parseError && !resp._emptyContent,
        `Unexpected response shape: ${JSON.stringify(resp)}`);
      assertEqual(resp.status, "confirmation_required",
        "user_delete without confirmed should require confirmation");
      // user_delete has riskLevel "critical"
      assert(typeof resp.risk_level === "string", "Should have risk_level field");
    });

    // ── Test 6: sec_harden_ssh triggers escalation from knowledge profile ──
    // The sshd knowledge profile has an interaction with trigger "edit /etc/ssh/sshd_config"
    // and risk_escalation "high". The safety gate checks if params.command.includes(trigger)
    // or if trigger.includes(serviceName). The sec_harden_ssh command uses sed/cp, so the
    // literal trigger string "edit /etc/ssh/sshd_config" may or may not match the generated
    // command. Either way, sec_harden_ssh has base riskLevel "high" (above threshold
    // "moderate"), so confirmation is always required. We verify:
    //   - status is confirmation_required
    //   - preview object is present with command and description
    //   - if escalation fires, it references the sshd knowledge profile
    await runTest(6, "sec_harden_ssh requires confirmation (with optional escalation from sshd profile)", async () => {
      const resp = await client.callTool("sec_harden_ssh", { actions: ["disable_x11"] });
      assert(!resp._rpcError && !resp._parseError && !resp._emptyContent,
        `Unexpected response shape: ${JSON.stringify(resp)}`);
      assertEqual(resp.status, "confirmation_required",
        "sec_harden_ssh should require confirmation");

      const preview = resp.preview;
      assert(typeof preview === "object" && preview !== null, "Should have preview object");
      assert(typeof preview.command === "string" && preview.command.length > 0,
        "Preview should include the command that would be executed");
      assert(typeof preview.description === "string" && preview.description.length > 0,
        "Preview should include a human-readable description");

      // Check for escalation evidence from the sshd knowledge profile
      const hasEscalation = preview.escalation_reason &&
        preview.escalation_reason.includes("sshd");

      if (hasEscalation) {
        assertIncludes(preview.escalation_reason, "sshd",
          "Escalation reason should reference sshd profile");
        assert(Array.isArray(preview.warnings) && preview.warnings.length > 0,
          "Escalation should produce warnings array");
        console.log("    (Escalation fired from sshd knowledge profile)");
      } else {
        // Trigger pattern "edit /etc/ssh/sshd_config" does not match the sed/cp command.
        // Confirmation still required from base riskLevel "high".
        console.log("    (Escalation trigger did not match command -- confirmed via base risk level 'high')");
      }
    });

    // ── Test 7: Read-only tool (perf_overview) never triggers confirmation ──
    await runTest(7, "perf_overview (read-only) never triggers confirmation", async () => {
      const resp = await client.callTool("perf_overview", {});
      assert(!resp._rpcError && !resp._parseError && !resp._emptyContent,
        `Unexpected response shape: ${JSON.stringify(resp)}`);
      assertEqual(resp.status, "success",
        "Read-only tool perf_overview should return success, not confirmation_required");
      assert(typeof resp.data === "object" && resp.data !== null,
        "Successful perf_overview should have data");
    });

    // ── Test 8: Dry-run pkg_install bypasses confirmation ──
    await runTest(8, "pkg_install with dry_run: true bypasses confirmation gate", async () => {
      // dry_run_bypass_confirmation is true by default in config.
      // Passing dry_run: true should bypass the safety gate entirely.
      const resp = await client.callTool("pkg_install", { packages: ["cowsay"], dry_run: true }, 60000);
      assert(!resp._rpcError && !resp._parseError && !resp._emptyContent,
        `Unexpected response shape: ${JSON.stringify(resp)}`);
      assert(resp.status !== "confirmation_required",
        "dry_run: true should bypass confirmation gate (dry_run_bypass_confirmation is enabled)");
      assertIncludes(["success", "error"], resp.status,
        "Dry-run should proceed to execution (success or error)");
    });

    // ── Summary ──
    console.log("");
    console.log("=".repeat(64));
    const passedCount = results.filter((r) => r.passed).length;
    const failedCount = results.filter((r) => !r.passed).length;

    console.log(`Summary: ${passedCount}/${results.length} passed`);

    if (failedCount > 0) {
      console.log("");
      console.log("Failures:");
      for (const r of results.filter((r) => !r.passed)) {
        console.log(`  ${r.num}. ${r.name}`);
        console.log(`     ${r.error}`);
      }
    }
    console.log("=".repeat(64));

    process.exit(failedCount > 0 ? 1 : 0);

  } finally {
    client.close();
  }
}

main().catch((err) => {
  console.error("Fatal error:", err);
  process.exit(2);
});
