# GitHub Repo Manager — Claude Code Plugin

## Design Document v2.0

**Author:** Chris
**Date:** February 17, 2026
**Status:** Implemented — v0.2.1 (Feb 2026)

---

## 1. Executive Summary

GitHub Repo Manager is a Claude Code plugin that performs routine maintenance on GitHub repositories through direct API interaction using a Personal Access Token (PAT). It operates in two modes: deep single-repo sessions where Claude assesses, recommends, and executes maintenance tasks conversationally with the owner, and targeted cross-repo checks where Claude scans all accessible repos for a specific concern (e.g., missing security files), reports findings, and applies fixes either selectively or in batch — all with owner approval. The tool is stateless, conversational, and never runs unattended.

---

## 2. Problem Statement

Maintaining a healthy GitHub repository involves a constellation of recurring tasks that are easy to neglect individually but compound into significant drift over time:

- Wiki pages fall out of sync with in-repo documentation and actual code behavior.
- Community health files (CONTRIBUTING.md, SECURITY.md, CODE_OF_CONDUCT.md, etc.) become stale or incomplete.
- Pull requests sit unreviewed, accumulating merge conflicts.
- Notifications pile up without triage.
- Discussion threads go unanswered.
- Security advisories and dependency alerts are acknowledged late.

These tasks don't require deep creative judgment — they require consistent attention and systematic checking. This makes them ideal candidates for an LLM-driven tool that can assess the current state of a repository, surface what needs attention, and execute fixes with owner approval.

The plugin is **conversational, not automated**. It runs when the owner invokes it, inspects the repository's current state, draws conclusions about what needs work, and proposes actions interactively. The owner is always in the loop to provide input, approve changes, or redirect priorities. There is no scheduling, no background automation, and no state persistence between sessions.

---

## 3. Goals and Non-Goals

### 3.1 Goals

- Provide a conversational tool that assesses repo health and surfaces what needs attention
- Synchronize wiki content with in-repo documentation and code implementation
- Audit and update community health files (CONTRIBUTING, SECURITY, CODE_OF_CONDUCT, issue/PR templates)
- Triage open pull requests (conflict detection, staleness checks, review summaries)
- Triage open issues (staleness, labels, assignees, linked PRs)
- Assess release readiness for repos with releases (unreleased commits, changelog drift, draft releases)
- Process and summarize repository notifications
- Monitor and surface security advisories, Dependabot alerts, and code scanning results
- Manage discussion threads (flag unanswered, suggest closures)
- Generate a structured maintenance report after each session
- Execute approved changes with owner confirmation during the conversation
- Operate entirely through GitHub's REST and GraphQL APIs via PAT (with git exception for wiki)

### 3.2 Non-Goals (v1)

- Automated/scheduled execution — the plugin runs only when invoked by the owner
- State persistence between sessions — each run assesses current state fresh
- Automated merging of pull requests — Claude can merge PRs on explicit owner request during a conversation, but will never merge without being asked
- CI/CD pipeline management
- Repository creation or deletion — **exception:** the plugin can create an org-level `.github` repository for shared community health files (Section 5.2), with owner approval and Administration Write PAT scope
- Cross-repo orchestration beyond targeted checks (no full-sweep automation across all repos)
- Real-time webhook-driven operation
- Direct git operations (no clone/push — API only), **except** for the wiki sync module which requires git access to `{repo}.wiki.git` (see Section 5.1)

---

## 4. Architecture Overview

### 4.1 High-Level Component Diagram

```
┌──────────┐
│  Owner   │ ◄─── Conversational interaction
└────┬─────┘      (approvals, redirects, questions)
     │
     ▼
┌─────────────────────────────────────────────────────┐
│              Claude Code + Skill Layer               │
│         (reads SKILL.md, reasons about findings)     │
├─────────────────────────────────────────────────────┤
│                                                     │
│  ┌───────────┐  ┌───────────┐  ┌────────────────┐  │
│  │  Module    │  │  Config   │  │   Report       │  │
│  │  Skills    │  │  Reader   │  │   Generator    │  │
│  └─────┬─────┘  └─────┬─────┘  └───────┬────────┘  │
│        │               │                │            │
│  ┌─────▼───────────────▼────────────────▼────────┐  │
│  │            Assessment & Reasoning              │  │
│  │   (interprets data, proposes actions to owner) │  │
│  └───────────────────┬───────────────────────────┘  │
│                      │                               │
└──────────────────────┼───────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│              gh-manager (Node.js Helper)              │
│            Stateless API plumbing layer              │
├─────────────────────────────────────────────────────┤
│  ┌──────┐┌─────┐┌────┐┌────┐┌────┐┌────┐┌──────┐┌─────┐┌─────┐│
│  │ Wiki ││Comm ││ PR ││Noti││Sec ││Disc││ Deps ││Issue││ Rel ││
│  │ Sync ││Hlth ││Mgmt││fy  ││ity ││uss ││Audit ││Trig ││Hlth ││
│  └──┬───┘└──┬──┘└──┬─┘└──┬─┘└──┬─┘└──┬─┘└──┬───┘└──┬──┘└──┬──┘│
│     └───────┴──────┴─────┴─────┴─────┴─────┴───────┴──────┘   │
│                      │                               │
└──────────────────────┼───────────────────────────────┘
                       │
                       ▼
              ┌─────────────────┐
              │   GitHub API    │
              │  api.github.com │
              └─────────────────┘
```

### 4.2 Plugin Structure

Follows the established Claude Code plugin pattern from `Claude-Code-Plugins/plugins/agent-orchestrator`.

```
github-repo-manager/
├── .claude-plugin/
│   └── plugin.json               # Plugin manifest (name, version, description)
│
├── hooks/
│   └── hooks.json                # PostToolUse on Bash — runs gh-manager-monitor.sh for
│                                  # rate-limit watchdog and mutation audit trail
│
├── commands/                      # Slash commands
│   └── repo-manager.md           # /repo-manager — single entry point
│
├── skills/                        # Skill reference material (Layer 1)
│   ├── repo-manager/
│   │   └── SKILL.md              # Core session skill — onboarding, tier logic,
│   │                              # communication style, error handling
│   ├── repo-manager-assessment/
│   │   └── SKILL.md              # Full assessment orchestration — module execution order,
│   │                              # cross-module dedup rules, unified findings format, reports
│   ├── repo-manager-reference/
│   │   └── SKILL.md              # gh-manager helper command reference (all subcommands)
│   ├── repo-config/
│   │   └── SKILL.md              # Configuration system — per-repo and portfolio config,
│   │                              # precedence rules, validation
│   ├── wiki-sync/
│   │   └── SKILL.md              # Wiki publish pipeline logic
│   ├── community-health/
│   │   └── SKILL.md              # Community file auditing logic
│   ├── pr-management/
│   │   └── SKILL.md              # PR triage decision trees
│   ├── notifications/
│   │   └── SKILL.md              # Notification processing logic
│   ├── security/
│   │   └── SKILL.md              # Security posture assessment logic
│   ├── discussions/
│   │   └── SKILL.md              # Discussion thread management logic
│   ├── dependency-audit/
│   │   └── SKILL.md              # Dependency review logic
│   ├── issue-triage/
│   │   └── SKILL.md              # Issue triage and labeling logic
│   ├── release-health/
│   │   └── SKILL.md              # Release readiness assessment logic
│   ├── cross-repo/
│   │   └── SKILL.md              # Cross-repo scope inference, batch mutations,
│   │                              # portfolio scanning
│   └── self-test/
│       └── SKILL.md              # Self-diagnostics — PAT scope check, gh-manager install,
│                                  # API connectivity verification
│
├── helper/                        # Node.js API helper (Layer 2)
│   ├── package.json
│   ├── bin/
│   │   └── gh-manager.js         # CLI entry point
│   ├── src/
│   │   ├── client.js             # Octokit client setup + auth
│   │   ├── rate-limit.js         # Rate limit tracking
│   │   ├── commands/
│   │   │   ├── auth.js           # auth verify, rate-limit
│   │   │   ├── repos.js          # repos list, classify (cross-repo discovery)
│   │   │   ├── repo.js           # repo info, community, labels
│   │   │   ├── wiki.js           # wiki clone, init, diff, push, cleanup (git)
│   │   │   ├── files.js          # files get, put, delete, exists
│   │   │   ├── branches.js      # branches create, delete, list
│   │   │   ├── prs.js            # prs list, get, diff, comments, label, comment, request-review, merge, create, close
│   │   │   ├── notifications.js  # notifications list, mark-read
│   │   │   ├── security.js       # dependabot, scanning, advisories, branch-rules
│   │   │   ├── discussions.js    # discussions list, comment, close (GraphQL)
│   │   │   ├── issues.js        # issues list, get, comments, label, comment, close, assign
│   │   │   ├── releases.js      # releases list, latest, compare, draft, publish, changelog
│   │   │   └── deps.js           # dependency graph, dependabot PRs
│   │   └── util/
│   │       ├── paginate.js       # Auto-pagination wrapper
│   │       └── output.js         # JSON stdout formatting
│   └── util/
│       ├── paginate.js       # Auto-pagination wrapper
│       └── output.js         # JSON stdout formatting
│
├── templates/                     # Content templates
│   ├── SECURITY.md.tmpl           # Security policy template
│   ├── CODE_OF_CONDUCT.md.tmpl    # Code of conduct template
│   ├── CONTRIBUTING.md.tmpl       # Contributing guide template
│   ├── PULL_REQUEST_TEMPLATE.md.tmpl  # PR description template
│   └── ISSUE_TEMPLATE/
│       ├── bug_report.md.tmpl
│       └── feature_request.md.tmpl
│
├── scripts/                       # Setup and lifecycle scripts
│   ├── setup.sh                  # First-time setup (npm install in helper/)
│   ├── ensure-deps.sh            # Auto-dependency installer — checks node_modules and
│   │                              # runs npm install if missing (called by core session skill)
│   ├── gh-manager-guard.sh      # PreToolUse hook script — mutation detection and warning.
│   │                              # Emits a context-window warning before any gh-manager write
│   │                              # command runs; exits 0 (warning only, does not block).
│   └── gh-manager-monitor.sh    # PostToolUse hook script — rate-limit watchdog and
│                                  # mutation audit trail (logs to ~/.github-repo-manager-audit.log)
│
├── tests/                         # Integration test framework
│   ├── lib.sh                    # Shared test library with JSON assertion helpers
│   ├── run-all.sh                # Test orchestrator with per-tier selection
│   ├── run-tier-a.sh             # Tier A: offline/infrastructure tests (61 tests)
│   ├── run-tier-b.sh             # Tier B: read-only GitHub API tests (28 tests)
│   ├── run-tier-c.sh             # Tier C: mutation tests (40 tests + 3 expected skips)
│   └── cleanup.sh                # Post-test cleanup (removes test artifacts from GitHub)
│
├── config/
│   ├── default.yml               # Default maintenance policies by tier
│   └── schema.yml                # Config validation schema
│
└── docs/
    ├── SETUP.md                  # PAT configuration & permissions guide
    ├── USAGE.md                  # Command reference
    └── POLICIES.md               # Customizable maintenance policies
```

---

## 5. Module Specifications

### 5.1 Wiki Sync Module

**Purpose:** Publish repository documentation to the GitHub wiki as a read-only public help resource. The wiki is a rendering target — repo files are always the single source of truth. Wiki content is never edited directly.

**Applicability:** Tiers 3 and 4 only (public repos). Disabled by default on Tiers 1 and 2.

**Inputs:**
- In-repo documentation files (`docs/`, `README.md`, and other configured sources)
- Source code (for generating/updating wiki content that describes implementation)
- Current wiki state (fetched via git clone of `{repo}.wiki.git`)

**Architecture:**

The wiki sync module operates as a one-way publish pipeline:

```
Source Code + In-Repo Docs
        │
        ▼
  Content Generation          (Skill layer: Claude Code analyzes code
        │                      and docs, produces wiki-ready markdown)
        ▼
  Diff Against Current Wiki   (Helper layer: clone wiki repo, compare)
        │
        ▼
  Present Diff to Owner       (Skill layer: show what will change,
        │                      explain implications, get approval)
        ▼
  Batch Push to Wiki Repo     (Helper layer: commit + push on approval)
```

**Operations:**
1. Clone the wiki repo (`{repo}.wiki.git`) to a temporary directory
2. Generate wiki page content from configured sources:
   - Transform in-repo docs into wiki-formatted pages
   - Analyze source code to produce/update implementation documentation
   - Apply wiki-specific formatting (sidebar, footer, page linking)
   - Write generated pages to a local staging directory (Claude Code uses its filesystem tools to create each `.md` file in a temp directory, e.g., `/tmp/wiki-generated-xyz/`)
3. Diff generated content against current wiki pages (`wiki diff --dir <clone-dir> --content-dir <staging-dir>`)
4. Identify changes: new pages, updated pages, orphaned pages (in wiki but no longer backed by a source)
5. Present diff and change summary to owner for review and approval
6. On approval: batch commit and push all changes in a single operation
7. Clean up both temp directories
8. Report what changed

**Git Access:**

This module requires git access to the wiki repo, which is the one exception to the "API only" design constraint. The `gh-manager` helper handles this internally:

```
gh-manager wiki clone --repo owner/name --dir /tmp/wiki-xyz
gh-manager wiki diff --dir /tmp/wiki-xyz --content-dir /path/to/generated
gh-manager wiki push --dir /tmp/wiki-xyz --message "Maintenance sync 2026-02-17"
gh-manager wiki cleanup --dir /tmp/wiki-xyz
```

PAT authentication works for git operations over HTTPS (`https://{PAT}@github.com/{owner}/{repo}.wiki.git`), so no additional credentials are needed.

**Wiki Initialization:**

GitHub only creates the wiki git repository (`{repo}.wiki.git`) after the first page is created through the web UI or API. If wiki is "enabled" in repo settings but no pages exist, the wiki git repo does not exist and `git clone` will fail with "Repository not found."

The helper must detect this and report it as a distinct status, not an error:

