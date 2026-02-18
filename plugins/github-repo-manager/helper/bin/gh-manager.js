#!/usr/bin/env node

/**
 * gh-manager — GitHub Repo Manager CLI helper
 *
 * Stateless API plumbing layer for the Claude Code plugin.
 * Returns structured JSON to stdout. Errors to stderr.
 * No business logic — the skill layer interprets the data.
 *
 * Phase 0: auth, repos, repo (info/community/labels)
 * Phase 1: files, branches, prs (list/create/label/comment)
 */

import 'dotenv/config';
import { Command } from 'commander';
import { handleCommand } from '../src/util/output.js';

// Phase 0 commands
import { verify, rateLimit } from '../src/commands/auth.js';
import { list as reposList, classify } from '../src/commands/repos.js';
import {
  info,
  community,
  labelsList,
  labelsCreate,
  labelsUpdate,
} from '../src/commands/repo.js';

// Phase 1 commands
import { exists, get, put, del as filesDel } from '../src/commands/files.js';
import {
  list as branchesList,
  create as branchesCreate,
  del as branchesDel,
} from '../src/commands/branches.js';
import {
  list as prsList,
  create as prsCreate,
  label as prsLabel,
  comment as prsComment,
  get as prsGet,
  diff as prsDiff,
  comments as prsComments,
  requestReview as prsRequestReview,
  merge as prsMerge,
  close as prsClose,
} from '../src/commands/prs.js';

// Phase 2 commands
import {
  clone as wikiClone,
  init as wikiInit,
  diff as wikiDiff,
  push as wikiPush,
  cleanup as wikiCleanup,
} from '../src/commands/wiki.js';

// Phase 3 commands
import {
  list as issuesList,
  get as issuesGet,
  issueComments,
  label as issuesLabel,
  comment as issuesComment,
  close as issuesClose,
  assign as issuesAssign,
} from '../src/commands/issues.js';
import {
  list as notificationsList,
  markRead as notificationsMarkRead,
} from '../src/commands/notifications.js';

// Phase 4 commands
import {
  dependabot as secDependabot,
  codeScanning as secCodeScanning,
  secretScanning as secSecretScanning,
  advisories as secAdvisories,
  branchRules as secBranchRules,
} from '../src/commands/security.js';
import {
  graph as depsGraph,
  dependabotPrs as depsDependabotPrs,
} from '../src/commands/deps.js';

// Phase 5 commands
import {
  list as releasesList,
  latest as releasesLatest,
  compare as releasesCompare,
  draft as releasesDraft,
  publish as releasesPublish,
  changelog as releasesChangelog,
} from '../src/commands/releases.js';
import {
  list as discussionsList,
  comment as discussionsComment,
  close as discussionsClose,
} from '../src/commands/discussions.js';

// Phase 6 commands
import {
  repoRead as configRepoRead,
  repoWrite as configRepoWrite,
  portfolioRead as configPortfolioRead,
  portfolioWrite as configPortfolioWrite,
  resolve as configResolve,
} from '../src/commands/config.js';

const program = new Command();

program
  .name('gh-manager')
  .description('GitHub Repo Manager — API helper for Claude Code plugin')
  .version('1.0.0');

// ──────────────────────────────────────────────
// auth
// ──────────────────────────────────────────────
const auth = program.command('auth').description('Authentication commands');

auth
  .command('verify')
  .description('Validate PAT and report scopes')
  .action(handleCommand(verify));

auth
  .command('rate-limit')
  .description('Show current rate limit status')
  .action(handleCommand(rateLimit));

// ──────────────────────────────────────────────
// repos (cross-repo discovery)
// ──────────────────────────────────────────────
const repos = program
  .command('repos')
  .description('Cross-repo discovery commands');

repos
  .command('list')
  .description('List all repos accessible via PAT')
  .option('--limit <n>', 'Maximum repos to return')
  .action(handleCommand(reposList));

