import pino from "pino";

// MCP stdio protocol owns stdout exclusively for JSON-RPC messages.
// Any stdout output (even valid JSON like pino's NDJSON) breaks clients
// that parse every stdout line as a protocol message. Always use stderr.
export const logger = pino(
  { name: "linux-sysadmin", level: process.env.LOG_LEVEL ?? "info" },
  process.stderr
);
