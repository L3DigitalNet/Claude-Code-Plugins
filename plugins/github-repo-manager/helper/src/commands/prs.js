/**
 * prs.js — Pull request operations for gh-manager
 *
 * Phase 1: list, create, label, comment
 * Phase 3: get, diff, comments, request-review, merge, close
 */

import { getOctokit, parseRepo } from '../client.js';
import { paginateRest } from '../util/paginate.js';
import { success, error } from '../util/output.js';

/**
 * List PRs with trimmed output.
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

  const prs = await paginateRest('pulls.list', params, limit);

  let filtered = prs;
  if (options.label) {
    const targetLabel = options.label.toLowerCase();
    filtered = prs.filter((pr) =>
      pr.labels.some((l) => l.name.toLowerCase() === targetLabel)
    );
  }

  const trimmed = filtered.map((pr) => ({
    number: pr.number,
    title: pr.title,
    author: pr.user?.login || null,
    state: pr.state,
    draft: pr.draft,
    created_at: pr.created_at,
    updated_at: pr.updated_at,
    labels: pr.labels.map((l) => l.name),
    head_branch: pr.head?.ref || null,
    base_branch: pr.base?.ref || null,
    mergeable: pr.mergeable,
    mergeable_state: pr.mergeable_state,
    additions: pr.additions,
    deletions: pr.deletions,
    changed_files: pr.changed_files,
  }));

  success({ count: trimmed.length, pull_requests: trimmed });
}

/**
 * Fetch single PR with full details.
 * Includes body, review status, CI status, and linked issues.
 */
export async function get(options) {
  const { owner, repo } = parseRepo(options.repo);
  const octokit = getOctokit();
  const prNumber = parseInt(options.pr, 10);

  const { data: pr } = await octokit.request(
    'GET /repos/{owner}/{repo}/pulls/{pull_number}',
    { owner, repo, pull_number: prNumber }
  );

  // Fetch reviews
  let reviews = [];
  try {
    const { data } = await octokit.request(
      'GET /repos/{owner}/{repo}/pulls/{pull_number}/reviews',
      { owner, repo, pull_number: prNumber }
    );
    reviews = data.map((r) => ({
      user: r.user?.login,
      state: r.state,
      submitted_at: r.submitted_at,
    }));
  } catch { /* reviews unavailable */ }

  // Fetch check runs for CI status
  let ciStatus = null;
  try {
    const { data: checks } = await octokit.request(
      'GET /repos/{owner}/{repo}/commits/{ref}/check-runs',
      { owner, repo, ref: pr.head.sha }
    );
    const total = checks.total_count;
    const passed = checks.check_runs.filter((c) => c.conclusion === 'success').length;
    const failed = checks.check_runs.filter((c) => c.conclusion === 'failure').length;
    const pending = checks.check_runs.filter((c) => c.status === 'in_progress' || c.status === 'queued').length;
    ciStatus = { total, passed, failed, pending, conclusion: failed > 0 ? 'failure' : pending > 0 ? 'pending' : 'success' };
  } catch { /* checks unavailable */ }

  // Determine review summary
  const latestReviews = {};
  for (const r of reviews) {
    if (!latestReviews[r.user] || r.submitted_at > latestReviews[r.user].submitted_at) {
      latestReviews[r.user] = r;
    }
  }
  const reviewStates = Object.values(latestReviews).map((r) => r.state);
  const reviewSummary = reviewStates.includes('CHANGES_REQUESTED')
    ? 'changes_requested'
    : reviewStates.includes('APPROVED')
      ? 'approved'
      : reviews.length > 0
        ? 'pending'
        : 'none';

  // Size classification
  const linesChanged = (pr.additions || 0) + (pr.deletions || 0);
  const size = linesChanged <= 50 ? 'S' : linesChanged <= 200 ? 'M' : linesChanged <= 500 ? 'L' : 'XL';

  success({
    number: pr.number,
    title: pr.title,
    body: pr.body || '',
    author: pr.user?.login || null,
    state: pr.state,
    draft: pr.draft,
    created_at: pr.created_at,
    updated_at: pr.updated_at,
    merged_at: pr.merged_at,
    labels: pr.labels.map((l) => l.name),
    head_branch: pr.head?.ref || null,
    base_branch: pr.base?.ref || null,
    mergeable: pr.mergeable,
    mergeable_state: pr.mergeable_state,
    additions: pr.additions,
    deletions: pr.deletions,
    changed_files: pr.changed_files,
    size,
    reviews,
    review_summary: reviewSummary,
    ci_status: ciStatus,
    requested_reviewers: (pr.requested_reviewers || []).map((r) => r.login),
  });
}

