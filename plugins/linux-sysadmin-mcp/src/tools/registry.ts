import type { RegisteredTool } from "../types/tool.js";
import { logger } from "../logger.js";

/**
 * Tool Registry — stores all registered tools.
 * The MCP server reads from this to populate tools/list and dispatch tools/call.
 */
export class ToolRegistry {
  private readonly tools = new Map<string, RegisteredTool>();

  register(tool: RegisteredTool): void {
    if (this.tools.has(tool.metadata.name)) {
      logger.warn({ tool: tool.metadata.name }, "Duplicate tool registration — overwriting");
    }
    this.tools.set(tool.metadata.name, tool);
  }

  get(name: string): RegisteredTool | undefined {
    return this.tools.get(name);
  }

  getAll(): Map<string, RegisteredTool> {
    return this.tools;
  }

  get size(): number {
    return this.tools.size;
  }
}
