/**
 * ha_get_states tool - Query entity states
 */

import { HaClient } from "../ha-client.js";
import type { HaGetStatesInput, HaGetStatesOutput } from "../types.js";

export async function handleHaGetStates(
  client: HaClient,
  input: HaGetStatesInput
): Promise<HaGetStatesOutput> {
  const states = await client.getStates({
    domain: input.domain,
    entityId: input.entity_id,
    area: input.area,
  });

  return {
    entities: states,
    count: states.length,
  };
}
