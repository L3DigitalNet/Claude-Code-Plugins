---
name: awk-sed
description: >
  awk and sed stream editors: invoked when the user asks about awk, sed, stream
  editor, text processing, column extraction, field splitting, in-place edit,
  text transform, sed replace, or awk print. Covers sed substitution and in-place
  editing, line deletion and printing, address ranges, awk field and separator
  usage, conditional logic, column summing, pattern-action blocks, and BEGIN/END.
globs: []
---

## Identity

| Property | Value |
|----------|-------|
| **Binary** | `awk`, `sed`, `gawk`, `mawk` |
| **Config** | No persistent config — invoked directly |
| **Logs** | No persistent logs — output to terminal |
| **Type** | CLI tool |
| **Install** | `apt install gawk` / `dnf install gawk` (sed is pre-installed) |

## Key Operations

| Task | Command |
|------|---------|
| sed: substitute first match per line | `sed 's/old/new/' file` |
| sed: substitute all matches per line | `sed 's/old/new/g' file` |
| sed: in-place edit (GNU) | `sed -i 's/old/new/g' file` |
| sed: in-place with backup | `sed -i.bak 's/old/new/g' file` |
| sed: delete lines matching pattern | `sed '/pattern/d' file` |
| sed: delete blank lines | `sed '/^$/d' file` |
| sed: print specific line number | `sed -n '5p' file` |
| sed: print line range | `sed -n '5,10p' file` |
| sed: address range (between two patterns) | `sed -n '/start/,/end/p' file` |
| sed: append line after match | `sed '/pattern/a\new line' file` |
| sed: insert line before match | `sed '/pattern/i\new line' file` |
| awk: print specific column | `awk '{print $2}' file` |
| awk: custom field separator | `awk -F: '{print $1}' /etc/passwd` |
| awk: conditional on column value | `awk '$3 > 100 {print $0}' file` |
| awk: pattern-action block | `awk '/error/ {print $0}' file` |
| awk: sum a column | `awk '{sum += $2} END {print sum}' file` |
| awk: BEGIN/END blocks | `awk 'BEGIN {FS=":"} {print $1} END {print "done"}' file` |
| awk: print last field | `awk '{print $NF}' file` |
| awk: print all but first field | `awk '{$1=""; print $0}' file` |

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `sed -i` errors on macOS | BSD sed requires empty string arg: `sed -i ''` | Use `sed -i.bak` (works both places) or install GNU sed via brew |
| sed backreference `$1` not working | sed uses `\1`, not `$1` for capture groups | Change to `sed 's/\(pattern\)/\1/'` or use extended regex: `sed -E 's/(pattern)/\1/'` |
| awk `-F` separator not splitting correctly | Multiple spaces or tabs as separator | Use `-F'[ \t]+'` for any whitespace, or default FS (no flag) which splits on any whitespace |
| `$0` includes old `$1` content after assignment | Assigning `$1=""` modifies `$0` with current OFS | Set `OFS=":"` in BEGIN if separator matters after field modification |
| `gawk` feature fails in POSIX awk | `gensub`, `match` with array, etc. are gawk extensions | Explicitly invoke `gawk` or rewrite using POSIX-compatible alternatives |
| Substitution changes too many lines | No address restriction on sed command | Add a line number or pattern address: `sed '3s/old/new/'` or `sed '/pattern/s/old/new/'` |

## Pain Points

- **GNU vs BSD sed `-i` syntax**: GNU sed (Linux): `sed -i 's/a/b/' file`. BSD sed (macOS): `sed -i '' 's/a/b/' file`. The safest cross-platform form is `sed -i.bak` which works on both and leaves a backup.
- **awk backreferences use `\1`, sed uses `\1` too**: The confusion comes from people expecting shell-style `$1`. In both tools, captured groups are `\1`, `\2`, etc. With `sed -E` or `awk` ERE, the group syntax is `()` without backslashes, but the reference is still `\1`.
- **Default FS splits on any whitespace**: When no `-F` is given, awk treats runs of spaces and tabs as a single separator and ignores leading whitespace. Convenient, but surprising when the input has intentional spaces within fields.
- **gawk has extensions POSIX awk lacks**: `gensub()`, multi-dimensional arrays, `PROCINFO`, and third-arg `match()` are gawk-only. Scripts relying on these will silently fail or error on systems running mawk (Ubuntu default) or nawk.
- **sed processes one line at a time by default**: Multi-line patterns require hold-space tricks (`H`, `G`, `N`) or a tool better suited to the job (awk with `RS`, perl, or python). Attempting multi-line sed without understanding hold space produces subtle bugs.