repos
  .command('classify')
  .description('Auto-detect tier for a repo (composite command)')
  .requiredOption('--repo <owner/name>', 'Repository (owner/name)')
  .action(handleCommand(classify));

// ──────────────────────────────────────────────
// repo (single-repo commands)
// ──────────────────────────────────────────────
const repo = program
  .command('repo')
  .description('Single-repo metadata commands');

repo
  .command('info')
  .description('Fetch repo metadata')
  .requiredOption('--repo <owner/name>', 'Repository (owner/name)')
  .action(handleCommand(info));

repo
  .command('community')
  .description('Fetch community profile score')
  .requiredOption('--repo <owner/name>', 'Repository (owner/name)')
  .action(handleCommand(community));

const labels = repo.command('labels').description('Label management');

labels
  .command('list')
  .description('List all labels on a repo')
  .requiredOption('--repo <owner/name>', 'Repository (owner/name)')
  .action(handleCommand(labelsList));

labels
  .command('create')
  .description('Create a label')
  .requiredOption('--repo <owner/name>', 'Repository (owner/name)')
  .requiredOption('--name <n>', 'Label name')
  .option('--color <hex>', 'Label color (hex without #)', '0E8A16')
  .option('--description <text>', 'Label description')
  .option('--dry-run', 'Show what would happen without executing')
  .action(handleCommand(labelsCreate));

labels
  .command('update')
  .description('Update an existing label')
  .requiredOption('--repo <owner/name>', 'Repository (owner/name)')
  .requiredOption('--name <n>', 'Current label name')
  .option('--new-name <n>', 'New label name')
  .option('--color <hex>', 'New label color (hex without #)')
  .option('--description <text>', 'New label description')
  .option('--dry-run', 'Show what would happen without executing')
  .action(handleCommand(labelsUpdate));

// ──────────────────────────────────────────────
// files
// ──────────────────────────────────────────────
const files = program.command('files').description('File operations');

files
  .command('exists')
  .description('Check if file exists in repo')
  .requiredOption('--repo <owner/name>', 'Repository (owner/name)')
  .requiredOption('--path <path>', 'File path in repo')
  .option('--branch <branch>', 'Branch to check (default: repo default)')
  .action(handleCommand(exists));

files
  .command('get')
  .description('Fetch file content from repo')
  .requiredOption('--repo <owner/name>', 'Repository (owner/name)')
  .requiredOption('--path <path>', 'File path in repo')
  .option('--branch <branch>', 'Branch to read from')
  .action(handleCommand(get));

files
  .command('put')
  .description('Create or update a file (content from stdin)')
  .requiredOption('--repo <owner/name>', 'Repository (owner/name)')
  .requiredOption('--path <path>', 'File path in repo')
  .option('--message <msg>', 'Commit message')
  .option('--branch <branch>', 'Target branch (for Tier 4 PR workflows)')
  .option('--dry-run', 'Show what would happen without executing')
  .action(handleCommand(put));

files
  .command('delete')
  .description('Delete a file from repo')
  .requiredOption('--repo <owner/name>', 'Repository (owner/name)')
  .requiredOption('--path <path>', 'File path in repo')
  .option('--message <msg>', 'Commit message')
  .option('--branch <branch>', 'Target branch')
  .option('--dry-run', 'Show what would happen without executing')
  .action(handleCommand(filesDel));

// ──────────────────────────────────────────────
// branches
// ──────────────────────────────────────────────
const branches = program
  .command('branches')
  .description('Branch operations');

branches
  .command('list')
  .description('List branches')
  .requiredOption('--repo <owner/name>', 'Repository (owner/name)')
  .option('--limit <n>', 'Maximum branches to return')
  .option('--protected', 'Only show protected branches')
  .action(handleCommand(branchesList));

branches
  .command('create')
  .description('Create a branch from a ref')
  .requiredOption('--repo <owner/name>', 'Repository (owner/name)')
  .requiredOption('--branch <n>', 'New branch name')
  .requiredOption('--from <ref>', 'Source branch/tag/SHA')
  .option('--dry-run', 'Show what would happen without executing')
  .action(handleCommand(branchesCreate));

