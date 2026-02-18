/**
 * wiki.js — Wiki operations for gh-manager
 *
 * Commands:
 *   wiki clone --repo --dir           — Clone wiki repo to temp directory
 *   wiki init --repo [--dry-run]      — Initialize wiki (create Home page)
 *   wiki diff --dir --content-dir     — Diff generated content vs current wiki
 *   wiki push --dir --message [--dry-run]  — Commit and push changes
 *   wiki cleanup --dir                — Remove temp clone directory
 *
 * This module is the one exception to "API only" — wiki content
 * is managed exclusively through git, not the REST API.
 * Uses simple-git for all git operations.
 * PAT authentication via HTTPS: https://{PAT}@github.com/{owner}/{repo}.wiki.git
 */

import { simpleGit } from 'simple-git';
import { parseRepo } from '../client.js';
import { success, error } from '../util/output.js';
import { existsSync, mkdirSync, readdirSync, readFileSync, writeFileSync, rmSync, statSync, cpSync } from 'fs';
import { join, basename, relative } from 'path';

/**
 * Build the authenticated wiki git URL.
 */
function wikiUrl(owner, repo) {
  const pat = process.env.GITHUB_PAT;
  if (!pat) throw new Error('GITHUB_PAT is not set');
  return `https://${pat}@github.com/${owner}/${repo}.wiki.git`;
}

/**
 * Clone the wiki repo to a local directory.
 * Detects wiki-not-initialized state (repo doesn't exist).
 */
export async function clone(options) {
  const { owner, repo } = parseRepo(options.repo);
  const dir = options.dir;

  if (!dir) {
    error('--dir is required', 400);
    return;
  }

  // Create target directory if it doesn't exist
  if (!existsSync(dir)) {
    mkdirSync(dir, { recursive: true });
  }

  const url = wikiUrl(owner, repo);
  const git = simpleGit();

  try {
    await git.clone(url, dir);

    // Count pages (markdown files, excluding _Sidebar, _Footer)
    const files = readdirSync(dir).filter(
      (f) => f.endsWith('.md') && !f.startsWith('.')
    );
    const pages = files.map((f) => ({
      name: f.replace(/\.md$/, ''),
      filename: f,
    }));

    success({
      status: 'cloned',
      dir,
      page_count: pages.length,
      pages,
    });
  } catch (err) {
    const pat = process.env.GITHUB_PAT;
    const msg = err.message || '';
    // GitHub returns 404 / "not found" when wiki repo doesn't exist
    if (
      msg.includes('not found') ||
      msg.includes('Repository not found') ||
      msg.includes('fatal: repository')
    ) {
      success({
        status: 'wiki_not_initialized',
        wiki_enabled: true,
        pages: 0,
        message:
          'Wiki is enabled but has no pages. The wiki git repo does not exist yet.',
      });
    } else {
      const sanitizedMsg = (err.message || '').replace(pat, '***');
      const sanitizedErr = new Error(sanitizedMsg);
      sanitizedErr.code = err.code;
      throw sanitizedErr;
    }
  }
}

/**
 * Initialize a wiki by pushing a starter Home page.
 * GitHub creates the wiki repo on receiving the first push.
 *
 * Internally:
 * 1. Create temp dir with Home.md
 * 2. git init, add remote, commit, push
 * 3. Clean up temp dir
 */
export async function init(options) {
  const { owner, repo } = parseRepo(options.repo);

  if (options.dryRun) {
    success({
      dry_run: true,
      action: 'initialize_wiki',
      repo: `${owner}/${repo}`,
      message: 'Would create Home.md and push to initialize wiki repo',
    });
    return;
  }

  const tmpDir = `/tmp/wiki-init-${repo}-${Date.now()}`;
  mkdirSync(tmpDir, { recursive: true });

  try {
    // Create starter Home page
    const homePath = join(tmpDir, 'Home.md');
    const homeContent = [
      `# ${repo}`,
      '',
      `Welcome to the ${repo} wiki!`,
      '',
      'This wiki is automatically maintained from the repository documentation.',
      'Do not edit wiki pages directly — changes will be overwritten on the next sync.',
      '',
      '---',
      `*Initialized by GitHub Repo Manager*`,
    ].join('\n');

    writeFileSync(homePath, homeContent, 'utf-8');

    // Git init, add remote, commit, push
    const git = simpleGit(tmpDir);
    await git.init();
    await git.addRemote('origin', wikiUrl(owner, repo));
    await git.add('.');
    await git.commit('Initialize wiki');
    // GitHub wiki repos always use 'master' as their default branch,
    // regardless of the parent repo's default branch setting.
    await git.push('origin', 'master', ['--force']);

    success({
      action: 'initialized',
      repo: `${owner}/${repo}`,
      page: 'Home.md',
      message: 'Wiki initialized with starter Home page',
    });
  } catch (err) {
    const pat = process.env.GITHUB_PAT;
    const sanitizedMsg = (err.message || '').replace(pat, '***');
    const sanitizedErr = new Error(sanitizedMsg);
    sanitizedErr.code = err.code;
    throw sanitizedErr;
  } finally {
    // Always clean up
    try {
      rmSync(tmpDir, { recursive: true, force: true });
    } catch { /* ignore cleanup errors */ }
  }
}

/**
 * Diff generated content against current wiki pages.
 *
 * Compares files in --content-dir (generated by Claude) against
 * files in --dir (cloned wiki). Reports:
 * - new: pages in content-dir but not wiki
 * - modified: pages in both but content differs
 * - unchanged: pages in both with identical content
 * - orphaned: pages in wiki but not in content-dir
 *
 * Does NOT include _Sidebar.md and _Footer.md in orphan detection
 * (these are scaffolding files managed separately).
 */
