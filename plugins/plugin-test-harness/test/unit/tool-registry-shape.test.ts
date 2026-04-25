// tool-registry-shape.test.ts — [P6] Composable, Focused Units.
// Each registered tool must be independently invocable: unique name, single
// description, single input schema, single handler.

import { ToolRegistry } from '../../src/tool-registry.js';

describe('ToolRegistry shape contract [P6]', () => {
  let registry: ToolRegistry;

  beforeEach(() => {
    registry = new ToolRegistry();
  });

  it('every tool has a non-empty name (TR-shape-name)', () => {
    const tools = registry.getAllTools();
    for (const tool of tools) {
      expect(tool.name).toBeTruthy();
      expect(typeof tool.name).toBe('string');
    }
  });

  it('every tool has a non-empty description (TR-shape-desc)', () => {
    const tools = registry.getAllTools();
    for (const tool of tools) {
      expect(tool.description).toBeTruthy();
      expect(typeof tool.description).toBe('string');
    }
  });

  it('every tool has an inputSchema object (TR-shape-schema)', () => {
    const tools = registry.getAllTools();
    for (const tool of tools) {
      expect(tool.inputSchema).toBeDefined();
      expect(typeof tool.inputSchema).toBe('object');
    }
  });

  it('no two tools share the same name (TR-shape-unique)', () => {
    const names = registry.getAllTools().map(t => t.name);
    const unique = new Set(names);
    expect(unique.size).toBe(names.length);
  });

  it('every tool name has the pth_ prefix (TR-shape-prefix)', () => {
    const tools = registry.getAllTools();
    for (const tool of tools) {
      expect(tool.name).toMatch(/^pth_/);
    }
  });
});
