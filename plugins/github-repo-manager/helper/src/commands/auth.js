/**
 * auth.js — Authentication commands for gh-manager
 *
 * Commands:
 *   auth verify     — Validate PAT and report scopes
 *   auth rate-limit — Show current rate limit status
 */

import { getOctokit } from '../client.js';
import { success } from '../util/output.js';

/**
 * Verify PAT is valid and report authentication details.
 * Reports: login, name, scopes, rate limit status.
 */
export async function verify() {
  const octokit = getOctokit();

  // GET /user returns the authenticated user
  // The response headers include x-oauth-scopes for classic PATs
  const response = await octokit.request('GET /user');
  const headers = response.headers;
  const user = response.data;

  // Classic PATs expose scopes via header; fine-grained PATs do not
  const scopesHeader = headers['x-oauth-scopes'];
  const scopes = scopesHeader
    ? scopesHeader.split(',').map((s) => s.trim()).filter(Boolean)
    : null;

  // Determine PAT type
  const patType = scopes !== null ? 'classic' : 'fine-grained';

  success({
    authenticated: true,
    login: user.login,
    name: user.name || null,
    pat_type: patType,
    scopes: scopes,
    scopes_note:
      patType === 'fine-grained'
        ? 'Fine-grained PATs do not expose scopes via API headers. Permissions are checked per-endpoint.'
        : null,
  });
}

/**
 * Show current rate limit status for REST and GraphQL.
 */
export async function rateLimit() {
  const octokit = getOctokit();

  const { data } = await octokit.request('GET /rate_limit');

  success({
    resources: {
      core: {
        limit: data.resources.core.limit,
        remaining: data.resources.core.remaining,
        reset: new Date(data.resources.core.reset * 1000).toISOString(),
        used: data.resources.core.used,
      },
      graphql: {
        limit: data.resources.graphql.limit,
        remaining: data.resources.graphql.remaining,
        reset: new Date(data.resources.graphql.reset * 1000).toISOString(),
        used: data.resources.graphql.used,
      },
      search: {
        limit: data.resources.search.limit,
        remaining: data.resources.search.remaining,
        reset: new Date(data.resources.search.reset * 1000).toISOString(),
        used: data.resources.search.used,
      },
    },
  });
}
