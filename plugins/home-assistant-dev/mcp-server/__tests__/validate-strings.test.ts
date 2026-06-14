/**
 * Tests for handleValidateStrings
 *
 * Mirrors validate-manifest.test.ts: exercises the valid path, the missing-file and
 * invalid-JSON failure paths, and config_flow.py/strings.json drift (missing step
 * translations, missing data_description). Added so validate-strings.ts is guarded by
 * the jest coverage threshold instead of excluded (F167).
 */

import { handleValidateStrings } from '../src/tools/validate-strings.js';
import { mkdir, writeFile, rm } from 'fs/promises';
import { tmpdir } from 'os';
import { join } from 'path';

describe('handleValidateStrings', () => {
  let tempDir: string;

  beforeEach(async () => {
    tempDir = join(tmpdir(), `ha-strings-test-${Date.now()}-${Math.random().toString(36).slice(2)}`);
    await mkdir(tempDir, { recursive: true });
  });

  afterEach(async () => {
    await rm(tempDir, { recursive: true, force: true });
  });

  /**
   * Write strings.json (optionally a sibling config_flow.py) into tempDir.
   * `strings` may be a value to JSON-encode or a raw string (to test malformed JSON).
   * Returns the full path to strings.json.
   */
  async function writeStrings(strings: unknown, configFlowPy?: string): Promise<string> {
    const stringsPath = join(tempDir, 'strings.json');
    await writeFile(
      stringsPath,
      typeof strings === 'string' ? strings : JSON.stringify(strings, null, 2)
    );
    if (configFlowPy !== undefined) {
      await writeFile(join(tempDir, 'config_flow.py'), configFlowPy);
    }
    return stringsPath;
  }

  it('should validate strings.json whose steps/errors/aborts match config_flow.py', async () => {
    const strings = {
      config: {
        step: { user: { title: 'Connect', description: 'Enter connection details' } },
        error: { cannot_connect: 'Failed to connect' },
        abort: { already_configured: 'Already configured' },
      },
    };
    const configFlow = [
      'class MyFlow:',
      '    async def async_step_user(self, user_input=None):',
      '        errors["base"] = "cannot_connect"',
      '        return self.async_abort(reason="already_configured")',
    ].join('\n');
    const path = await writeStrings(strings, configFlow);

    const result = await handleValidateStrings({ path });

    expect(result.valid).toBe(true);
    expect(result.missing_steps).toHaveLength(0);
    expect(result.missing_errors).toHaveLength(0);
    expect(result.missing_data_descriptions).toHaveLength(0);
  });

  it('should return invalid when strings.json does not exist', async () => {
    const result = await handleValidateStrings({ path: join(tempDir, 'missing.json') });

    expect(result.valid).toBe(false);
    expect((result.errors ?? []).some((e) => e.includes('not found'))).toBe(true);
  });

  it('should return invalid for malformed JSON', async () => {
    const path = await writeStrings('{ "config": { not valid json ');

    const result = await handleValidateStrings({ path });

    expect(result.valid).toBe(false);
    expect((result.errors ?? []).some((e) => e.includes('Invalid JSON'))).toBe(true);
  });

  it('should report a step used in config_flow.py but missing from strings.json', async () => {
    const strings = { config: { step: {} } };
    const configFlow = [
      'class MyFlow:',
      '    async def async_step_user(self, user_input=None):',
      '        return self.async_show_form(step_id="user")',
    ].join('\n');
    const path = await writeStrings(strings, configFlow);

    const result = await handleValidateStrings({ path });

    expect(result.valid).toBe(false);
    expect(result.missing_steps).toContain('user');
  });

  it('should flag a data field that has no data_description (IQS Bronze)', async () => {
    const strings = {
      config: {
        step: { user: { title: 'Connect', data: { host: 'Host' } } },
      },
    };
    const path = await writeStrings(strings);

    const result = await handleValidateStrings({ path });

    expect(result.missing_data_descriptions).toContain('user');
    expect(result.valid).toBe(false);
  });
});
