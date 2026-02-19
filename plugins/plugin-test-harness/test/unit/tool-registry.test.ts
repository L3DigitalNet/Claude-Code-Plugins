import { ToolRegistry } from '../../src/tool-registry.js';

describe('ToolRegistry', () => {
  it('starts in dormant state with 3 tools', () => {
    const registry = new ToolRegistry();
    const tools = registry.getActiveTools();
    expect(tools).toHaveLength(3);
    expect(tools.map(t => t.name)).toContain('pth_start_session');
    expect(tools.map(t => t.name)).toContain('pth_resume_session');
    expect(tools.map(t => t.name)).toContain('pth_preflight');
  });

  it('returns all tools after activation', () => {
    const registry = new ToolRegistry();
    registry.activate();
    const tools = registry.getActiveTools();
    expect(tools.length).toBeGreaterThan(3);
    expect(tools.map(t => t.name)).toContain('pth_end_session');
    expect(tools.map(t => t.name)).toContain('pth_generate_tests');
  });

  it('returns only dormant tools after deactivation', () => {
    const registry = new ToolRegistry();
    registry.activate();
    registry.deactivate();
    expect(registry.getActiveTools()).toHaveLength(3);
  });
});