```json
{
  "status": "wiki_not_initialized",
  "wiki_enabled": true,
  "pages": 0,
  "message": "Wiki is enabled but has no pages. The wiki git repo does not exist yet."
}
```

Claude handles this conversationally:

```
Claude: Wiki is enabled on ha-light-controller but doesn't have any
        content yet. GitHub hasn't created the wiki repository until
        the first page is added.

        I can initialize it by pushing a starter Home page — that
        will create the wiki repo. Then I can populate it with
        your documentation. Want me to set it up?
```

The helper's `wiki init` command initializes the wiki by performing a git push to the wiki repo. GitHub has no REST API for creating wiki pages — wiki content is managed exclusively through git. When wiki is enabled in repo settings but no pages exist, the wiki git repo doesn't exist yet. Pushing a commit to `{repo}.wiki.git` for the first time causes GitHub to create the wiki repo and publish the page.

```
gh-manager wiki init --repo owner/name
```

Internally, this:
1. Creates a local temp directory with a `Home.md` containing a placeholder welcome page
2. Initializes a git repo, adds `{repo}.wiki.git` as remote (authenticated via PAT over HTTPS)
3. Commits and pushes — GitHub creates the wiki repo on receiving the first push
4. Cleans up the temp directory

This initialization requires owner approval. After init succeeds, the normal `wiki clone` → `wiki diff` → `wiki push` pipeline takes over to populate the wiki with real content.

**Wiki Structure Management:**

The module manages standard wiki scaffolding:

| Wiki File | Generated From |
|-----------|---------------|
| `Home.md` | Project README or configured landing page |
| `_Sidebar.md` | Auto-generated table of contents from page list |
| `_Footer.md` | Configurable template (version, last updated, links) |
| Content pages | Mapped from `docs/` structure and code analysis |

**Page Mapping Strategy:**

The mapping from repo files to wiki pages is configurable:

```yaml
wiki_sync:
  page_map:
    - source: "docs/getting-started.md"
      wiki_page: "Getting-Started"
    - source: "docs/api/"
      wiki_page: "API-Reference"
      mode: "concatenate"  # Combine directory into single page
    - source: "auto:functions"
      wiki_page: "Function-Reference"
      mode: "generate"     # Generate from code analysis
```

The `auto:` prefix triggers Claude Code to analyze source code and generate documentation. Supported auto-generation targets:
- `auto:functions` — exported function signatures, parameters, return types
- `auto:cli` — CLI flags, commands, usage examples
- `auto:config` — configuration options, defaults, environment variables
- `auto:api` — API endpoints, request/response schemas

**Orphan Handling:**

Wiki pages that exist but no longer map to any source are flagged as orphans. Configurable behavior:
- `warn` (default) — include in maintenance report
- `delete` — remove orphaned pages during sync
- `archive` — move to an `_Archive` section in the sidebar

**Tier-Specific Behavior:**

| Behavior | Tier 3 | Tier 4 |
|----------|--------|--------|
| Push on approval | Yes | Yes, with full diff review first |
| Orphan handling | Configurable | `warn` only — owner decides |
| Sidebar regeneration | Included in push (no separate approval) | Included in push (no separate approval) |
| Content generation | Full | Full, with extra caution on API docs |

---

### 5.2 Community Health Module

**Purpose:** Audit and maintain community health files per GitHub's community standards.

**Target Files:**
| File | Location | Purpose |
|------|----------|---------|
| `README.md` | Root | Project overview, badges, quickstart |
| `CONTRIBUTING.md` | Root or `.github/` | Contribution guidelines |
| `CODE_OF_CONDUCT.md` | Root or `.github/` | Community behavior standards |
| `SECURITY.md` | Root or `.github/` | Vulnerability reporting process |
| `SUPPORT.md` | Root or `.github/` | How to get help |
| `FUNDING.yml` | `.github/` | Sponsorship configuration |
| `CODEOWNERS` | Root or `.github/` | Auto-review assignment |
| Issue templates | `.github/ISSUE_TEMPLATE/` | Structured issue reporting |
| PR template | `.github/PULL_REQUEST_TEMPLATE.md` | PR description structure |
| Discussion templates | `.github/DISCUSSION_TEMPLATE/` | Discussion category forms |

**Operations:**
1. Check existence of each file via Contents API
2. Validate content freshness (last commit date vs. configurable threshold)
3. Cross-reference content accuracy:
   - Does CONTRIBUTING.md reference the correct branch names?
   - Does SECURITY.md list a valid contact method?
   - Does CODEOWNERS reference valid team/user handles?
   - Do issue templates match current project labels?
4. Score the repo against GitHub's Community Profile API (`GET /repos/{owner}/{repo}/community/profile`)
5. Present findings and propose patches for missing/stale files (owner approves before execution)

**Content Generation Policy:**
- Never overwrite existing content without presenting the diff to the owner
- For missing files: generate from configurable templates, present for approval
- For stale files: propose targeted edits, not full rewrites

**Label Management:**

The plugin uses labels (e.g., `maintenance`, `stale`, `ready-to-merge`, `needs-rebase`) for PR and issue management. These labels may not exist on the repo. Before any module attempts to apply a label, the community health module verifies it exists and creates it if missing — with owner approval.

On first assessment of a repo, Claude checks the repo's label set against the labels the plugin needs:

```
Claude: I noticed your repo only has the default GitHub labels (bug,
        enhancement, etc.). Several of the maintenance actions I can
        take use custom labels for tracking:

        Missing labels I'd like to create:
        • maintenance — marks PRs created by this plugin
        • stale — flags PRs/issues with no recent activity
        • ready-to-merge — approved PRs awaiting merge
        • needs-rebase — PRs with merge conflicts

        Want me to create these, or would you prefer different names?
```

This is a one-time setup per repo. Once labels exist, subsequent sessions use them without re-prompting.

```yaml
community_health:
  maintenance_labels:
    - name: "maintenance"
      color: "0E8A16"
      description: "Maintenance task created by repo manager"
    - name: "stale"
      color: "FBCA04"
      description: "No recent activity"
    - name: "ready-to-merge"
      color: "0E8A16"
      description: "Approved and ready to merge"
    - name: "needs-rebase"
      color: "E11D48"
      description: "Has merge conflicts, needs rebase"
```

**Org-Level `.github` Repository:**

GitHub supports organization-level community health files via a special `.github` repository. Files like SECURITY.md, CODE_OF_CONDUCT.md, CONTRIBUTING.md, and SUPPORT.md placed in this repo automatically apply to all repositories in the organization that don't have their own version.

When a cross-repo community health check reveals the same file missing from multiple repos, Claude should suggest the `.github` repo approach as an alternative to adding the file to each repo individually:

```
Claude: SECURITY.md is missing from all 5 of your public repos.
        Instead of adding it to each one, you could create a
        .github repository for your L3DigitalNet organization.
        Files in that repo automatically apply to all your repos
        that don't have their own version.

        That means one SECURITY.md covers everything, and you
        only need per-repo versions where the policy differs.

        Want me to create the .github repo with a shared
        SECURITY.md, or add it to each repo individually?
```

**Detection:** On cross-repo checks, the helper checks whether a `.github` repo exists (`gh-manager repos list` includes it). If it does, the community health module inspects its contents and factors them into per-repo health scores — a repo without its own SECURITY.md but covered by an org-level one is not flagged as missing.

**Actions (owner approves):**
- Create the `.github` repo if it doesn't exist
- Add shared community health files to `.github`
- Migrate individual per-repo files to org-level when they're identical across repos

---

### 5.3 Pull Request Management Module

**Purpose:** Triage, audit, and surface actionable intelligence on open pull requests.

**Operations:**
1. Fetch all open PRs via REST/GraphQL
2. For each PR, assess:
   - **Staleness:** Days since last activity (commit, comment, review)
   - **Merge conflicts:** Mergeable state via API
   - **Review status:** Approved, changes requested, pending, no reviewers assigned
   - **CI status:** Check runs passing/failing/pending
   - **Size classification:** Lines changed (S/M/L/XL)
   - **Label compliance:** Required labels present?
   - **Linked issues:** Are there associated issues?
3. Generate triage recommendations:
   - "PR #42 has been idle for 14 days with approved reviews — ready to merge"
   - "PR #57 has merge conflicts and failing CI — needs author attention"
   - "PR #31 has no reviewers assigned — suggest @team/core"
4. Propose actions to owner for approval:
   - Add labels (stale, needs-rebase, needs-review)
   - Post reminder comments (with HTML markers for deduplication)
   - Request specific reviewers
   - Merge PRs that are approved and passing CI (on explicit owner request)
   - Close stale PRs (with comment explaining why)

**Configurable Policies:**
```yaml
pr_management:
  staleness_threshold_days: auto  # auto = use tier default (Section 7.3)
  ignore_labels:
    - "do-not-close"
    - "long-running"
  size_thresholds:
    small: 50
    medium: 200
    large: 500
    xlarge: 1000    # Anything above large; S/M/L/XL used in triage summary
```

---

### 5.4 Notifications Module

**Purpose:** Process and triage repository notifications for the authenticated user.

**Operations:**
1. Fetch notifications filtered by repository (`GET /repos/{owner}/{repo}/notifications`)
2. Categorize by type: mention, review_requested, assign, ci_activity, security_alert, discussion
3. Summarize notification backlog with counts and priorities
4. Present action items to owner: "You were requested to review PR #42", "Security alert on lodash@4.17.20"
5. Mark notifications as read on owner approval

**Priority Classification:**
| Priority | Criteria |
|----------|----------|
| Critical | Security alerts, CI failures on default branch |
| High | Review requests, direct mentions, assigned issues |
| Medium | PR activity on watched threads, discussion replies |
| Low | Dependabot PRs, bot comments, subscription updates |

---

### 5.5 Security Module

**Purpose:** Audit the repository's security posture and surface actionable findings.

**Operations:**
1. **Dependabot Alerts:** Fetch via REST API, summarize severity distribution, flag critical/high
2. **Code Scanning Alerts:** Fetch CodeQL or third-party results, summarize open findings
3. **Secret Scanning Alerts:** Check for exposed secrets
4. **Security Advisories:** Fetch repository security advisories, check draft status
5. **Security Policy:** Validate SECURITY.md exists and is current (cross-ref with Community Health module)
6. **Branch Protection:** Audit default branch protection rules — require reviews? require status checks? enforce admins?
7. **Dependency Graph:** Verify dependency graph and Dependabot are enabled

**Output:** Security posture scorecard with severity-weighted findings. Most recommended actions (enabling Dependabot, dismissing resolved alerts) are presented to the owner for approval before execution. **Exception:** Branch protection configuration is recommend-only — the helper can audit current rules but cannot modify them. Configuring branch protection requires Administration Write scope, which is reserved for `.github` repo creation (Section 5.2). If Claude recommends branch protection changes, it provides the specific settings to configure and directs the owner to the repository's Settings → Branches page.

---

### 5.6 Discussions Module

**Purpose:** Manage GitHub Discussions for the repository.

**Operations:**
1. Fetch open discussions via GraphQL (REST support is limited)
2. Identify unanswered discussions (no replies or no marked answer)
3. Identify stale discussions (no activity beyond configurable threshold)
4. Categorize by discussion category (Q&A, Ideas, Show and Tell, etc.)
5. Surface threads needing maintainer attention
6. Propose closing resolved or stale discussions (owner approves)

---

### 5.7 Dependency Audit Module

**Purpose:** Review dependency health beyond just security alerts.

**Operations:**
1. Fetch dependency graph via API
2. Check for outdated major versions (if Dependabot PRs exist but are unmerged)
3. Summarize Dependabot PR backlog (count, age, severity)
4. Flag license compliance issues (if license detection data available)
5. Recommend batch-merge strategies for low-risk dependency bumps (owner approves before any merges)

---

### 5.8 Issue Triage Module

**Purpose:** Audit and triage open issues to surface what needs attention, identify stale or unlabeled issues, and keep the issue tracker healthy.

**Operations:**
1. Fetch all open issues via REST API (excluding pull requests, which share the issues endpoint)
2. For each issue, assess:
   - **Staleness:** Days since last activity (comment, label change, assignment)
   - **Labels:** Are issues labeled? Are labels from the project's label set?
   - **Assignees:** Is anyone assigned?
   - **Linked PRs:** Is there a PR that addresses this issue?
   - **Duplicates:** Are any open issues clearly related (similar titles, referenced together)?
   - **Milestones:** Is the issue assigned to a milestone?
3. Generate triage recommendations:
   - "Issue #12 has been open 45 days with no comments or assignee — stale or forgotten?"
   - "Issue #8 has a linked PR (#15) that's been merged — this issue may be resolved"
   - "3 issues have no labels — want me to suggest labels based on their content?"
4. Propose actions to owner for approval:
   - Add labels (based on issue content analysis)
   - Close resolved issues (with comment linking to the fix)
   - Post activity check comments on stale issues
   - Assign issues to the owner

**Configurable Policies:**
```yaml
issue_triage:
  staleness_threshold_days: auto  # auto = use tier default (Section 7.3)
  require_labels: true
  ignore_labels:
    - "long-term"
    - "backlog"
```

**Cross-Module Connection:** Issues with linked PRs are cross-referenced with the PR Management module to identify issues that may be resolved but not yet closed. Dependabot and security alerts that have associated issues are noted to avoid duplicate surfacing with the Security module.

---

### 5.9 Release Health Module

**Purpose:** Assess release readiness for Tier 4 repos — surface unreleased work, changelog drift, and draft releases. Helps the owner answer the question: "Should I cut a release?"

**Applicability:** Tier 4 only (public repos with releases). Informational on Tier 3 repos that have tags but no formal release process. Disabled on Tiers 1-2.