branches
  .command('delete')
  .description('Delete a branch')
  .requiredOption('--repo <owner/name>', 'Repository (owner/name)')
  .requiredOption('--branch <n>', 'Branch to delete')
  .option('--dry-run', 'Show what would happen without executing')
  .action(handleCommand(branchesDel));

// ──────────────────────────────────────────────
// prs (Phase 1 subset)
// ──────────────────────────────────────────────
const prs = program
  .command('prs')
  .description('Pull request operations');

prs
  .command('list')
  .description('List PRs with trimmed output')
  .requiredOption('--repo <owner/name>', 'Repository (owner/name)')
  .option('--state <state>', 'PR state: open, closed, all', 'open')
  .option('--label <n>', 'Filter by label name')
  .option('--limit <n>', 'Maximum PRs to return')
  .action(handleCommand(prsList));

prs
  .command('get')
  .description('Fetch single PR with full details, reviews, and CI status')
  .requiredOption('--repo <owner/name>', 'Repository (owner/name)')
  .requiredOption('--pr <number>', 'PR number')
  .action(handleCommand(prsGet));

prs
  .command('diff')
  .description('Fetch PR changed files with patches')
  .requiredOption('--repo <owner/name>', 'Repository (owner/name)')
  .requiredOption('--pr <number>', 'PR number')
  .action(handleCommand(prsDiff));

prs
  .command('comments')
  .description('Fetch comments on a PR')
  .requiredOption('--repo <owner/name>', 'Repository (owner/name)')
  .requiredOption('--pr <number>', 'PR number')
  .option('--limit <n>', 'Maximum comments to return')
  .action(handleCommand(prsComments));

prs
  .command('create')
  .description('Create a pull request')
  .requiredOption('--repo <owner/name>', 'Repository (owner/name)')
  .requiredOption('--head <branch>', 'Head branch')
  .requiredOption('--base <branch>', 'Base branch')
  .requiredOption('--title <title>', 'PR title')
  .option('--body <body>', 'PR description')
  .option('--label <labels>', 'Comma-separated labels to add')
  .option('--dry-run', 'Show what would happen without executing')
  .action(handleCommand(prsCreate));

prs
  .command('label')
  .description('Add or remove labels on a PR')
  .requiredOption('--repo <owner/name>', 'Repository (owner/name)')
  .requiredOption('--pr <number>', 'PR number')
  .option('--add <labels>', 'Comma-separated labels to add')
  .option('--remove <labels>', 'Comma-separated labels to remove')
  .option('--dry-run', 'Show what would happen without executing')
  .action(handleCommand(prsLabel));

prs
  .command('comment')
  .description('Post a comment on a PR')
  .requiredOption('--repo <owner/name>', 'Repository (owner/name)')
  .requiredOption('--pr <number>', 'PR number')
  .requiredOption('--body <body>', 'Comment body')
  .option('--dry-run', 'Show what would happen without executing')
  .action(handleCommand(prsComment));

prs
  .command('request-review')
  .description('Request reviewers on a PR')
  .requiredOption('--repo <owner/name>', 'Repository (owner/name)')
  .requiredOption('--pr <number>', 'PR number')
  .requiredOption('--reviewers <users>', 'Comma-separated user/team list')
  .option('--dry-run', 'Show what would happen without executing')
  .action(handleCommand(prsRequestReview));

prs
  .command('merge')
  .description('Merge a PR')
  .requiredOption('--repo <owner/name>', 'Repository (owner/name)')
  .requiredOption('--pr <number>', 'PR number')
  .option('--method <method>', 'Merge method: merge, squash, rebase', 'merge')
  .option('--commit-title <title>', 'Custom merge commit title')
  .option('--dry-run', 'Show what would happen without executing')
  .action(handleCommand(prsMerge));

