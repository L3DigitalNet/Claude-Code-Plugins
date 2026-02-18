/** Risk levels ordered from lowest to highest (Section 7.4). */
export type RiskLevel = "read-only" | "low" | "moderate" | "high" | "critical";

/** Numeric ordering for risk comparison. */
export const RISK_ORDER: Record<RiskLevel, number> = {
  "read-only": 0,
  "low": 1,
  "moderate": 2,
  "high": 3,
  "critical": 4,
};

/** Duration category for command timeouts (Section 7.1). */
export type DurationCategory = "instant" | "quick" | "normal" | "slow" | "long_running";

/** Timeout in ms per duration category. */
export const DURATION_TIMEOUTS: Record<DurationCategory, number> = {
  instant: 5_000,
  quick: 15_000,
  normal: 30_000,
  slow: 60_000,
  long_running: 300_000,
};
