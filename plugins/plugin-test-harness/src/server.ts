import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import {
  ListToolsRequestSchema,
  CallToolRequestSchema,
} from '@modelcontextprotocol/sdk/types.js';
import { zodToJsonSchema } from 'zod-to-json-schema';
import { ToolRegistry } from './tool-registry.js';
import type { SessionState } from './session/types.js';

export function createServer(): Server {
  const registry = new ToolRegistry();

  // Session state scoped to this server instance (fix #1: no module-level state)
  let currentSession: SessionState | null = null;

  // Lazily imported to avoid circular deps
  let sessionManager: typeof import('./session/manager.js') | null = null;

  const server = new Server(
    { name: 'plugin-test-harness', version: '1.0.0' },
    { capabilities: { tools: {} } }
  );

  // Dynamic tool list
  server.setRequestHandler(ListToolsRequestSchema, async () => ({
    tools: registry.getActiveTools().map(t => ({
      name: t.name,
      description: t.description,
      inputSchema: zodToJsonSchema(t.inputSchema),
    })),
  }));

  // Tool dispatch
  server.setRequestHandler(CallToolRequestSchema, async (request) => {
    const { name, arguments: args } = request.params;
    return dispatch(name, args ?? {});
  });

  return server;

  async function dispatch(
    toolName: string,
    args: Record<string, unknown>
  ): Promise<{ content: Array<{ type: 'text'; text: string }> }> {
    // Lazy import session manager
    if (!sessionManager) {
      sessionManager = await import('./session/manager.js');
    }

    const respond = (text: string) => ({ content: [{ type: 'text' as const, text }] });

    switch (toolName) {
      case 'pth_preflight': {
        const result = await sessionManager.preflight(args as { pluginPath: string });
        return respond(result);
      }
      case 'pth_start_session': {
        const result = await sessionManager.startSession(
          args as { pluginPath: string; sessionNote?: string }
        );
        currentSession = result.state;
        registry.activate();
        try { await server.notification({ method: 'notifications/tools/list_changed' }); } catch { /* best-effort */ }
        return respond(result.message);
      }
      case 'pth_resume_session': {
        const result = await sessionManager.resumeSession(
          args as { branch: string; pluginPath: string }
        );
        currentSession = result.state;
        registry.activate();
        try { await server.notification({ method: 'notifications/tools/list_changed' }); } catch { /* best-effort */ }
        return respond(result.message);
      }
      case 'pth_end_session': {
        if (!currentSession) return respond('No active session.');
        const result = await sessionManager.endSession(currentSession);
        currentSession = null;
        registry.deactivate();
        try { await server.notification({ method: 'notifications/tools/list_changed' }); } catch { /* best-effort */ }
        return respond(result);
      }
      default: {
        // fix #3: guard on currentSession (not registry.isActive()) — eliminates ! assertion
        if (!currentSession) {
          return respond(`No PTH session active. Call pth_start_session first.`);
        }
        // Delegate to session handlers — implemented in Task 12
        return handleSessionTool(toolName, args, currentSession);
      }
    }
  }
}

// Session tool dispatch — implemented in Task 12
async function handleSessionTool(
  toolName: string,
  _args: Record<string, unknown>,
  _session: SessionState
): Promise<{ content: Array<{ type: 'text'; text: string }> }> {
  const respond = (text: string) => ({ content: [{ type: 'text' as const, text }] });
  return respond(`Tool ${toolName} not yet implemented.`);
}