**Operations:**
1. **Unreleased commits:** Compare latest release tag against default branch head (`GET /repos/{owner}/{repo}/compare/{tag}...{branch}`). Surface commit count, date range, and notable changes.
2. **CHANGELOG drift:** Fetch CHANGELOG.md (or CHANGES.md, HISTORY.md) and check whether the latest entry matches the latest release tag. If the changelog has entries beyond the last release, note that unreleased changes are documented. If it hasn't been updated since the last release but commits exist, flag the drift.
3. **Draft releases:** Fetch releases and check for unpublished drafts (`GET /repos/{owner}/{repo}/releases` → filter `draft: true`). Surface draft releases that may be ready to publish.
4. **Release cadence:** Calculate time since last release and average interval between previous releases. Flag if significantly overdue relative to historical pattern.
5. **Tag-branch alignment:** Verify the latest release tag points to a commit on the default branch (not a stale branch or detached commit).

**Presentation:**

```
Claude: 📦 Release Health — ha-light-controller

        Last release: v0.2.2 (Feb 10, 2026 — 7 days ago)
        Unreleased commits: 9 commits on main since v0.2.2
        CHANGELOG.md: Last entry is for v0.2.2 — not yet updated
                       for unreleased work
        Draft releases: None
        Average release cadence: ~12 days (based on last 5 releases)

        There's a decent amount of unreleased work accumulating.
        The CHANGELOG hasn't been updated for the new commits yet.
        Want me to summarize the unreleased commits so you can
        decide if it's time for a release?
```

**Actions (owner approves):**
- Summarize unreleased commits into a draft changelog entry
- Create a draft release on GitHub with generated release notes
- Flag specific commits that may warrant a minor vs. patch version bump
- Update CHANGELOG.md with new entries (via PR on Tier 4)

**Configurable Policies:**
```yaml
release_health:
  enabled: true                    # Auto-enabled on Tier 4
  changelog_files:
    - CHANGELOG.md
    - CHANGES.md
    - HISTORY.md
  cadence_warning_multiplier: 2.0  # Warn if 2x average interval since last release
```

---

## 6. GitHub API Strategy

### 6.1 Authentication

- **Method:** Personal Access Token (PAT) — fine-grained or classic
- **Storage:** Environment variable (`GITHUB_PAT`) or Claude Code config
- **Scoping (fine-grained PAT recommended):**

| Permission | Access Level | Used By |
|-----------|-------------|---------|
| Contents | Read & Write | Wiki sync, community health file updates |
| Pull requests | Read & Write | PR management, labels, comments |
| Issues | Read & Write | Issue triage, labels, comments, linked issue management |
| Discussions | Read & Write | Discussion triage |
| Security events | Read | Security alerts, advisories |
| Administration | Read | Branch protection audit |
| Administration | Write (optional) | Required only for creating org-level `.github` repo (Section 5.2). Not needed for standard operation — Claude will note the missing permission and suggest the owner create the repo manually if this scope isn't available. |
| Notifications | Read & Write | Notification processing |
| Metadata | Read | General repo info |
| Dependabot alerts | Read | Security module |
| Code scanning alerts | Read | Security module |
| Secret scanning alerts | Read | Security module |

### 6.2 API Selection: REST vs. GraphQL

| Task | Preferred API | Rationale |
|------|--------------|-----------|
| Fetch repo metadata | REST | Simple, well-documented |
| Fetch open PRs with reviews | GraphQL | Single query gets PRs + reviews + status checks |
| Community profile check | REST | Dedicated endpoint |
| Fetch discussions | GraphQL | REST has no discussions endpoint |
| File CRUD operations | REST (Contents API) | Straightforward file management |
| Notification management | REST | Dedicated endpoints |
| Security alerts | REST | Dedicated endpoints per alert type |
| Issue management | REST | Well-supported CRUD operations |
| Releases & tags | REST | Dedicated release endpoints |
| Bulk operations | GraphQL | Reduces API calls |

### 6.3 Rate Limiting Strategy

- GitHub REST: 5,000 requests/hour (authenticated)
- GitHub GraphQL: 5,000 points/hour (authenticated)
- **Mitigation:**
  - Use GraphQL for bulk data fetching where possible
  - Cache responses during a single maintenance run
  - Track remaining rate limit via response headers
  - When rate limit is approaching exhaustion, report remaining budget to owner and discuss whether to pause, generate a partial report, or continue selectively
  - Report rate limit consumption in maintenance report

---

## 7. Repository Classification & Mutation Strategy

**Core Principle: No action without owner approval.** Regardless of tier, the plugin never mutates a repository without explicit owner approval during the conversation. Tiers control *how much ceremony* surrounds that approval (brief batch confirmation vs. detailed per-item review with diffs), not *whether* approval is required. The owner always has the final say.

### 7.1 Tier System

Repositories are classified into four tiers based on visibility and release maturity. Each tier defines a different mutation strategy, balancing speed against ceremony.

| Tier | Description | Visibility | Has Releases | Mutation Philosophy |
|------|-------------|-----------|-------------|-------------------|
| **1** | Private, Docs Only | Private | N/A* | Low ceremony — batch approvals, brief context |
| **2** | Private, Runnable Code | Private | N/A* | Moderate ceremony — show diffs, individual approvals for code-adjacent changes |
| **3** | Public, No Releases | Public | No | Direct commit with detailed review, never auto-close external contributions |
| **4** | Public, Releases | Public | Yes | Maximum ceremony — PRs for file changes, detailed review before every action |

*Releases don't factor into tier assignment for private repos. A private repo with releases stays at Tier 1 or 2 based on code signals alone (see Section 7.4).

### 7.2 Tier Behaviors

The tier system determines how much ceremony and caution the plugin applies when proposing and executing changes during a conversational session. Higher tiers prompt for more confirmation and default to less aggressive actions.

#### Tier 1 — Private, Documentation Only

Lowest stakes. Only the repo owner sees it, nothing executes. Claude still requires owner approval for all actions, but the conversation moves quickly — batch approvals and brief summaries rather than detailed per-item review.

- **File mutations:** Commit directly to default branch (with owner approval)
- **Labels/comments:** Apply on approval
- **Stale PRs/discussions:** Propose closing, execute on approval
- **Community health files:** Propose creation/updates, execute on approval
- **Wiki sync:** N/A (private repo)
- **Conversation style:** Brief summary, batch approvals ("I found 5 issues, want me to fix them all?")

#### Tier 2 — Private, Runnable Code

Still private, but changes could affect runtime behavior. Claude shows more detail before acting.

- **File mutations:** Commit directly to default branch (with owner approval)
- **Labels/comments:** Apply on approval
- **Stale PRs/discussions:** Propose closing with rationale, execute on approval
- **Community health files:** Propose creation/updates, execute on approval
- **Wiki sync:** N/A (private repo)
- **Conversation style:** Show diffs for content changes, individual approval for code-adjacent docs

#### Tier 3 — Public, No Releases

Public visibility adds reputational risk. Claude is more cautious, presents detailed context, and flags anything externally visible. File mutations still use direct commits (the owner approves each change conversationally), but Claude never auto-closes PRs or discussions created by external contributors. This tier covers both public repos with runnable code and public docs-only repos (markdown collections, awesome-lists). For docs-only repos, code-dependent modules (dependency audit, release health) are automatically skipped.

- **File mutations:** Commit directly to default branch (with owner approval), showing full diff before committing
- **Labels/comments:** Propose with rationale, execute on approval
- **Stale PRs/discussions:** Flag for owner review, never auto-close
- **Community health files:** Commit directly to default branch (with owner approval)
- **Wiki sync:** Generate and present diff, push on approval
- **Conversation style:** Detailed findings with recommendations, explicit approval per action category

If the owner wants PR-based mutations on a Tier 3 repo, they can override the tier to 4 in the repo config.

#### Tier 4 — Public, Runnable Code, Releases

Highest ceremony. Users depend on stability. Claude surfaces everything for review and acts conservatively.

- **File mutations:** Via PR, grouped by module, labeled `maintenance` (with owner approval)
- **Labels/comments:** Propose with full context, execute on approval
- **Stale PRs/discussions:** Flag for owner review, never auto-close
- **Community health files:** Via PR (with owner approval)
- **Wiki sync:** Generate and present full diff, push only on explicit approval
- **Conversation style:** Prioritized findings report, owner drives which actions to take

### 7.3 Default Staleness Thresholds by Tier

These thresholds guide Claude's assessment of what needs attention. Claude uses them to classify and prioritize findings, not to take automatic action.

| Tier | PR Flagged as Stale | PR Proposed for Closing | Discussion Flagged as Stale | Issue Flagged as Stale |
|------|--------------------|-----------------------|---------------------------|----------------------|
| 1 — Private Docs | 7 days | 30 days | 14 days | 14 days |
| 2 — Private Code | 14 days | 60 days | 21 days | 21 days |
| 3 — Public, No Releases | 21 days | Owner decision | 30 days | 30 days |
| 4 — Public Releases | 30 days | Owner decision | 30 days | 30 days |

All thresholds are configurable per-repo in `.github-repo-manager.yml`.

### 7.4 Auto-Detection

On first run against a new repo, the plugin inspects the repository to propose a tier classification. The owner confirms or overrides the suggestion, which is then persisted in config.

**Detection Signals:**

| Signal | Detection Method | Indicates |
|--------|-----------------|-----------|
| Fork | `GET /repos/{owner}/{repo}` → `fork` field | Fork — skip by default |
| Archived | `GET /repos/{owner}/{repo}` → `archived` field | Archived — skip by default (read-only, no mutations possible) |
| Visibility | `GET /repos/{owner}/{repo}` → `private` field | Private vs. Public |
| Has releases | `GET /repos/{owner}/{repo}/releases` → non-empty | Release repo |
| Has runnable code | Presence of CI workflows (`.github/workflows/`), package manifests (`package.json`, `Cargo.toml`, `pyproject.toml`, etc.), or `src/`/`lib/` directories | Code repo vs. docs-only |
| Docs only | Repository contains only `.md`, `.txt`, `.rst`, or similar text files; no CI; no package manifest | Documentation repo |

**Detection Flow:**

```
1. Fetch repo metadata (visibility, fork status, archived status)
2. If fork → skip (default) or apply override from config
3. If archived → skip (default) or apply override from config (read-only assessment only)
4. Check for releases
5. Scan root directory and .github/workflows/ for code signals
6. Propose tier:
   - Private + no code signals           → Tier 1
   - Private + code signals              → Tier 2 (even if releases exist — see note)
   - Public + no code signals            → Tier 3 (docs-only variant — see note)
   - Public + code signals + no releases → Tier 3
   - Public + code signals + releases    → Tier 4
7. Present proposal to owner for confirmation
8. Store confirmed tier in .github-repo-manager.yml
```

**Public docs-only repos:** A public repository with no runnable code (markdown collections, awesome-lists, documentation-only repos) is classified as Tier 3 because public visibility still carries reputational risk and external contributor considerations. The wiki sync and community health modules apply normally. Modules that require code (dependency audit, release health) are automatically skipped since there's nothing to analyze.

**Private repos with releases:** A private repository with releases stays at Tier 2, not Tier 4. The tier system's ceremony escalation is driven by public visibility risk — external consumers, reputational impact, contributor relations — none of which apply to private repos. The mutation strategy stays low-ceremony since only the owner sees the repo. Note that the Release Health module is Tier 4 only (with informational support on Tier 3), so it won't run on Tier 2 repos by default. If the owner wants release health assessment on a private repo, they can override the tier to 3 or 4 in the repo config — though this also raises the mutation ceremony level, which may be unnecessary for a private repo.

**Archived repos:** Archived repos are read-only on GitHub — all mutations return 403. They are skipped by default in both single-repo and cross-repo modes. In cross-repo reports, archived repos are listed alongside forks:

```
Skipped:
  forks: integration_blueprint, brands
  archived: old-project, legacy-tool
```

If the owner explicitly targets an archived repo, Claude can still run a read-only assessment (check community health, review open PRs/issues) but will note that no mutations are possible:

```
Claude: ha-legacy-tool is archived, so it's read-only — I can't
        create PRs, push to wiki, or modify files. I can still
        assess its current state if you want a health snapshot.
```

The owner can include archived repos in portfolio config with a read-only flag:

```yaml
repos:
  old-project:
    skip: false
    read_only: true   # Allow assessment, block mutations
```

**Manual Override:**

```yaml
# .github-repo-manager.yml
repo:
  tier: 3  # Manual override — auto-detection suggested 2
```

### 7.5 PR Batching Strategy (Tier 4)

When mutations require PRs (Tier 4 only), changes are batched by module into a single PR per module per run.

**PR creation workflow:**
1. Create a branch from the default branch head (`gh-manager branches create --repo owner/name --branch maintenance/community-health-2026-02-17 --from main`)
2. Commit file changes to the branch (`gh-manager files put --repo owner/name --branch maintenance/community-health-2026-02-17 --path SECURITY.md --message "Add SECURITY.md"`)
3. Open a PR from the branch to default (`gh-manager prs create --repo owner/name --head maintenance/community-health-2026-02-17 --base main --title "[Maintenance] Community health — SECURITY.md added"`)

**Branch naming convention:**

- `maintenance/wiki-sync-2026-02-17`
- `maintenance/community-health-2026-02-17`
- `maintenance/dependency-updates-2026-02-17`

Each PR includes:
- A descriptive title: `[Maintenance] Wiki sync — 3 pages updated`
- The module's findings and rationale in the PR body
- A `maintenance` label for easy filtering
- Individual commits per file change within the branch (for granular review)

If a maintenance PR from a previous run is still open, the plugin updates the existing branch rather than creating a duplicate PR (addresses idempotency concern).

**Existing PR detection:** Before creating a new maintenance branch, Claude checks for open PRs with the `maintenance` label whose title starts with the same module prefix (e.g., `[Maintenance] Community health`). If a match is found, Claude updates the existing branch with new commits and adds a comment to the existing PR noting what changed. This works regardless of the date in the branch name. If the existing branch has merge conflicts with the default branch, Claude reports this and offers to close the old PR and create a fresh one.

---

### 7.6 Communication Style & Educational Approach

The plugin's conversational style is informative and educational. The owner is a competent developer but not a GitHub power user — concepts like forks, pull requests, branch protection, and merge strategies may not be fully familiar. Claude explains as it goes, in context, without being condescending.

