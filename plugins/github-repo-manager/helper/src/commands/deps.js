/**
 * deps.js — Dependency audit operations for gh-manager
 *
 * Commands:
 *   deps graph --repo           — Fetch dependency graph summary
 *   deps dependabot-prs --repo  — List open Dependabot PRs with age/severity
 *
 * The dependency graph endpoint requires the dependency graph to be enabled.
 * Dependabot PRs are fetched from the regular PR list, filtered by author.
 */

import { getOctokit, parseRepo } from '../client.js';
import { paginateRest } from '../util/paginate.js';
import { success, error } from '../util/output.js';

/**
 * Fetch dependency graph — SBOM summary.
 * Uses the dependency graph SBOM endpoint for an overview.
 */
export async function graph(options) {
  const { owner, repo } = parseRepo(options.repo);
  const octokit = getOctokit();

  try {
    const { data } = await octokit.request(
      'GET /repos/{owner}/{repo}/dependency-graph/sbom',
      { owner, repo }
    );

    const sbom = data.sbom;
    const packages = sbom?.packages || [];

    // Summarize by ecosystem
    const byEcosystem = {};
    for (const pkg of packages) {
      // SPDX external refs contain ecosystem info
      const ecosystem = pkg.externalRefs?.find(
        (r) => r.referenceCategory === 'PACKAGE-MANAGER'
      )?.referenceType || 'unknown';
      byEcosystem[ecosystem] = (byEcosystem[ecosystem] || 0) + 1;
    }

    success({
      name: sbom?.name || `${owner}/${repo}`,
      total_packages: packages.length,
      by_ecosystem: byEcosystem,
      sbom_format: sbom?.spdxVersion || 'unknown',
      created_at: sbom?.creationInfo?.created || null,
    });
  } catch (err) {
    if (err.status === 404) {
      success({
        total_packages: 0,
        enabled: false,
        message: 'Dependency graph is not enabled on this repository',
      });
      return;
    }
    if (err.status === 403) {
      error(
        'Dependency graph not accessible — may require additional PAT permissions',
        403,
        `GET /repos/${owner}/${repo}/dependency-graph/sbom`
      );
      return;
    }
    throw err;
  }
}

/**
 * List open Dependabot PRs with age and severity context.
 * Filters the PR list by author (dependabot[bot]).
 * Cross-references with Dependabot alerts where possible.
 */
export async function dependabotPrs(options) {
  const { owner, repo } = parseRepo(options.repo);

  // Fetch open PRs and filter to Dependabot
  const prs = await paginateRest('pulls.list', {
    owner,
    repo,
    state: 'open',
    sort: 'created',
    direction: 'desc',
  });

  const dependabotPrs = prs.filter(
    (pr) => pr.user?.login === 'dependabot[bot]'
  );

  const now = new Date();
  const trimmed = dependabotPrs.map((pr) => {
    const createdAt = new Date(pr.created_at);
    const ageDays = Math.floor((now - createdAt) / (1000 * 60 * 60 * 24));

    // Try to extract package info from title
    // Dependabot titles: "Bump lodash from 4.17.20 to 4.17.21"
    const bumpMatch = pr.title.match(
      /^Bump\s+(.+?)\s+from\s+(\S+)\s+to\s+(\S+)/i
    );

    // Check labels for severity hints
    const labels = pr.labels.map((l) => l.name.toLowerCase());
    let severity = 'unknown';
    if (labels.some((l) => l.includes('critical'))) severity = 'critical';
    else if (labels.some((l) => l.includes('high'))) severity = 'high';
    else if (labels.some((l) => l.includes('medium'))) severity = 'medium';
    else if (labels.some((l) => l.includes('low'))) severity = 'low';
    // Dependabot often includes "dependencies" and "security" labels
    const isSecurity = labels.some((l) => l.includes('security'));

    return {
      number: pr.number,
      title: pr.title,
      package_name: bumpMatch ? bumpMatch[1] : null,
      from_version: bumpMatch ? bumpMatch[2] : null,
      to_version: bumpMatch ? bumpMatch[3] : null,
      severity,
      is_security: isSecurity,
      created_at: pr.created_at,
      age_days: ageDays,
      labels: pr.labels.map((l) => l.name),
      mergeable: pr.mergeable,
      head_branch: pr.head?.ref || null,
      additions: pr.additions,
      deletions: pr.deletions,
    };
  });

  // Summary
  const securityPrs = trimmed.filter((p) => p.is_security);
  const nonSecurityPrs = trimmed.filter((p) => !p.is_security);
  const avgAge = trimmed.length
    ? Math.round(trimmed.reduce((s, p) => s + p.age_days, 0) / trimmed.length)
    : 0;

  success({
    count: trimmed.length,
    security_count: securityPrs.length,
    non_security_count: nonSecurityPrs.length,
    average_age_days: avgAge,
    oldest_age_days: trimmed.length ? Math.max(...trimmed.map((p) => p.age_days)) : 0,
    pull_requests: trimmed,
  });
}
