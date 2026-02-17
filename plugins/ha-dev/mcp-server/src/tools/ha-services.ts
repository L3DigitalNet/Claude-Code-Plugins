/**
 * ha_get_services tool - List available services
 */

import { HaClient } from "../ha-client.js";
import type { HaGetServicesInput, HaGetServicesOutput } from "../types.js";

export async function handleHaGetServices(
  client: HaClient,
  input: HaGetServicesInput
): Promise<HaGetServicesOutput> {
  const services = await client.getServices(input.domain);

  return {
    services,
  };
}
