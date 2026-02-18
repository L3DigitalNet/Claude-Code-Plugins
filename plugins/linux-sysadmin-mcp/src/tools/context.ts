import type { DistroContext } from "../types/distro.js";
import type { PluginConfig } from "../types/config.js";
import type { DistroCommands } from "../distro/commands/interface.js";
import type { Executor } from "../execution/executor.js";
import type { KnowledgeBase } from "../knowledge/loader.js";
import type { SafetyGate } from "../safety/gate.js";
import type { ToolRegistry } from "./registry.js";

/**
 * Shared plugin context — the glue between all components.
 * Created once at startup, passed to all tool modules.
 */
export interface PluginContext {
  readonly config: PluginConfig;
  readonly distro: DistroContext;
  readonly commands: DistroCommands;
  readonly executor: Executor;
  readonly safetyGate: SafetyGate;
  readonly knowledgeBase: KnowledgeBase;
  readonly registry: ToolRegistry;
  readonly targetHost: string;
  readonly sudoAvailable: boolean;
  readonly isRemote: boolean;
  readonly configPath: string;
  readonly firstRun: boolean;
}
