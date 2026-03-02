# jq Command Reference

Each block below is copy-paste-ready. Substitute actual field names, values, and
file paths for your data.

---

## 1. Pretty-Print and Basic Inspection

```bash
# Pretty-print a JSON file
jq '.' file.json

# Pretty-print from a command's output
curl -s https://api.example.com/items | jq '.'

# Compact output (single line, no whitespace)
jq -c '.' file.json

# Get all top-level keys
jq 'keys' file.json

# Check the type of the root value (object, array, string, number, boolean, null)
jq 'type' file.json
```

---

## 2. Field Extraction

```bash
# Extract a single field
jq '.name' file.json

# Nested field
jq '.user.email' file.json

# Extract with raw output (no JSON quotes around strings)
jq -r '.name' file.json

# Multiple fields at once
jq '.name, .email' file.json

# Extract from all elements of an array
jq '.[].name' file.json
```

---

## 3. Array Operations

```bash
# Access array by index (0-based)
jq '.[0]' file.json

# Last element
jq '.[-1]' file.json

# Slice (elements 1 through 3, exclusive of 4)
jq '.[1:4]' file.json

# Iterate over all elements
jq '.[]' file.json

# Count elements
jq '.items | length' file.json

# Check if array contains a value
jq '.tags | contains(["admin"])' file.json
```

---

## 4. Filter with select

```bash
# Keep only elements where a field equals a value
jq '.[] | select(.status == "active")' file.json

# Numeric comparison
jq '.[] | select(.age > 30)' file.json

# Multiple conditions (AND)
jq '.[] | select(.status == "active" and .role == "admin")' file.json

# Test with regex
jq '.[] | select(.email | test("@example\\.com$"))' file.json

# Wrap results in an array
jq '[.[] | select(.active == true)]' file.json
```

---

## 5. Map and Transform

```bash
# Transform each element into a new shape
jq '[.[] | {id: .id, label: .name, ts: .created_at}]' file.json

# Extract one field from every element
jq '[.[] | .email]' file.json

# Same with map shorthand
jq '[.items[] | .id]' file.json

# Add a computed field
jq '[.[] | . + {full_name: "\(.first) \(.last)"}]' file.json

# Conditional value in map
jq '[.[] | {id, status: (if .active then "enabled" else "disabled" end)}]' file.json
```

---

## 6. String Interpolation and Raw Output

```bash
# Build a string from fields
jq -r '.[] | "\(.name): \(.status)"' file.json

# Useful for generating config lines or CSV-like output
jq -r '.servers[] | "\(.host) \(.port) \(.weight)"' file.json

# Produce a shell-safe string (escapes for use in $(...))
jq -r '.[] | @sh' file.json

# Produce CSV output (values must be strings or numbers)
jq -r '.[] | [.id, .name, .status] | @csv' file.json

# Produce TSV output
jq -r '.[] | [.id, .name, .status] | @tsv' file.json
```

---

## 7. Null-Safe Defaults and Error Handling

```bash
# Return a default when a field is null or missing
jq '.config.timeout // 30' file.json

# Return a default string
jq '.user.nickname // .user.name // "anonymous"' file.json

# Skip null values in an array
jq '[.[] | select(. != null)]' file.json

# Handle missing optional object gracefully
jq '.metadata? // {}' file.json

# Try-catch for type errors
jq '.items | try .[] catch "not an array"' file.json
```

---

## 8. Construct New JSON

```bash
# Build a new object
jq '{id: .id, name: .name}' file.json

# Build from array elements
jq '[.items[] | {id: .id, label: .name}]' file.json

# Merge two objects (right side wins on key conflict)
jq '. * {"debug": true}' file.json

# Add a key to an existing object
jq '. + {"version": "2.0"}' file.json

# Remove a key
jq 'del(.internal_id)' file.json
```

---

## 9. Slurp, Streaming, and Multi-File Input

```bash
# Slurp multiple JSON files into a single array
jq -s '.' a.json b.json

# Combine and deduplicate by a field
jq -s '[.[] | .[] | {id, name}] | unique_by(.id)' a.json b.json

# Read a jq filter from a file
jq -f transform.jq input.json

# Stream mode for large files (emits path/value pairs)
jq --stream 'select(.[0][-1] == "name")' large.json

# Null-input mode (no file — generate JSON from scratch)
jq -n '{generated: true, ts: now | todate}'
```

---

## 10. Encoders and Built-In Functions

```bash
# Base64 encode a string value
jq -r '.secret | @base64' file.json

# Base64 decode
jq -r '.encoded | @base64d' file.json

# URL-encode a value
jq -r '.path | @uri' file.json

# HTML-encode a value
jq -r '.content | @html' file.json

# Current Unix timestamp
jq -n 'now'

# Format Unix timestamp as ISO 8601
jq -n 'now | todate'

# Convert a number to a string
jq '.count | tostring' file.json

# Convert a string to a number
jq '.price | tonumber' file.json
```