prs
  .command('close')
  .description('Close a PR with optional comment')
  .requiredOption('--repo <owner/name>', 'Repository (owner/name)')
  .requiredOption('--pr <number>', 'PR number')
  .option('--body <body>', 'Closing comment')
  .option('--dry-run', 'Show what would happen without executing')
  .action(handleCommand(prsClose));

// ──────────────────────────────────────────────
// issues (Phase 3)
// ──────────────────────────────────────────────
const issues = program
  .command('issues')
  .description('Issue operations');

issues
  .command('list')
  .description('List open issues (excluding PRs)')
  .requiredOption('--repo <owner/name>', 'Repository (owner/name)')
  .option('--state <state>', 'Issue state: open, closed, all', 'open')
  .option('--label <labels>', 'Filter by label name')
  .option('--limit <n>', 'Maximum issues to return')
  .action(handleCommand(issuesList));

issues
  .command('get')
  .description('Fetch single issue with full details and linked PRs')
  .requiredOption('--repo <owner/name>', 'Repository (owner/name)')
  .requiredOption('--issue <number>', 'Issue number')
  .action(handleCommand(issuesGet));

issues
  .command('comments')
  .description('Fetch comments on an issue')
  .requiredOption('--repo <owner/name>', 'Repository (owner/name)')
  .requiredOption('--issue <number>', 'Issue number')
  .option('--limit <n>', 'Maximum comments to return')
  .action(handleCommand(issueComments));

issues
  .command('label')
  .description('Add or remove labels on an issue')
  .requiredOption('--repo <owner/name>', 'Repository (owner/name)')
  .requiredOption('--issue <number>', 'Issue number')
  .option('--add <labels>', 'Comma-separated labels to add')
  .option('--remove <labels>', 'Comma-separated labels to remove')
  .option('--dry-run', 'Show what would happen without executing')
  .action(handleCommand(issuesLabel));

issues
  .command('comment')
  .description('Post a comment on an issue')
  .requiredOption('--repo <owner/name>', 'Repository (owner/name)')
  .requiredOption('--issue <number>', 'Issue number')
  .requiredOption('--body <body>', 'Comment body')
  .option('--dry-run', 'Show what would happen without executing')
  .action(handleCommand(issuesComment));

issues
  .command('close')
  .description('Close an issue with optional comment')
  .requiredOption('--repo <owner/name>', 'Repository (owner/name)')
  .requiredOption('--issue <number>', 'Issue number')
  .option('--body <body>', 'Closing comment')
  .option('--reason <reason>', 'State reason: completed or not_planned', 'completed')
  .option('--dry-run', 'Show what would happen without executing')
  .action(handleCommand(issuesClose));

issues
  .command('assign')
  .description('Assign an issue to users')
  .requiredOption('--repo <owner/name>', 'Repository (owner/name)')
  .requiredOption('--issue <number>', 'Issue number')
  .requiredOption('--assignees <users>', 'Comma-separated usernames')
  .option('--dry-run', 'Show what would happen without executing')
  .action(handleCommand(issuesAssign));

// ──────────────────────────────────────────────
// notifications (Phase 3)
// ──────────────────────────────────────────────
const notifications = program
  .command('notifications')
  .description('Notification operations');

notifications
  .command('list')
  .description('List notifications for a repo, categorized by priority')
  .requiredOption('--repo <owner/name>', 'Repository (owner/name)')
  .option('--all', 'Include read notifications')
  .option('--limit <n>', 'Maximum notifications to return')
  .action(handleCommand(notificationsList));

notifications
  .command('mark-read')
  .description('Mark notifications as read')
  .requiredOption('--repo <owner/name>', 'Repository (owner/name)')
  .option('--thread-id <id>', 'Mark only this thread (otherwise marks all)')
  .option('--dry-run', 'Show what would happen without executing')
  .action(handleCommand(notificationsMarkRead));

// ──────────────────────────────────────────────
// security (Phase 4)
// ──────────────────────────────────────────────
const security = program
  .command('security')
  .description('Security audit operations (read-only)');

