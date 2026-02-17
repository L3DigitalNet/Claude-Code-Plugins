/**
 * ha_connect tool - Connect to Home Assistant
 */

import { HaClient } from "../ha-client.js";
import type { HaConnectInput, HaConnectOutput, ServerConfig } from "../types.js";

export async function handleHaConnect(
  input: HaConnectInput,
  config: ServerConfig
): Promise<HaClient> {
  const client = new HaClient(config);

  const url = input.url || config.homeAssistant.url;
  const token = input.token || config.homeAssistant.token;

  if (!url) {
    throw new Error("Home Assistant URL is required");
  }

  if (!token) {
    throw new Error("Home Assistant token is required");
  }

  await client.connect(url, token);

  return client;
}
