# Wiki Sync Module — Skill

## Purpose

Publish repository documentation to the GitHub wiki as a read-only public help resource. The wiki is a rendering target — repo files are always the single source of truth. Wiki content is never edited directly.

## Applicability

**Tiers 3 and 4 only** (public repos). Disabled by default on Tiers 1 and 2 (private repos don't have public wikis).

## Execution Order

Runs as module #9 (last) during full assessments. Runs last because it may reference findings from other modules and generates content that incorporates the current state of the project.

## Helper Commands

```bash
# Clone the wiki repo to a local directory
gh-manager wiki clone --repo owner/name --dir /tmp/wiki-xyz

# Initialize wiki (first-time — creates Home page, pushes to create wiki repo)
gh-manager wiki init --repo owner/name [--dry-run]

# Diff generated content against current wiki
gh-manager wiki diff --dir /tmp/wiki-xyz --content-dir /tmp/wiki-generated-xyz

# Commit and push all changes
gh-manager wiki push --dir /tmp/wiki-xyz --message "Wiki sync 2026-02-17" [--dry-run]

# Clean up temp directory
gh-manager wiki cleanup --dir /tmp/wiki-xyz
```

---

## Assessment Flow

### Step 1: Check Wiki Status

First, verify the repo has wiki enabled:

```bash
gh-manager repo info --repo owner/name
```

Check `has_wiki` in the response. If `false`:

> Wiki is disabled on this repo. Want me to skip wiki sync, or would you like to enable it? (You can enable it in repo Settings → Features → Wikis)

If wiki is enabled, try to clone:

```bash
gh-manager wiki clone --repo owner/name --dir /tmp/wiki-owner-name-TIMESTAMP
```

Check the response `status` field:

- **`cloned`** — Wiki exists with pages. Proceed to content generation.
- **`wiki_not_initialized`** — Wiki enabled but empty. Offer to initialize.

### Step 2: Handle Uninitialized Wiki

If wiki is enabled but not initialized:

> Wiki is enabled on this repo but doesn't have any content yet. GitHub hasn't created the wiki repository until the first page is added.
>
> I can initialize it by pushing a starter Home page — that will create the wiki repo. Then I can populate it with your documentation. Want me to set it up?

On approval:

```bash
gh-manager wiki init --repo owner/name
```

Then re-clone to get the fresh wiki for content generation:

```bash
gh-manager wiki clone --repo owner/name --dir /tmp/wiki-owner-name-TIMESTAMP
```

### Step 3: Generate Wiki Content

This is the core skill-layer work. You (Claude) analyze the repo's documentation and code to produce wiki-ready markdown files.

**Create a staging directory:**

```bash
mkdir -p /tmp/wiki-generated-owner-name-TIMESTAMP
```

**Generate each wiki page as a markdown file in the staging directory.** Use Claude Code's filesystem tools to write each file.

#### Page Sources (in priority order)

1. **Explicit page_map from config** — if the owner configured specific source→wiki mappings, follow them
2. **docs/ directory** — transform each doc file into a wiki page
3. **README.md** → Home.md (if no custom Home mapping)
4. **Auto-generation targets** — analyze code for functions, CLI, config, API docs

#### Standard Scaffolding

Always generate these:

| File | Content |
|------|---------|
| `Home.md` | From README.md or configured landing page |
| `_Sidebar.md` | Auto-generated table of contents from all pages |
| `_Footer.md` | Template: version, last sync date, repo link |

#### Page Naming Convention

Wiki pages use GitHub's wiki filename convention:
- Spaces → hyphens in filenames: `Getting Started` → `Getting-Started.md`
- Display name is derived from filename: `Getting-Started.md` displays as "Getting Started"
- Keep filenames simple and descriptive

#### Content Transformation Rules

When converting repo docs to wiki pages:

1. **Fix relative links** — repo-relative links (`./docs/api.md`) become wiki page links (`[[API-Reference]]`)
2. **Fix image references** — repo-relative images need full GitHub URLs (`https://raw.githubusercontent.com/owner/repo/main/docs/images/...`)
3. **Add wiki header** — brief note that the page is auto-generated:
   ```
   > This page is automatically generated from repository documentation.
   > Do not edit directly — changes will be overwritten on the next sync.
   ```
4. **Remove repo-specific sections** — badges, CI status, install instructions that reference cloning the repo (these don't make sense in wiki context)

#### Auto-Generation from Code

When the config includes `auto_generate` targets, or when you identify code that would benefit from wiki documentation:

**`auto:functions`** — Read source files, identify exported functions/classes, generate a reference page with signatures, parameters, return types, and brief descriptions.

**`auto:cli`** — If the repo has a CLI tool, generate a command reference from the CLI definition (commander, argparse, etc.).

**`auto:config`** — Identify configuration options (from config files, environment variable references, etc.) and generate a configuration reference page.

**`auto:api`** — If the repo exposes an API, generate endpoint documentation from route definitions.

**Important:** Auto-generated content should be clearly marked as such and presented to the owner before pushing. Code analysis is best-effort — flag uncertain areas.

### Step 4: Diff Generated Content

Compare your generated pages against the current wiki:

```bash
gh-manager wiki diff --dir /tmp/wiki-owner-name-TIMESTAMP --content-dir /tmp/wiki-generated-owner-name-TIMESTAMP
```

The diff command returns:
- `new_pages` — pages you're adding that don't exist in the wiki
- `modified` — pages that exist but content has changed
- `unchanged` — pages that are identical (no action needed)
- `orphaned` — pages in the wiki that don't map to any source

### Step 5: Present Changes to Owner

Present the diff summary conversationally:

> 📚 Wiki Sync — ha-light-controller
>
> Changes detected:
> • 2 new pages: Getting-Started, API-Reference
> • 1 updated: Home (README changed since last sync)
> • 3 unchanged: Configuration, FAQ, Troubleshooting
> • 1 orphan: Old-Setup-Guide (no longer has a source file)
>
> Want me to show the diff for the updated Home page?

**For Tier 4:** Always show full diffs for modified pages before approval. These repos have the highest public visibility.

**For Tier 3:** Show a summary and offer to show diffs on request.

### Step 6: Handle Orphans

Based on the config `orphan_handling` setting:

**`warn` (default):**
> The wiki has a page "Old-Setup-Guide" that doesn't map to any current documentation. This sometimes happens when docs are reorganized. Want me to remove it, archive it, or leave it?

**`delete`:**
> I'll remove "Old-Setup-Guide" from the wiki since it no longer has a source file.

**`archive`:**
> I'll move "Old-Setup-Guide" to an Archive section in the sidebar.

To delete orphans, remove the file from the wiki clone directory before pushing.

To archive, move it to a clearly marked section and update the sidebar.

### Step 7: Apply Changes

On owner approval, copy generated content into the wiki clone directory:

```bash
# Copy each generated file into the wiki clone
cp /tmp/wiki-generated-owner-name-TIMESTAMP/*.md /tmp/wiki-owner-name-TIMESTAMP/

# If deleting orphans, remove them from the clone
rm /tmp/wiki-owner-name-TIMESTAMP/Old-Setup-Guide.md
```

Then push:

```bash
gh-manager wiki push --dir /tmp/wiki-owner-name-TIMESTAMP --message "Wiki sync 2026-02-17"
```

### Step 8: Clean Up

Always clean up temp directories:

```bash
gh-manager wiki cleanup --dir /tmp/wiki-owner-name-TIMESTAMP
gh-manager wiki cleanup --dir /tmp/wiki-generated-owner-name-TIMESTAMP
```

---

## Sidebar Generation

Generate `_Sidebar.md` automatically from the page list:

```markdown
**ha-light-controller Wiki**

* [[Home]]
* [[Getting-Started]]
* [[Configuration]]
* [[API-Reference]]
* [[FAQ]]
* [[Troubleshooting]]

---
*Auto-maintained by GitHub Repo Manager*
```

Group pages logically if the repo has sections (e.g., guides, reference, troubleshooting). Use the docs/ directory structure as a hint for grouping.

## Footer Generation

Generate `_Footer.md` from a simple template:

```markdown
---
*Last synced: 2026-02-17 · [View source](https://github.com/owner/repo)*
```

---

## Page Map Configuration

The owner can configure explicit source→wiki mappings:

```yaml
wiki_sync:
  page_map:
    - source: "docs/getting-started.md"
      wiki_page: "Getting-Started"
    - source: "docs/api/"
      wiki_page: "API-Reference"
      mode: "concatenate"       # Combine directory into single page
    - source: "auto:functions"
      wiki_page: "Function-Reference"
      mode: "generate"          # Generate from code analysis
```

**Modes:**
- (default) — one source file → one wiki page
- `concatenate` — directory of files → single wiki page (files joined in alphabetical order with headings)
- `generate` — auto-generate from code analysis (no source file)

Without explicit page_map, use sensible defaults:
- `README.md` → `Home.md`
- Each file in `docs/` → wiki page named after the file
- `_Sidebar.md` and `_Footer.md` auto-generated

---

## Cross-Module Interactions

### With Community Health

- If CONTRIBUTING.md or other community files were just created/updated by the Community Health module in this session, include the fresh versions in wiki content generation
- Don't duplicate community health findings — wiki sync focuses on documentation content, not file existence

### With Release Health

- If Release Health found unreleased commits or CHANGELOG drift, the wiki Home page can note the latest release version
- Don't duplicate release findings in the wiki sync report

### General

- Wiki sync runs last in module execution order so it can reference the current state of everything else
- Wiki content should reflect the repo's actual state, including any changes made during this maintenance session

---

## Error Handling

| Error | Response |
|-------|----------|
| Wiki not enabled | Inform owner, offer to skip. Don't error. |
| Wiki not initialized | Offer to initialize with Home page. |
| Git clone fails (auth) | "I can't access the wiki repo. Check that your PAT has Contents read/write permission." |
| Git push fails (conflict) | "Someone else may have pushed to the wiki since I cloned it. Want me to re-clone and try again?" |
| Git push fails (auth) | "I don't have permission to push to the wiki. Check that your PAT has Contents write access." |
| Empty content (no docs to publish) | "This repo doesn't have documentation files I can publish to the wiki. Want me to skip wiki sync?" |

### ⚠️ Irreversibility Warning

Wiki pushes overwrite content. Always warn before pushing:

> ⚠️ This will update 3 wiki pages and remove 1 orphaned page. Wiki changes take effect immediately and are publicly visible. Proceed?

For Tier 4, be especially explicit about what changes.

---

## Tier-Specific Behavior

| Behavior | Tier 3 | Tier 4 |
|----------|--------|--------|
| Show full diffs before push | On request | Always |
| Orphan handling | Configurable (warn/delete/archive) | `warn` only — owner decides |
| Auto-generation | Full | Full, with extra review for API docs |
| Push approval | Single confirmation | Page-level confirmation available |

---

## Presenting Findings

### Summary (end of module)

> 📚 Wiki Sync — ha-light-controller
>
> Synced 5 pages: 2 new, 1 updated, 2 unchanged
> Removed 1 orphaned page (Old-Setup-Guide)
> Wiki is now current with repo documentation.

### For Reports

| Module | Status | Findings | Actions Taken |
|--------|--------|----------|---------------|
| Wiki Sync | ⚠️ Drift Detected | 3 pages stale | 3 pages updated (pushed) |
