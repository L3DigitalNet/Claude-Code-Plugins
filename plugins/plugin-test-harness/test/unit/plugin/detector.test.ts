import path from 'path';
import { fileURLToPath } from 'url';
import { detectPluginMode, detectBuildSystem } from '../../../src/plugin/detector.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const FIXTURES = path.join(__dirname, '../../fixtures');

describe('detectPluginMode', () => {
  it('returns mcp for a plugin with .mcp.json', async () => {
    const mode = await detectPluginMode(path.join(FIXTURES, 'sample-mcp-plugin'));
    expect(mode).toBe('mcp');
  });

  it('returns plugin for a plugin with .claude-plugin/ but no .mcp.json', async () => {
    const mode = await detectPluginMode(path.join(FIXTURES, 'sample-hook-plugin'));
    expect(mode).toBe('plugin');
  });

  it('throws if path is not a valid plugin', async () => {
    await expect(detectPluginMode('/tmp/not-a-plugin-at-all')).rejects.toThrow();
  });
});

describe('detectBuildSystem', () => {
  it('detects npm from package.json with build script', async () => {
    const build = await detectBuildSystem(path.join(FIXTURES, 'sample-mcp-plugin'));
    expect(build.installCommand).toContain('npm');
    expect(build.buildCommand).toContain('build');
  });

  it('returns null buildCommand when no build script exists', async () => {
    // sample-hook-plugin has no package.json
    const build = await detectBuildSystem(path.join(FIXTURES, 'sample-hook-plugin'));
    expect(build.buildCommand).toBeNull();
  });
});
