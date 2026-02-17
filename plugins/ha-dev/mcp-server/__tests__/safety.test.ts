/**
 * Tests for SafetyChecker
 */

import { SafetyChecker } from '../src/safety.js';

describe('SafetyChecker', () => {
  const defaultConfig = {
    allowServiceCalls: true,
    blockedServices: ['homeassistant.restart'],
    requireDryRun: true,
  };

  describe('checkServiceCall', () => {
    it('should block always-blocked services', () => {
      const checker = new SafetyChecker(defaultConfig);
      const result = checker.checkServiceCall('homeassistant', 'stop', false);

      expect(result.allowed).toBe(false);
      expect(result.reason).toContain('always blocked');
    });

    it('should block configured blocked services', () => {
      const checker = new SafetyChecker(defaultConfig);
      const result = checker.checkServiceCall('homeassistant', 'restart', false);

      expect(result.allowed).toBe(false);
      expect(result.reason).toContain('blocked list');
    });

    it('should require dry-run for non-safe domains', () => {
      const checker = new SafetyChecker(defaultConfig);
      const result = checker.checkServiceCall('light', 'turn_on', false);

      expect(result.allowed).toBe(false);
      expect(result.reason).toContain('Dry-run mode is required');
    });

    it('should allow dry-run calls', () => {
      const checker = new SafetyChecker(defaultConfig);
      const result = checker.checkServiceCall('light', 'turn_on', true);

      expect(result.allowed).toBe(true);
    });

    it('should allow safe domains without dry-run', () => {
      const checker = new SafetyChecker(defaultConfig);
      const result = checker.checkServiceCall('input_boolean', 'turn_on', false);

      expect(result.allowed).toBe(true);
    });

    it('should warn about dangerous services', () => {
      const checker = new SafetyChecker({
        ...defaultConfig,
        blockedServices: [],
      });
      const result = checker.checkServiceCall('recorder', 'purge', true);

      expect(result.allowed).toBe(true);
      expect(result.warning).toContain('modify system state');
    });

    it('should block all service calls when disabled', () => {
      const checker = new SafetyChecker({
        ...defaultConfig,
        allowServiceCalls: false,
      });
      const result = checker.checkServiceCall('light', 'turn_on', true);

      expect(result.allowed).toBe(false);
      expect(result.reason).toContain('disabled');
    });
  });

  describe('redactSensitiveData', () => {
    it('should redact password fields', () => {
      const checker = new SafetyChecker(defaultConfig);
      const data = { username: 'admin', password: 'secret123' };
      const redacted = checker.redactSensitiveData(data);

      expect(redacted.username).toBe('admin');
      expect(redacted.password).toBe('**REDACTED**');
    });

    it('should redact nested sensitive fields', () => {
      const checker = new SafetyChecker(defaultConfig);
      const data = {
        config: {
          api_key: 'abc123',
          host: 'example.com',
        },
      };
      const redacted = checker.redactSensitiveData(data);

      expect((redacted.config as Record<string, unknown>).api_key).toBe('**REDACTED**');
      expect((redacted.config as Record<string, unknown>).host).toBe('example.com');
    });
  });

  describe('isSafeDomain', () => {
    it('should identify safe domains', () => {
      const checker = new SafetyChecker(defaultConfig);

      expect(checker.isSafeDomain('input_boolean')).toBe(true);
      expect(checker.isSafeDomain('input_number')).toBe(true);
      expect(checker.isSafeDomain('counter')).toBe(true);
    });

    it('should identify unsafe domains', () => {
      const checker = new SafetyChecker(defaultConfig);

      expect(checker.isSafeDomain('light')).toBe(false);
      expect(checker.isSafeDomain('switch')).toBe(false);
      expect(checker.isSafeDomain('homeassistant')).toBe(false);
    });
  });
});
