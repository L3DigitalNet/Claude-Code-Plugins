/**
 * ha_get_logs tool - Fetch and analyze Home Assistant logs
 */

import { HaClient } from "../ha-client.js";
import type { HaGetLogsInput, HaGetLogsOutput } from "../types.js";

export async function handleHaGetLogs(
  client: HaClient,
  input: HaGetLogsInput
): Promise<HaGetLogsOutput> {
  const entries = await client.getLogs({
    domain: input.domain,
    level: input.level,
    lines: input.lines,
    since: input.since,
  });

  // Calculate summary
  const summary = {
    errors: entries.filter((e) => e.level === "ERROR" || e.level === "CRITICAL")
      .length,
    warnings: entries.filter((e) => e.level === "WARNING").length,
  };

  return {
    entries,
    summary,
  };
}
