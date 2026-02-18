/**
 * Tests for handleValidateManifest
 */

import { handleValidateManifest } from '../src/tools/validate-manifest.js';
import { mkdir, writeFile, rm } from 'fs/promises';
import { tmpdir } from 'os';
import { join } from 'path';

describe('handleValidateManifest', () => {
  let tempDir: string;

  beforeEach(async () => {
    tempDir = join(tmpdir(), `ha-manifest-test-${Date.now()}-${Math.random().toString(36).slice(2)}`);
    await mkdir(tempDir, { recursive: true });
  });

  afterEach(async () => {
    await rm(tempDir, { recursive: true, force: true });
  });

  /**
   * Helper to write a manifest file into a directory named after the domain.
   * Returns the full path to the manifest.json file.
   */
  async function writeManifest(
    manifest: Record<string, unknown>,
    dirName?: string
  ): Promise<string> {
    const domain = (dirName ?? manifest.domain ?? 'test_integration') as string;
    const dir = join(tempDir, domain);
    await mkdir(dir, { recursive: true });
    const filePath = join(dir, 'manifest.json');
    await writeFile(filePath, JSON.stringify(manifest, null, 2));
    return filePath;
  }

  /** A complete HACS-valid manifest with all required fields. */
  function fullHacsManifest(overrides?: Record<string, unknown>): Record<string, unknown> {
    return {
      domain: 'my_integration',
      name: 'My Integration',
      codeowners: ['@my-github'],
      documentation: 'https://github.com/my-org/my_integration',
      integration_type: 'hub',
      iot_class: 'local_polling',
      version: '1.0.0',
      issue_tracker: 'https://github.com/my-org/my_integration/issues',
      config_flow: true,
      ...overrides,
    };
  }

  /** A complete core-valid manifest. */
  function fullCoreManifest(overrides?: Record<string, unknown>): Record<string, unknown> {
    return {
      domain: 'my_integration',
      name: 'My Integration',
      codeowners: ['@my-github'],
      documentation: 'https://github.com/my-org/my_integration',
      integration_type: 'hub',
      iot_class: 'local_polling',
      config_flow: true,
      ...overrides,
    };
  }

  it('should validate a correct HACS manifest', async () => {
    const manifest = fullHacsManifest();
    const filePath = await writeManifest(manifest, 'my_integration');

    const result = await handleValidateManifest({ path: filePath });

    expect(result.valid).toBe(true);
    expect(result.errors).toHaveLength(0);
  });

  it('should validate a correct core manifest', async () => {
    const manifest = fullCoreManifest();
    const filePath = await writeManifest(manifest, 'my_integration');

    const result = await handleValidateManifest({ path: filePath, mode: 'core' });

    expect(result.valid).toBe(true);
    expect(result.errors).toHaveLength(0);
  });

  it('should report missing required HACS fields', async () => {
    const manifest = {
      domain: 'my_integration',
      name: 'My Integration',
      config_flow: true,
    };
    const filePath = await writeManifest(manifest, 'my_integration');

    const result = await handleValidateManifest({ path: filePath });

    expect(result.valid).toBe(false);
    expect(result.errors.length).toBeGreaterThan(0);

    const missingFields = result.errors.map((e) => e.field);
    expect(missingFields).toContain('version');
    expect(missingFields).toContain('issue_tracker');
    expect(missingFields).toContain('codeowners');
    expect(missingFields).toContain('documentation');
    expect(missingFields).toContain('integration_type');
    expect(missingFields).toContain('iot_class');
  });

  it('should report missing file', async () => {
    const nonexistentPath = join(tempDir, 'does_not_exist', 'manifest.json');

    const result = await handleValidateManifest({ path: nonexistentPath });

    expect(result.valid).toBe(false);
    expect(result.errors).toHaveLength(1);
    expect(result.errors[0].field).toBe('file');
    expect(result.errors[0].message).toContain('not found');
  });

  it('should report invalid JSON', async () => {
    const dir = join(tempDir, 'bad_json');
    await mkdir(dir, { recursive: true });
    const filePath = join(dir, 'manifest.json');
    await writeFile(filePath, '{ invalid json: }}}');

    const result = await handleValidateManifest({ path: filePath });

    expect(result.valid).toBe(false);
    expect(result.errors).toHaveLength(1);
    expect(result.errors[0].field).toBe('json');
    expect(result.errors[0].message).toContain('Invalid JSON');
  });

  it('should reject invalid domain format', async () => {
    const manifest = fullHacsManifest({ domain: 'My Integration' });
    const filePath = await writeManifest(manifest, 'My Integration');

    const result = await handleValidateManifest({ path: filePath });

    const domainErrors = result.errors.filter((e) => e.field === 'domain');
    expect(domainErrors.length).toBeGreaterThanOrEqual(1);
    expect(domainErrors.some((e) => e.message.includes('lowercase'))).toBe(true);
  });

  it('should reject invalid iot_class', async () => {
    const manifest = fullHacsManifest({ iot_class: 'magic_telepathy' });
    const filePath = await writeManifest(manifest, 'my_integration');

    const result = await handleValidateManifest({ path: filePath });

    const iotErrors = result.errors.filter((e) => e.field === 'iot_class');
    expect(iotErrors).toHaveLength(1);
    expect(iotErrors[0].message).toContain('magic_telepathy');
  });

  it('should reject invalid semver', async () => {
    const manifest = fullHacsManifest({ version: '1.0' });
    const filePath = await writeManifest(manifest, 'my_integration');

    const result = await handleValidateManifest({ path: filePath });

    const versionErrors = result.errors.filter((e) => e.field === 'version');
    expect(versionErrors).toHaveLength(1);
    expect(versionErrors[0].message).toContain('semver');
  });

  it('should reject codeowner without @', async () => {
    const manifest = fullHacsManifest({ codeowners: ['missing_at'] });
    const filePath = await writeManifest(manifest, 'my_integration');

    const result = await handleValidateManifest({ path: filePath });

    const ownerErrors = result.errors.filter((e) => e.field === 'codeowners');
    expect(ownerErrors).toHaveLength(1);
    expect(ownerErrors[0].message).toContain("'missing_at'");
    expect(ownerErrors[0].message).toContain("'@'");
  });

  it('should warn about domain/directory mismatch', async () => {
    const manifest = fullHacsManifest({ domain: 'my_integration' });
    // Write into a directory with a different name than the domain
    const filePath = await writeManifest(manifest, 'different_dir_name');

    const result = await handleValidateManifest({ path: filePath });

    const domainWarnings = result.warnings.filter((w) => w.field === 'domain');
    expect(domainWarnings.length).toBeGreaterThanOrEqual(1);
    expect(
      domainWarnings.some((w) => w.message.includes('does not match directory'))
    ).toBe(true);
  });

  it('should warn about missing config_flow', async () => {
    const manifest = fullHacsManifest();
    delete manifest.config_flow;
    const filePath = await writeManifest(manifest, 'my_integration');

    const result = await handleValidateManifest({ path: filePath });

    const cfWarnings = result.warnings.filter((w) => w.field === 'config_flow');
    expect(cfWarnings.length).toBeGreaterThanOrEqual(1);
    expect(
      cfWarnings.some((w) => w.message.includes('config_flow'))
    ).toBe(true);
  });
});