**This is a skill-layer concern.** The communication style is defined in the SKILL.md and module markdown files, not in the helper. The helper returns raw data; Claude interprets it and communicates with the owner using the principles below.

#### Owner Expertise Level

The communication principles above are modulated by a configurable expertise level that controls how much explanation Claude provides. This is set in the portfolio config and can be changed at any time as the owner's GitHub proficiency grows.

```yaml
# portfolio.yml
owner:
  expertise: beginner  # beginner | intermediate | advanced
```

**Beginner (default):**
All seven principles active at full intensity. Claude explains GitHub concepts on first mention, provides implication warnings for most actions, includes jargon translation, and offers teaching moments.

```
Claude: I'll create a pull request — that's a proposal to merge these
        changes into the main branch. Your Tier 4 repos use PRs so
        you can review the changes before they go live. You'll see it
        in the repo's "Pull requests" tab and can merge it when ready.
```

**Intermediate:**
Claude assumes familiarity with core GitHub concepts (PRs, branches, merging, issues, labels). Explanations are limited to less common operations (rebasing, squash merging, branch protection rules, GitHub Actions, security advisories). Implication warnings and irreversibility flags still appear for consequential actions. Jargon translation is dropped for common terms.

```
Claude: I'll open a PR with the updated SECURITY.md. Since this is
        Tier 4, you'll want to review and merge it when ready.
```

**Advanced:**
Claude communicates concisely, like a peer who knows you understand GitHub. Explanations are omitted for standard operations. Only irreversibility flags and unusual-situation warnings remain — things any experienced user would want flagged regardless of expertise.

```
Claude: Opening PR with SECURITY.md on ha-light-controller.
        ⚠️ This will also trigger the CI workflow — just a heads up
        since the last CI run had a flaky test.
```

**The expertise level can also be changed mid-session:**

```
Owner: You don't need to explain what PRs are anymore, I get it

Claude: Got it — I'll dial back the explanations. You can also set
        this permanently by updating your expertise level to
        "intermediate" in your portfolio config.
```

**What each level affects:**

| Principle | Beginner | Intermediate | Advanced |
|-----------|----------|-------------|----------|
| Explanatory context | Full | Uncommon concepts only | Omitted |
| Implication warnings | All actions | Consequential actions | High-risk only |
| Irreversibility flags | Always | Always | Always |
| Jargon translation | All terms | Uncommon terms only | None |
| Tier-aware sensitivity | Full | Reduced on lower tiers | High tiers only |
| Teaching moments | Proactive | On request | Off |
| Progressive depth | Offers detail | Assumes competence | Terse |

#### Principle 1: Explanatory Context

Before proposing an action, Claude briefly explains what it is and why it matters (at beginner/intermediate levels). Not a tutorial — just enough to make an informed decision.

```
Claude: PR #5 has merge conflicts. That means the code in the main
        branch has changed since this PR was created, so GitHub can't
        automatically combine them. The PR author (in this case Copilot)
        would need to update their branch to include the latest changes
        before this PR can be merged.

        Options: I can post a comment asking for a rebase, or you
        could close this PR and have Copilot regenerate it against
        the current code. What would you prefer?
```

#### Principle 2: Implication Warnings

When the owner asks Claude to do something with consequences they might not be aware of, Claude flags them before acting — especially for publicly visible actions.

```
Owner: Close PR #8 on HA-Dev-Template

Claude: I can close that. A couple things to know: closing a PR is
        reversible (you can reopen it later), but it will send a
        notification to the PR author. Since this one was created by
        Copilot there's no human to notify, so no concern there.

        On repos where external contributors submit PRs, it's good
        practice to leave a comment explaining why before closing —
        closing without explanation can discourage future contributions.

        Want me to close it, or close with a comment?
```

#### Principle 3: Irreversibility Flags

Clear callouts when an action cannot be easily undone. These should be concise but unmissable.

Actions that warrant irreversibility flags:
- Deleting a branch (commits may become unreachable)
- Force-pushing to a wiki (overwrites history)
- Deleting wiki pages
- Dismissing security alerts
- Closing and locking discussions

```
Claude: ⚠️ Heads up: pushing to the wiki will overwrite whatever is
        there now. Wiki history is preserved in git, so it's technically
        recoverable, but it's not as simple as hitting "undo." I'll
        show you the diff first so you can see exactly what changes.
```

#### Principle 4: Jargon Translation

When GitHub concepts come up naturally, Claude uses plain language alongside the terminology. The goal is to build the owner's understanding over time without slowing down the conversation.

**Do this:**
```
Claude: I'll create a pull request — that's a proposal to merge these
        changes into the main branch. Your Tier 4 repos use PRs so
        you can review the changes before they go live. You'll see it
        in the repo's "Pull requests" tab and can merge it when ready.
```

**Not this:**
```
Claude: I'll create a PR. [proceeds without explanation]
```

**And not this:**
```
Claude: A pull request, which is a feature of git-based version control
        systems that allows developers to notify team members that they
        have completed a feature, is a mechanism by which... [wall of text]
```

The right amount of explanation is one or two sentences, inline, on first mention in a session. If the same concept comes up again in the same session, Claude can use the shorthand without re-explaining.

#### Principle 5: Tier-Aware Sensitivity

The level of explanation and warning scales with the repo tier:

| Tier | Explanation Level | Warning Level |
|------|------------------|---------------|
| 1 — Private Docs | Light — brief context | Minimal — low stakes |
| 2 — Private Code | Moderate — explain code-affecting actions | Moderate — flag runtime impact |
| 3 — Public, No Releases | Full — explain public visibility implications | High — flag anything externally visible |
| 4 — Public Releases | Full — explain release/stability implications | Highest — flag anything affecting users |

For example, adding a label on a Tier 1 repo needs no warning. Adding a label on a Tier 4 repo might warrant: "This label will be visible to anyone watching the repo, and subscribers may get a notification depending on their settings."

#### Principle 6: Teaching Moments

When Claude detects a gap that represents a learning opportunity, it can briefly explain *why* something matters, not just *that* it's missing.

```
Claude: Your repo is missing a SECURITY.md file. This is important
        for public projects because it tells people how to responsibly
        report security vulnerabilities — without it, someone who
        finds a bug might post it as a public issue, which exposes
        the vulnerability to everyone before you can fix it.

        SECURITY.md typically includes a contact email and a brief
        description of your disclosure process. Want me to create one?
```

#### Principle 7: Progressive Depth

Claude defaults to concise explanations but offers to go deeper when the topic warrants it. This avoids information overload while keeping detail available.

```
Claude: Your default branch (main) doesn't have branch protection
        rules enabled. That means anyone with write access can push
        directly to main without a review. For a public project with
        releases, it's best practice to require at least one review
        before changes land on main.

        Want me to explain the specific protection options, or just
        set up the recommended defaults?
```

---

### 7.7 Error Handling

Errors are handled conversationally, not programmatically. When something fails, Claude reports what happened, explains the implications at the appropriate expertise level, and collaborates with the owner on how to proceed. There is no hardcoded retry logic, no automatic fallback, and no silent failures.

#### Helper Error Contract

Every `gh-manager` command returns structured errors to stderr with a non-zero exit code:

```json
{
  "error": "Resource not accessible by integration",
  "status": 403,
  "endpoint": "GET /repos/L3DigitalNet/ha-light-controller/dependabot/alerts",
  "context": "PAT lacks 'security_events' permission or Dependabot is not enabled"
}
```

The skill layer interprets these errors and presents them to the owner in plain language.

#### Error Categories

| Category | Example | Claude's Response |
|----------|---------|-------------------|
| **Permission** | PAT missing a required scope | Explain which permission is missing, what it would enable, and how to add it. Offer to continue with available data. |
| **Not Enabled** | Dependabot/discussions not enabled on repo | Explain what the feature is, note it's not enabled, offer to skip or explain how to enable it. |
| **Rate Limit** | Approaching or hit API rate limit | Report remaining budget, what's been completed so far, and whether to pause, generate a partial report, or wait for reset. |
| **Network** | Timeout, DNS failure, GitHub outage | Report the failure, suggest retrying or waiting. |
| **Not Found** | Repo, branch, or resource doesn't exist | Flag the specific resource and likely cause. |
| **Unexpected** | Malformed API response, unknown error | Report raw details, suggest it may be a GitHub issue, offer to skip and continue. |

#### Behavior During Single-Repo Sessions

Claude collects errors as it works through modules and handles them inline:

```
Claude: I finished checking community health and PRs. When I tried
        to check Dependabot alerts, I got a 403 — your PAT doesn't
        have permission to access security alerts on this repo, or
        Dependabot may not be enabled.

        I still have notifications, discussions, and wiki left to
        check. Want me to continue with those, or would you rather
        pause and sort out the Dependabot access first?
```

If multiple errors accumulate, Claude summarizes them together rather than interrupting the flow for each one:

```
Claude: I've completed the assessment with a few issues:

        ⚠️ Errors encountered:
        • Dependabot alerts: 403 — permission denied
        • Code scanning: 404 — not enabled on this repo
        • Discussions: skipped — not enabled

        Everything else completed successfully. Here are the
        findings from the modules that worked...
```

#### Behavior During Cross-Repo Checks

When scanning multiple repos, Claude continues past per-repo errors and includes them in the report:

```
Claude: Scanned 17 repositories for community health:

        ✅ 14 repos scanned successfully
        ⚠️ 3 repos had issues:
        • ha-dev-test-server: 403 on community profile endpoint
        • integration_blueprint: skipped (fork)
        • brands: skipped (fork)

        Here are the findings from the 14 successful scans...
```

#### Partial Reports

If a session is interrupted by a systemic failure (rate limit, network), Claude generates a partial maintenance report covering everything completed up to that point, clearly marking what was and wasn't checked.

#### No Silent Failures

The helper must never swallow errors. If an API call fails, the structured error must reach Claude so it can be reported to the owner. The principle is: **the owner always knows what happened, what it means, and what the options are.**

---

### 7.8 Cross-Module Intelligence

Modules are specified independently, but in practice their findings overlap. The same underlying issue can appear in multiple modules from different angles — a Dependabot alert shows up in both the Security module and as an open PR in PR Management; a merged PR that fixes issue #12 should inform both Issue Triage and PR Management. Without cross-module awareness, the owner sees redundant findings that waste their time and erode trust in the tool.

**This is a skill-layer concern.** The core orchestration skill (`skills/repo-manager/SKILL.md`) must instruct Claude to synthesize findings across modules before presenting them to the owner.

#### Module Execution Order

For cross-module deduplication to work correctly, modules must run in a specific order so that the "primary" module for each overlapping concern discovers the finding first:

```
1. Security          — owns Dependabot alerts, secret scanning, security posture
2. Release Health    — owns CHANGELOG drift, unreleased commits, release cadence
3. Community Health  — owns community files (defers CHANGELOG to Release Health on Tier 4)
4. PR Management     — owns open PRs (defers Dependabot PRs to Security)
5. Issue Triage      — owns open issues (cross-references merged PRs from step 4)
6. Dependency Audit  — owns dependency graph (defers Dependabot alerts to Security)
7. Notifications     — owns notification backlog
8. Discussions       — owns discussion threads
9. Wiki Sync         — owns wiki content (runs last — may reference findings from above)
```

This order ensures that when the deduplication rules (below) reference "primary module," that module has already run and claimed its findings. Modules running later check whether findings have already been claimed before surfacing them.

For narrow checks (owner asks about a single module), the order is irrelevant — only the requested module runs. Cross-module deduplication only applies during full assessments.

#### Deduplication Rules

Claude applies these rules when assembling the findings summary:

| Overlap | Primary Module | Other Module(s) | Resolution |
|---------|---------------|-----------------|------------|
| Dependabot PR is also a security alert | Security | PR Management | Present once under Security with a note that a fix PR exists. Don't repeat in PR findings. |
| Merged PR links to open issue | PR Management | Issue Triage | Surface in Issue Triage as "may be resolved — linked PR was merged." Omit from PR findings (PR is closed). |
| SECURITY.md missing | Community Health | Security | Present once under Community Health. Security module references it ("security policy gap noted in community health"). |
| CHANGELOG stale + unreleased commits | Release Health | Community Health | Present once under Release Health. Community Health skips CHANGELOG freshness for Tier 4 repos (Release Health owns it). |
| Copilot PR aligns docs with code | PR Management | Community Health | Present in PR Management. Note that merging would address community health drift. |

#### Unified Findings Presentation

Rather than walking through modules in sequence and repeating overlapping issues, Claude presents a unified view organized by priority:

```
Claude: 📊 Repository Health — ha-light-controller (Tier 4)

        🔴 Critical
        • 1 Dependabot security alert (lodash CVE-2024-XXXX)
          — fix PR #67 is open, CI passing, ready to merge

        ⚠️ Needs Attention
        • 9 unreleased commits since v0.2.2, CHANGELOG not updated
        • Missing SECURITY.md and CODE_OF_CONDUCT.md
        • PR #5 from Copilot — doc alignment, CI passing

        ✅ Healthy
        • No stale issues or discussions
        • CI workflows passing
        • Branch protection configured

        The Dependabot alert is most urgent — and it already has
        a fix PR. Want to start by merging that?
```

Note how the Dependabot alert + its PR are presented as a single finding instead of appearing separately in both Security and PR Management.

#### Cross-Module References in Reports

The maintenance report should include a "Related Findings" column or cross-reference notes so the owner can see connections:

```markdown
| Finding | Module | Related |
|---------|--------|---------|
| lodash CVE-2024-XXXX | Security | Fix: PR #67 (PR Management) |
| PR #5 — doc alignment | PR Management | Addresses community health drift |
| CHANGELOG stale | Release Health | 9 unreleased commits |
```

---

## 8. Configuration System

### 8.1 Configuration File (`.github-repo-manager.yml`)

Stored in the repository root, this file customizes maintenance behavior per-repo.

