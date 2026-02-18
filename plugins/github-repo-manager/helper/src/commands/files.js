/**
 * files.js — File operations for gh-manager
 *
 * Commands:
 *   files exists --repo --path            — Check if file exists (exit code 0/1)
 *   files get --repo --path [--branch]    — Fetch file content
 *   files put --repo --path --message [--branch] [--dry-run]  — Create/update file (stdin)
 *   files delete --repo --path --message [--branch] [--dry-run]  — Delete file
 *
 * Uses GitHub Contents API. File content for put is read from stdin.
 * SHA-conditional updates: put fetches current SHA before updating.
 * Design principle 6: Idempotent where possible.
 */

import { getOctokit, parseRepo } from '../client.js';
import { success, error } from '../util/output.js';

/**
 * Check if a file exists in the repo.
 * Exit code 0 = exists, exit code 1 = not found.
 */
export async function exists(options) {
  const { owner, repo } = parseRepo(options.repo);
  const octokit = getOctokit();
  const ref = options.branch || undefined;

  try {
    const { data } = await octokit.request(
      'GET /repos/{owner}/{repo}/contents/{path}',
      { owner, repo, path: options.path, ...(ref ? { ref } : {}) }
    );

    success({
      exists: true,
      path: options.path,
      type: data.type,
      size: data.size,
      sha: data.sha,
    });
  } catch (err) {
    if (err.status === 404) {
      // Not found is a valid result, not an error
      success({ exists: false, path: options.path });
    } else {
      throw err;
    }
  }
}

/**
 * Fetch file content from the repo.
 * Returns decoded content (base64 → UTF-8), path, sha, size.
 */
export async function get(options) {
  const { owner, repo } = parseRepo(options.repo);
  const octokit = getOctokit();
  const ref = options.branch || undefined;

  const { data } = await octokit.request(
    'GET /repos/{owner}/{repo}/contents/{path}',
    { owner, repo, path: options.path, ...(ref ? { ref } : {}) }
  );

  if (data.type !== 'file') {
    error(
      `Path "${options.path}" is a ${data.type}, not a file`,
      422,
      `GET /repos/${owner}/${repo}/contents/${options.path}`
    );
    return;
  }

  const content = Buffer.from(data.content, 'base64').toString('utf-8');

  success({
    path: data.path,
    sha: data.sha,
    size: data.size,
    encoding: 'utf-8',
    content,
  });
}

/**
 * Create or update a file in the repo.
 * Content is read from stdin.
 *
 * For updates: fetches current SHA first (idempotent — won't clobber concurrent changes).
 * For creates: no SHA needed.
 *
 * --branch targets a specific branch (for Tier 4 PR workflows).
 * Without --branch, targets the default branch.
 */
export async function put(options) {
  const { owner, repo } = parseRepo(options.repo);
  const octokit = getOctokit();

  // Read content from stdin
  const content = await readStdin();
  if (!content && content !== '') {
    error('No content provided on stdin', 400);
    return;
  }

  // Short-circuit before any network calls
  if (options.dryRun) {
    success({
      dry_run: true,
      action: 'create_or_update',
      path: options.path,
      branch: options.branch || '(default)',
      message: options.message || `Update ${options.path}`,
      content_length: content.length,
    });
    return;
  }

  const params = {
    owner,
    repo,
    path: options.path,
    message: options.message || `Update ${options.path}`,
    content: Buffer.from(content).toString('base64'),
  };

  if (options.branch) {
    params.branch = options.branch;
  }

  // Check if file already exists to get SHA for update
  let existingSha = null;
  try {
    const { data: existing } = await octokit.request(
      'GET /repos/{owner}/{repo}/contents/{path}',
      {
        owner,
        repo,
        path: options.path,
        ...(options.branch ? { ref: options.branch } : {}),
      }
    );
    existingSha = existing.sha;
  } catch (err) {
    if (err.status !== 404) throw err;
    // 404 = new file, no SHA needed
  }

  if (existingSha) {
    params.sha = existingSha;
  }

  const { data } = await octokit.request(
    'PUT /repos/{owner}/{repo}/contents/{path}',
    params
  );

  success({
    action: existingSha ? 'updated' : 'created',
    path: data.content.path,
    sha: data.content.sha,
    size: data.content.size,
    branch: options.branch || data.commit.parents?.[0]?.sha ? '(default)' : '(default)',
    commit_sha: data.commit.sha,
    commit_message: data.commit.message,
  });
}

/**
 * Delete a file from the repo.
 * Fetches current SHA first (required by API).
 */
export async function del(options) {
  const { owner, repo } = parseRepo(options.repo);
  const octokit = getOctokit();

  // Short-circuit before any network calls
  if (options.dryRun) {
    success({
      dry_run: true,
      action: 'delete',
      path: options.path,
      branch: options.branch || '(default)',
      message: options.message || `Delete ${options.path}`,
    });
    return;
  }

  // Fetch current SHA (required for delete)
  const { data: existing } = await octokit.request(
    'GET /repos/{owner}/{repo}/contents/{path}',
    {
      owner,
      repo,
      path: options.path,
      ...(options.branch ? { ref: options.branch } : {}),
    }
  );

  const params = {
    owner,
    repo,
    path: options.path,
    message: options.message || `Delete ${options.path}`,
    sha: existing.sha,
  };

  if (options.branch) {
    params.branch = options.branch;
  }

  await octokit.request('DELETE /repos/{owner}/{repo}/contents/{path}', params);

  success({
    action: 'deleted',
    path: options.path,
    sha: existing.sha,
    message: params.message,
  });
}

/**
 * Read all of stdin as a string.
 */
function readStdin() {
  return new Promise((resolve, reject) => {
    // If stdin is a TTY (no pipe), return empty
    if (process.stdin.isTTY) {
      resolve('');
      return;
    }

    const chunks = [];
    process.stdin.setEncoding('utf-8');
    process.stdin.on('data', (chunk) => chunks.push(chunk));
    process.stdin.on('end', () => resolve(chunks.join('')));
    process.stdin.on('error', reject);
  });
}
