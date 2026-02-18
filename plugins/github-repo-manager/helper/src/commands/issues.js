/**
 * issues.js — Issue operations for gh-manager
 *
 * Commands:
 *   issues list --repo [--state] [--label] [--limit]
 *   issues get --repo --issue
 *   issues comments --repo --issue [--limit]
 *   issues label --repo --issue --add [--remove] [--dry-run]
 *   issues comment --repo --issue --body [--dry-run]
 *   issues close --repo --issue [--body] [--reason] [--dry-run]
 *   issues assign --repo --issue --assignees [--dry-run]
 *
 * Note: GitHub's issues endpoint includes PRs. All list operations
 * filter out pull_request objects so only true issues are returned.
 */

import { getOctokit, parseRepo } from '../client.js';
import { paginateRest } from '../util/paginate.js';
import { success } from '../util/output.js';

/**
 * List open issues (excluding PRs).
 */
export async function list(options) {
  const { owner, repo } = parseRepo(options.repo);
  const limit = options.limit ? parseInt(options.limit, 10) : null;

  const params = {
    owner,
    repo,
    state: options.state || 'open',
    sort: 'updated',
    direction: 'desc',
  };

  if (options.label) params.labels = options.label;

  const items = await paginateRest('issues.listForRepo', params, limit ? limit + 50 : null);

  // Filter out PRs (they have pull_request key)
  const issues = items.filter((i) => !i.pull_request);
  const trimmed = (limit ? issues.slice(0, limit) : issues).map((i) => ({
    number: i.number,
    title: i.title,
    author: i.user?.login || null,
    state: i.state,
    state_reason: i.state_reason || null,
    created_at: i.created_at,
    updated_at: i.updated_at,
    closed_at: i.closed_at,
    labels: i.labels.map((l) => (typeof l === 'string' ? l : l.name)),
    assignees: (i.assignees || []).map((a) => a.login),
    comments: i.comments,
    milestone: i.milestone?.title || null,
    linked_prs: [],  // Requires separate lookup if needed
  }));

  success({ count: trimmed.length, issues: trimmed });
}

/**
 * Fetch single issue with full details.
 */
export async function get(options) {
  const { owner, repo } = parseRepo(options.repo);
  const octokit = getOctokit();
  const issueNumber = parseInt(options.issue, 10);

  const { data: issue } = await octokit.request(
    'GET /repos/{owner}/{repo}/issues/{issue_number}',
    { owner, repo, issue_number: issueNumber }
  );

  // Check for linked PRs via timeline events
  let linkedPRs = [];
  try {
    const { data: events } = await octokit.request(
      'GET /repos/{owner}/{repo}/issues/{issue_number}/timeline',
      { owner, repo, issue_number: issueNumber, per_page: 100 }
    );
    linkedPRs = events
      .filter((e) => e.event === 'cross-referenced' && e.source?.issue?.pull_request)
      .map((e) => ({
        number: e.source.issue.number,
        title: e.source.issue.title,
        state: e.source.issue.state,
        merged: !!e.source.issue.pull_request?.merged_at,
      }));
  } catch { /* timeline API may not be available */ }

  success({
    number: issue.number,
    title: issue.title,
    body: issue.body || '',
    author: issue.user?.login || null,
    state: issue.state,
    state_reason: issue.state_reason || null,
    created_at: issue.created_at,
    updated_at: issue.updated_at,
    closed_at: issue.closed_at,
    labels: issue.labels.map((l) => (typeof l === 'string' ? l : l.name)),
    assignees: (issue.assignees || []).map((a) => a.login),
    comments: issue.comments,
    milestone: issue.milestone?.title || null,
    linked_prs: linkedPRs,
    is_pull_request: !!issue.pull_request,
  });
}

/**
 * Fetch comments on an issue.
 * Used for dedup marker checking before posting.
 */
export async function issueComments(options) {
  const { owner, repo } = parseRepo(options.repo);
  const issueNumber = parseInt(options.issue, 10);
  const limit = options.limit ? parseInt(options.limit, 10) : null;

  const allComments = await paginateRest('issues.listComments', {
    owner,
    repo,
    issue_number: issueNumber,
  }, limit);

  const trimmed = allComments.map((c) => ({
    id: c.id,
    author: c.user?.login || null,
    body: c.body || '',
    created_at: c.created_at,
    updated_at: c.updated_at,
  }));

  success({ issue: issueNumber, count: trimmed.length, comments: trimmed });
}