security
  .command('dependabot')
  .description('Fetch Dependabot alerts with severity summary')
  .requiredOption('--repo <owner/name>', 'Repository (owner/name)')
  .option('--state <state>', 'Alert state: open, closed, dismissed, fixed', 'open')
  .option('--severity <level>', 'Filter by severity: critical, high, medium, low')
  .action(handleCommand(secDependabot));

security
  .command('code-scanning')
  .description('Fetch code scanning alerts')
  .requiredOption('--repo <owner/name>', 'Repository (owner/name)')
  .option('--state <state>', 'Alert state: open, closed, dismissed, fixed', 'open')
  .action(handleCommand(secCodeScanning));

security
  .command('secret-scanning')
  .description('Fetch secret scanning alerts')
  .requiredOption('--repo <owner/name>', 'Repository (owner/name)')
  .option('--state <state>', 'Alert state: open, resolved', 'open')
  .action(handleCommand(secSecretScanning));

security
  .command('advisories')
  .description('Fetch repository security advisories')
  .requiredOption('--repo <owner/name>', 'Repository (owner/name)')
  .action(handleCommand(secAdvisories));

security
  .command('branch-rules')
  .description('Audit branch protection rules (read-only)')
  .requiredOption('--repo <owner/name>', 'Repository (owner/name)')
  .option('--branch <name>', 'Branch to check (default: repo default branch)')
  .action(handleCommand(secBranchRules));

// ──────────────────────────────────────────────
// deps (Phase 4)
// ──────────────────────────────────────────────
const deps = program
  .command('deps')
  .description('Dependency audit operations');

deps
  .command('graph')
  .description('Fetch dependency graph summary (SBOM)')
  .requiredOption('--repo <owner/name>', 'Repository (owner/name)')
  .action(handleCommand(depsGraph));

deps
  .command('dependabot-prs')
  .description('List open Dependabot PRs with age and severity')
  .requiredOption('--repo <owner/name>', 'Repository (owner/name)')
  .action(handleCommand(depsDependabotPrs));

// ──────────────────────────────────────────────
// releases (Phase 5)
// ──────────────────────────────────────────────
const releases = program
  .command('releases')
  .description('Release operations');

releases
  .command('list')
  .description('List releases (most recent first)')
  .requiredOption('--repo <owner/name>', 'Repository (owner/name)')
  .option('--limit <n>', 'Maximum releases to return', '20')
  .action(handleCommand(releasesList));

releases
  .command('latest')
  .description('Get latest release details')
  .requiredOption('--repo <owner/name>', 'Repository (owner/name)')
  .action(handleCommand(releasesLatest));

releases
  .command('compare')
  .description('Commits since last release tag on default branch')
  .requiredOption('--repo <owner/name>', 'Repository (owner/name)')
  .action(handleCommand(releasesCompare));

releases
  .command('draft')
  .description('Create a draft release')
  .requiredOption('--repo <owner/name>', 'Repository (owner/name)')
  .requiredOption('--tag <tag>', 'Tag name (e.g. v1.2.3)')
  .option('--name <name>', 'Release name (defaults to tag)')
  .option('--body <body>', 'Release notes body')
  .option('--target <branch>', 'Target branch (defaults to repo default)')
  .option('--dry-run', 'Show what would happen without executing')
  .action(handleCommand(releasesDraft));

releases
  .command('publish')
  .description('Publish a draft release')
  .requiredOption('--repo <owner/name>', 'Repository (owner/name)')
  .requiredOption('--release-id <id>', 'Release ID to publish')
  .option('--dry-run', 'Show what would happen without executing')
  .action(handleCommand(releasesPublish));

releases
  .command('changelog')
  .description('Fetch and parse changelog file')
  .requiredOption('--repo <owner/name>', 'Repository (owner/name)')
  .action(handleCommand(releasesChangelog));

// ──────────────────────────────────────────────
// discussions (Phase 5) — GraphQL-based
// ──────────────────────────────────────────────
const discussions = program
  .command('discussions')
  .description('Discussion operations (GraphQL)');

