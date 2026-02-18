/**
 * discussions.js — Discussion operations for gh-manager
 *
 * Commands:
 *   discussions list --repo [--category] [--limit]
 *   discussions comment --repo --discussion --body [--dry-run]
 *   discussions close --repo --discussion [--reason] [--dry-run]
 *
 * Uses GraphQL API — REST support for discussions is very limited.
 * Discussions require the repository to have discussions enabled.
 */

import { getGraphQL, parseRepo } from '../client.js';
import { success, error } from '../util/output.js';

/**
 * List discussions with unanswered/stale classification.
 */
export async function list(options) {
  const { owner, repo } = parseRepo(options.repo);
  const graphql = getGraphQL();
  const limit = options.limit ? parseInt(options.limit, 10) : 25;

  try {
    const result = await graphql(`
      query($owner: String!, $repo: String!, $first: Int!, $categoryId: ID) {
        repository(owner: $owner, name: $repo) {
          discussions(first: $first, orderBy: {field: UPDATED_AT, direction: DESC}, categoryId: $categoryId) {
            totalCount
            nodes {
              id
              number
              title
              author { login }
              createdAt
              updatedAt
              isAnswered
              answerChosenAt
              answerChosenBy { login }
              category { id name emoji isAnswerable }
              comments { totalCount }
              labels(first: 5) {
                nodes { name }
              }
              closed
              closedAt
            }
          }
          discussionCategories(first: 20) {
            nodes { id name emoji isAnswerable }
          }
        }
      }
    `, { owner, repo, first: limit, categoryId: options.category || null });

    const repoData = result.repository;
    const discussions = repoData.discussions.nodes || [];
    const categories = repoData.discussionCategories.nodes || [];

    const now = new Date();

    const trimmed = discussions.map((d) => {
      const updatedAt = new Date(d.updatedAt);
      const ageDays = Math.floor((now - updatedAt) / (1000 * 60 * 60 * 24));
      const isUnanswered = d.category?.isAnswerable && !d.isAnswered;
      const hasNoReplies = d.comments.totalCount === 0;

      return {
        id: d.id,
        number: d.number,
        title: d.title,
        author: d.author?.login || null,
        created_at: d.createdAt,
        updated_at: d.updatedAt,
        age_days: ageDays,
        category: d.category?.name || null,
        category_emoji: d.category?.emoji || null,
        is_answerable: d.category?.isAnswerable || false,
        is_answered: d.isAnswered || false,
        is_unanswered: isUnanswered,
        has_no_replies: hasNoReplies,
        comment_count: d.comments.totalCount,
        labels: (d.labels?.nodes || []).map((l) => l.name),
        closed: d.closed,
        closed_at: d.closedAt,
        needs_attention: isUnanswered || hasNoReplies,
      };
    });

    // Summary
    const open = trimmed.filter((d) => !d.closed);
    const unanswered = trimmed.filter((d) => d.is_unanswered);
    const noReplies = trimmed.filter((d) => d.has_no_replies && !d.closed);
    const needsAttention = trimmed.filter((d) => d.needs_attention && !d.closed);

    // By category
    const byCategory = {};
    for (const d of open) {
      const cat = d.category || 'Uncategorized';
      byCategory[cat] = (byCategory[cat] || 0) + 1;
    }

    success({
      total: repoData.discussions.totalCount,
      returned: trimmed.length,
      open_count: open.length,
      unanswered_count: unanswered.length,
      no_replies_count: noReplies.length,
      needs_attention_count: needsAttention.length,
      by_category: byCategory,
      categories: categories.map((c) => ({
        id: c.id,
        name: c.name,
        emoji: c.emoji,
        is_answerable: c.isAnswerable,
      })),
      discussions: trimmed,
    });
  } catch (err) {
    const msg = err.message || '';
    if (msg.includes('discussions are not enabled') ||
        msg.includes('Could not resolve to a Repository') ||
        (err.errors && err.errors.some((e) => e.type === 'NOT_FOUND'))) {
      success({
        enabled: false,
        total: 0,
        message: 'Discussions are not enabled on this repository',
        discussions: [],
      });
      return;
    }
    throw err;
  }
}

/**
 * Post a comment on a discussion.
 */
export async function comment(options) {
  const { owner, repo } = parseRepo(options.repo);
  const graphql = getGraphQL();
  const discussionNumber = parseInt(options.discussion, 10);

  if (options.dryRun) {
    success({
      dry_run: true,
      action: 'comment_discussion',
      discussion: discussionNumber,
      body_length: (options.body || '').length,
    });
    return;
  }

  // First, get the discussion node ID
  const lookup = await graphql(`
    query($owner: String!, $repo: String!, $number: Int!) {
      repository(owner: $owner, name: $repo) {
        discussion(number: $number) {
          id
        }
      }
    }
  `, { owner, repo, number: discussionNumber });

  const discussionId = lookup.repository.discussion.id;

  const result = await graphql(`
    mutation($discussionId: ID!, $body: String!) {
      addDiscussionComment(input: {discussionId: $discussionId, body: $body}) {
        comment {
          id
          createdAt
          author { login }
        }
      }
    }
  `, { discussionId, body: options.body });

  success({
    action: 'commented',
    discussion: discussionNumber,
    comment_id: result.addDiscussionComment.comment.id,
  });
}

/**
 * Close a discussion.
 * Reason: RESOLVED, OUTDATED, or DUPLICATE.
 */
export async function close(options) {
  const { owner, repo } = parseRepo(options.repo);
  const graphql = getGraphQL();
  const discussionNumber = parseInt(options.discussion, 10);

  if (options.dryRun) {
    success({
      dry_run: true,
      action: 'close_discussion',
      discussion: discussionNumber,
      reason: options.reason || 'RESOLVED',
    });
    return;
  }

  // Get the discussion node ID
  const lookup = await graphql(`
    query($owner: String!, $repo: String!, $number: Int!) {
      repository(owner: $owner, name: $repo) {
        discussion(number: $number) {
          id
        }
      }
    }
  `, { owner, repo, number: discussionNumber });

  const discussionId = lookup.repository.discussion.id;
  const reason = (options.reason || 'RESOLVED').toUpperCase();

  await graphql(`
    mutation($discussionId: ID!, $reason: DiscussionCloseReason!) {
      closeDiscussion(input: {discussionId: $discussionId, reason: $reason}) {
        discussion {
          id
          closed
          closedAt
        }
      }
    }
  `, { discussionId, reason });

  success({
    action: 'closed',
    discussion: discussionNumber,
    reason,
  });
}
