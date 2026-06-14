# project-standards refresh — detection ledger

**Scratch progress file** for the standards-compliance refresh (2026-06-14). Not an adoption footprint of any standard; safe to delete after the refresh closes. Resume protocol: `pwd`, read this file, then `git log`.

- **Source of truth:** `L3DigitalNet/project-standards` (PUBLIC), local clone at `/home/chris/projects/project-standards`. Read canonically with `git -C /home/chris/projects/project-standards show v3.0.0:<path>` (the clone's working tree is on `testing` — not canonical).
- **Release mechanism:** GitHub Releases + SemVer tags. **Latest released tool version = `v3.0.0`** (`standards/` tree byte-identical to `origin/main`; `@v3` ≡ `@v3.0.0`, both peel to commit `e69ab6b`).
- **Per-standard contract versions** (distinct from the tool tag), per `meta/versioning.md@v3.0.0`: markdown-frontmatter `1.1`, adr `1.0`, python-tooling `1.0`, markdown-tooling `1.0`.
- **This repo's manifest** (`.project-standards.yml`) records one selection: `markdown_tooling: version: "1.0"`, and disclaims markdown-frontmatter + python-tooling as not adopted.

## Ledger — every standard under `standards/`

| Standard | Adopted? | Adopted ver | Latest ver | Behind? | Outcome |
| --- | --- | --- | --- | --- | --- |
| markdown-tooling | YES | contract 1.0 | contract 1.0 | YES | UPDATED → v3: pin `@v2`→`@v3`; MD060 enabled; repo formatted; gate green |
| markdown-frontmatter | no | — | 1.1 | n/a | out of scope (not adopted) |
| adr | no | — | 1.0 | n/a | out of scope (informal ADR docs only; no template/fragment footprint) |
| python-tooling | no | — | 1.0 | n/a | out of scope (no pyproject fragment / .python-version / check.yml) |
| python-coding | no — not adoptable | — | draft 0.4 | n/a | out of scope (in-dev draft; no contract version) |

Detection independently confirmed by an adversarial read-only workflow (6 agents): markdown-tooling adopted + behind on the `@v2` pin; MD060 a documented override; `.vscode/extensions.json` markdown subset legitimate; the other four not adopted (no stray footprints).

## What was done (markdown-tooling → project-standards v3.0.0)

1. **Pin bump** — `.github/workflows/lint-markdown.yml`: `@v2` → `@v3` (the actual v3 compliance change; v2→v3 reusable workflow diff is additive only, cannot newly-fail).
2. **MD060** — user chose to enable it. Standard's `{style:"any"}` is incompatible with Prettier (renders empty cells `|  |` → 152 violations). Set `{style:"leading_and_trailing", aligned_delimiter:false}` instead (0 violations, Prettier-stable). Recorded in `docs/decisions/adr-0001-prettier-jsts-scope.md` (supersedes the original MD060-disable).
3. **Prettier autoformat** — `prettier --write .` reformatted 15 pre-existing-dirty files (formatting-only, content-identical; fixes the previously-failing `prettier --check .` gate).
4. **Residual lint fixes** — main was pre-existingly red (30 markdownlint errors). Prettier fixed 17 (MD022/MD049/MD012); the last 13 fixed by hand, Prettier-stable: MD031 (fences-in-tight-lists → loose lists) in the up-docs-llm-wiki plan; MD040 (bare fence → `gitignore`) in uv-strict-python `uv-commands.md`.

**Unchanged (correct as-is):** `.markdownlint.json` (other 64 rules), `.prettierrc.json`, `.editorconfig` byte-identical to v3.0.0; `.vscode/extensions.json` is the legitimate markdown subset; `markdown_tooling.version: "1.0"` already current.

## Acceptance — markdown-tooling gate

- `npx markdownlint-cli2 "**/*.md"` → **0 errors** (235 files); exit 0.
- `npx prettier --check .` → clean.
- Caller pinned `@v3`; `MD060` = `leading_and_trailing`.

No root `ruff`/`pyright`/`pytest` gate applies to markdown-tooling; markdownlint + Prettier are this standard's enforcement and both pass.
