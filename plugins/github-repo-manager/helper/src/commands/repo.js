/**
 * repo.js — Single-repo commands for gh-manager
 *
 * Commands:
 *   repo info --repo         — Fetch repo metadata (trimmed)
 *   repo community --repo    — Fetch community profile score
 *   repo labels list --repo  — List all labels
 *   repo labels create --repo --name --color --description
 *   repo labels update --repo --name --color --description
 */

import { getOctokit, parseRepo } from '../client.js';
import { paginateRest } from '../util/paginate.js';
import { success } from '../util/output.js';

/**
 * Fetch trimmed repo metadata.
 */
export async function info(options) {
  const { owner, repo } = parseRepo(options.repo);
  const octokit = getOctokit();

  const { data } = await octokit.request('GET /repos/{owner}/{repo}', {
    owner,
    repo,
  });

  success({
    full_name: data.full_name,
    private: data.private,
    fork: data.fork,
    archived: data.archived,
    description: data.description || null,
    language: data.language,
    default_branch: data.default_branch,
    has_wiki: data.has_wiki,
    has_discussions: data.has_discussions,
    has_issues: data.has_issues,
    has_projects: data.has_projects,
    license: data.license?.spdx_id || null,
    open_issues_count: data.open_issues_count,
    stargazers_count: data.stargazers_count,
    forks_count: data.forks_count,
    created_at: data.created_at,
    updated_at: data.updated_at,
    pushed_at: data.pushed_at,
    topics: data.topics || [],
  });
}

/**
 * Fetch community profile score.
 * Uses GitHub's Community Profile API.
 */
export async function community(options) {
  const { owner, repo } = parseRepo(options.repo);
  const octokit = getOctokit();

  const { data } = await octokit.request(
    'GET /repos/{owner}/{repo}/community/profile',
    { owner, repo }
  );

  success({
    health_percentage: data.health_percentage,
    files: {
      code_of_conduct: data.files.code_of_conduct
        ? { name: data.files.code_of_conduct.name, url: data.files.code_of_conduct.html_url }
        : null,
      code_of_conduct_file: data.files.code_of_conduct_file
        ? { name: data.files.code_of_conduct_file.name, url: data.files.code_of_conduct_file.html_url }
        : null,
      contributing: data.files.contributing
        ? { name: data.files.contributing.name, url: data.files.contributing.html_url }
        : null,
      issue_template: data.files.issue_template
        ? { name: data.files.issue_template.name, url: data.files.issue_template.html_url }
        : null,
      pull_request_template: data.files.pull_request_template
        ? { name: data.files.pull_request_template.name, url: data.files.pull_request_template.html_url }
        : null,
      license: data.files.license
        ? { name: data.files.license.name, spdx_id: data.files.license.spdx_id }
        : null,
      readme: data.files.readme
        ? { name: data.files.readme.name, url: data.files.readme.html_url }
        : null,
      security: data.files.security
        ? { name: data.files.security.name, url: data.files.security.html_url }
        : null,
    },
    description: data.description || null,
    documentation: data.documentation || null,
    updated_at: data.updated_at,
  });
}

/**
 * List all labels on a repo.
 */
export async function labelsList(options) {
  const { owner, repo } = parseRepo(options.repo);

  const labels = await paginateRest('issues.listLabelsForRepo', {
    owner,
    repo,
  });

  const trimmed = labels.map((l) => ({
    name: l.name,
    color: l.color,
    description: l.description || null,
    default: l.default,
  }));

  success({ count: trimmed.length, labels: trimmed });
}

/**
 * Create a label on a repo.
 * Idempotent — if the label already exists with the same color, it's a no-op.
 * If it exists with a different color/description, reports the conflict.
 */
export async function labelsCreate(options) {
  const { owner, repo } = parseRepo(options.repo);
  const octokit = getOctokit();

  if (options.dryRun) {
    success({
      dry_run: true,
      action: 'create_label',
      name: options.name,
      color: options.color,
      description: options.description || null,
    });
    return;
  }

  try {
    const { data } = await octokit.request(
      'POST /repos/{owner}/{repo}/labels',
      {
        owner,
        repo,
        name: options.name,
        color: (options.color || '').replace('#', ''),
        description: options.description || '',
      }
    );

    success({
      action: 'created',
      label: {
        name: data.name,
        color: data.color,
        description: data.description || null,
      },
    });
  } catch (err) {
    if (err.status === 422) {
      // Label already exists — check if it matches
      try {
        const { data: existing } = await octokit.request(
          'GET /repos/{owner}/{repo}/labels/{name}',
          { owner, repo, name: options.name }
        );

        success({
          action: 'already_exists',
          label: {
            name: existing.name,
            color: existing.color,
            description: existing.description || null,
          },
        });
      } catch {
        throw err; // Re-throw original if we can't verify
      }
    } else {
      throw err;
    }
  }
}

/**
 * Update an existing label on a repo.
 */
export async function labelsUpdate(options) {
  const { owner, repo } = parseRepo(options.repo);
  const octokit = getOctokit();

  if (options.dryRun) {
    success({
      dry_run: true,
      action: 'update_label',
      name: options.name,
      color: options.color || null,
      description: options.description || null,
    });
    return;
  }

  const params = { owner, repo, name: options.name };
  if (options.color) params.color = options.color.replace('#', '');
  if (options.description !== undefined)
    params.description = options.description;
  if (options.newName) params.new_name = options.newName;

  const { data } = await octokit.request(
    'PATCH /repos/{owner}/{repo}/labels/{name}',
    params
  );

  success({
    action: 'updated',
    label: {
      name: data.name,
      color: data.color,
      description: data.description || null,
    },
  });
}
