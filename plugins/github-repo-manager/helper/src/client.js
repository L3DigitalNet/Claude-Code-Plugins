/**
 * client.js — Octokit client setup for gh-manager
 *
 * Creates authenticated Octokit REST and GraphQL clients
 * using the GITHUB_PAT environment variable.
 *
 * Hooks into every response to capture rate limit headers.
 */

import { Octokit } from '@octokit/rest';
import { graphql } from '@octokit/graphql';
import { updateRateLimit } from './rate-limit.js';

let _octokit = null;
let _graphqlClient = null;

/**
 * Get the PAT from environment, or throw a clear error.
 */
function getPAT() {
  const pat = process.env.GITHUB_PAT;
  if (!pat) {
    throw new Error(
      'GITHUB_PAT environment variable is not set. ' +
        'Set it to a GitHub Personal Access Token to authenticate.'
    );
  }
  return pat;
}

/**
 * Get or create the Octokit REST client.
 * Singleton — created once per process.
 */
export function getOctokit() {
  if (_octokit) return _octokit;

  const auth = getPAT();

  _octokit = new Octokit({
    auth,
    userAgent: 'gh-manager/0.1.0',
  });

  // Hook into every response to capture rate limit headers
  _octokit.hook.after('request', (response) => {
    updateRateLimit(response);
  });

  return _octokit;
}

/**
 * Get or create the GraphQL client.
 * Singleton — created once per process.
 */
export function getGraphQL() {
  if (_graphqlClient) return _graphqlClient;

  const auth = getPAT();

  _graphqlClient = graphql.defaults({
    headers: {
      authorization: `token ${auth}`,
      'user-agent': 'gh-manager/1.0.0',
    },
  });

  return _graphqlClient;
}

/**
 * Parse an "owner/repo" string into { owner, repo }.
 * Throws with a clear message if format is invalid.
 */
export function parseRepo(repoString) {
  if (!repoString) {
    throw new Error('--repo is required (format: owner/name)');
  }
  const parts = repoString.split('/');
  if (parts.length !== 2 || !parts[0] || !parts[1]) {
    throw new Error(
      `Invalid repo format: "${repoString}". Expected: owner/name`
    );
  }
  return { owner: parts[0], repo: parts[1] };
}
