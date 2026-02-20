---
name: docs
description: Documentation lifecycle management
---

Parse the first argument as `<subcommand>`. Route to the matching section below. If no argument, run **status (brief)**.

**Scripts directory:** `${CLAUDE_PLUGIN_ROOT}/scripts`

## Pre-flight

Before routing, check if `~/.docs-manager/config.yaml` exists. If missing and subcommand is not `help`:
1. Inform the user: "docs-manager needs initial setup."
2. Ask via `AskUserQuestion`: "Where is your documentation index stored?" with options:
   - "Local git repo (git-markdown)" — ask for path, validate it exists or offer to create
   - "JSON file only" — use `~/.docs-manager/docs-index.json`
3. Ask machine identity — default to `$(hostname)`, confirm or override
4. Write `~/.docs-manager/config.yaml` with chosen settings
5. Run `bootstrap.sh`
6. Continue to subcommand

---

## queue

Display current queue. Run: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/queue-read.sh`

Format the output as a markdown table if items exist.

## queue review

Interactive review of queued items:

1. Run `queue-read.sh --json` to get pending items
2. If empty, say "No items to review" and stop
3. For each pending item, read the associated file at `doc-path` and assess its current state
4. Draft a 1-3 sentence proposed update per item
5. Present via `AskUserQuestion` with `multiSelect: true`:
   - Each option label: `"[filename] — [type]: [proposed summary]"`
   - Each option description: the drafted update detail
   - Selected = approved for update
6. For unselected items, present second `AskUserQuestion` with `multiSelect: true`:
   - "These N items were not approved. Select any to permanently dismiss — the rest defer to next session."
7. Apply approved updates — edit the documents using Edit tool
8. For dismissed items: run `queue-clear.sh` per-item with the dismiss reason
9. For deferred items: update their status to `"deferred"` in queue.json via jq

## queue clear

Requires a reason. Run: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/queue-clear.sh --reason "<reason>"`

If the user provides `/docs queue clear` without a reason, ask for one via `AskUserQuestion`.

## status

Operational and library health dashboard.

**Operational Health** — gather:
- Config: check `~/.docs-manager/config.yaml` exists and is valid YAML
- Hooks: read timestamps from `~/.docs-manager/hooks/*.last-fired`, report age
- Queue: validate `queue.json` is parseable, report item count
- Lock: check if `~/.docs-manager/index.lock` exists (stale lock warning)
- Fallback: check if `queue.fallback.json` exists (pending merge warning)

**Library Health** — gather from `docs-index.json` if it exists:
- Count total registered documents
- Count documents missing recommended fields (source-files, upstream-url)
- Count overdue verification items (last-verified > 90 days ago)
- Count pending queue items

Format output:
```
Operational Health
  Config:    ✓ loaded
  Hooks:     PostToolUse (2m ago) | Stop (last session)
  Queue:     3 pending items
  Lock:      none
  Fallback:  none

Library Health
  Documents: 12 registered (3 libraries)
  Missing:   2 without upstream-url, 1 without source-files
  Overdue:   1 verification overdue (>90 days)
```

With `--test` flag: run all operational checks and report pass/fail for each.

## hook status

Read and display hook last-fired timestamps from `~/.docs-manager/hooks/`:
- `post-tool-use.last-fired`
- `stop.last-fired`

Report each as "Xm ago" or "never fired". Check that `hooks.json` is properly registered.

## index init

Initialize the documentation index:
1. Check config.yaml for index type and location
2. If git-markdown: verify repo exists or offer to `git init`
3. Create empty `docs-index.json` and `docs-index.md` if not present
4. Run `bootstrap.sh` if state directory incomplete
5. Report success with index location

## index sync

Synchronize index with remote (git-markdown backend):
1. Run `git pull` in index location
2. Check for merge conflicts — if found, report and suggest `/docs index repair`
3. Apply any pending offline writes from `~/.docs-manager/cache/pending-writes.json`
4. Update local cache snapshot
5. Report sync result

## index audit

Check index integrity:
1. For each document entry, verify the file at `path` exists
2. Report orphaned entries (file missing) — present options: remove, update path, or keep
3. Check for documents on disk with frontmatter but not in index
4. Use `AskUserQuestion` for orphan resolution

## index repair

Resolve index conflicts (git-markdown backend):
1. Use union-merge strategy: keep both sides' additions
2. For true conflicts (same doc modified on both machines), present side-by-side via `AskUserQuestion`
3. Rebuild `docs-index.md` after resolution
4. Commit the merge

## library

List all documentation libraries.

Run: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/index-query.sh` and group by library.

Default: show libraries on current machine only. `--all-machines` shows all.

Format: table with name, machine, description, document count.

## find

Search the documentation index.

Usage: `/docs find <query>` with optional flags: `--library`, `--type`, `--machine`

Run: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/index-query.sh --search "<query>"` (with any additional filter flags)

Display results as a table: title, library, path, last-verified, summary. Show cross-references if present.

## new

Create a new managed document:

1. Ask: "What are you documenting?" — infer library, doc-type, template from context
2. Run `index-query.sh --search` to check for related existing docs — surface matches to avoid duplication
3. Ask three classification questions via `AskUserQuestion`:
   - "Does this document capture a state snapshot, a process flow, or dependencies?" (multiSelect)
