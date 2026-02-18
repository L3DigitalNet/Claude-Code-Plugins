/**
 * security.js — Security operations for gh-manager
 *
 * Commands:
 *   security dependabot --repo [--state] [--severity]
 *   security code-scanning --repo [--state]
 *   security secret-scanning --repo [--state]
 *   security advisories --repo
 *   security branch-rules --repo [--branch]
 *
 * All read-only. Branch protection is audit-only (recommend, not modify).
 * Errors on 403/404 are expected — features may not be enabled or
 * PAT may lack scopes. Structured errors let the skill layer handle gracefully.
 */

import { getOctokit, parseRepo } from '../client.js';
import { paginateRest } from '../util/paginate.js';
import { success, error } from '../util/output.js';

/**
 * Fetch Dependabot alerts with severity summary.
 */
export async function dependabot(options) {
  const { owner, repo } = parseRepo(options.repo);
  const octokit = getOctokit();

  const params = {
    owner,
    repo,
    state: options.state || 'open',
    per_page: 100,
    sort: 'created',
    direction: 'desc',
  };

  if (options.severity) {
    params.severity = options.severity;
  }

  let alerts = [];
  try {
    const { data } = await octokit.request(
      'GET /repos/{owner}/{repo}/dependabot/alerts',
      params
    );
    alerts = data;
  } catch (err) {
    if (err.status === 403 || err.status === 404) {
      error(
        'Dependabot alerts not accessible — Dependabot may not be enabled or PAT lacks security_events scope',
        err.status,
        `GET /repos/${owner}/${repo}/dependabot/alerts`,
        'Enable Dependabot in repo Settings → Security, or add security_events scope to PAT'
      );
      return;
    }
    throw err;
  }

  const trimmed = alerts.map((a) => ({
    number: a.number,
    state: a.state,
    severity: a.security_vulnerability?.severity || a.security_advisory?.severity || 'unknown',
    package_name: a.security_vulnerability?.package?.name || a.dependency?.package?.name || 'unknown',
    ecosystem: a.security_vulnerability?.package?.ecosystem || a.dependency?.package?.ecosystem || 'unknown',
    summary: a.security_advisory?.summary || '',
    cve_id: a.security_advisory?.cve_id || null,
    ghsa_id: a.security_advisory?.ghsa_id || null,
    created_at: a.created_at,
    fixed_at: a.fixed_at,
    dismissed_at: a.dismissed_at,
    auto_dismissed_at: a.auto_dismissed_at,
    fix_available: !!(a.security_vulnerability?.first_patched_version),
    patched_version: a.security_vulnerability?.first_patched_version?.identifier || null,
  }));

  // Severity summary
  const bySeverity = { critical: 0, high: 0, medium: 0, low: 0 };
  for (const a of trimmed) {
    const sev = a.severity?.toLowerCase();
    if (sev in bySeverity) bySeverity[sev]++;
  }

  success({
    count: trimmed.length,
    state_filter: options.state || 'open',
    by_severity: bySeverity,
    alerts: trimmed,
  });
}

/**
 * Fetch code scanning alerts (CodeQL or third-party).
 */
export async function codeScanning(options) {
  const { owner, repo } = parseRepo(options.repo);
  const octokit = getOctokit();

  let alerts = [];
  try {
    const { data } = await octokit.request(
      'GET /repos/{owner}/{repo}/code-scanning/alerts',
      {
        owner,
        repo,
        state: options.state || 'open',
        per_page: 100,
      }
    );
    alerts = data;
  } catch (err) {
    if (err.status === 403) {
      error(
        'Code scanning alerts not accessible — code scanning may not be enabled or PAT lacks security_events scope',
        403,
        `GET /repos/${owner}/${repo}/code-scanning/alerts`,
        'Enable code scanning in repo Settings → Security → Code scanning'
      );
      return;
    }
    if (err.status === 404) {
      success({
        count: 0,
        enabled: false,
        message: 'Code scanning is not enabled on this repository',
        alerts: [],
      });
      return;
    }
    throw err;
  }

  const trimmed = alerts.map((a) => ({
    number: a.number,
    state: a.state,
    severity: a.rule?.security_severity_level || a.rule?.severity || 'unknown',
    rule_id: a.rule?.id || null,
    rule_description: a.rule?.description || '',
    tool: a.tool?.name || 'unknown',
    file: a.most_recent_instance?.location?.path || null,
    line: a.most_recent_instance?.location?.start_line || null,
    created_at: a.created_at,
    dismissed_at: a.dismissed_at,
    dismissed_reason: a.dismissed_reason,
  }));

  const bySeverity = { critical: 0, high: 0, medium: 0, low: 0, warning: 0 };
  for (const a of trimmed) {
    const sev = a.severity?.toLowerCase();
    if (sev in bySeverity) bySeverity[sev]++;
  }

  success({
    count: trimmed.length,
    enabled: true,
    by_severity: bySeverity,
    alerts: trimmed,
  });
}

