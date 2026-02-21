import { ToolRegistry } from '../../src/tool-registry.js';

// ToolRegistry exposes all tools at all times — Claude Code caches the tool list
// at session start, making dynamic activation via list_changed unreliable.
// Session-gating is enforced at dispatch time in server.ts, not here.
describe('ToolRegistry', () => {
  it('getAllTools returns all dormant and session tools', () => {
    const registry = new ToolRegistry();
    const tools = registry.getAllTools();
    // 3 dormant + 16 session = 19 total
    expect(tools).toHaveLength(19);
  });

  it('getAllTools always includes dormant tools', () => {
    const registry = new ToolRegistry();
    const names = registry.getAllTools().map(t => t.name);
    expect(names).toContain('pth_start_session');
    expect(names).toContain('pth_resume_session');
    expect(names).toContain('pth_preflight');
  });

  it('getAllTools always includes session tools', () => {
    const registry = new ToolRegistry();
    const names = registry.getAllTools().map(t => t.name);
    expect(names).toContain('pth_end_session');
    expect(names).toContain('pth_generate_tests');
    expect(names).toContain('pth_apply_fix');
    expect(names).toContain('pth_get_iteration_status');
  });

  it('isActive always returns true', () => {
    const registry = new ToolRegistry();
    expect(registry.isActive()).toBe(true);
    registry.deactivate();
    expect(registry.isActive()).toBe(true);
    registry.activate();
    expect(registry.isActive()).toBe(true);
  });
});