4. Infer template from context (directory, library, intent). If confidence low, ask one question.
5. Draft document with frontmatter and structure from template
6. User reviews and confirms location/content
7. Write file, register in index via `index-register.sh`
8. If third-party tool detected: prompt for `upstream-url`

## onboard

Register existing documents in the index.

**Single file** (`/docs onboard <path>`):
1. Read document, extract or infer library/type/machine from content and path
2. Present assignments for confirmation via `AskUserQuestion`
3. Add frontmatter if missing (preserve existing content)
4. Register in index via `index-register.sh`
5. Prompt for `upstream-url` if third-party tool detected
6. Suggest cross-references based on same-library docs

**Directory** (`/docs onboard <directory>`):
1. Use Glob to find all `.md` files recursively
2. Group by inferred library, present summary
3. User confirms/corrects groupings via `AskUserQuestion`
4. Batch frontmatter addition and index registration
5. Follow-up pass for upstream URLs

## template

Manage document templates.

**`/docs template register --from <path>`**: Analyze document structure, extract reusable skeleton with `{{placeholder}}` syntax, save to index templates directory.

**`/docs template register --file <path>`**: Copy template file directly to templates directory.

**`/docs template list`**: Show registered templates.

Template inference during `/docs new`: check directory against known library root-paths, filename patterns, and library type.

## update

Update a managed document:

Usage: `/docs update <path>`

1. Read the document and its `source-files` entries
2. For each source-file, read current content and compare against doc's description
3. If stale: draft updates, present for user confirmation
4. If current: update `last-verified` timestamp in frontmatter
5. Register changes in queue as completed

## review

Comprehensive single-document review:

Usage: `/docs review <path>` with optional `--full` flag

1. Staleness check: compare `last-verified` age against configured threshold
2. P5 compliance: verify survival-context docs have prose sections (call `is-survival-context.sh`)
3. Internal consistency: validate cross-refs point to existing docs, source-files exist
4. Upstream verification: if `upstream-url` present, fetch and compare
5. `--full`: also check adjacent docs in same library

## organize

Reorganize a document:

Usage: `/docs organize <path>`

1. Analyze content — infer correct library, directory, filename, structure
2. Present proposed reorganization via `AskUserQuestion`
3. On confirm: move/rename file, update frontmatter, update index path
4. Repair cross-references: find all docs that link to old path, update their `cross-refs`
5. Regenerate `docs-index.md` via `index-rebuild-md.sh`

## audit

Audit documentation quality:

Usage: `/docs audit` with optional `--p5` or `--p7` flags

1. Check all registered docs for missing recommended fields (source-files, upstream-url, template)
2. `--p5`: verify survival-context docs have prose sections
3. `--p7`: list docs without upstream-url that describe third-party tools
4. Output prioritized list (critical / standard / reference) with repair actions

## dedupe

Find near-duplicate documents:

1. Compare titles, content similarity, source-file overlap within each library
2. `--across-libraries`: cross-library comparison
3. Present findings with suggested resolution (merge, redirect, keep both)

## consistency

Check internal consistency across the index:

1. Cross-refs point to existing, registered docs
2. Source-files exist on disk
3. Library assignments match directory structure
4. Incoming-refs are symmetric with cross-refs

## streamline

Identify redundant content within a single document:

Usage: `/docs streamline <path>`

Analyze sections for repetition, suggest condensation. Present before/after comparison.

## compress

Compress for token efficiency (AI-audience docs only):

Usage: `/docs compress <path>`

1. Check P5 classification via `is-survival-context.sh`
2. If survival-context: refuse with explanation ("Use /docs streamline instead for human-readable docs")
3. If AI-audience: compress to token-efficient format, preserving all factual content

## full-review

Comprehensive documentation sweep across all libraries. Delegates to the `full-review` agent for context efficiency.

Combines: audit + consistency + upstream verification.

Returns structured findings report.

## verify

Upstream verification:

Usage: `/docs verify [path]` with optional `--all`, `--tier <N>` flags

**Single doc**: fetch `upstream-url` via `WebFetch`, compare against doc content.

**Batch** (no path): verify all docs due for re-verification based on `review-frequency`.

Tiered batching:
- Tier 1 (critical): verify immediately, ask to proceed
- Tier 2 (standard): ask to continue or defer
- Tier 3 (reference): ask to continue or defer

For each doc: confident match → update `last-verified`; confident discrepancy → queue correction; uncertain → queue with specific question for user.

## help

Output:
```
/docs — Documentation Lifecycle Manager

Commands:
  queue              Display current queue items
  queue review       Review and approve queued items
  queue clear        Dismiss all items (reason required)
  status [--test]    Operational and library health
  hook status        Check hook registration and timestamps
  index init         Initialize documentation index
  index sync         Sync index with remote
  index audit        Check index integrity
  index repair       Resolve index conflicts
  library            List documentation libraries
  find <query>       Search the documentation index
  new                Create a new managed document
  onboard <path>     Register existing docs in index
  template           Manage document templates
  update <path>      Update a managed document
  review <path>      Comprehensive document review
  organize <path>    Reorganize a document
  audit              Audit documentation quality
  dedupe             Find near-duplicate documents
  consistency        Check internal consistency
  streamline <path>  Identify redundant content
  compress <path>    Compress for token efficiency
  full-review        Comprehensive sweep (uses agent)
  verify [path]      Upstream verification
  help               This help text
```
