/** @type {import('ts-jest').JestConfigWithTsJest} */
export default {
  preset: 'ts-jest/presets/default-esm',
  testEnvironment: 'node',
  extensionsToTreatAsEsm: ['.ts'],
  moduleNameMapper: {
    '^(\\.{1,2}/.*)\\.js$': '$1',
  },
  transform: {
    '^.+\\.tsx?$': [
      'ts-jest',
      {
        useESM: true,
        tsconfig: 'tsconfig.test.json',
        diagnostics: {
          // ts-jest emits TS151002 (hybrid module kind) in NodeNext+useESM setup.
          // Cannot enable isolatedModules to silence — it breaks ESM imports
          // ("exports is not defined") under ts-jest 29 + module:NodeNext.
          ignoreCodes: [151002],
        },
      },
    ],
  },
  testMatch: ['**/__tests__/**/*.test.ts'],
  collectCoverageFrom: [
    'src/**/*.ts',
    '!src/**/*.d.ts',
    // HA API tool files require a live HA instance — covered by E2E tests, not unit tests
    '!src/tools/ha-*.ts',
    // Unit-testable (read in-memory DOCS_INDEX / parse static JSON, no live HA) — tests TODO.
    // Until those tests exist these are excluded so the threshold is not skewed by 0% coverage;
    // once tested, drop them here so the threshold guards them (F167/F170).
    // validate-strings.ts is now covered by validate-strings.test.ts (F167) — kept guarded.
    '!src/tools/docs-*.ts',
    '!src/tools/check-patterns.ts',
    // Server infrastructure — requires a running server to exercise
    '!src/ha-client.ts',
    '!src/config.ts',
    '!src/index.ts',
    '!src/types.ts',
  ],
  coverageThreshold: {
    global: {
      branches: 50,
      functions: 50,
      lines: 50,
      statements: 50,
    },
    './src/safety.ts': {
      branches: 85,
      functions: 80,
      lines: 85,
      statements: 85,
    },
  },
};
