# GitHub Repo Manager — Setup Guide

## Prerequisites

- **Node.js** 18 or later
- **Claude Code** with plugin support
- **GitHub account** with repositories to manage

## Installation

1. Clone or add the plugin to your Claude Code plugins directory:

```bash
# If using Claude-Code-Plugins repo structure:
cp -r github-repo-manager /path/to/Claude-Code-Plugins/plugins/
```

2. Run the setup script:

```bash
bash github-repo-manager/scripts/setup.sh
```

This installs the Node.js helper dependencies.

## Create a GitHub Personal Access Token (PAT)

The plugin needs a PAT to access your repositories via the GitHub API.

### Fine-Grained PAT (Recommended)

1. Go to **GitHub → Settings → Developer Settings → Personal Access Tokens → Fine-grained tokens**
2. Click **Generate new token**
3. Set a descriptive name: `github-repo-manager`
4. Set expiration as desired
5. Under **Repository access**, select "All repositories" or choose specific repos
6. Under **Permissions**, grant:

| Permission | Access Level | Why |
|-----------|-------------|-----|
| Contents | Read & Write | File operations, wiki sync |
| Pull requests | Read & Write | PR triage, labels, comments |
| Issues | Read & Write | Issue triage, labels, comments |
| Metadata | Read | General repo info |

Additional permissions for full functionality (can be added later):

| Permission | Access Level | Why |
|-----------|-------------|-----|
| Discussions | Read & Write | Discussion management |
| Security events | Read | Security alerts |
| Administration | Read | Branch protection audit |
| Notifications | Read & Write | Notification processing |
| Dependabot alerts | Read | Security module |
| Code scanning alerts | Read | Security module |
| Secret scanning alerts | Read | Security module |

7. Click **Generate token** and copy it

### Classic PAT (Alternative)

1. Go to **GitHub → Settings → Developer Settings → Personal Access Tokens → Tokens (classic)**
2. Generate with scopes: `repo`, `notifications`
3. Copy the token

## Set the Environment Variable

```bash
# Add to your shell profile (~/.bashrc, ~/.zshrc, etc.)
export GITHUB_PAT=ghp_your_token_here
```

Or create a `.env` file in the helper directory:

```bash
# github-repo-manager/helper/.env
GITHUB_PAT=ghp_your_token_here
```

## Verify

```bash
node github-repo-manager/helper/bin/gh-manager.js auth verify
```

You should see your GitHub login and PAT details.

## Usage

In Claude Code, invoke the plugin:

```
/repo-manager
Check ha-light-controller
```

See [USAGE.md](USAGE.md) for the full command reference.
