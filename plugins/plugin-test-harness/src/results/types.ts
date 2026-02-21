// src/results/types.ts — re-export from testing/types.ts for convenience
export type { TestResult, TestStatus } from '../testing/types.js';

export interface IterationSnapshot {
  passing: number;
  failing: number;
}

export type ConvergenceTrend = 'improving' | 'plateaued' | 'oscillating' | 'declining' | 'unknown';
