// gap-analyzer.test.ts — Cross-cutting Mechanical: 4-axis diff between snapshot and scan.
// Plugin mode: precise name comparison.

import { analyzeGap } from '../../../src/persistence/gap-analyzer.js';
import type { PluginSnapshot } from '../../../src/persistence/types.js';
import type { CurrentScan } from '../../../src/persistence/plugin-scanner.js';
import type { PthTest } from '../../../src/testing/types.js';

const baseSnapshot: PluginSnapshot = {
  pluginMode: 'plugin',
  capturedAt: '2026-01-01T00:00:00Z',
  version: '1.0.0',
  tools: [],
  commands: ['cmd1', 'cmd2'],
  skills: ['skill1'],
  agents: ['agent1'],
};

const makeScan = (overrides: Partial<CurrentScan> = {}): CurrentScan => ({
  pluginMode: 'plugin',
  version: '1.0.0',
  toolNames: [],
  commands: ['cmd1', 'cmd2'],
  skills: ['skill1'],
  agents: ['agent1'],
  changedSourceFiles: [],
  scannedAt: '2026-01-01T00:00:00Z',
  ...overrides,
});

describe('analyzeGap (plugin mode)', () => {
  it('identical snapshot + scan → all components unchanged, no gaps (GA-identical)', () => {
    const result = analyzeGap(baseSnapshot, makeScan(), []);
    expect(result.newComponents).toHaveLength(0);
    expect(result.removedComponents).toHaveLength(0);
    expect(result.modifiedComponents).toHaveLength(0);
    expect(result.unchangedComponents.length).toBeGreaterThan(0);
    expect(result.staleTestIds).toHaveLength(0);
  });

  it('new command in scan but absent from snapshot → newComponents (GA-added)', () => {
    const result = analyzeGap(
      baseSnapshot,
      makeScan({ commands: ['cmd1', 'cmd2', 'cmd-new'] }),
      []
    );
    expect(result.newComponents).toContain('command:cmd-new');
    expect(result.removedComponents).toHaveLength(0);
  });

  it('command removed from scan but present in snapshot → removedComponents (GA-removed)', () => {
    const result = analyzeGap(
      baseSnapshot,
      makeScan({ commands: ['cmd1'] }),  // cmd2 removed
      []
    );
    expect(result.removedComponents).toContain('command:cmd2');
    expect(result.newComponents).toHaveLength(0);
  });

  it('test pointing at removed component surfaces as staleTestIds (GA-stale)', () => {
    const savedTests: PthTest[] = [{
      id: 'cmd2-old-test',
      name: 'cmd2 — old test',
      mode: 'plugin',
      type: 'validate',
      tool: 'cmd2',
      checks: [],
      expect: {},
    } as unknown as PthTest];
    const result = analyzeGap(
      baseSnapshot,
      makeScan({ commands: ['cmd1'] }),
      savedTests
    );
    expect(result.staleTestIds).toContain('cmd2-old-test');
  });

  it('skill name change in scan tracked (GA-skill-track)', () => {
    const result = analyzeGap(
      baseSnapshot,
      makeScan({ skills: ['skill1', 'skill-fresh'] }),
      []
    );
    expect(result.newComponents).toContain('skill:skill-fresh');
    expect(result.removedComponents).toHaveLength(0);
  });
});
