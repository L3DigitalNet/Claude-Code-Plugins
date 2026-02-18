/**
 * config.js — Configuration management for gh-manager
 *
 * Commands:
 *   config repo-read --repo                — Read .github-repo-manager.yml from repo
 *   config repo-write --repo [--dry-run]   — Write .github-repo-manager.yml to repo (stdin)
 *   config portfolio-read                  — Read local portfolio.yml
 *   config portfolio-write [--dry-run]     — Write local portfolio.yml (stdin)
 *   config resolve --repo                  — Resolve effective config (merged precedence)
 *
 * Config precedence (highest to lowest):
 *   1. Portfolio per-repo overrides
 *   2. Per-repo .github-repo-manager.yml
 *   3. Portfolio defaults
 *   4. Built-in tier defaults
 */

import { getOctokit, parseRepo } from '../client.js';
import { success, error } from '../util/output.js';
import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'fs';
import { join } from 'path';
import { homedir } from 'os';
import { parse as yamlParse, stringify as yamlStringify } from 'yaml';

const CONFIG_FILENAME = '.github-repo-manager.yml';
const PORTFOLIO_DIR = join(homedir(), '.config', 'github-repo-manager');
const PORTFOLIO_PATH = join(PORTFOLIO_DIR, 'portfolio.yml');

/**
 * Tier defaults per the design doc Section 7.3.
 */
const TIER_DEFAULTS = {
  1: {
    staleness: { pr_flag: 7, pr_close: 30, discussion: 14, issue: 14 },
    mutation: 'direct',
    ceremony: 'low',
  },
  2: {
    staleness: { pr_flag: 14, pr_close: 60, discussion: 21, issue: 21 },
    mutation: 'direct',
    ceremony: 'moderate',
  },
  3: {
    staleness: { pr_flag: 21, pr_close: null, discussion: 30, issue: 30 },
    mutation: 'direct',
    ceremony: 'detailed',
  },
  4: {
    staleness: { pr_flag: 30, pr_close: null, discussion: 30, issue: 30 },
    mutation: 'pr',
    ceremony: 'maximum',
  },
};

/**
 * Read .github-repo-manager.yml from a repo.
 */
export async function repoRead(options) {
  const { owner, repo } = parseRepo(options.repo);
  const octokit = getOctokit();

  try {
    const { data } = await octokit.request(
      'GET /repos/{owner}/{repo}/contents/{path}',
      { owner, repo, path: CONFIG_FILENAME }
    );

    if (data.type !== 'file') {
      success({ exists: false, message: `${CONFIG_FILENAME} is not a file` });
      return;
    }

    const content = Buffer.from(data.content, 'base64').toString('utf-8');
    let parsed = null;
    let parseError = null;

    try {
      parsed = yamlParse(content);
    } catch (err) {
      parseError = err.message;
    }

    success({
      exists: true,
      sha: data.sha,
      raw: content,
      parsed,
      parse_error: parseError,
    });
  } catch (err) {
    if (err.status === 404) {
      success({
        exists: false,
        message: `No ${CONFIG_FILENAME} found in repository root`,
      });
      return;
    }
    throw err;
  }
}

/**
 * Write .github-repo-manager.yml to a repo.
 * Content comes from stdin.
 */
export async function repoWrite(options) {
  const { owner, repo } = parseRepo(options.repo);
  const octokit = getOctokit();

  // Read content from stdin
  const chunks = [];
  for await (const chunk of process.stdin) {
    chunks.push(chunk);
  }
  const content = Buffer.concat(chunks).toString('utf-8');

  // Validate YAML
  try {
    yamlParse(content);
  } catch (err) {
    error(`Invalid YAML: ${err.message}`, 400, 'config repo-write');
    return;
  }

  if (options.dryRun) {
    success({
      dry_run: true,
      action: 'write_repo_config',
      repo: `${owner}/${repo}`,
      content_length: content.length,
    });
    return;
  }

  // Check if file exists (need SHA for update)
  let sha = null;
  try {
    const { data } = await octokit.request(
      'GET /repos/{owner}/{repo}/contents/{path}',
      { owner, repo, path: CONFIG_FILENAME }
    );
    sha = data.sha;
  } catch { /* file doesn't exist yet */ }

  const params = {
    owner,
    repo,
    path: CONFIG_FILENAME,
    message: sha
      ? 'Update .github-repo-manager.yml'
      : 'Add .github-repo-manager.yml',
    content: Buffer.from(content).toString('base64'),
  };
  if (sha) params.sha = sha;

  if (options.branch) params.branch = options.branch;

  const { data } = await octokit.request(
    'PUT /repos/{owner}/{repo}/contents/{path}',
    params
  );

  success({
    action: sha ? 'updated' : 'created',
    sha: data.content.sha,
    path: CONFIG_FILENAME,
    repo: `${owner}/${repo}`,
  });
}

/**
 * Read local portfolio.yml.
 */
