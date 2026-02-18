/**
 * releases.js — Release operations for gh-manager
 *
 * Commands:
 *   releases list --repo [--limit]
 *   releases latest --repo
 *   releases compare --repo                    — Commits since last release
 *   releases draft --repo --tag --name [--body] [--target] [--dry-run]
 *   releases publish --repo --release-id [--dry-run]
 *   releases changelog --repo                  — Fetch and parse changelog file
 *
 * Supports Tier 4 release health assessment: unreleased commits,
 * CHANGELOG drift, draft releases, release cadence.
 */

import { getOctokit, parseRepo } from '../client.js';
import { success, error } from '../util/output.js';

/**
 * List releases (most recent first).
 */
export async function list(options) {
  const { owner, repo } = parseRepo(options.repo);
  const octokit = getOctokit();
  const limit = options.limit ? parseInt(options.limit, 10) : 20;

  const { data } = await octokit.request(
    'GET /repos/{owner}/{repo}/releases',
    { owner, repo, per_page: limit }
  );

  const trimmed = data.map((r) => ({
    id: r.id,
    tag_name: r.tag_name,
    name: r.name || r.tag_name,
    draft: r.draft,
    prerelease: r.prerelease,
    created_at: r.created_at,
    published_at: r.published_at,
    author: r.author?.login || null,
    body_length: (r.body || '').length,
    assets_count: (r.assets || []).length,
  }));

  success({ count: trimmed.length, releases: trimmed });
}

/**
 * Get latest release details.
 */
export async function latest(options) {
  const { owner, repo } = parseRepo(options.repo);
  const octokit = getOctokit();

  try {
    const { data } = await octokit.request(
      'GET /repos/{owner}/{repo}/releases/latest',
      { owner, repo }
    );

    success({
      id: data.id,
      tag_name: data.tag_name,
      name: data.name || data.tag_name,
      draft: data.draft,
      prerelease: data.prerelease,
      created_at: data.created_at,
      published_at: data.published_at,
      author: data.author?.login || null,
      body: data.body || '',
      target_commitish: data.target_commitish,
      assets: (data.assets || []).map((a) => ({
        name: a.name,
        size: a.size,
        download_count: a.download_count,
      })),
    });
  } catch (err) {
    if (err.status === 404) {
      success({
        exists: false,
        message: 'No published releases found',
      });
      return;
    }
    throw err;
  }
}

/**
 * Compare: commits since last release tag on the default branch.
 * Returns commit count, date range, and commit summaries.
 */
export async function compare(options) {
  const { owner, repo } = parseRepo(options.repo);
  const octokit = getOctokit();

  // Get latest release tag
  let latestTag = null;
  try {
    const { data: rel } = await octokit.request(
      'GET /repos/{owner}/{repo}/releases/latest',
      { owner, repo }
    );
    latestTag = rel.tag_name;
  } catch (err) {
    if (err.status === 404) {
      success({
        has_releases: false,
        message: 'No releases found — cannot compare unreleased commits',
      });
      return;
    }
    throw err;
  }

  // Get default branch
  const { data: repoData } = await octokit.request(
    'GET /repos/{owner}/{repo}',
    { owner, repo }
  );
  const defaultBranch = repoData.default_branch;

  // Compare tag to default branch head
  const { data: comparison } = await octokit.request(
    'GET /repos/{owner}/{repo}/compare/{basehead}',
    { owner, repo, basehead: `${latestTag}...${defaultBranch}` }
  );

  const commits = (comparison.commits || []).map((c) => ({
    sha: c.sha.substring(0, 7),
    message: (c.commit?.message || '').split('\n')[0], // First line only
    author: c.author?.login || c.commit?.author?.name || null,
    date: c.commit?.author?.date || null,
  }));

  const dateRange = commits.length
    ? {
        oldest: commits[0].date,
        newest: commits[commits.length - 1].date,
      }
    : null;

  success({
    base_tag: latestTag,
    head_branch: defaultBranch,
    ahead_by: comparison.ahead_by,
    behind_by: comparison.behind_by,
    total_commits: comparison.total_commits,
    date_range: dateRange,
    status: comparison.status, // ahead, behind, identical, diverged
    commits,
    files_changed: comparison.files?.length || 0,
  });
}

/**
 * Create a draft release.
 */
export async function draft(options) {
  const { owner, repo } = parseRepo(options.repo);
  const octokit = getOctokit();

  if (options.dryRun) {
    success({
      dry_run: true,
      action: 'create_draft_release',
      tag: options.tag,
      name: options.name || options.tag,
      target: options.target || '(default branch)',
      body_length: (options.body || '').length,
    });
    return;
  }

  const { data } = await octokit.request(
    'POST /repos/{owner}/{repo}/releases',
    {
      owner,
      repo,
      tag_name: options.tag,
      name: options.name || options.tag,
      body: options.body || '',
      draft: true,
      target_commitish: options.target || undefined,
    }
  );

  success({
    action: 'created_draft',
    id: data.id,
    tag_name: data.tag_name,
    name: data.name,
    url: data.html_url,
    draft: true,
  });
}

/**
 * Publish a draft release (set draft=false).
 */
export async function publish(options) {
  const { owner, repo } = parseRepo(options.repo);
  const octokit = getOctokit();
  const releaseId = parseInt(options.releaseId, 10);

  if (options.dryRun) {
    success({
      dry_run: true,
      action: 'publish_release',
      release_id: releaseId,
    });
    return;
  }

  const { data } = await octokit.request(
    'PATCH /repos/{owner}/{repo}/releases/{release_id}',
    {
      owner,
      repo,
      release_id: releaseId,
      draft: false,
    }
  );

  success({
    action: 'published',
    id: data.id,
    tag_name: data.tag_name,
    name: data.name,
    url: data.html_url,
    draft: false,
  });
}

/**
 * Fetch and parse the changelog file.
 * Searches for CHANGELOG.md, CHANGES.md, HISTORY.md in root.
 * Returns raw content and attempts to identify the latest version entry.
 */
export async function changelog(options) {
  const { owner, repo } = parseRepo(options.repo);
  const octokit = getOctokit();

  const candidates = ['CHANGELOG.md', 'CHANGES.md', 'HISTORY.md'];
  let found = null;
  let content = null;

  for (const filename of candidates) {
    try {
      const { data } = await octokit.request(
        'GET /repos/{owner}/{repo}/contents/{path}',
        { owner, repo, path: filename }
      );
      if (data.type === 'file') {
        found = filename;
        content = Buffer.from(data.content, 'base64').toString('utf-8');
        break;
      }
    } catch (err) {
      if (err.status !== 404) throw err;
    }
  }

  if (!found) {
    success({
      exists: false,
      searched: candidates,
      message: 'No changelog file found',
    });
    return;
  }

  // Try to extract the latest version heading
  // Common patterns: ## [1.2.3], ## v1.2.3, # 1.2.3, ## 1.2.3 - 2026-02-17
  const versionPattern = /^#{1,3}\s+\[?v?(\d+\.\d+(?:\.\d+)?)\]?/gm;
  const versions = [];
  let match;
  while ((match = versionPattern.exec(content)) !== null) {
    versions.push({
      version: match[1],
      position: match.index,
      heading: match[0].trim(),
    });
  }

  success({
    exists: true,
    filename: found,
    content_length: content.length,
    line_count: content.split('\n').length,
    versions_found: versions.length,
    latest_version: versions.length ? versions[0].version : null,
    latest_heading: versions.length ? versions[0].heading : null,
    all_versions: versions.map((v) => v.version),
    content,
  });
}