**Visibility note:** This file is committed to the repo and is publicly visible on Tier 3-4 repos. It contains only non-sensitive settings (tier classification, module toggles, staleness thresholds). Owner-specific information like email addresses should not be stored here — use the portfolio config (Section 8.2) or templates for that. If the owner prefers not to have a config file in a public repo, the portfolio config can provide all per-repo overrides instead, and `.github-repo-manager.yml` can be omitted entirely. The plugin will fall back to tier auto-detection and default policies.

**Validation:** The config is validated by the skill layer when read, not by the helper. The plugin's `config/schema.yml` defines valid types, ranges, and enum values. When Claude loads a config file (from repo or portfolio), it checks it against the schema and handles problems conversationally:

- **Unknown keys** (e.g., misspelled module name): Claude notes them and ignores them. "Your config has a `relase_health` key — did you mean `release_health`? I'm ignoring it for now."
- **Invalid values** (e.g., `tier: 5`, `staleness_threshold_days: -3`): Claude reports the problem and falls back to the tier default. "Your staleness threshold is set to -3 days, which doesn't make sense — I'll use the Tier 3 default of 21 days instead."
- **Type mismatches** (e.g., `enabled: "yes"` instead of `true`): Claude coerces where obvious, flags where ambiguous.

Config errors never block a session. Claude reports them, uses sensible fallbacks, and continues. The owner can fix the config file between sessions.

```yaml
# .github-repo-manager.yml

# Repo identity is inferred from the repository this file lives in.
# No need to specify owner or name here.

repo:
  tier: auto  # auto | 1 | 2 | 3 | 4 — auto-detect on first run, then persisted

# Global settings
settings:
  report_format: "markdown" # markdown | json
  verbose: true
  deferred_items:
    persist: true            # Create/update tracking issue for deferred items
    pin_issue: true          # Pin the tracking issue
    auto_resolve: true       # Move items to Resolved when addressed

# Module toggles and per-repo policy overrides
# Unspecified values inherit from tier defaults (see Section 7)
#
# Tier applicability: Some modules have tier restrictions (e.g., wiki sync
# is Tiers 3-4 only, release health is Tier 4 only). The skill layer
# enforces these regardless of the `enabled` flag:
#   - enabled: false  → always disables the module
#   - enabled: true   → enables the module IF the tier supports it;
#                        ignored on inapplicable tiers (Claude notes why)
modules:
  wiki_sync:
    enabled: true       # Tiers 3-4 only (see tier applicability note above)
    orphan_handling: "warn"  # warn | delete | archive
    doc_sources:
      - "docs/"
      - "README.md"
    exclude_patterns:
      - "docs/internal/"
    page_map: []        # Optional explicit source-to-page mappings
    auto_generate:      # Code analysis targets
      - "functions"
      - "cli"
      - "config"

  community_health:
    enabled: true
    templates_dir: "templates/"
    required_files:
      - README.md
      - CONTRIBUTING.md
      - CODE_OF_CONDUCT.md
      - SECURITY.md
      - LICENSE

  pr_management:
    enabled: true
    staleness_threshold_days: auto  # auto = use tier default (see Section 7.3)
    ignore_labels:
      - "do-not-close"
      - "long-running"

  notifications:
    enabled: true
    priority_filter: "high"  # Only surface high+ priority

  security:
    enabled: true
    audit_branch_protection: true
    required_branch_protections:
      - require_pull_request_reviews
      - require_status_checks
      - enforce_admins

  discussions:
    enabled: true
    staleness_threshold_days: auto  # auto = use tier default (see Section 7.3)

  dependency_audit:
    enabled: true
    max_dependabot_pr_age_days: 7

  issue_triage:
    enabled: true
    staleness_threshold_days: auto  # auto = use tier default (see Section 7.3)
    require_labels: true
    ignore_labels:
      - "long-term"
      - "backlog"

  release_health:
    enabled: true                    # Auto-enabled on Tier 4
    changelog_files:
      - CHANGELOG.md
      - CHANGES.md
      - HISTORY.md
    cadence_warning_multiplier: 2.0  # Warn if 2x average interval since last release
```

### 8.2 Portfolio Configuration (Optional)

An optional central config file for cross-repo checks. If absent, the plugin auto-discovers all repos from the PAT and auto-detects tiers. The portfolio config provides overrides only.

**Location:** `~/.config/github-repo-manager/portfolio.yml`

**Config Precedence (highest to lowest):**

1. **Portfolio per-repo overrides** (`portfolio.yml → repos → {name}`) — highest priority. The owner's local machine config always wins, since it reflects their latest intent and isn't subject to PR review cycles.
2. **Per-repo config** (`.github-repo-manager.yml` in repo root) — mid priority. Good for settings that should travel with the repo.
3. **Portfolio defaults** (`portfolio.yml → defaults`) — applied to all repos unless overridden.
4. **Tier defaults** (`config/default.yml` in plugin) — built-in baseline policies per tier.

If a setting appears at multiple levels, the highest-priority source wins. Unset values cascade down. Claude reports which source a setting came from when the owner asks ("Your staleness threshold is 21 days — that's from your portfolio config, overriding the repo config's 14 days").

```yaml
# portfolio.yml — optional, overrides auto-detection

owner:
  expertise: beginner  # beginner | intermediate | advanced

# Default settings applied to all repos unless overridden
defaults:
  community_health:
    required_files:
      - README.md
      - CONTRIBUTING.md
      - SECURITY.md
      - LICENSE

# Per-repo overrides
# For public repos, this is the preferred place for settings
# (avoids committing .github-repo-manager.yml to a public repo)
repos:
  integration_blueprint:
    skip: true       # Fork — exclude from all checks
  brands:
    skip: true       # Fork — exclude from all checks
  ha-light-controller:
    tier: 4          # Lock tier (skip auto-detection)
    pr_management:
      staleness_threshold_days: 21
  testing:
    skip: true       # Scratch repo — not worth checking
```

---

## 9. Invocation Interface

The plugin is activated with a single slash command: `/repo-manager`. The scope — single-repo session, cross-repo check, or anything in between — is determined conversationally based on what the owner asks for.

### 9.1 Entry Point

```
/repo-manager
```

That's it. After activation, the owner states what they need and Claude infers the appropriate mode:

| Owner says | Claude infers |
|-----------|---------------|
| "Check ha-light-controller" | Single-repo session |
| "Let's look at my HA Dev Template repo" | Single-repo session |
| "Are any of my repos missing SECURITY.md?" | Cross-repo targeted check |
| "Check security posture across everything" | Cross-repo targeted check |
| "What's the state of my public repos?" | Cross-repo summary |
| "Any open PRs I should deal with?" | Cross-repo targeted check |

If Claude isn't sure of the scope, it asks.

### 9.2 First-Run Onboarding

When `/repo-manager` is invoked for the very first time — or against a repo the plugin hasn't seen before — Claude handles setup conversationally rather than failing with configuration errors.

**First time ever (no PAT, no helper):**

```
Owner: /repo-manager

Claude: Welcome to GitHub Repo Manager! Let me get you set up.

        First, I need to check that the helper tool is installed...
        [checks for gh-manager binary]

        ✅ gh-manager is installed.

        Now I need a GitHub Personal Access Token (PAT) to access
        your repos. A PAT is like a password that lets this tool
        talk to GitHub on your behalf — but with specific permissions
        so it can only do what you allow.

        Do you have a PAT set in your GITHUB_PAT environment variable,
        or do you need help creating one?
```

**PAT present, first contact with a repo:**

```
Owner: /repo-manager
        Check ha-light-controller

Claude: This is my first time looking at ha-light-controller.
        Let me assess it...

        [fetches repo metadata]

        Based on what I see — public repo, 14 releases, CI workflows,
        Python package — I'd classify this as Tier 4 (Public with
        Releases). That means I'll use pull requests for any file
        changes and give you detailed context before any actions.

        Does Tier 4 sound right, or would you prefer a different level?

Owner: That's right

Claude: Got it. I also noticed your repo only has default GitHub
        labels. I use a few custom labels for tracking maintenance
        work — want me to create them? [lists labels]
```

**First-run checklist (internal, not shown to owner):**

1. Verify `gh-manager` binary is accessible
2. Verify PAT is set and valid (`gh-manager auth verify`)
3. Check PAT scopes against required permissions
4. For the target repo: run tier auto-detection
5. Check for `.github-repo-manager.yml` in repo — if absent, offer to create one on private repos; on public repos, mention that settings can also live in the portfolio config to avoid committing a config file
6. Check for required maintenance labels
7. Check for deferred items tracking issue (Section 10.2)
8. Proceed to assessment

Claude collapses steps that succeed silently and only surfaces steps that need owner input. A fully configured repo with a valid PAT skips straight to assessment with no onboarding friction.

### 9.3 Single-Repo Sessions

The primary use case. Claude deeply assesses one repository, surfaces findings across modules, and works through them conversationally with the owner.

**The owner controls the depth.** A single-repo session doesn't always mean a full health sweep. The owner's initial request determines how broad the assessment is:

| Owner says | Session scope |
|-----------|---------------|
| "Check ha-light-controller" | Full assessment — all modules |
| "How are the PRs on ha-light-controller?" | Narrow — PR management only |
| "Is ha-light-controller ready for a release?" | Narrow — Release health + changelog |
| "Check security on Markdown-Keeper" | Narrow — Security module only |
| "What's the wiki status on DFBU?" | Narrow — Wiki sync only |

For a full assessment, Claude runs all enabled modules, synthesizes findings using cross-module intelligence (Section 7.8), and presents a unified priority-ordered summary. For a narrow check, Claude runs only the relevant module(s) and stays focused.

The owner can always broaden or narrow mid-session:
- "Actually, check everything while you're at it"
- "That's enough on PRs, what about security?"
- "Just the release health stuff, skip the rest"

**Full assessment example:**

```
Owner: /repo-manager
        Let's check ha-light-controller

Claude: Let me check the current state of ha-light-controller...
        [fetches repo metadata, detects Tier 4]

        📊 Repository Health — ha-light-controller (Tier 4: Public, Releases)

        ⚠️ Release Health
        • 9 unreleased commits since v0.2.2 (7 days ago)
        • CHANGELOG.md not updated for unreleased work

        ⚠️ Community & Security Gaps
        • Missing SECURITY.md and CODE_OF_CONDUCT.md
        • No issue templates configured

        ⚠️ Pull Requests
        • PR #5 from Copilot — doc alignment, CI passing
          (merging would address some community health drift)

        ⚠️ Wiki
        • Wiki enabled but empty — no content published yet

        ✅ Healthy: CI passing, no security alerts, no stale issues

        The unreleased commits stand out — you're 9 commits past
        v0.2.2 and the changelog hasn't been updated yet. Want to
        start with release readiness, or tackle the missing
        community files first?

Owner: Let's review the PR first

Claude: [fetches PR #5 details, diff, CI status]
        PR #5: "Align documentation with code implementation (v0.2.2)"
        Author: Copilot | Created: Feb 14 | CI: Passing | No conflicts

        The PR updates documentation to match the current code.
        Changes look straightforward — mostly function signature
        updates and corrected parameter descriptions.

        This looks safe to merge. Want me to approve it, or do
        you want to review the diff in detail first?
```

### 9.4 Cross-Repo Checks

The owner names a specific concern. Claude runs that check across all repos (auto-discovered from the PAT), presents a report with findings ranked by severity, makes recommendations, and the owner chooses how to proceed — fix them all in one batch, or work through them selectively.

Claude infers which modules, repos, and tiers are relevant from the owner's request:

| Concern | Inferred Scope | Module |
|---------|---------------|--------|
| "community health" | Public repos only | Community Health |
| "security posture" | All repos | Security |
| "open PRs" | All repos with open PRs | PR Management |
| "stale notifications" | All repos with notifications | Notifications |
| "wiki status" | Public repos (Tiers 3-4) | Wiki Sync |
| "dependency alerts" | Repos with code | Dependency Audit |
| "any open Dependabot PRs" | All repos | PR Management + Deps |
| "stale issues" | All repos with open issues | Issue Triage |
| "release readiness" | Repos with releases (Tier 4 primary) | Release Health |
| "which repos need a release?" | Repos with releases (Tier 4 primary) | Release Health |

**Report → Recommend → Act flow:**

```
Owner: /repo-manager
        Check community health across all my repos

Claude: Scanning 17 repositories (skipping 2 forks)...

        📋 Community Health — Cross-Repo Report

        Missing SECURITY.md (5 repos):
          ha-light-controller (Tier 4)
          DFBU-Dotfiles-Backup-Utility (Tier 4)
          HA-Dev-Template (Tier 4)
          Markdown-Keeper (Tier 3)
          Claude-Code-Plugins (Tier 3)

        Missing CODE_OF_CONDUCT.md (5 repos):
          [same 5 repos]

        Missing issue templates (5 repos):
          [same 5 repos]

        Missing PR template (2 repos):
          DFBU-Dotfiles-Backup-Utility (Tier 4)
          Markdown-Keeper (Tier 3)

        My recommendation: SECURITY.md is the highest priority —
        it's expected on any public project. I can generate a
        standard template with your contact info and apply it to
        all 5 repos. PRs for Tier 4, direct commits for Tier 3.

        Want me to fix them all, or work through one at a time?

Owner: Fix them all, use chris@l3digital.net as the security contact

Claude: [generates SECURITY.md, applies to 5 repos per tier strategy]

        Done. Here's what I did:
          Tier 4 (PRs created):
            ha-light-controller — PR #6
            DFBU-Dotfiles-Backup-Utility — PR #12
            HA-Dev-Template — PR #9
          Tier 3 (committed directly):
            Markdown-Keeper — committed to main
            Claude-Code-Plugins — committed to main

        Want to tackle CODE_OF_CONDUCT.md next?
```

### 9.5 Scope Inference and Filtering

Claude infers the relevant scope from the owner's request, but the owner can narrow it conversationally at any time.

