---
name: deps-audit
description: Dependency security and freshness audit. Reads every package manifest, researches each dependency for CVEs, abandonment, and major version lag, and returns a prioritized report.
argument-hint: "[optional: directory to scope the audit]"
allowed-tools:
  - Read
  - Glob
  - Bash
  - AskUserQuestion
  - WebFetch
  - mcp__brave-search__brave_web_search
  - mcp__serper-search__google_search
---

# /qdev:deps-audit

Audit project dependencies for security vulnerabilities, version lag, and abandoned packages.

## Step 1: Discover Manifests

If `$ARGUMENTS` is provided, scope discovery to that path. Otherwise scan from the project root.

```bash
find . -maxdepth 4 \
  \( -name "package.json" -o -name "requirements.txt" -o -name "pyproject.toml" \
     -o -name "Pipfile" -o -name "go.mod" -o -name "Cargo.toml" \
     -o -name "Gemfile" -o -name "composer.json" \) \
  -not -path "*/.git/*" \
  -not -path "*/node_modules/*" \
  -not -path "*/.venv/*" \
  -not -path "*/vendor/*" | sort
```

Read each manifest found. For `package.json`, also read `package-lock.json` or `yarn.lock` if present to get resolved (pinned) versions. For Python, read `poetry.lock` and all `requirements*.txt` variants.

Build a dependency list: `{ name, declared_version, resolved_version, manifest_path, ecosystem }`.

If no manifests are found, emit `No package manifests found.` and stop.

Announce: `Found N dependencies across M manifests.`

## Step 2: Research Dependencies

For each dependency, run both search tools in the same response turn (parallel tool calls):
- `mcp__brave-search__brave_web_search` with 10 results
- `mcp__serper-search__google_search` with 10 results

Use two queries per dependency:
1. `"<name> CVE vulnerability security advisory <year>"`
2. `"<name> latest version deprecated abandoned <year>"`

For projects with more than 30 dependencies, prioritize: direct dependencies over transitive, pinned-to-old-versions first. Research up to 50 dependencies; note any skipped in the report.

For dependencies where search results surface a CVE or security advisory, use `WebFetch` to read the advisory page in full.

Deduplicate findings across the two search tools.

## Step 3: Classify Findings

Assign each finding a severity:

**Critical** (must address):
- Known CVE in the version currently in use
- Package flagged as malicious or compromised

**High** (should address):
- No release in 24+ months with no stated maintenance status
- Two or more major versions behind the current stable release
- Official deprecation with a stated end-of-life date

**Medium** (worth reviewing):
- One major version behind current stable
- Soft deprecation (still maintained, but a successor is recommended)
- No release in 12-24 months

**Info** (low urgency):
- Patch or minor version behind latest
- No pinned version (using ranges without a lockfile)

## Step 4: Present Report

Present findings grouped by severity. Omit severity sections with zero findings.

```
Dependency Audit: N dependencies across M manifests
Critical: N  |  High: N  |  Medium: N  |  Info: N

[CRITICAL]
  <package>@<version> — <CVE-ID>: <one-line description>
  Fix: upgrade to <version> or later
  Advisory: <url>

[HIGH]
  <package>@<version> — <reason>
  Latest: <version>  |  <link>

[MEDIUM]
  <package>@<version> — <reason>
  Latest: <version>  |  <link>

[INFO]
  <package>@<version> — <note>
```

If no Critical or High findings exist, emit:

```
✓ No critical or high-severity findings. N dependencies reviewed.
```

Then list Medium and Info as compact entries and stop without proceeding to Step 5.

## Step 5: Offer Upgrade Commands

If any Critical or High findings were found, use `AskUserQuestion`:
- header: `"Upgrade commands"`
- question: `"Would you like the exact upgrade commands for critical and high findings?"`
- options:
  1. label: `"Yes, generate them"`, description: `"Print the install commands for each affected package"`
  2. label: `"No thanks"`, description: `"The report is enough"`

If `"Yes, generate them"` is chosen: emit the appropriate package manager command for each Critical and High finding (e.g., `npm install package@X.Y.Z`, `pip install "package==X.Y.Z"`, `go get package@vX.Y.Z`, `cargo update -p package --precise X.Y.Z`). Note any packages where the safe upgrade version could not be confirmed from research.
