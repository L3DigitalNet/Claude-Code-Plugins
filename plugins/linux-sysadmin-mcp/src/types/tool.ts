import type { z } from "zod";
import type { RiskLevel, DurationCategory } from "./risk.js";

/** Metadata declared by every tool at registration time. */
export interface ToolMetadata {
  readonly name: string;
  readonly description: string;
  readonly module: string;
  readonly riskLevel: RiskLevel;
  readonly duration: DurationCategory;
  readonly inputSchema: z.ZodType;
  readonly annotations?: {
    readOnlyHint?: boolean;
    destructiveHint?: boolean;
    idempotentHint?: boolean;
    openWorldHint?: boolean;
  };
}

/** A registered tool with its execute function. */
export interface RegisteredTool {
  readonly metadata: ToolMetadata;
  readonly execute: (args: Record<string, unknown>, context: ExecutionContext) => Promise<import("./response.js").ToolResponse>;
}

/** Context passed to tool execute functions. */
export interface ExecutionContext {
  readonly targetHost: string;
  readonly isRemote: boolean;
}
