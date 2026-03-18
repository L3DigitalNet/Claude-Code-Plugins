---
name: jq
description: >
  jq JSON processor: pretty-printing, field extraction, array iteration,
  filtering with select, map transforms, string interpolation, raw output,
  compact output, reading from files, constructing new JSON, slurping
  multiple inputs, null-safe defaults, and built-in encoders.
  MUST consult when writing jq expressions for JSON processing.
triggerPhrases:
  - "jq"
  - "JSON"
  - "parse JSON"
  - "JSON query"
  - "JSON filter"
  - "JSON transform"
  - "JSON from command line"
  - "process JSON"
globs: []
last_verified: "unverified"
---

## Identity

| Property | Value |
|----------|-------|
| **Binary** | `jq` |
| **Config** | No persistent config — invoked directly |
| **Logs** | No persistent logs — output to terminal |
| **Type** | CLI tool |
| **Install** | `apt install jq` / `dnf install jq` |

## Quick Start

```bash
sudo apt install jq
echo '{"name":"test","value":42}' | jq '.'
echo '{"name":"test","value":42}' | jq -r '.name'
curl -s https://api.example.com/data | jq '.items[] | {id, name}'
```

## Key Operations

| Task | Command |
|------|---------|
| Pretty-print JSON | `jq '.' file.json` |
| Extract a field | `jq '.name' file.json` |
| Nested field | `jq '.user.email' file.json` |
| Array index | `jq '.[0]' file.json` |
| Iterate array (all elements) | `jq '.[]' file.json` |
| Filter array with select | `jq '.[] \| select(.status == "active")' file.json` |
| Map transform | `jq '[.[] \| {id: .id, label: .name}]' file.json` |
| Get all keys | `jq 'keys' file.json` |
| Get all values | `jq '[.[]]' file.json` |
| String interpolation | `jq '.[] \| "\(.name): \(.value)"' file.json` |
| Raw string output (no quotes) | `jq -r '.name' file.json` |
| Compact output (no whitespace) | `jq -c '.' file.json` |
| Read filter from file | `jq -f filter.jq file.json` |
| Null-safe default | `jq '.missing // "default"' file.json` |
| Slurp multiple files into array | `jq -s '.' a.json b.json` |
| Check type of a value | `jq 'type' file.json` |
| Length of array or string | `jq '.items \| length' file.json` |
| Construct new JSON object | `jq '{id: .id, ts: .timestamp}' file.json` |
| Base64 encode a string | `jq -r '.data \| @base64' file.json` |
| URL-encode a string | `jq -r '.path \| @uri' file.json` |

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| Output is `null` for a field that exists | Key name typo or wrong nesting level | Use `jq 'keys'` to inspect available keys at that level |
| `jq: error: Invalid numeric literal` | Shell variable with special chars injected into filter | Use `--arg name "$var"` to pass shell variables safely |
| Filter works on file, fails on pipe | Input is multiple JSON objects (not an array) | Use `-s` to slurp all into an array, or `--slurpfile` |
| Quoted strings in output when you want plain text | Missing `-r` (raw output) flag | Add `-r` to strip quotes from string output |
| `Cannot iterate over null` | Field is absent or null | Guard with `// []` or `select(. != null)` before iterating |
| `compile error: ... unexpected INVALID_CHARACTER` | Single quotes don't work in Windows shells | Use double-quoted filter with internal escaping, or a `-f` filter file |
| Large JSON hangs or uses excessive memory | Processing multi-GB file with `.[]` | Use `--stream` mode or `jq -n --stream` for streaming parse |

## Pain Points

- **Silent null for missing keys**: `.field` returns `null` rather than an error when the key is absent. Use `// "default"` to catch this, or `has("field")` to test existence before accessing.
- **Shell quoting vs jq quoting**: Single quotes protect the jq filter from shell expansion, but when you need to embed a shell variable you must break out of single quotes or use `--arg`. Getting this wrong produces subtly wrong filters with no error.
- **`-r` is almost always required when piping**: Without it, string values are wrapped in JSON quotes, which breaks downstream commands expecting plain text. Treat `-r` as the default for pipelines.
- **Streaming mode for large inputs**: Loading a 500 MB JSON file into memory for `.[]` iteration is slow and may OOM. `--stream` emits path/value pairs incrementally, but requires a different filter style.
- **Hidden encoder builtins**: `@base64`, `@uri`, `@sh`, `@csv`, `@tsv`, `@html` are format strings, not functions — they go after `|` and require `-r` to produce usable output: `jq -r '.value | @uri'`.

## See Also

- **awk-sed** — Text stream processing for line-oriented and column-oriented data
- **ripgrep** — Fast recursive text search across files; pair with jq for structured output

## References
See `references/` for:
- `cheatsheet.md` — task-organized command reference
- `docs.md` — official documentation links
