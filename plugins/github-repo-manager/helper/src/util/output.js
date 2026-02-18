/**
 * output.js — Structured JSON output for gh-manager
 *
 * Design principle: JSON in, JSON out.
 * - Success: JSON to stdout, exit 0
 * - Error: JSON to stderr, exit non-zero
 *
 * Every successful response includes _rate_limit metadata
 * when rate limit data is available.
 */

import { getRateLimit } from '../rate-limit.js';

/**
 * Write successful response to stdout and exit.
 * Attaches _rate_limit metadata if available.
 */
export function success(data) {
  const rateLimit = getRateLimit();
  const output = {
    ...data,
    ...(rateLimit ? { _rate_limit: rateLimit } : {}),
  };
  process.stdout.write(JSON.stringify(output, null, 2) + '\n');
}

/**
 * Write error to stderr and exit with non-zero code.
 * Follows the helper error contract from design doc Section 7.7.
 */
export function error(message, status = 1, endpoint = null, context = null) {
  const err = { error: message };
  if (status) err.status = status;
  if (endpoint) err.endpoint = endpoint;
  if (context) err.context = context;
  process.stderr.write(JSON.stringify(err, null, 2) + '\n');
  process.exit(1);
}

/**
 * Wrap an async command handler with standard error handling.
 * Catches Octokit RequestError and formats per error contract.
 */
export function handleCommand(fn) {
  return async (...args) => {
    try {
      await fn(...args);
    } catch (err) {
      if (err.status) {
        // Octokit RequestError
        error(
          err.message,
          err.status,
          err.request?.url
            ? `${err.request.method || 'GET'} ${err.request.url}`
            : null,
          err.response?.data?.message || null
        );
      } else {
        // Unexpected error
        error(err.message || 'Unknown error', 1, null, err.code || null);
      }
    }
  };
}
