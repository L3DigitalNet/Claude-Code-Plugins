/**
 * repos.js — Cross-repo discovery commands for gh-manager
 *
 * Commands:
 *   repos list               — List all repos accessible via PAT
 *   repos classify --repo    — Auto-detect tier for a repo (composite)
 *
 * The classify command is the one documented exception to the
 * single-endpoint pattern (see design doc Section 11.1).
 */

import { getOctokit, parseRepo } from '../client.js';
import { paginateRest } from '../util/paginate.js';
import { success } from '../util/output.js';

/**
 * List all repos accessible to the authenticated user.
 * Trimmed to fields the skill layer needs for discovery and filtering.
 */
export async function list(options) {
  const limit = options.limit ? parseInt(options.limit, 10) : null;

  const repos = await paginateRest(
    'repos.listForAuthenticatedUser',
    {
      sort: 'updated',
      direction: 'desc',
      type: 'all',
    },
    limit
  );

  const trimmed = repos.map((r) => ({
    name: r.name,
    full_name: r.full_name,
    private: r.private,
    fork: r.fork,
    archived: r.archived,
    language: r.language,
    description: r.description || null,
    default_branch: r.default_branch,
    has_wiki: r.has_wiki,
    has_discussions: r.has_discussions,
    updated_at: r.updated_at,
    pushed_at: r.pushed_at,
  }));

  success({ count: trimmed.length, repos: trimmed });
}

/**
 * Auto-detect tier for a single repo.
 *
 * Composite command: fetches metadata, releases, and root contents
 * to determine code signals. Returns raw signals + suggested tier.
 * Makes NO decisions — the skill layer (and owner) decide.
 *
 * Detection flow per design doc Section 7.4:
 *   1. Fetch repo metadata (visibility, fork, archived)
 *   2. Check fork/archived status
 *   3. Check for releases
 *   4. Scan root contents + .github/workflows/ for code signals
 *   5. Return signals + suggested tier
 */
export async function classify(options) {
  const { owner, repo } = parseRepo(options.repo);
  const octokit = getOctokit();

  // 1. Fetch repo metadata
  const { data: repoData } = await octokit.request(
    'GET /repos/{owner}/{repo}',
    { owner, repo }
  );

  const signals = {
    full_name: repoData.full_name,
    private: repoData.private,
    fork: repoData.fork,
    archived: repoData.archived,
    has_wiki: repoData.has_wiki,
    has_discussions: repoData.has_discussions,
    default_branch: repoData.default_branch,
    language: repoData.language,
    has_releases: false,
    release_count: 0,
    has_code_signals: false,
    code_signals: [],
    has_ci: false,
    suggested_tier: null,
    skip_reason: null,
  };

  // 2. Check fork/archived
  if (repoData.fork) {
    signals.skip_reason = 'fork';
    signals.suggested_tier = null;
    success(signals);
    return;
  }
  if (repoData.archived) {
    signals.skip_reason = 'archived';
    signals.suggested_tier = null;
    success(signals);
    return;
  }

  // 3. Check for releases (just need to know if any exist)
  try {
    const { data: releases } = await octokit.request(
      'GET /repos/{owner}/{repo}/releases',
      { owner, repo, per_page: 1 }
    );
    signals.has_releases = releases.length > 0;
    if (signals.has_releases) {
      // Get total count with a second lightweight call
      const { data: allReleases } = await octokit.request(
        'GET /repos/{owner}/{repo}/releases',
        { owner, repo, per_page: 100 }
      );
      signals.release_count = allReleases.length;
    }
  } catch {
    // 404 or permission issue — treat as no releases
    signals.has_releases = false;
  }

  // 4. Scan root directory for code signals
  const codeSignals = [];

  try {
    const { data: contents } = await octokit.request(
      'GET /repos/{owner}/{repo}/contents',
      { owner, repo }
    );

    // Package manifests
    const packageFiles = [
      'package.json',
      'Cargo.toml',
      'pyproject.toml',
      'setup.py',
      'setup.cfg',
      'go.mod',
      'Gemfile',
      'pom.xml',
      'build.gradle',
      'composer.json',
      'mix.exs',
      'CMakeLists.txt',
      'Makefile',
    ];

    // Code directories
    const codeDirs = ['src', 'lib', 'app', 'cmd', 'pkg', 'internal'];

    for (const item of contents) {
      if (item.type === 'file' && packageFiles.includes(item.name)) {
        codeSignals.push(`package_manifest:${item.name}`);
      }
      if (item.type === 'dir' && codeDirs.includes(item.name)) {
        codeSignals.push(`code_dir:${item.name}`);
      }
    }
  } catch {
    // Empty repo or permission issue
  }

  // Check for CI workflows
  try {
    const { data: workflows } = await octokit.request(
      'GET /repos/{owner}/{repo}/contents/.github/workflows',
      { owner, repo }
    );
    if (workflows.length > 0) {
      signals.has_ci = true;
      codeSignals.push(`ci_workflows:${workflows.length}`);
    }
  } catch {
    // No .github/workflows/ — not an error
  }

  signals.code_signals = codeSignals;
  signals.has_code_signals = codeSignals.length > 0;

  // 5. Suggest tier per detection flow
  if (repoData.private) {
    // Private repos: Tier 1 (docs-only) or Tier 2 (code)
    // Releases don't factor into tier for private repos
    signals.suggested_tier = signals.has_code_signals ? 2 : 1;
  } else {
    // Public repos
    if (!signals.has_code_signals) {
      // Public + no code signals → Tier 3 (docs-only variant)
      signals.suggested_tier = 3;
    } else if (signals.has_releases) {
      // Public + code + releases → Tier 4
      signals.suggested_tier = 4;
    } else {
      // Public + code + no releases → Tier 3
      signals.suggested_tier = 3;
    }
  }

  success({ ...signals, tier: signals.suggested_tier });
}
