/**
 * notifications.js — Notification operations for gh-manager
 *
 * Commands:
 *   notifications list --repo [--all] [--limit]
 *   notifications mark-read --repo [--thread-id] [--dry-run]
 *
 * Fetches notifications scoped to a specific repo and categorizes
 * them by type and priority for the skill layer to triage.
 */

import { getOctokit, parseRepo } from '../client.js';
import { paginateRest } from '../util/paginate.js';
import { success } from '../util/output.js';

/**
 * Priority classification per design doc Section 5.4.
 */
function classifyPriority(notification) {
  const type = notification.subject?.type || '';
  const reason = notification.reason || '';
  const title = (notification.subject?.title || '').toLowerCase();

  // Critical: security alerts, CI failures on default branch
  if (type === 'SecurityAlert' || type === 'RepositoryVulnerabilityAlert') return 'critical';
  if (type === 'CheckSuite' && title.includes('fail')) return 'critical';

  // High: review requests, direct mentions, assigned issues
  if (reason === 'review_requested') return 'high';
  if (reason === 'mention') return 'high';
  if (reason === 'assign') return 'high';
  if (reason === 'author' && type === 'Issue') return 'high';

  // Medium: PR activity, discussion replies
  if (type === 'PullRequest' && reason === 'subscribed') return 'medium';
  if (type === 'Discussion') return 'medium';
  if (reason === 'comment') return 'medium';

  // Low: bot activity, subscription updates
  if (reason === 'ci_activity') return 'low';
  if (reason === 'subscribed') return 'low';

  return 'medium'; // Default
}

/**
 * Categorize notification by type.
 */
function categorizeType(notification) {
  const type = notification.subject?.type || 'Unknown';
  const reason = notification.reason || '';

  if (type === 'SecurityAlert' || type === 'RepositoryVulnerabilityAlert') return 'security_alert';
  if (type === 'PullRequest' && reason === 'review_requested') return 'review_requested';
  if (type === 'PullRequest') return 'pr_activity';
  if (type === 'Issue' && reason === 'assign') return 'assigned';
  if (type === 'Issue') return 'issue_activity';
  if (type === 'Discussion') return 'discussion';
  if (reason === 'mention') return 'mention';
  if (type === 'CheckSuite') return 'ci_activity';
  return 'other';
}

/**
 * List notifications for a repo, categorized by priority and type.
 */
export async function list(options) {
  const { owner, repo } = parseRepo(options.repo);
  const octokit = getOctokit();
  const limit = options.limit ? parseInt(options.limit, 10) : null;

  // GitHub doesn't support repo filtering in the list endpoint via Octokit paginate,
  // so we use the direct request
  const params = {
    all: options.all || false,
    per_page: 100,
  };

  let notifications = [];
  try {
    const { data } = await octokit.request('GET /notifications', params);
    notifications = data;
  } catch (err) {
    // Paginate manually if needed
    throw err;
  }

  // Filter to the target repo
  const repoFullName = `${owner}/${repo}`;
  const filtered = notifications.filter(
    (n) => n.repository?.full_name === repoFullName
  );

  const limited = limit ? filtered.slice(0, limit) : filtered;

  const trimmed = limited.map((n) => ({
    id: n.id,
    type: categorizeType(n),
    priority: classifyPriority(n),
    reason: n.reason,
    subject_type: n.subject?.type || null,
    subject_title: n.subject?.title || null,
    subject_url: n.subject?.url || null,
    unread: n.unread,
    updated_at: n.updated_at,
    last_read_at: n.last_read_at,
  }));

  // Summary by priority
  const summary = { critical: 0, high: 0, medium: 0, low: 0 };
  for (const n of trimmed) {
    summary[n.priority] = (summary[n.priority] || 0) + 1;
  }

  // Summary by type
  const byType = {};
  for (const n of trimmed) {
    byType[n.type] = (byType[n.type] || 0) + 1;
  }

  success({
    count: trimmed.length,
    unread: trimmed.filter((n) => n.unread).length,
    summary_by_priority: summary,
    summary_by_type: byType,
    notifications: trimmed,
  });
}

/**
 * Mark notifications as read.
 * If --thread-id is specified, marks only that thread.
 * Otherwise, marks all repo notifications as read.
 */
export async function markRead(options) {
  const { owner, repo } = parseRepo(options.repo);
  const octokit = getOctokit();

  if (options.dryRun) {
    success({
      dry_run: true,
      action: 'mark_read',
      scope: options.threadId ? `thread ${options.threadId}` : `all for ${owner}/${repo}`,
    });
    return;
  }

  if (options.threadId) {
    // Mark single thread
    await octokit.request(
      'PATCH /notifications/threads/{thread_id}',
      { thread_id: options.threadId }
    );

    success({
      action: 'marked_read',
      thread_id: options.threadId,
    });
  } else {
    // Mark all for repo
    await octokit.request(
      'PUT /repos/{owner}/{repo}/notifications',
      { owner, repo, last_read_at: new Date().toISOString() }
    );

    success({
      action: 'marked_all_read',
      repo: `${owner}/${repo}`,
    });
  }
}
