import { TestStore } from '../../../src/testing/store.js';
import type { PthTest } from '../../../src/testing/types.js';

const makeTest = (id: string, extra: Record<string, unknown> = {}): PthTest => ({
  id,
  name: `Test ${id}`,
  mode: 'mcp',
  type: 'single',
  tool: 'example',
  input: {},
  expect: { success: true },
  ...extra,
});

describe('TestStore upsert pattern (BUG-4)', () => {
  it('add() throws when ID already exists', () => {
    const store = new TestStore();
    store.add(makeTest('t1'));
    expect(() => store.add(makeTest('t1'))).toThrow('already exists');
  });

  it('update() silently overwrites an existing test', () => {
    const store = new TestStore();
    store.add(makeTest('t1'));
    store.update(makeTest('t1', { name: 'Updated' }));
    expect(store.get('t1')?.name).toBe('Updated');
  });

  it('upsert pattern does not throw on duplicate IDs', () => {
    const store = new TestStore();
    store.add(makeTest('existing', { input: { old: true } }));

    const generated = [makeTest('existing', { input: { new: true } }), makeTest('brand-new')];
    expect(() => {
      generated.forEach(t => store.get(t.id) ? store.update(t) : store.add(t));
    }).not.toThrow();

    expect(store.get('existing')?.input).toEqual({ new: true });
    expect(store.get('brand-new')).toBeDefined();
    expect(store.count()).toBe(2);
  });
});
