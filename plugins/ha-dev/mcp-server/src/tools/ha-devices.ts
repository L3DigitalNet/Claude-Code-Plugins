/**
 * ha_get_devices tool - Query device registry
 */

import { HaClient } from "../ha-client.js";
import type { HaGetDevicesInput, HaGetDevicesOutput } from "../types.js";

export async function handleHaGetDevices(
  client: HaClient,
  input: HaGetDevicesInput
): Promise<HaGetDevicesOutput> {
  const devices = await client.getDevices({
    manufacturer: input.manufacturer,
    model: input.model,
    integration: input.integration,
  });

  return {
    devices,
  };
}
