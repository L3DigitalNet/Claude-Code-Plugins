# Security Setup

The standard's universal scanner baseline is **`pip-audit`** (run in CI). This plugin additionally treats **Dependabot** as baseline for update PRs — the standard's own CI template assumes it (Dependabot bumps the SHA-pinned `setup-uv` action). Everything beyond that is **threat-model-driven** — added per project, documented, and run as plain CLI/CI steps. This standard does not use pre-commit/prek; the verification gate is the single entry point.

## Baseline: pip-audit

Checks installed packages against the Python Packaging Advisory Database for known CVEs. It is already in the dev group (see [pyproject.md](./pyproject.md)).

```bash
uv run pip-audit          # audit the project environment
uv run pip-audit --fix    # upgrade vulnerable packages where a fix exists
```

In CI it is the last step of the gate:

```yaml
- name: Dependency audit
  run: uv run pip-audit
```

**When a vulnerability is found:**

1. Check whether the CVE affects your usage (many sit in unused code paths).
2. Update the package: `uv add <package>@latest`.
3. If no fix exists: evaluate risk, consider an alternative, or record an explicit, time-bounded ignore.

## Baseline: Dependabot

Automated update PRs. Copy [templates/dependabot.yml](../templates/dependabot.yml) to `.github/dependabot.yml`.

| Tool       | Trigger      | Scope                                              |
| ---------- | ------------ | -------------------------------------------------- |
| pip-audit  | every CI run | "You have a vulnerable version right now"          |
| Dependabot | scheduled    | "Don't fall behind and accumulate vulnerabilities" |

A cooldown window on Dependabot updates blunts attacks that publish a malicious release hoping for instant adoption. See [dependabot.md](./dependabot.md).

## Threat-model-driven additions

pip-audit is the _only_ universal scanner because extra tooling adds noise to small internal tools. Add stronger tooling when a project includes any of:

- authentication / authorization
- public network services
- subprocess execution
- user-uploaded files
- secrets handling
- database writes
- payment / financial data
- personal data

Candidate additions (run as CLI or explicit CI steps — **not** as a pre-commit/prek layer, which this standard avoids):

| Tool | Catches | Add when |
| --- | --- | --- |
| **Bandit** | insecure Python patterns (eval, weak crypto, shell=True) | handling untrusted input, subprocess, crypto |
| **zizmor** | GitHub Actions security issues (excessive permissions, injection) | the repo's CI is security-sensitive |
| **actionlint** | workflow syntax / invalid action refs | CI complexity warrants it |
| **shellcheck** | shell-script bugs | the repo ships non-trivial shell |
| **detect-secrets** | committed credentials | broad contributor surface / public mirror |

When you add one, record it (an ADR or the project's security notes) so future agents preserve the reason, and wire it into CI or a documented manual step — keep the verification gate as the canonical entry point.

## Secret hygiene (always)

- Do not commit secrets; do not hardcode API keys, tokens, passwords, or private endpoints.
- Use environment variables or a secret manager.
- Treat file paths, shell commands, URLs, and user input as untrusted at boundaries.