/**
 * Add or remove labels on an issue.
 */
export async function label(options) {
  const { owner, repo } = parseRepo(options.repo);
  const octokit = getOctokit();
  const issueNumber = parseInt(options.issue, 10);

  if (options.dryRun) {
    success({
      dry_run: true,
      action: 'label_issue',
      issue: issueNumber,
      add: options.add ? options.add.split(',').map((l) => l.trim()) : [],
      remove: options.remove ? options.remove.split(',').map((l) => l.trim()) : [],
    });
    return;
  }

  const results = { added: [], removed: [], issue: issueNumber };

  if (options.add) {
    const labels = options.add.split(',').map((l) => l.trim());
    await octokit.request(
      'POST /repos/{owner}/{repo}/issues/{issue_number}/labels',
      { owner, repo, issue_number: issueNumber, labels }
    );
    results.added = labels;
  }

  if (options.remove) {
    const labels = options.remove.split(',').map((l) => l.trim());
    for (const labelName of labels) {
      try {
        await octokit.request(
          'DELETE /repos/{owner}/{repo}/issues/{issue_number}/labels/{name}',
          { owner, repo, issue_number: issueNumber, name: labelName }
        );
        results.removed.push(labelName);
      } catch (err) {
        if (err.status !== 404) throw err;
      }
    }
  }

  success({ action: 'labeled', ...results });
}

/**
 * Post a comment on an issue.
 */
export async function comment(options) {
  const { owner, repo } = parseRepo(options.repo);
  const octokit = getOctokit();
  const issueNumber = parseInt(options.issue, 10);

  if (options.dryRun) {
    success({
      dry_run: true,
      action: 'comment_issue',
      issue: issueNumber,
      body_length: (options.body || '').length,
    });
    return;
  }

  const { data } = await octokit.request(
    'POST /repos/{owner}/{repo}/issues/{issue_number}/comments',
    { owner, repo, issue_number: issueNumber, body: options.body }
  );

  success({
    action: 'commented',
    issue: issueNumber,
    comment_id: data.id,
    url: data.html_url,
  });
}

/**
 * Close an issue with optional comment.
 * Supports state_reason: completed (default) or not_planned.
 */
export async function close(options) {
  const { owner, repo } = parseRepo(options.repo);
  const octokit = getOctokit();
  const issueNumber = parseInt(options.issue, 10);

  if (options.dryRun) {
    success({
      dry_run: true,
      action: 'close_issue',
      issue: issueNumber,
      reason: options.reason || 'completed',
      comment: options.body || null,
    });
    return;
  }

  if (options.body) {
    await octokit.request(
      'POST /repos/{owner}/{repo}/issues/{issue_number}/comments',
      { owner, repo, issue_number: issueNumber, body: options.body }
    );
  }

  await octokit.request(
    'PATCH /repos/{owner}/{repo}/issues/{issue_number}',
    {
      owner,
      repo,
      issue_number: issueNumber,
      state: 'closed',
      state_reason: options.reason || 'completed',
    }
  );

  success({
    action: 'closed',
    issue: issueNumber,
    reason: options.reason || 'completed',
    commented: !!options.body,
  });
}

/**
 * Assign an issue to one or more users.
 */
export async function assign(options) {
  const { owner, repo } = parseRepo(options.repo);
  const octokit = getOctokit();
  const issueNumber = parseInt(options.issue, 10);
  const assignees = options.assignees.split(',').map((a) => a.trim());

  if (options.dryRun) {
    success({
      dry_run: true,
      action: 'assign_issue',
      issue: issueNumber,
      assignees,
    });
    return;
  }

  await octokit.request(
    'POST /repos/{owner}/{repo}/issues/{issue_number}/assignees',
    { owner, repo, issue_number: issueNumber, assignees }
  );

  success({
    action: 'assigned',
    issue: issueNumber,
    assignees,
  });
}