**Auto-inference rules:**
- Community health checks → public repos only (community files on private repos are optional)
- Security posture → all repos (even private repos have dependency risks)
- Wiki status → public repos with wiki enabled (Tiers 3-4)
- Open PRs / notifications → all repos
- Issue triage → all repos with open issues
- Release readiness → Tier 4 repos primarily; also surfaces Tier 2-3 repos that have releases with a note that the full Release Health module requires Tier 4 (owner can override tier if desired)
- Discussions → repos with discussions enabled

**Conversational narrowing:**
- "Just check my Home Assistant repos"
- "Only look at public repos"
- "Skip the Tier 1 stuff, just focus on repos with releases"

### 9.6 Fork and Archive Handling

Forked repositories are detected via the `fork` field in the GitHub API response and are **skipped by default** in both modes. Forks have upstream conventions for community files, branch structure, and workflows that the plugin should not override.

Archived repositories are detected via the `archived` field and are also **skipped by default**. Archived repos are fully read-only on GitHub — all mutation attempts return 403.

In cross-repo reports, forks and archived repos are listed as skipped so the owner knows they were excluded:

```
Skipped:
  forks: integration_blueprint, brands
  archived: old-project
```

The owner can explicitly include either type if needed:

```yaml
# portfolio.yml override
repos:
  integration_blueprint:
    skip: false
    tier: 3
  old-project:
    skip: false
    read_only: true   # Archived — allow assessment, block mutations
```

### 9.7 Cross-Repo Mutation Strategy

When applying fixes across multiple repos, the tier system governs the mutation method per repo:

| Tier | Mutation Method | Owner Interaction |
|------|----------------|-------------------|
| 1 | Direct commit | Batch approval ("fix them all") |
| 2 | Direct commit | Batch approval ("fix them all") |
| 3 | Direct commit | Batch approval ("fix them all") |
| 4 | Pull request | PRs created, owner merges at their pace |

Within a single batch action, Claude:
1. Generates the content once (or customizes per-repo if needed)
2. Applies to all target repos using the appropriate mutation per tier
3. Reports what was done, grouped by mutation method
4. For PRs: provides links so the owner can review and merge later

### 9.8 Mid-Session Directives

In either mode, the owner can redirect Claude at any time:

- "Skip the rest, move to wiki sync"
- "Show me the diff before you push"
- "Actually, close that PR with a comment explaining why"
- "How many API calls have we used so far?"
- "Generate the report for what we've done so far"
- "Switch to repo X instead" (exits current session, starts new one)

### 9.9 Session Wrap-Up

When the owner indicates they're done — or changes topic away from repo management — Claude wraps up the session cleanly:

1. **Check for deferred items.** If anything was assessed but not acted on, Claude notes the deferrals and offers to persist them (Section 10.2).
2. **Offer a report.** If the session involved actions or significant findings, Claude offers to generate the maintenance report (Section 10.1). For narrow checks with minimal findings, Claude skips the offer.
3. **Summarize what was done.** A brief statement of what changed: "I created 2 PRs, labeled 1 issue, and pushed wiki updates." No need for a full report if the session was short.
4. **Exit cleanly.** Claude confirms the session is ended and returns to normal operation. No residual repo-management behavior.

**Example (full session):**

```
Owner: I think that's it for now

Claude: Good session. Here's what we did on ha-light-controller:

        Actions taken:
        • Merged PR #5 (doc alignment)
        • Created SECURITY.md via PR #6
        • Pushed 3 wiki pages

        Deferred:
        • CODE_OF_CONDUCT.md — you want to customize it first
        • Release decision — 9 unreleased commits, revisit next time

        Want me to save those deferrals as a tracking issue, or
        generate a full maintenance report?
```

**Example (quick check):**

```
Owner: Thanks, that's all I needed

Claude: 👍 ha-light-controller PR situation looks good — just the
        one Copilot PR, CI passing, ready to merge when you want.
```

Claude infers the appropriate wrap-up depth from the session's scope and activity. A full assessment with multiple actions gets a summary and report offer. A quick "how are the PRs?" check gets a one-liner.

---

## 10. Report Output

### 10.1 Maintenance Report Structure

At the end of a maintenance session (or on request mid-session), Claude presents a structured report summarizing findings and actions taken. The owner can ask Claude to adjust, add notes, or regenerate sections before considering the session complete.

**Report delivery:** Reports are presented inline in conversation by default. The owner can ask Claude to save the report as a local markdown file:

```
Owner: Save that report

Claude: Saved the maintenance report to:
        ~/github-repo-manager-reports/ha-light-controller-2026-02-17.md
```

**Report directory:** `~/github-repo-manager-reports/` (created on first save). Reports are never committed to the repo — they're local working documents for the owner.

**Report format:** Always markdown. The `report_format` config option controls whether the inline conversation presentation uses a structured summary table (default `markdown`) or raw JSON output for scripting use cases (`json`).

```markdown
# Repository Maintenance Report
**Repo:** owner/my-project
**Tier:** 3 — Public, No Releases
**Date:** 2026-02-17T14:30:00Z
**Session Type:** Full Assessment

## Summary
| Module | Status | Findings | Actions Taken |
|--------|--------|----------|---------------|
| Wiki Sync | ⚠️ Drift Detected | 3 pages stale | 3 pages updated (pushed) |
| Community Health | ✅ Healthy | 0 issues | — |
| PR Management | ⚠️ Attention Needed | 2 stale PRs | 1 labeled, 1 deferred |
| Notifications | ℹ️ Reviewed | 7 notifications | 5 marked read |
| Security | 🔴 Critical | 1 critical alert | Owner notified |
| Discussions | ✅ Healthy | 0 unanswered | — |
| Dependencies | ⚠️ Behind | 4 Dependabot PRs | 2 labeled ready-to-merge |
| Issue Triage | ⚠️ Attention Needed | 3 unlabeled issues | 3 labels suggested |
| Release Health | ⚠️ Overdue | 9 unreleased commits | Draft changelog proposed |

## Deferred Items
- PR #31: Owner chose to defer — waiting on contributor response
- Express vulnerability: Owner handling manually

## API Usage
- REST calls: 47 / 5,000
- GraphQL points: 120 / 5,000

## Detailed Findings
[... per-module details ...]
```

The report includes a **Deferred Items** section to capture things the owner acknowledged but chose not to act on during this session, providing a natural starting point for the next run.

**Cross-repo report format:** Cross-repo checks produce a different report structure — findings grouped by concern across repos rather than by module within one repo:

```markdown
# Cross-Repo Report: Community Health
**Date:** 2026-02-17T14:30:00Z
**Scope:** 15 repos scanned (2 forks skipped, 1 archived skipped)

## Findings by Concern
| Concern | Repos Affected | Severity |
|---------|---------------|----------|
| Missing SECURITY.md | 5 repos | High |
| Missing CODE_OF_CONDUCT.md | 5 repos | Medium |
| Missing issue templates | 5 repos | Low |
| Missing PR template | 2 repos | Low |

## Actions Taken
| Action | Repo | Method | Result |
|--------|------|--------|--------|
| Added SECURITY.md | ha-light-controller | PR #6 | Created |
| Added SECURITY.md | Markdown-Keeper | Direct commit | Done |
| Added SECURITY.md | DFBU | PR #12 | Created |

## Skipped
- forks: integration_blueprint, brands
- archived: old-project

## API Usage
- REST calls: 89 / 5,000
- GraphQL points: 45 / 5,000
```

### 10.2 Deferred Items Persistence

Since the plugin is stateless, the deferred items in a report would normally be lost after the conversation ends. To give deferred items continuity across sessions, the plugin can optionally persist them as a pinned GitHub issue on the repo.

**Mechanism:** At the end of a session with deferred items, Claude offers to create or update a tracking issue:

```
Claude: We deferred 2 items this session:
        • PR #31 — waiting on contributor response
        • Express vulnerability — you're handling manually

        Want me to save these as a tracking issue on the repo?
        That way I can pick them up next time we maintain this repo.
```

If the owner approves, Claude creates (or updates) a single issue:

```markdown
## [Maintenance] Deferred Items

Last updated: 2026-02-17 by GitHub Repo Manager

### Active Deferrals
- [ ] PR #31 — waiting on contributor response (deferred 2026-02-17)
- [ ] Express vulnerability — owner handling manually (deferred 2026-02-17)

### Resolved
- [x] SECURITY.md missing — created via PR #6 (resolved 2026-02-17)

<!-- grm:deferred-items -->
```

**Behavior:**
- One tracking issue per repo, identified by the `<!-- grm:deferred-items -->` HTML marker
- Claude checks for this issue at the start of each session and mentions outstanding deferrals
- Items are moved to "Resolved" when Claude detects they've been addressed (PR merged, file created, alert dismissed)
- The owner can manually edit the issue between sessions
- The issue is labeled `maintenance` and pinned (if the owner approves pinning)
- If the owner doesn't want a tracking issue, deferred items exist only in the session report — no persistence

**At session start (if tracking issue exists):**

```
Claude: I found your deferred items from last session:
        • PR #31 — waiting on contributor response (deferred 3 days ago)
        • Express vulnerability — you were handling manually

        PR #31 still shows as open. Want to check on it, or
        keep it deferred?
```

**Configuration:**

```yaml
settings:
  deferred_items:
    persist: true           # Create/update tracking issue
    pin_issue: true          # Pin the tracking issue
    auto_resolve: true       # Move items to Resolved when addressed
```

---

## 11. Implementation Approach

### 11.1 Technology Decisions

**Decision: Option D — Hybrid (Skill Markdown + Node.js/Octokit Helper)**

The plugin is split into two layers with a clear boundary of responsibility:

#### Layer 1: Skill Markdown (Orchestration & Reasoning)

Claude Code reads the SKILL.md and module-specific markdown files to understand:
- What to check and in what order
- How to interpret API responses (thresholds, scoring, drift detection)
- What recommendations to make based on findings
- How much context and explanation to provide based on expertise level and tier
- How to structure the maintenance report

This layer contains **no executable code** — it's pure instruction and decision logic. This is where maintenance policies, heuristics, and domain knowledge live. It can be iterated conversationally without touching the codebase.

#### Layer 2: Node.js Helper (API Plumbing)

A thin Node.js CLI tool (`gh-manager`) handles all GitHub API interaction:
- Authentication (PAT from env var)
- REST and GraphQL calls via Octokit
- Response pagination
- Rate limit tracking and enforcement
- Structured error reporting (no retries — errors surface to Claude for conversational handling)
- JSON output to stdout for Claude Code to consume

This layer is **stateless and dumb** — it fetches, mutates, and returns structured data. It makes no decisions about what the data means.

#### Interaction Model

```
Claude Code (reads SKILL.md)
    │
    │  "I need to check open PRs"
    │
    ▼
$ gh-manager prs list --repo owner/name --state open
    │
    │  Returns JSON array of PRs with review status, CI, staleness
    │
    ▼
Claude Code (interprets results per skill instructions)
    │
    │  "PR #42 is stale and approved — I should label it"
    │
    ▼
$ gh-manager prs label --repo owner/name --pr 42 --add stale,ready-to-merge
    │
    │  Returns confirmation
    │
    ▼
Claude Code (adds to report, moves to next module)
```

**Content delivery for file mutations:** When Claude needs to create or update a file (the primary mutation path for Tiers 1-3), it writes the content to a temp file and pipes it to the helper:

```
$ gh-manager files put --repo owner/name --path SECURITY.md \
    --message "Add SECURITY.md" < /tmp/security-md-content.md
```

For Tier 4 PR workflows, the same mechanism works with a `--branch` flag to target the maintenance branch instead of the default branch.

#### Helper CLI Surface (`gh-manager`)

The helper exposes subcommands aligned to the module structure. Every command accepts `--repo owner/name` and outputs JSON to stdout.

```
gh-manager
├── auth
│   ├── verify          # Validate PAT and report scopes
│   └── rate-limit      # Show current rate limit status
├── repos
│   ├── list            # List all repos accessible via PAT (with fork/visibility/language metadata)
│   └── classify        # Auto-detect tier for a repo (composite — see note below)
├── repo
│   ├── info            # Fetch repo metadata
│   ├── community       # Fetch community profile score
│   └── labels          # List, create, update labels
├── wiki
│   ├── clone           # Clone wiki repo to temp directory
│   ├── init            # Initialize wiki (create Home page if wiki repo doesn't exist)
│   ├── diff            # Diff generated content against current wiki
│   ├── push            # Commit and push changes to wiki repo
│   └── cleanup         # Remove temp clone directory
├── files
│   ├── get <path>      # Fetch file content from repo
│   ├── put <path>      # Create/update file (stdin, --branch, --message)
│   ├── delete <path>   # Delete file (--branch, --message, SHA-conditional)
│   └── exists <path>   # Check file existence (exit code)
├── branches
│   ├── create          # Create a branch from ref (for Tier 4 PR workflows)
│   ├── delete          # Delete a branch (cleanup after PR merge)
│   └── list            # List branches (for conflict detection)
├── prs
│   ├── list            # List PRs with review/CI/conflict status
│   ├── get             # Fetch single PR details (full metadata + body)
│   ├── diff            # Fetch PR diff (changed files with patches)
│   ├── comments        # Fetch comments on a PR (for dedup marker checking)
│   ├── label           # Add/remove labels on a PR
│   ├── comment         # Post a comment on a PR
│   ├── request-review  # Request reviewers on a PR
│   ├── merge           # Merge a PR (merge, squash, or rebase)
│   ├── create          # Create a PR (title, body, head branch, base branch)
│   └── close           # Close a PR with comment
├── notifications
│   ├── list            # Fetch notifications for repo
│   └── mark-read       # Mark notifications as read
├── security
│   ├── dependabot      # Fetch Dependabot alerts
│   ├── code-scanning   # Fetch code scanning alerts
│   ├── secret-scanning # Fetch secret scanning alerts
│   ├── advisories      # Fetch security advisories
│   └── branch-rules    # Fetch branch protection rules
├── discussions
│   ├── list            # List discussions (GraphQL)
│   ├── comment         # Post a comment on a discussion (GraphQL)
│   └── close           # Close a discussion
├── issues
│   ├── list            # List open issues (excluding PRs)
│   ├── get             # Fetch single issue details (full body + metadata)
│   ├── comments        # Fetch comments on an issue (for dedup marker checking)
│   ├── label           # Add/remove labels on an issue
│   ├── comment         # Post a comment on an issue
│   ├── close           # Close an issue with comment
│   └── assign          # Assign an issue
├── releases
│   ├── list            # List releases
│   ├── latest          # Get latest release details
│   ├── compare         # Commits since last release tag
│   ├── draft           # Create a draft release
│   ├── publish         # Publish a draft release (undraft)
│   └── changelog       # Fetch and parse changelog file
└── deps
    ├── graph           # Fetch dependency graph
    └── dependabot-prs  # List open Dependabot PRs
```

