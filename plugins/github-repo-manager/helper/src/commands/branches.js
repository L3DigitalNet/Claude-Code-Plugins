/**
 * branches.js — Branch operations for gh-manager
 *
 * Commands:
 *   branches list --repo                          — List branches
 *   branches create --repo --branch --from        — Create branch from ref
 *   branches delete --repo --branch [--dry-run]   — Delete a branch
 *
 * Used primarily for Tier 4 PR workflows where file mutations
 * go through maintenance branches → PRs.
 */

import { getOctokit, parseRepo } from '../client.js';
import { paginateRest } from '../util/paginate.js';
import { success } from '../util/output.js';

/**
 * List branches on a repo.
 * Returns trimmed branch data.
 */
export async function list(options) {
  const { owner, repo } = parseRepo(options.repo);
  const limit = options.limit ? parseInt(options.limit, 10) : null;

  const branches = await paginateRest('repos.listBranches', {
    owner,
    repo,
    protected: options.protected === true ? true : undefined,
  }, limit);

  const trimmed = branches.map((b) => ({
    name: b.name,
    sha: b.commit.sha,
    protected: b.protected,
  }));

  success({ count: trimmed.length, branches: trimmed });
}

/**
 * Create a branch from a ref (branch name, tag, or SHA).
 * Used for Tier 4 maintenance branch workflow.
 *
 * Idempotent: if the branch already exists pointing at the same ref, no-op.
 * If it exists pointing at a different ref, reports the conflict.
 */
export async function create(options) {
  const { owner, repo } = parseRepo(options.repo);
  const octokit = getOctokit();

  // Short-circuit before any network calls
  if (options.dryRun) {
    success({
      dry_run: true,
      action: 'create_branch',
      branch: options.branch,
      from: options.from,
    });
    return;
  }

  // Resolve the source ref to a SHA
  const { data: refData } = await octokit.request(
    'GET /repos/{owner}/{repo}/git/ref/{ref}',
    {
      owner,
      repo,
      ref: `heads/${options.from}`,
    }
  );
  const sourceSha = refData.object.sha;

  try {
    const { data } = await octokit.request(
      'POST /repos/{owner}/{repo}/git/refs',
      {
        owner,
        repo,
        ref: `refs/heads/${options.branch}`,
        sha: sourceSha,
      }
    );

    success({
      action: 'created',
      branch: options.branch,
      sha: data.object.sha,
      from: options.from,
    });
  } catch (err) {
    if (err.status === 422) {
      // Branch might already exist — check if it points to the same SHA
      try {
        const { data: existing } = await octokit.request(
          'GET /repos/{owner}/{repo}/git/ref/{ref}',
          { owner, repo, ref: `heads/${options.branch}` }
        );

        if (existing.object.sha === sourceSha) {
          success({
            action: 'already_exists',
            branch: options.branch,
            sha: existing.object.sha,
            from: options.from,
          });
        } else {
          success({
            action: 'conflict',
            branch: options.branch,
            existing_sha: existing.object.sha,
            requested_sha: sourceSha,
            message: `Branch "${options.branch}" already exists but points to a different commit.`,
          });
        }
      } catch {
        throw err;
      }
    } else {
      throw err;
    }
  }
}

/**
 * Delete a branch.
 * ⚠️ Irreversible — commits on this branch may become unreachable.
 */
export async function del(options) {
  const { owner, repo } = parseRepo(options.repo);
  const octokit = getOctokit();

  if (options.dryRun) {
    success({
      dry_run: true,
      action: 'delete_branch',
      branch: options.branch,
    });
    return;
  }

  await octokit.request('DELETE /repos/{owner}/{repo}/git/refs/{ref}', {
    owner,
    repo,
    ref: `heads/${options.branch}`,
  });

  success({
    action: 'deleted',
    branch: options.branch,
  });
}