discussions
  .command('list')
  .description('List discussions with unanswered/stale classification')
  .requiredOption('--repo <owner/name>', 'Repository (owner/name)')
  .option('--category <id>', 'Filter by category ID')
  .option('--limit <n>', 'Maximum discussions to return', '25')
  .action(handleCommand(discussionsList));

discussions
  .command('comment')
  .description('Post a comment on a discussion')
  .requiredOption('--repo <owner/name>', 'Repository (owner/name)')
  .requiredOption('--discussion <number>', 'Discussion number')
  .requiredOption('--body <body>', 'Comment body')
  .option('--dry-run', 'Show what would happen without executing')
  .action(handleCommand(discussionsComment));

discussions
  .command('close')
  .description('Close a discussion')
  .requiredOption('--repo <owner/name>', 'Repository (owner/name)')
  .requiredOption('--discussion <number>', 'Discussion number')
  .option('--reason <reason>', 'Close reason: RESOLVED, OUTDATED, DUPLICATE', 'RESOLVED')
  .option('--dry-run', 'Show what would happen without executing')
  .action(handleCommand(discussionsClose));

// ──────────────────────────────────────────────
// config (Phase 6)
// ──────────────────────────────────────────────
const config = program
  .command('config')
  .description('Configuration management');

config
  .command('repo-read')
  .description('Read .github-repo-manager.yml from a repo')
  .requiredOption('--repo <owner/name>', 'Repository (owner/name)')
  .action(handleCommand(configRepoRead));

config
  .command('repo-write')
  .description('Write .github-repo-manager.yml to a repo (content from stdin)')
  .requiredOption('--repo <owner/name>', 'Repository (owner/name)')
  .option('--branch <branch>', 'Target branch (for Tier 4 PR workflow)')
  .option('--dry-run', 'Show what would happen without executing')
  .action(handleCommand(configRepoWrite));

config
  .command('portfolio-read')
  .description('Read local portfolio.yml')
  .action(handleCommand(configPortfolioRead));

config
  .command('portfolio-write')
  .description('Write local portfolio.yml (content from stdin)')
  .option('--dry-run', 'Show what would happen without executing')
  .action(handleCommand(configPortfolioWrite));

config
  .command('resolve')
  .description('Resolve effective config for a repo (merged precedence)')
  .requiredOption('--repo <owner/name>', 'Repository (owner/name)')
  .action(handleCommand(configResolve));

// ──────────────────────────────────────────────
// wiki (Phase 2)
// ──────────────────────────────────────────────
const wiki = program
  .command('wiki')
  .description('Wiki operations (git-based)');

wiki
  .command('clone')
  .description('Clone wiki repo to temp directory')
  .requiredOption('--repo <owner/name>', 'Repository (owner/name)')
  .requiredOption('--dir <path>', 'Local directory for wiki clone')
  .action(handleCommand(wikiClone));

wiki
  .command('init')
  .description('Initialize wiki (create Home page if wiki repo does not exist)')
  .requiredOption('--repo <owner/name>', 'Repository (owner/name)')
  .option('--dry-run', 'Show what would happen without executing')
  .action(handleCommand(wikiInit));

wiki
  .command('diff')
  .description('Diff generated content against current wiki pages')
  .requiredOption('--dir <path>', 'Path to cloned wiki repo')
  .requiredOption('--content-dir <path>', 'Path to generated content directory')
  .action(handleCommand(wikiDiff));

wiki
  .command('push')
  .description('Commit and push changes to wiki repo')
  .requiredOption('--dir <path>', 'Path to cloned wiki repo')
  .option('--message <msg>', 'Commit message')
  .option('--dry-run', 'Show what would happen without executing')
  .action(handleCommand(wikiPush));

wiki
  .command('cleanup')
  .description('Remove temp wiki clone directory')
  .requiredOption('--dir <path>', 'Directory to remove')
  .action(handleCommand(wikiCleanup));

program.parse();