#### Key Design Principles for the Helper

1. **JSON in, JSON out.** Every command returns structured JSON. Errors return `{ "error": "message", "status": 404 }` to stderr with a non-zero exit code.
2. **No business logic.** The helper never decides whether a PR is "stale" — it returns `last_activity_date` and lets the skill layer do the math.
3. **Trimmed responses.** Raw GitHub API responses include many fields Claude doesn't need (avatar URLs, node IDs, HTML URLs for every linked resource, etc.). The helper must extract only the fields relevant to each module's assessment needs. This is critical for context window efficiency — a full assessment across 9 modules can easily generate 50-100K tokens of raw API data. The helper should return compact, purpose-built JSON, not pass-through API responses.

   **Example — PR list output:**
   ```json
   {
     "number": 5,
     "title": "Align documentation with code implementation",
     "author": "copilot",
     "state": "open",
     "created_at": "2026-02-14T10:00:00Z",
     "updated_at": "2026-02-14T12:00:00Z",
     "mergeable": true,
     "mergeable_state": "clean",
     "ci_status": "success",
     "review_status": "approved",
     "labels": ["documentation"],
     "additions": 42,
     "deletions": 18,
     "changed_files": 3,
     "linked_issues": [12],
     "draft": false
   }
   ```

   Not the 300+ field GitHub API response.

4. **Pagination handled internally.** Commands that can return paginated results fetch all pages by default (with `--limit` override).
5. **Rate limit awareness.** Every response includes a `_rate_limit` metadata field: `{ "remaining": 4823, "reset": "2026-02-17T15:00:00Z" }`.
6. **Idempotent where possible.** `prs label --add stale` is a no-op if the label already exists. `files put` uses SHA-based conditional updates.
7. **Dry run support.** All mutation commands accept `--dry-run` and return what *would* happen without executing.

**Exception: `repos classify`.** Most helper commands are thin wrappers around a single API endpoint. `repos classify` is a composite command — it fetches repo metadata, checks for releases, scans the root directory for code signals, and checks for CI workflows (3-5 API calls internally). It still makes no *decisions* — it returns the raw signals and a suggested tier, but the skill layer (and ultimately the owner) decides whether to accept the suggestion. This is documented as an exception to the single-endpoint pattern because the alternative (having Claude make 5 separate helper calls and assemble the signals itself) would waste context window tokens on API plumbing that has no assessment value.

#### Dependencies

```json
{
  "dependencies": {
    "@octokit/rest": "^20.x",
    "@octokit/graphql": "^7.x",
    "simple-git": "^3.x",
    "commander": "^12.x",
    "dotenv": "^16.x"
  }
}
```

Minimal footprint. `simple-git` is only used by the wiki module for clone/push operations.

### 11.2 Phased Delivery

| Phase | Scope | Milestone |
|-------|-------|-----------|
| Phase 0 — Scaffolding | Plugin structure, `.claude-plugin` manifest, slash command, helper skeleton with auth/rate-limit/repo info/label CRUD, setup script, first-run onboarding flow, tier auto-detection | Plugin installs, authenticates, classifies repos |
| Phase 1 — Foundation | Community health module (incl. label bootstrapping), config system, report generator, cross-module intelligence framework | Can audit a repo's community files, manage labels, and generate a report |
| Phase 2 — Documentation | Wiki sync module (publish pipeline, page mapping, auto-generation) | Wiki stays current with code |
| Phase 3 — Workflow | PR management module, issue triage module, notifications module | PR and issue triage, notification processing working |
| Phase 4 — Security | Security module, dependency audit module | Full security posture awareness |
| Phase 5 — Release & Discussions | Release health module, discussions module | Complete module coverage |
| Phase 6 — Cross-Repo | Cross-repo check flow, portfolio config, scope inference, batch mutations, deferred items persistence | Cross-repo targeted checks and session continuity working |

### 11.3 Plugin Packaging

The plugin follows the Claude Code plugin pattern established in the `Claude-Code-Plugins` repository.

#### Plugin Manifest (`.claude-plugin/plugin.json`)

```json
{
  "name": "github-repo-manager",
  "description": "Conversational GitHub repository maintenance — health auditing, wiki sync, PR triage, security posture, and community file management via PAT.",
  "version": "0.2.1",
  "author": {
    "name": "L3DigitalNet"
  },
  "keywords": [
    "github",
    "maintenance",
    "wiki",
    "security",
    "community-health",
    "pull-requests",
    "repository-management"
  ]
}
```

#### Slash Commands

**`/repo-manager`** (`commands/repo-manager.md`)
Single entry point that activates the GitHub Repo Manager skill. The command's body contains orchestration instructions telling Claude how to assess what the owner is asking for and respond appropriately — whether that's a deep single-repo session, a cross-repo check, or something in between.

```yaml
---
description: Activate GitHub repository management. Assess repo health, triage PRs, sync wikis, audit security, and manage community files — for a single repo or across all repos.
---
```

The scope is determined conversationally, not by command syntax:

```
Owner: /repo-manager
        Check ha-light-controller

Claude: [single-repo session for ha-light-controller]
```

```
Owner: /repo-manager
        Are any of my repos missing SECURITY.md?

Claude: [cross-repo check targeting community health]
```

```
Owner: /repo-manager
        What's the overall state of my public repos?

Claude: [cross-repo summary scoped to public repos]
```

#### Activation Boundary

**This plugin is strictly explicit-invocation-only.** It must never interfere with normal development workflows.

- **Two scoped hooks.** The plugin registers a `PreToolUse` hook (`gh-manager-guard.sh`) and a `PostToolUse` hook (`gh-manager-monitor.sh`), both scoped to Bash tool calls involving `gh-manager`. These are not session-activation hooks — the plugin remains dormant until `/repo-manager` is invoked. The hooks serve two mechanical purposes:
  - **Pre-mutation warning** (`gh-manager-guard.sh`): Emits a context-window message before any write command runs, giving the AI a chance to abort if no prior owner approval existed in the conversation. Exits 0 — it warns but cannot programmatically block, because hooks cannot inspect conversation history.
  - **Post-mutation audit trail** (`gh-manager-monitor.sh`): Logs every non-dry-run mutation to `~/.github-repo-manager-audit.log` and emits rate-limit warnings when the API budget runs low.

  **Accepted limitation:** The guard hook's warning is an agent-context injection only — it is not visible to the user in the terminal. The user-facing consent gate is entirely behavioral (the skill's `AskUserQuestion` approval flows). This is an accepted design constraint: hooks cannot read conversation history to verify that approval was given.
