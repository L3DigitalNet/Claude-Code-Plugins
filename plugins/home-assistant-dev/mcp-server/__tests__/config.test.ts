/**
 * Tests for configuration merging precedence
 */

import { deepMerge, loadEnvConfig, DEFAULT_CONFIG } from '../src/config.js';

describe('config merge precedence', () => {
  const ORIGINAL_ENV = process.env;

  beforeEach(() => {
    process.env = { ...ORIGINAL_ENV };
  });

  afterEach(() => {
    process.env = ORIGINAL_ENV;
  });

  it('preserves a file-level blockedServices addition when env enables service calls', () => {
    // File extends the blocklist on top of the defaults.
    const fileConfig = {
      safety: {
        blockedServices: [...DEFAULT_CONFIG.safety.blockedServices, 'light.turn_off'],
      },
    };

    // Env enables real service calls - the moment the blocklist matters most.
    process.env.HA_DEV_MCP_ALLOW_SERVICE_CALLS = 'true';

    let config = deepMerge(DEFAULT_CONFIG, fileConfig);
    config = deepMerge(config, loadEnvConfig());

    expect(config.safety.allowServiceCalls).toBe(true);
    // The user's addition survives instead of being dropped by the env layer.
    expect(config.safety.blockedServices).toContain('light.turn_off');
    // Default-blocked services remain blocked too.
    expect(config.safety.blockedServices).toContain('homeassistant.restart');
    // requireDryRun is not clobbered back by the env layer.
    expect(config.safety.requireDryRun).toBe(true);
  });
});