/**
 * Fetch PR diff — changed files with patch data.
 */
export async function diff(options) {
  const { owner, repo } = parseRepo(options.repo);
  const octokit = getOctokit();
  const prNumber = parseInt(options.pr, 10);

  const files = await paginateRest('pulls.listFiles', {
    owner,
    repo,
    pull_number: prNumber,
  });

  const trimmed = files.map((f) => ({
    filename: f.filename,
    status: f.status,
    additions: f.additions,
    deletions: f.deletions,
    changes: f.changes,
    patch: f.patch || null,
  }));

  success({ pr: prNumber, file_count: trimmed.length, files: trimmed });
}

/**
 * Fetch comments on a PR.
 * Used for dedup marker checking before posting maintenance comments.
 */
export async function comments(options) {
  const { owner, repo } = parseRepo(options.repo);
  const prNumber = parseInt(options.pr, 10);
  const limit = options.limit ? parseInt(options.limit, 10) : null;

  const allComments = await paginateRest('issues.listComments', {
    owner,
    repo,
    issue_number: prNumber,
  }, limit);

  const trimmed = allComments.map((c) => ({
    id: c.id,
    author: c.user?.login || null,
    body: c.body || '',
    created_at: c.created_at,
    updated_at: c.updated_at,
  }));

  success({ pr: prNumber, count: trimmed.length, comments: trimmed });
}

/**
 * Create a pull request.
 */
export async function create(options) {
  const { owner, repo } = parseRepo(options.repo);
  const octokit = getOctokit();

  if (options.dryRun) {
    success({
      dry_run: true,
      action: 'create_pr',
      head: options.head,
      base: options.base,
      title: options.title,
      body: options.body || null,
    });
    return;
  }

  const { data } = await octokit.request('POST /repos/{owner}/{repo}/pulls', {
    owner,
    repo,
    title: options.title,
    body: options.body || '',
    head: options.head,
    base: options.base,
  });

  if (options.label) {
    const labels = options.label.split(',').map((l) => l.trim());
    try {
      await octokit.request(
        'POST /repos/{owner}/{repo}/issues/{issue_number}/labels',
        { owner, repo, issue_number: data.number, labels }
      );
    } catch { /* non-critical */ }
  }

  success({
    action: 'created',
    number: data.number,
    title: data.title,
    url: data.html_url,
    head: data.head.ref,
    base: data.base.ref,
    labels: options.label ? options.label.split(',').map((l) => l.trim()) : [],
  });
}

/**
 * Add or remove labels on a PR.
 */
