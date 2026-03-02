---
name: ripgrep
description: >
  ripgrep (rg) fast recursive search: invoked when the user asks about ripgrep,
  rg, grep, search files, find text, regex search, search codebase, fast grep,
  or recursive search. Covers basic and case-insensitive search, fixed strings,
  file type filtering, glob patterns, context lines, match counting, multiline
  mode, replace output, JSON output, hidden file search, and .gitignore behavior.
globs: []
---

## Identity

| Property | Value |
|----------|-------|
| **Binary** | `rg` |
| **Config** | `~/.ripgreprc` (set via `RIPGREP_CONFIG_PATH`) |
| **Logs** | No persistent logs — output to terminal |
| **Type** | CLI tool |
| **Install** | `apt install ripgrep` / `dnf install ripgrep` |

## Key Operations

| Task | Command |
|------|---------|
| Basic search | `rg 'pattern' /path/` |
| Case-insensitive | `rg -i 'pattern' /path/` |
| Fixed string (no regex) | `rg -F 'literal.string' /path/` |
| Count matches per file | `rg -c 'pattern' /path/` |
| List only filenames with matches | `rg -l 'pattern' /path/` |
| Show N lines of context | `rg -C 3 'pattern' /path/` |
| Lines after match | `rg -A 2 'pattern' /path/` |
| Lines before match | `rg -B 2 'pattern' /path/` |
| Filter by file type | `rg -t py 'pattern'` |
| Filter by glob pattern | `rg -g '*.yaml' 'pattern'` |
| Exclude a path | `rg --iglob '!.git' 'pattern'` |
| Search hidden files | `rg -. 'pattern'` |
| Search ignored files too | `rg -u 'pattern'` |
| Search hidden + ignored | `rg -uu 'pattern'` |
| Multiline match | `rg -U 'start.*\nend' /path/` |
| Replace in output (not in file) | `rg -r 'replacement' 'pattern' /path/` |
| JSON output | `rg --json 'pattern' /path/` |
| Print stats summary | `rg --stats 'pattern' /path/` |
| PCRE2 regex (lookaheads etc.) | `rg -P '(?<=prefix)pattern' /path/` |

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| Expected files not in results | `.gitignore` is hiding them | Use `-u` to search ignored files, `-uu` for hidden+ignored |
| `-t mytype` gives "unrecognized type" | Custom extension not in rg's built-in type list | Use `-g '*.ext'` instead, or define a type with `--type-add` |
| Colors break piped output | ANSI codes injected into pipe | Add `--color never` when piping to other commands |
| Lookahead/lookbehind fails | Default regex engine (Rust) doesn't support them | Add `-P` for PCRE2 mode |
| `rg: command not found` | Package name differs from binary name | Binary is `rg`, package is `ripgrep`: `apt install ripgrep` |
| Multiline pattern matches nothing | Default mode is line-by-line | Add `-U` to enable multiline mode |
| Output includes binary file noise | Binary files partially matched | Add `--no-binary` to skip binary files entirely |

## Pain Points

- **`.gitignore` respect by default**: rg silently skips files listed in `.gitignore`, `.ignore`, and global gitignore. For a full filesystem search outside a repo, or when searching build artifacts, add `-u` (skip ignore rules) or `-uu` (skip ignore + hidden).
- **File type names are predefined**: `-t py` works because rg ships a built-in type list. To see all types, run `rg --type-list`. Extensions not in the list require `-g '*.ext'` instead.
- **Colorized output breaks pipes**: Piped output still contains ANSI escape codes by default. Add `--color never` (or `--color always` if color is needed downstream and the consumer supports it).
- **`rg`, not `ripgrep`**: The binary is `rg`. The package is `ripgrep`. Muscle memory from typing the full name will produce a "command not found" error.
- **Rust regex engine has no lookaheads**: The default engine is fast but limited. Add `-P` to switch to PCRE2 when you need lookaheads, lookbehinds, or backreferences. PCRE2 may not be compiled in on all distros — check with `rg --pcre2-version`.