export async function portfolioRead() {
  if (!existsSync(PORTFOLIO_PATH)) {
    success({
      exists: false,
      path: PORTFOLIO_PATH,
      message: 'No portfolio.yml found',
    });
    return;
  }

  const content = readFileSync(PORTFOLIO_PATH, 'utf-8');
  let parsed = null;
  let parseError = null;

  try {
    parsed = yamlParse(content);
  } catch (err) {
    parseError = err.message;
  }

  success({
    exists: true,
    path: PORTFOLIO_PATH,
    raw: content,
    parsed,
    parse_error: parseError,
  });
}

/**
 * Write local portfolio.yml.
 * Content comes from stdin.
 */
export async function portfolioWrite(options) {
  const chunks = [];
  for await (const chunk of process.stdin) {
    chunks.push(chunk);
  }
  const content = Buffer.concat(chunks).toString('utf-8');

  // Validate YAML
  try {
    yamlParse(content);
  } catch (err) {
    error(`Invalid YAML: ${err.message}`, 400, 'config portfolio-write');
    return;
  }

  if (options.dryRun) {
    success({
      dry_run: true,
      action: 'write_portfolio',
      path: PORTFOLIO_PATH,
      content_length: content.length,
    });
    return;
  }

  // Ensure directory exists
  mkdirSync(PORTFOLIO_DIR, { recursive: true });

  const existed = existsSync(PORTFOLIO_PATH);
  writeFileSync(PORTFOLIO_PATH, content, 'utf-8');

  success({
    action: existed ? 'updated' : 'created',
    path: PORTFOLIO_PATH,
  });
}

/**
 * Resolve effective config for a repo.
 * Merges: tier defaults ← portfolio defaults ← repo config ← portfolio per-repo overrides.
 * Returns the merged config and which source each key came from.
 */
export async function resolve(options) {
  const { owner, repo } = parseRepo(options.repo);
  const repoName = repo;

  // 1. Load portfolio config (if exists)
  let portfolio = null;
  if (existsSync(PORTFOLIO_PATH)) {
    try {
      portfolio = yamlParse(readFileSync(PORTFOLIO_PATH, 'utf-8'));
    } catch { /* ignore parse errors — skill layer handles */ }
  }

  // 2. Load repo config (if exists)
  let repoConfig = null;
  const octokit = getOctokit();
  try {
    const { data } = await octokit.request(
      'GET /repos/{owner}/{repo}/contents/{path}',
      { owner, repo: repoName, path: CONFIG_FILENAME }
    );
    const content = Buffer.from(data.content, 'base64').toString('utf-8');
    repoConfig = yamlParse(content);
  } catch { /* no repo config */ }

  // 3. Determine tier
  let tier = null;
  let tierSource = 'auto-detection';

  // Check portfolio per-repo override first (highest priority)
  const portfolioRepoOverride = portfolio?.repos?.[repoName];
  if (portfolioRepoOverride?.tier) {
    tier = portfolioRepoOverride.tier;
    tierSource = 'portfolio per-repo override';
  } else if (repoConfig?.repo?.tier && repoConfig.repo.tier !== 'auto') {
    tier = repoConfig.repo.tier;
    tierSource = 'repo config';
  }
  // If tier is still null, the skill layer runs auto-detection

  // 4. Check skip/read-only
  const skip = portfolioRepoOverride?.skip || false;
  const readOnly = portfolioRepoOverride?.read_only || false;

  // 5. Merge module configs (portfolio defaults ← repo config ← portfolio per-repo)
  const moduleNames = [
    'community_health', 'pr_management', 'issue_triage',
    'notifications', 'security', 'discussions',
    'dependency_audit', 'release_health', 'wiki_sync',
  ];

  const modules = {};
  for (const mod of moduleNames) {
    const portfolioDefault = portfolio?.defaults?.[mod] || {};
    const repoModule = repoConfig?.modules?.[mod] || {};
    const portfolioOverride = portfolioRepoOverride?.[mod] || {};

    modules[mod] = {
      ...portfolioDefault,
      ...repoModule,
      ...portfolioOverride,
    };
  }

  // 6. Get tier defaults if tier is known
  const tierDefaults = tier ? TIER_DEFAULTS[tier] : null;

  // 7. Resolve staleness thresholds (replace 'auto' with tier defaults)
  if (tierDefaults) {
    for (const mod of ['pr_management', 'issue_triage', 'discussions']) {
      if (modules[mod].staleness_threshold_days === 'auto' || !modules[mod].staleness_threshold_days) {
        const thresholdKey = mod === 'pr_management' ? 'pr_flag'
          : mod === 'issue_triage' ? 'issue'
          : 'discussion';
        modules[mod].staleness_threshold_days = tierDefaults.staleness[thresholdKey];
        modules[mod]._staleness_source = 'tier default';
      }
    }
  }

  success({
    repo: `${owner}/${repoName}`,
    tier,
    tier_source: tierSource,
    tier_defaults: tierDefaults,
    skip,
    read_only: readOnly,
    owner_expertise: portfolio?.owner?.expertise || 'beginner',
    modules,
    sources: {
      portfolio: !!portfolio,
      portfolio_path: PORTFOLIO_PATH,
      repo_config: !!repoConfig,
      portfolio_repo_override: !!portfolioRepoOverride,
    },
  });
}