- **No passive activation.** The skill files must not be read or applied during unrelated tasks. The `/repo-manager` command is the only entry point.
- **No git interception.** The plugin never intercepts, wraps, or monitors `git push`, `git commit`, `git merge`, or any other git operations performed during normal development. It uses the GitHub API separately and independently from the local git workflow.
- **Clean session boundary.** When the `/repo-manager` session ends (owner says they're done, or moves on to other work), the plugin's context is fully released. Claude returns to normal operation with no residual repo-management behavior.

The `commands/repo-manager.md` frontmatter should reinforce this:

```yaml
---
description: Activate GitHub repository management. Only runs when explicitly invoked. Does not monitor or intercept normal git operations.
---
```

The command body's opening instruction to Claude should include:

```markdown
# IMPORTANT: Activation Scope
You are now in GitHub Repo Manager mode. This mode was explicitly
requested by the owner via /repo-manager. Do NOT apply any repo
management logic outside of this explicit invocation. When the owner
indicates they are done or changes topic, exit this mode cleanly.
```

#### Skill Files

Each module has a SKILL.md in `skills/<module>/` containing:
- What the module checks and why
- How to interpret data from the helper
- Decision trees for recommendations
- Communication examples at each expertise level
- Error handling guidance for that module's failure modes

The core skill (`skills/repo-manager/SKILL.md`) contains:
- Tier system logic and detection rules
- Communication style principles and expertise level handling
- Module sequencing and orchestration
- Cross-module intelligence and deduplication rules
- Cross-repo check flow
- First-run onboarding flow
- Report generation templates
- Deferred items persistence logic
- Error handling philosophy

#### First-Time Setup

```bash
# scripts/setup.sh
cd "$(dirname "$0")/../helper"
npm install
echo "✅ gh-manager helper installed"
echo "Set GITHUB_PAT environment variable to authenticate"
```

The setup script is run once after cloning. The SKILL.md references `${CLAUDE_PLUGIN_ROOT}/helper/bin/gh-manager.js` for helper invocations.

---

## 12. Open Questions (All Resolved)

1. ~~**Wiki access method:** REST API vs. git clone for wiki repo~~ — **RESOLVED: One-way publish via git clone. Wiki is read-only output, repo is source of truth. Tiers 3-4 only. See Section 5.1.**
2. ~~**Implementation language:** Shell/Python/Node.js/Hybrid~~ — **RESOLVED: Option D, Hybrid (Skill Markdown + Node.js/Octokit)**
3. ~~**State persistence:** Should the plugin track run history to detect trends across runs?~~ — **RESOLVED: No state persistence. The plugin is stateless and conversational. Each invocation assesses the current repo state fresh. Claude draws conclusions from what it observes (timestamps, activity dates, PR ages, alert counts) without needing historical comparisons. Comment deduplication uses GitHub-native HTML comment markers (e.g., `<!-- grm:stale-reminder:PR42 -->`) to detect prior actions without local state.**
4. ~~**Multi-repo support:** Should v1 support a manifest of repos, or strictly single-repo per invocation?~~ — **RESOLVED: Two interaction modes — single-repo sessions (primary) and cross-repo targeted checks (secondary) — accessed via single `/repo-manager` command. Scope determined conversationally. Auto-discover repos from PAT with optional central config for overrides. Forks skipped by default. See Section 9.**
5. ~~**Notification scope:** Process all notifications or only actionable ones? What about team-level notifications?~~ — **RESOLVED: In single-repo mode, fetch all notifications for that repo and present them categorized by priority (see Section 5.4). In cross-repo mode, only surface notifications when specifically asked ("any stale notifications?"). The priority classification table in Section 5.4 handles filtering — Claude presents critical/high by default and mentions lower-priority count. The owner can ask to see all. Team-level notifications are out of scope for v1 (PAT authenticates as an individual user).**
6. ~~**Wiki content generation:** When wiki pages are missing entirely, should the plugin generate content from code analysis, or only sync existing docs?~~ — **RESOLVED: Both. The `auto_generate` config and `auto:` page map prefix support code-analysis-driven content generation. See Section 5.1.**
7. ~~**Branch strategy for mutations:** Should file updates go to a PR branch or commit directly to default?~~ — **RESOLVED: Tier-based strategy (see Section 7)**
8. ~~**Error recovery:** If a module fails mid-run, should the orchestrator continue with remaining modules or abort?~~ — **RESOLVED: Conversational error handling. Claude reports errors transparently, continues where possible, and collaborates with the owner on how to proceed. No hardcoded recovery logic. See Section 7.7.**
9. ~~**Idempotency:** How to ensure repeated runs don't create duplicate comments, labels, etc.?~~ — **RESOLVED: Three mechanisms: (1) Helper uses idempotent API calls — label additions are no-ops if already present, file updates are SHA-conditional. (2) Comments posted by the plugin include HTML comment markers (`<!-- grm:module:context -->`) that the plugin checks before posting duplicates. (3) Maintenance PRs reuse existing open branches rather than creating new ones. The conversational model further mitigates this since the owner sees what's happening in real time.**
10. ~~**Claude Code integration pattern:** Skill file only, or does this need a companion CLI tool?~~ — **RESOLVED: Follows the established Claude Code plugin pattern from the Claude-Code-Plugins repo. `.claude-plugin/plugin.json` manifest, single slash command (`/repo-manager`) in `commands/`, skill files in `skills/`, Node.js helper bundled in `helper/`, setup scripts in `scripts/`. Scope is determined conversationally, not by command syntax. See Sections 4.2 and 11.3.**

---

## 13. Security Considerations

- PAT should use minimum required permissions (fine-grained preferred over classic)
- PAT must never be logged, included in reports, or committed to files. **Note:** Wiki git operations embed the PAT in HTTPS clone URLs (`https://{PAT}@github.com/...`). This is an accepted risk for trusted-machine usage — `simple-git` may include the URL in local debug output or error messages, but these do not leave the machine.
- The plugin should validate PAT scopes at startup and warn about missing permissions
- All API calls use HTTPS (enforced by GitHub)
- Mutation operations always require explicit owner approval during the conversation. The `--dry-run` flag is available as a preview tool so the owner can see what would happen before confirming.
- Consider supporting GitHub App authentication as a future enhancement (better permission model, higher rate limits)

---

## 14. Revision History

| Version | Date | Changes |
|---------|------|---------|
| 0.1 | 2026-02-17 | Initial draft — structure and open questions |
| 0.2 | 2026-02-17 | Resolved: Implementation language → Hybrid (Skill MD + Node.js/Octokit). Expanded Section 11.1 with layer responsibilities, interaction model, CLI surface, and design principles. Updated project structure (Section 4.2) to reflect two-layer architecture. |
| 0.3 | 2026-02-17 | Resolved: Branch/mutation strategy → Tier-based (Section 7). Four-tier repo classification system with auto-detection and manual override. Tier-specific mutation policies, staleness thresholds, and PR batching strategy. Updated config schema with `tier` field and tier-aware defaults. |
| 0.4 | 2026-02-17 | Resolved: Wiki access method → One-way git publish, repo is source of truth (Section 5.1). Rewrote wiki sync module as publish pipeline with page mapping, auto-generation from code analysis, orphan handling, and wiki scaffolding management. Scoped to Tiers 3-4 only. Updated helper CLI, config schema, and non-goals. Also resolved wiki content generation (Q6). |
| 0.5 | 2026-02-17 | Resolved: State persistence → No persistence, stateless and conversational (Q3, Q9). Rewrote problem statement, goals, non-goals, tier behaviors, invocation interface, and report structure to reflect conversational model. Owner is always in the loop. Removed automation flags from config. Added example session flow, mid-conversation directives, and deferred items tracking in reports. |
| 0.6 | 2026-02-17 | Resolved: Multi-repo support (Q4). Two interaction modes: single-repo sessions (primary) and cross-repo targeted checks (secondary). Report → Recommend → Act flow for cross-repo. Auto-discover repos from PAT, optional portfolio.yml for overrides. Fork detection and skip-by-default. Scope inference for cross-repo checks. Added repos discovery commands to helper CLI. Updated executive summary, non-goals, auto-detection with fork handling. Grounded examples in actual L3DigitalNet repo data. |
| 0.7 | 2026-02-17 | Added Section 7.6: Communication Style & Educational Approach. Seven principles: explanatory context, implication warnings, irreversibility flags, jargon translation, tier-aware sensitivity, teaching moments, and progressive depth. All examples grounded in real repo scenarios. This is a skill-layer concern defined in SKILL.md, not in the helper. |
| 0.8 | 2026-02-17 | Added configurable owner expertise level (beginner/intermediate/advanced) to Section 7.6. Modulates all seven communication principles. Added to portfolio.yml config. Supports mid-session adjustment. |
| 0.9 | 2026-02-17 | Resolved: Error recovery (Q8). Added Section 7.7: Conversational error handling. Structured error contract for helper, six error categories, inline and accumulated error reporting, cross-repo error tolerance, partial report generation. No hardcoded recovery logic — owner decides how to proceed. |
| 1.0 | 2026-02-17 | Resolved: Claude Code integration pattern (Q10) and notification scope (Q5). All open questions now resolved. Added Section 11.3: Plugin packaging following Claude-Code-Plugins pattern — plugin.json manifest, single slash command (`/repo-manager`), skill files per module, bundled Node.js helper, setup script. Scope (single-repo vs. cross-repo) determined conversationally, not by command syntax. Revised project structure (Section 4.2) and invocation interface (Section 9) to match. Added templates directory for community health file generation. |
| 1.1 | 2026-02-17 | Added activation boundary to Section 11.3: explicit-invocation-only policy. No hooks, no passive activation, no git interception, clean session boundary. Added empty hooks.json to project structure. Added activation scope instruction for command body. Ensures plugin never interferes with normal development workflows. |
| 1.2 | 2026-02-17 | Full conversational compliance review. Fixed 8 issues: (1) Tier 1/2 summary labels replaced "Full autopilot"/"auto-actions" with approval-centric language. (2) Wiki sync pipeline now includes explicit owner approval step before push. (3) Security module explicitly requires owner approval for recommended actions. (4) Dependency audit explicitly requires owner approval for merges. (5) Rate limit handling changed from "abort gracefully" to conversational reporting. (6) Removed "auto-act" from Layer 1 skill description. (7) Security considerations: dry_run clarified as preview tool, not substitute for approval. (8) Report generation made conversational — owner can review/adjust. Added core principle statement to Section 7: "No action without owner approval." Clarified Tier 1 intro, wiki sidebar regeneration language. |
| 1.3 | 2026-02-17 | Gap analysis and 8 enhancements: (1) New Issue Triage module (Section 5.8) — staleness, labels, assignees, linked PRs, duplicates. (2) New Release Health module (Section 5.9) — unreleased commits, CHANGELOG drift, draft releases, release cadence. Covers item 7 (CHANGELOG drift). (3) Label bootstrapping in Community Health — verifies/creates maintenance labels before use. (4) Cross-module intelligence (Section 7.8) — deduplication rules, unified findings presentation, cross-references in reports. (5) First-run onboarding (Section 9.2) — graceful setup flow for new repos and first-time users. (6) Session flexibility in Section 9.3 — narrow single-repo checks without full assessment. (7) CHANGELOG drift covered by Release Health module. (8) Deferred items persistence (Section 10.2) — optional GitHub tracking issue for session continuity. Updated: architecture diagram, project structure, helper CLI (issues, releases, labels commands), config schema, phased delivery, API selection table, scope inference, report template. |
| 1.4 | 2026-02-17 | Second gap analysis — 7 issues fixed: (1) Wiki initialization handling — detect when wiki is enabled but git repo doesn't exist, offer to initialize via API before cloning (Section 5.1). Added `wiki init` helper command. (2) Tier 3 mutation consistency — aligned Section 7.2 with Section 9.7: Tier 3 uses direct commits with detailed review, not PRs. Updated tier summary table and PR batching scope. (3) PR merge capability — added `prs merge` helper command, updated non-goals to distinguish automated merging (out of scope) from conversational merging (in scope), added merge to PR module actions. (4) Session wrap-up flow (Section 9.9) — deferred item check, report offer, action summary, clean exit. (5) Helper response trimming (Section 11.1, principle 3) — compact purpose-built JSON instead of raw API pass-through, with example. Critical for context window efficiency. (6) Org-level .github repo awareness in Community Health — detect/suggest shared community files, factor into health scores. (7) Config file visibility — documented that .github-repo-manager.yml is public on Tier 3-4 repos, portfolio.yml is the preferred alternative for per-repo settings on public repos. Updated first-run checklist. |
| 1.5 | 2026-02-17 | Third review — 7 issues and 3 refinements: (1) Tier 4 summary label changed from "recommend-only" to accurate mutation description. (2) Module execution order defined in Section 7.8 — Security first through Wiki Sync last, required for cross-module deduplication to work. (3) Added `prs get` and `prs diff` helper commands for PR detail/diff review. (4) Added branch management (`branches create/delete/list`) and `prs create` commands for Tier 4 PR workflow. Expanded PR batching (Section 7.5) with full branch→commit→PR workflow. Added `branches.js` to project structure. (5) Config precedence defined in Section 8.2 — portfolio per-repo > repo config > portfolio defaults > tier defaults. Claude reports active source on request. (6) Issue staleness thresholds now tier-varied in Section 7.3 table (14/21/30/30 days), matching PR and discussion treatment. Issue triage config uses `auto` to reference tier defaults. (7) PAT Administration scope split to Read (standard) + Write (optional, only for org-level .github repo creation). Refinements: (A) Removed redundant `repo.owner` and `repo.name` from config — inferred from context. (B) Report export defined — saved as local markdown file to ~/github-repo-manager-reports/, never committed to repo. `report_format` controls inline presentation style. (C) Documented `repos classify` as composite command exception to single-endpoint pattern. |
| 1.6 | 2026-02-17 | Fourth review — 7 issues and 2 refinements: (1) Wiki init corrected — GitHub has no REST API for wiki pages; initialization uses git push to create the wiki repo on first commit via `simple-git`, not `PUT /repos/.../pages`. (2) Archived repo handling — detected via `archived` field, skipped by default like forks. Read-only assessment available with `read_only: true` portfolio override. Updated detection flow, fork handling section (now 9.6 Fork and Archive Handling), and cross-repo skip reporting. (3) Public docs-only repo gap — detection flow now handles "Public + no code signals" → Tier 3. Tier 3 broadened from "Public, Runnable Code" to "Public, No Releases" to cover docs-only repos. Code-dependent modules auto-skip on docs-only repos. Updated tier table, section heading, staleness table labels. (4) Comment-reading for dedup markers — added `prs comments` and `issues comments` read commands so the helper can check for existing `<!-- grm:... -->` markers before posting duplicates. Also added `issues get` for single-issue detail. Updated prs.js and issues.js descriptions. (5) Missing helper commands — added `releases publish` (undraft a release) and `issues get` (single issue detail). Updated releases.js description. (6) Phase 0 milestone — removed label creation claim (belongs to Phase 1). Added label CRUD to Phase 0 scope as standalone scaffolding. (7) Staleness config normalization — all modules now use `staleness_threshold_days: auto` referencing tier defaults. Discussions key renamed from `stale_days` to `staleness_threshold_days` for consistency. Refinements: (A) Removed redundant `--format json` from interaction model example — JSON is the only output format per design principle 1. (B) Added `PULL_REQUEST_TEMPLATE.md.tmpl` to templates directory — was listed as a community health target file but missing from templates. |
| 1.7 | 2026-02-17 | Fifth review — 6 issues and 3 refinements: (1) Wiki init conversational example updated — removed "through the API" language, now says "pushing a starter Home page" to match the git-push technical description. (2) Non-goals exception — ".github" org-level repo creation is now listed as an explicit exception to the "no repository creation" non-goal (Section 3.2). (3) Branch protection marked recommend-only in Security module (Section 5.5) — helper can audit but not modify protection rules. Claude directs owner to Settings page for changes. Avoids requiring Administration Write for standard operation. (4) `templates_dir` path corrected from `templates/community/` to `templates/` to match actual project structure. (5) Existing maintenance PR detection mechanism defined (Section 7.5) — searches for open PRs with `maintenance` label and matching module title prefix. Handles cross-date branch name mismatches and merge conflicts. (6) Layer 2 "retries" removed from helper responsibilities (Section 11.1) — contradicted Section 7.7 error handling philosophy. Helper now does "structured error reporting (no retries)" with errors surfacing to Claude for conversational handling. Refinements: (A) PAT embedding in wiki git URLs acknowledged as accepted risk for trusted-machine usage in Section 13. (B) Open Question 7 given strikethrough formatting to match other resolved questions. (C) Tier-based module enable/disable semantics documented in config schema — `enabled: true` on an inapplicable tier is ignored; skill layer enforces tier restrictions regardless of flag. |
| 1.8 | 2026-02-17 | Sixth review — 6 issues and 2 refinements: (1) Wiki content generation handoff made explicit (Section 5.1) — Claude writes generated pages to a local staging directory via filesystem tools, then passes it to `wiki diff --content-dir`. Added staging directory step to operations list and cleanup step. (2) Project structure comments synchronized with CLI surface — `repo.js` now includes `labels`, `wiki.js` includes `init`, `prs.js` includes `request-review`, `security.js` includes `branch-rules`. (3) Added `files delete` command to helper CLI surface and project structure — required for community health file migration from per-repo to org-level `.github` repo. Uses Contents API DELETE with SHA-conditional safety. (4) Private repos with releases explicitly addressed in detection flow (Section 7.4) — maps to Tier 2 with rationale note. Tier ceremony is driven by public visibility risk, not release maturity alone. Release health module still runs for assessment value. Owner can override to higher tier manually. (5) Added `discussions comment` command to helper CLI surface and project structure — required for leaving explanatory comments before closing discussions, consistent with communication principles and PR/issue parity. (6) Config validation behavior defined in Section 8.1 — skill layer validates against `config/schema.yml` on read. Unknown keys noted and ignored, invalid values fall back to tier defaults, type mismatches coerced where obvious. Config errors never block sessions; Claude reports and continues. Refinements: (A) Cross-repo report template added to Section 10.1 — findings grouped by concern across repos, with actions-taken table, skip list, and API usage. (B) `files put` content delivery mechanism documented in interaction model — Claude writes content to temp file and pipes via stdin, with `--branch` flag for Tier 4 PR workflows. |
| 1.9 | 2026-02-17 | Seventh review — 4 issues and 1 refinement: (1) Release Health applicability corrected in private-repos-with-releases note (Section 7.4) — removed claim that release health "still runs" on Tier 2, since the module is Tier 4 only and the tier enforcement rules would block it. Note now explains that the owner can override tier to get release health, with the caveat that this also raises mutation ceremony. (2) `wiki_sync` config comment changed from "Auto-disabled on Tiers 1-2 unless overridden" to "Tiers 3-4 only" — the previous wording implied `enabled: true` could override tier restrictions, contradicting the tier applicability enforcement note six lines above. (3) PR size threshold `xlarge: 1000` added to config (Section 5.3) — the module spec references S/M/L/XL classification but only three thresholds were defined. XL now has an explicit boundary. (4) Notifications API endpoint corrected from `GET /notifications?repo={owner}/{repo}` to `GET /repos/{owner}/{repo}/notifications` — the previous format is not a valid GitHub API endpoint. Refinement: (A) Release readiness scope inference (Sections 9.4, 9.5) broadened from "Tier 4 repos only" to "repos with releases (Tier 4 primary)" — acknowledges that repos at other tiers can have releases and should surface in cross-repo checks, even though the full Release Health module requires Tier 4. |
| 2.0 | 2026-02-17 | Final verification pass — 1 minor issue: Tier summary table (Section 7.1) listed "No" in the "Has Releases" column for Tiers 1-2, but the detection flow routes private repos with releases to Tier 2 regardless. Changed to "N/A*" with footnote explaining that releases don't factor into tier assignment for private repos. Version promoted from draft to v2.0. Eight review passes total (v1.3-v2.0), declining from 8 issues to 1, confirming design stability. |
| 2.1 | 2026-02-19 | Plugin review corrections: (1) Section 4.2 structure tree updated to include `gh-manager-guard.sh` (PreToolUse hook script). (2) Section 11.3 Activation Boundary corrected from "No hooks" to accurate description of the two registered hooks (PreToolUse guard + PostToolUse monitor), with documented accepted limitation (guard exits 0, warns but cannot block). (3) Section 11.3 manifest example version updated from 0.1.0 to 0.2.1. |

---

*This document is a complete design spec (v2.0). All open questions have been resolved through collaborative discussion. Eight review passes confirmed internal consistency across all sections. The design is grounded in actual repository data from the L3DigitalNet GitHub account (19 repos, 4 tiers). Ready for Phase 0 implementation.*
