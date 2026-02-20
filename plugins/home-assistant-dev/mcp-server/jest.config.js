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
      },
    ],
  },
  testMatch: ['**/__tests__/**/*.test.ts'],
  collectCoverageFrom: [
    'src/**/*.ts',
    '!src/**/*.d.ts',
    // HA API tool files require a live HA instance — covered by E2E tests, not unit tests
    '!src/tools/ha-*.ts',
    '!src/tools/docs-*.ts',
    '!src/tools/check-patterns.ts',
    '!src/tools/validate-strings.ts',
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
