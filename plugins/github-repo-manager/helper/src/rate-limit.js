/**
 * rate-limit.js — Rate limit tracking for gh-manager
 *
 * Captures rate limit data from GitHub API response headers
 * and makes it available for inclusion in every JSON response.
 *
 * Design principle 5: Every response includes _rate_limit metadata.
 */

let _currentRateLimit = null;

/**
 * Update rate limit state from Octokit response headers.
 * Called automatically by the client's afterRequest hook.
 */
export function updateRateLimit(response) {
  if (!response?.headers) return;

  const remaining = response.headers['x-ratelimit-remaining'];
  const limit = response.headers['x-ratelimit-limit'];
  const reset = response.headers['x-ratelimit-reset'];
  const resource = response.headers['x-ratelimit-resource'];

  if (remaining !== undefined) {
    _currentRateLimit = {
      remaining: parseInt(remaining, 10),
      limit: parseInt(limit, 10),
      reset: reset ? new Date(parseInt(reset, 10) * 1000).toISOString() : null,
      resource: resource || 'core',
    };
  }
}

/**
 * Get the current rate limit state.
 * Returns null if no API call has been made yet.
 */
export function getRateLimit() {
  return _currentRateLimit;
}

/**
 * Reset rate limit state (for testing).
 */
export function resetRateLimit() {
  _currentRateLimit = null;
}
