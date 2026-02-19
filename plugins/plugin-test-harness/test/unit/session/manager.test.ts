import path from 'path';
import { fileURLToPath } from 'url';
import { preflight } from '../../../src/session/manager.js';

const __dirname = fileURLToPath(new URL('.', import.meta.url));

describe('preflight', () => {
  it('returns ok message for a valid plugin directory', async () => {
    const fixturePath = path.join(__dirname, '../../fixtures/sample-mcp-plugin');
    const result = await preflight({ pluginPath: fixturePath });
    expect(result).toContain('OK');
  });

  it('returns error message for non-existent path', async () => {
    const result = await preflight({ pluginPath: '/tmp/does-not-exist-pth' });
    expect(result).toContain('not found');
  });
});