export async function label(options) {
  const { owner, repo } = parseRepo(options.repo);
  const octokit = getOctokit();
  const prNumber = parseInt(options.pr, 10);

  if (options.dryRun) {
    success({
      dry_run: true,
      action: 'label_pr',
      pr: prNumber,
      add: options.add ? options.add.split(',').map((l) => l.trim()) : [],
      remove: options.remove ? options.remove.split(',').map((l) => l.trim()) : [],
    });
    return;
  }

  const results = { added: [], removed: [], pr: prNumber };

  if (options.add) {
    const labels = options.add.split(',').map((l) => l.trim());
    await octokit.request(
      'POST /repos/{owner}/{repo}/issues/{issue_number}/labels',
      { owner, repo, issue_number: prNumber, labels }
    );
    results.added = labels;
  }

  if (options.remove) {
    const labels = options.remove.split(',').map((l) => l.trim());
    for (const labelName of labels) {
      try {
        await octokit.request(
          'DELETE /repos/{owner}/{repo}/issues/{issue_number}/labels/{name}',
          { owner, repo, issue_number: prNumber, name: labelName }
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
 * Post a comment on a PR.
 */
export async function comment(options) {
  const { owner, repo } = parseRepo(options.repo);
  const octokit = getOctokit();
  const prNumber = parseInt(options.pr, 10);

  if (options.dryRun) {
    success({
      dry_run: true,
      action: 'comment_pr',
      pr: prNumber,
      body_length: (options.body || '').length,
    });
    return;
  }

  const { data } = await octokit.request(
    'POST /repos/{owner}/{repo}/issues/{issue_number}/comments',
    { owner, repo, issue_number: prNumber, body: options.body }
  );

  success({
    action: 'commented',
    pr: prNumber,
    comment_id: data.id,
    url: data.html_url,
  });
}

/**
 * Request reviewers on a PR.
 */
export async function requestReview(options) {
  const { owner, repo } = parseRepo(options.repo);
  const octokit = getOctokit();
  const prNumber = parseInt(options.pr, 10);
  const reviewers = options.reviewers.split(',').map((r) => r.trim());

  if (options.dryRun) {
    success({
      dry_run: true,
      action: 'request_review',
      pr: prNumber,
      reviewers,
    });
    return;
  }

  // Separate user reviewers from team reviewers (teams use team_reviewers param)
  const userReviewers = reviewers.filter((r) => !r.includes('/'));
  const teamReviewers = reviewers.filter((r) => r.includes('/')).map((r) => r.split('/').pop());

  const params = { owner, repo, pull_number: prNumber };
  if (userReviewers.length) params.reviewers = userReviewers;
  if (teamReviewers.length) params.team_reviewers = teamReviewers;

  await octokit.request(
    'POST /repos/{owner}/{repo}/pulls/{pull_number}/requested_reviewers',
    params
  );

  success({
    action: 'review_requested',
    pr: prNumber,
    reviewers: userReviewers,
    team_reviewers: teamReviewers,
  });
}

/**
 * Merge a PR.
 * Supports merge, squash, and rebase strategies.
 */
export async function merge(options) {
  const { owner, repo } = parseRepo(options.repo);
  const octokit = getOctokit();
  const prNumber = parseInt(options.pr, 10);
  const method = options.method || 'merge';

  if (options.dryRun) {
    success({
      dry_run: true,
      action: 'merge_pr',
      pr: prNumber,
      method,
    });
    return;
  }

  const { data } = await octokit.request(
    'PUT /repos/{owner}/{repo}/pulls/{pull_number}/merge',
    {
      owner,
      repo,
      pull_number: prNumber,
      merge_method: method,
      commit_title: options.commitTitle || undefined,
    }
  );

  success({
    action: 'merged',
    pr: prNumber,
    method,
    sha: data.sha,
    message: data.message,
  });
}

/**
 * Close a PR with a comment.
 */
export async function close(options) {
  const { owner, repo } = parseRepo(options.repo);
  const octokit = getOctokit();
  const prNumber = parseInt(options.pr, 10);

  if (options.dryRun) {
    success({
      dry_run: true,
      action: 'close_pr',
      pr: prNumber,
      comment: options.body || null,
    });
    return;
  }

  // Post closing comment if provided
  if (options.body) {
    await octokit.request(
      'POST /repos/{owner}/{repo}/issues/{issue_number}/comments',
      { owner, repo, issue_number: prNumber, body: options.body }
    );
  }

  await octokit.request(
    'PATCH /repos/{owner}/{repo}/pulls/{pull_number}',
    { owner, repo, pull_number: prNumber, state: 'closed' }
  );

  success({
    action: 'closed',
    pr: prNumber,
    commented: !!options.body,
  });
}
