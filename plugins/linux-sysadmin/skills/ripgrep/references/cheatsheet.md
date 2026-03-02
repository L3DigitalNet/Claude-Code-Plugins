# ripgrep (rg) Command Reference

Each block below is copy-paste-ready. Substitute patterns, paths, and file types
for your actual search targets.

---

## 1. Basic Search

```bash
# Search for a literal string (case-sensitive)
rg 'error' /var/log/

# Recursive search from current directory
rg 'TODO'

# Case-insensitive search
rg -i 'error'

# Search for a fixed string (no regex interpretation)
rg -F 'config.file.path' /etc/

# Whole-word match only
rg -w 'error' /var/log/
```

---

## 2. File and Path Filtering

```bash
# Restrict to a specific file type
rg -t py 'import requests'

# Restrict to multiple file types
rg -t py -t js 'fetch('

# Custom glob pattern
rg -g '*.yaml' 'namespace:'

# Exclude files matching a glob
rg --iglob '!*.min.js' 'function'

# Exclude a directory
rg --iglob '!node_modules' 'require('

# List all supported type names
rg --type-list
```

---

## 3. Output Control

```bash
# Only list filenames that contain a match
rg -l 'TODO'

# Count matches per file
rg -c 'error'

# Show only the matched portion (not the whole line)
rg -o 'error: .*' /var/log/

# Show line numbers (enabled by default)
rg -n 'pattern' /path/

# No filename in output (useful when searching a single file)
rg --no-filename 'pattern' file.txt

# Print stats summary (files searched, matches, elapsed time)
rg --stats 'pattern' /path/
```

---

## 4. Context Lines

```bash
# Show 3 lines before and after each match
rg -C 3 'panic' /var/log/syslog

# Show only lines after match
rg -A 5 'ERROR' /var/log/app.log

# Show only lines before match
rg -B 2 'FATAL' /var/log/app.log

# Combine: show surrounding context for each match
rg -B 1 -A 3 'connection refused' /var/log/
```

---

## 5. Ignore and Hidden File Handling

```bash
# Search ignored files too (respects hidden but ignores .gitignore)
rg -u 'pattern'

# Search hidden files (dot files/dirs)
rg -. 'pattern'

# Search hidden + ignored (equivalent to -uu)
rg -uu 'pattern'

# Search all files including binary (full unrestricted search)
rg -uuu 'pattern'

# Only show matches in files tracked by git
rg --no-ignore 'pattern'

# Search a specific .gitignore'd directory explicitly
rg 'pattern' dist/
```

---

## 6. Regex Features

```bash
# Anchored line match
rg '^ERROR' /var/log/

# Character class
rg '[0-9]{3}-[0-9]{4}' contacts.txt

# Alternation
rg 'error|warning|critical' /var/log/

# Capture and replace in output (not in file)
rg -r 'replacement $1' '(pattern)' file.txt

# Multiline match (dot matches newlines with -U)
rg -U 'start\n.*\nend' file.txt

# PCRE2 mode (lookaheads, backreferences)
rg -P '(?<=PREFIX)\w+' file.txt
```

---

## 7. JSON and Structured Output

```bash
# Emit JSON for programmatic processing
rg --json 'pattern' /path/ | jq '.data.lines.text'

# Count with JSON output (pipe to jq for totals)
rg --json 'error' /var/log/ | jq 'select(.type=="match") | .data.lines.text'

# Extract unique matched values
rg -o '\b[A-Z]{2,}\b' file.txt | sort -u

# Build a simple report
rg -c 'error' /var/log/*.log | sort -t: -k2 -rn | head -10
```

---

## 8. Colorized and Terminal-Friendly Output

```bash
# Force color even when piping (useful for less -R)
rg --color always 'pattern' | less -R

# Disable color for plain text output
rg --color never 'pattern' > matches.txt

# Heading mode (filename printed once above matches, not per line)
rg --heading 'pattern'

# No heading (one result per line with filename prefix)
rg --no-heading 'pattern'

# Separator between match groups
rg --context-separator '---' -C 2 'pattern'
```

---

## 9. Search and Replace (Output Only)

```bash
# Replace matched portion in output (does not modify files)
rg -r 'new_value' 'old_pattern' file.txt

# Capture group in replacement
rg -r '$1_suffix' '(prefix_)(\w+)' file.txt

# Preview what sed -i would do, safely
rg 'old_name' --replace 'new_name' src/

# Count occurrences to understand scope before patching
rg -c 'old_name' src/
```

---

## 10. Practical Search Combos

```bash
# Find all TODOs with author context
rg -i 'todo|fixme|hack|xxx' --heading src/

# Find large files that match (sort results by file)
rg -l 'pattern' | xargs ls -lh | sort -k5 -rh

# Search only recent files (using find to filter, rg to match)
find /var/log -mtime -1 -name '*.log' | xargs rg 'error'

# Find files containing all of two patterns
rg -l 'pattern1' | xargs rg -l 'pattern2'

# Search and pipe matched files to another command
rg -l 'deprecated' src/ | xargs sed -i 's/deprecated/legacy/g'
```