export async function diff(options) {
  const wikiDir = options.dir;
  const contentDir = options.contentDir;

  if (!wikiDir || !contentDir) {
    error('Both --dir (wiki clone) and --content-dir (generated content) are required', 400);
    return;
  }

  if (!existsSync(wikiDir)) {
    error(`Wiki directory does not exist: ${wikiDir}`, 404);
    return;
  }
  if (!existsSync(contentDir)) {
    error(`Content directory does not exist: ${contentDir}`, 404);
    return;
  }

  // Scaffolding files excluded from orphan detection
  const scaffolding = new Set(['_Sidebar.md', '_Footer.md']);

  // Gather wiki pages
  const wikiFiles = readdirSync(wikiDir).filter(
    (f) => f.endsWith('.md') && !f.startsWith('.')
  );
  const wikiSet = new Set(wikiFiles);

  // Gather generated pages
  const contentFiles = readdirSync(contentDir).filter(
    (f) => f.endsWith('.md') && !f.startsWith('.')
  );
  const contentSet = new Set(contentFiles);

  const results = {
    new_pages: [],
    modified: [],
    unchanged: [],
    orphaned: [],
    summary: { new: 0, modified: 0, unchanged: 0, orphaned: 0 },
  };

  // Check content pages against wiki
  for (const file of contentFiles) {
    const contentPath = join(contentDir, file);
    const contentText = readFileSync(contentPath, 'utf-8');

    if (!wikiSet.has(file)) {
      // New page
      results.new_pages.push({
        page: file.replace(/\.md$/, ''),
        filename: file,
        lines: contentText.split('\n').length,
      });
    } else {
      // Exists in both — compare
      const wikiPath = join(wikiDir, file);
      const wikiText = readFileSync(wikiPath, 'utf-8');

      if (contentText.trim() === wikiText.trim()) {
        results.unchanged.push({
          page: file.replace(/\.md$/, ''),
          filename: file,
        });
      } else {
        // Generate a simple line diff summary
        const contentLines = contentText.split('\n');
        const wikiLines = wikiText.split('\n');
        results.modified.push({
          page: file.replace(/\.md$/, ''),
          filename: file,
          wiki_lines: wikiLines.length,
          new_lines: contentLines.length,
          diff_summary: `${wikiLines.length} → ${contentLines.length} lines`,
        });
      }
    }
  }

  // Check for orphans (in wiki but not in content)
  for (const file of wikiFiles) {
    if (!contentSet.has(file) && !scaffolding.has(file)) {
      results.orphaned.push({
        page: file.replace(/\.md$/, ''),
        filename: file,
      });
    }
  }

  results.summary = {
    new: results.new_pages.length,
    modified: results.modified.length,
    unchanged: results.unchanged.length,
    orphaned: results.orphaned.length,
  };

  success(results);
}

/**
 * Commit and push changes to the wiki repo.
 *
 * Expects --dir to be a cloned wiki repo where changes have been
 * made (files added/updated/deleted). Commits all changes and pushes.
 *
 * The skill layer is responsible for copying generated content into
 * the wiki clone directory before calling this command.
 */
export async function push(options) {
  const dir = options.dir;
  const message = options.message || `Wiki sync ${new Date().toISOString().split('T')[0]}`;

  if (!dir) {
    error('--dir is required (path to wiki clone)', 400);
    return;
  }

  if (options.dryRun) {
    // Show what would be committed
    const git = simpleGit(dir);
    const status = await git.status();
    success({
      dry_run: true,
      action: 'push_wiki',
      dir,
      message,
      changes: {
        created: status.not_added.concat(status.created),
        modified: status.modified,
        deleted: status.deleted,
        total: status.not_added.length + status.created.length + status.modified.length + status.deleted.length,
      },
    });
    return;
  }

  const git = simpleGit(dir);

  // Stage all changes
  await git.add('-A');

  // Check if there are actually changes to commit
  const status = await git.status();
  const totalChanges = status.not_added.length + status.created.length +
    status.modified.length + status.deleted.length + status.staged.length;

  if (totalChanges === 0) {
    success({
      action: 'no_changes',
      dir,
      message: 'Wiki is already up to date',
    });
    return;
  }

  try {
    await git.commit(message);
    // GitHub wiki repos always use 'master' as their default branch,
    // regardless of the parent repo's default branch setting.
    await git.push('origin', 'master');
  } catch (err) {
    const pat = process.env.GITHUB_PAT;
    const sanitizedMsg = (err.message || '').replace(pat, '***');
    const sanitizedErr = new Error(sanitizedMsg);
    sanitizedErr.code = err.code;
    throw sanitizedErr;
  }

  success({
    action: 'pushed',
    dir,
    message,
    changes: {
      created: status.not_added.concat(status.created),
      modified: status.modified,
      deleted: status.deleted,
      total: totalChanges,
    },
  });
}

/**
 * Clean up a temporary wiki clone directory.
 */
export async function cleanup(options) {
  const dir = options.dir;

  if (!dir) {
    error('--dir is required', 400);
    return;
  }

  if (!existsSync(dir)) {
    success({
      action: 'already_clean',
      dir,
      message: 'Directory does not exist',
    });
    return;
  }

  rmSync(dir, { recursive: true, force: true });

  success({
    action: 'cleaned',
    dir,
  });
}
