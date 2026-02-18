/**
 * paginate.js — Auto-pagination wrapper for gh-manager
 *
 * Design principle 4: Pagination handled internally.
 * Commands that return lists fetch all pages by default.
 * Use --limit to cap results.
 */

import { getOctokit } from '../client.js';

/**
 * Paginate an Octokit REST endpoint, collecting all results.
 *
 * @param {string} method - Octokit method string, e.g. 'repos.listForAuthenticatedUser'
 * @param {object} params - Request parameters (per_page defaults to 100)
 * @param {number|null} limit - Maximum results to return (null = all)
 * @returns {Promise<Array>} All collected items
 */
export async function paginateRest(method, params = {}, limit = null) {
  const octokit = getOctokit();

  // Resolve the method from dot notation
  const parts = method.split('.');
  let fn = octokit;
  for (const part of parts) {
    fn = fn[part];
    if (!fn) throw new Error(`Unknown Octokit method: ${method}`);
  }

  const allItems = [];
  const perPage = Math.min(params.per_page || 100, 100);

  for await (const response of octokit.paginate.iterator(fn, {
    ...params,
    per_page: perPage,
  })) {
    for (const item of response.data) {
      allItems.push(item);
      if (limit && allItems.length >= limit) {
        return allItems.slice(0, limit);
      }
    }
  }

  return allItems;
}