/**
 * Fetch secret scanning alerts.
 */
export async function secretScanning(options) {
  const { owner, repo } = parseRepo(options.repo);
  const octokit = getOctokit();

  let alerts = [];
  try {
    const { data } = await octokit.request(
      'GET /repos/{owner}/{repo}/secret-scanning/alerts',
      {
        owner,
        repo,
        state: options.state || 'open',
        per_page: 100,
      }
    );
    alerts = data;
  } catch (err) {
    if (err.status === 404) {
      success({
        count: 0,
        enabled: false,
        message: 'Secret scanning is not enabled or not available on this repository',
        alerts: [],
      });
      return;
    }
    if (err.status === 403) {
      error(
        'Secret scanning alerts not accessible — PAT may lack secret_scanning_alerts scope',
        403,
        `GET /repos/${owner}/${repo}/secret-scanning/alerts`
      );
      return;
    }
    throw err;
  }

  const trimmed = alerts.map((a) => ({
    number: a.number,
    state: a.state,
    secret_type: a.secret_type || 'unknown',
    secret_type_display: a.secret_type_display_name || a.secret_type || 'unknown',
    created_at: a.created_at,
    resolved_at: a.resolved_at,
    resolution: a.resolution,
    push_protection_bypassed: a.push_protection_bypassed || false,
  }));

  success({
    count: trimmed.length,
    enabled: true,
    alerts: trimmed,
  });
}

/**
 * Fetch repository security advisories.
 */
export async function advisories(options) {
  const { owner, repo } = parseRepo(options.repo);
  const octokit = getOctokit();

  let advList = [];
  try {
    const { data } = await octokit.request(
      'GET /repos/{owner}/{repo}/security-advisories',
      { owner, repo, per_page: 100 }
    );
    advList = data;
  } catch (err) {
    if (err.status === 404 || err.status === 403) {
      success({
        count: 0,
        enabled: false,
        message: 'Security advisories not accessible on this repository',
        advisories: [],
      });
      return;
    }
    throw err;
  }

  const trimmed = advList.map((a) => ({
    ghsa_id: a.ghsa_id,
    cve_id: a.cve_id,
    summary: a.summary || '',
    severity: a.severity || 'unknown',
    state: a.state,
    published_at: a.published_at,
    created_at: a.created_at,
    updated_at: a.updated_at,
    withdrawn_at: a.withdrawn_at,
  }));

  success({
    count: trimmed.length,
    draft_count: trimmed.filter((a) => a.state === 'draft').length,
    published_count: trimmed.filter((a) => a.state === 'published').length,
    advisories: trimmed,
  });
}

/**
 * Fetch branch protection rules for the default (or specified) branch.
 * Audit-only — cannot modify. Recommend-only output.
 */
export async function branchRules(options) {
  const { owner, repo } = parseRepo(options.repo);
  const octokit = getOctokit();

  // Get default branch if not specified
  let branch = options.branch;
  if (!branch) {
    const { data: repoData } = await octokit.request(
      'GET /repos/{owner}/{repo}',
      { owner, repo }
    );
    branch = repoData.default_branch;
  }

  try {
    const { data } = await octokit.request(
      'GET /repos/{owner}/{repo}/branches/{branch}/protection',
      { owner, repo, branch }
    );

    success({
      branch,
      protected: true,
      rules: {
        require_pull_request_reviews: !!data.required_pull_request_reviews,
        required_approving_review_count: data.required_pull_request_reviews?.required_approving_review_count || 0,
        dismiss_stale_reviews: data.required_pull_request_reviews?.dismiss_stale_reviews || false,
        require_code_owner_reviews: data.required_pull_request_reviews?.require_code_owner_reviews || false,
        require_status_checks: !!data.required_status_checks,
        strict_status_checks: data.required_status_checks?.strict || false,
        status_check_contexts: data.required_status_checks?.contexts || [],
        enforce_admins: data.enforce_admins?.enabled || false,
        require_linear_history: data.required_linear_history?.enabled || false,
        allow_force_pushes: data.allow_force_pushes?.enabled || false,
        allow_deletions: data.allow_deletions?.enabled || false,
        require_conversation_resolution: data.required_conversation_resolution?.enabled || false,
        require_signed_commits: data.required_signatures?.enabled || false,
      },
    });
  } catch (err) {
    if (err.status === 404) {
      success({
        branch,
        protected: false,
        rules: null,
        message: `Branch "${branch}" has no protection rules configured`,
      });
    } else if (err.status === 403) {
      error(
        'Cannot read branch protection — PAT may lack admin access to this repo',
        403,
        `GET /repos/${owner}/${repo}/branches/${branch}/protection`
      );
    } else {
      throw err;
    }
  }
}
