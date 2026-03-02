# awk and sed Command Reference

Each block below is copy-paste-ready. The two tools complement each other:
sed excels at line-level substitution and deletion; awk excels at field
extraction, conditional logic, and aggregation.

---

## 1. sed: Substitution

```bash
# Replace first occurrence per line
sed 's/old/new/' file

# Replace all occurrences per line (global flag)
sed 's/old/new/g' file

# Case-insensitive substitution (GNU sed)
sed 's/old/new/gI' file

# Replace only on lines matching a pattern
sed '/pattern/s/old/new/g' file

# Replace only on line number 5
sed '5s/old/new/' file

# Backreference: swap two captured groups
sed -E 's/(first) (second)/\2 \1/' file
```

---

## 2. sed: In-Place Editing

```bash
# Edit file in place (GNU sed — Linux)
sed -i 's/old/new/g' file

# Edit in place with a backup (works on GNU and BSD/macOS)
sed -i.bak 's/old/new/g' file

# Multiple expressions in one command
sed -i 's/foo/bar/g; s/baz/qux/g' file

# Edit multiple files at once
sed -i 's/old/new/g' *.conf

# Preview changes without modifying (omit -i, use stdout)
sed 's/old/new/g' file
```

---

## 3. sed: Line Deletion and Selection

```bash
# Delete lines containing a pattern
sed '/error/d' file

# Delete blank lines
sed '/^$/d' file

# Delete leading whitespace from each line
sed 's/^[[:space:]]*//' file

# Print only lines matching a pattern
sed -n '/pattern/p' file

# Print a specific line number
sed -n '5p' file

# Print a range of lines
sed -n '5,10p' file
```

---

## 4. sed: Address Ranges and Multi-Line Operations

```bash
# Print lines between two patterns (inclusive)
sed -n '/start/,/end/p' file

# Delete lines between two patterns
sed '/start/,/end/d' file

# Append a new line after a matching line
sed '/pattern/a\new line content' file

# Insert a new line before a matching line
sed '/pattern/i\new line content' file

# Replace an entire line matching a pattern
sed '/pattern/c\replacement line' file

# Join next line to current line (N command)
sed 'N; s/\n/ /' file
```

---

## 5. awk: Column Extraction and Field Separators

```bash
# Print the second column (space/tab delimited by default)
awk '{print $2}' file

# Print first and third columns
awk '{print $1, $3}' file

# Custom field separator (colon)
awk -F: '{print $1}' /etc/passwd

# Multi-character separator
awk -F'::' '{print $2}' file

# Tab separator
awk -F'\t' '{print $3}' file

# Print last field
awk '{print $NF}' file

# Print number of fields on each line
awk '{print NF}' file
```

---

## 6. awk: Conditional Logic and Pattern Matching

```bash
# Print lines where column 3 is greater than 100
awk '$3 > 100 {print $0}' file

# Print lines where a field equals a specific value
awk '$2 == "active" {print $1}' file

# Pattern match on any field
awk '/error/ {print $0}' file

# Pattern match on a specific column
awk '$4 ~ /^2[0-9]{3}/ {print}' file

# Negate a pattern
awk '!/^#/ {print}' file

# AND / OR conditions
awk '$1 > 0 && $2 != "skip" {print}' file
```

---

## 7. awk: Aggregation and Arithmetic

```bash
# Sum all values in column 2
awk '{sum += $2} END {print sum}' file

# Count matching lines
awk '/error/ {count++} END {print count}' file

# Average of column 3
awk '{sum += $3; n++} END {print sum/n}' file

# Find maximum value in column 1
awk 'NR==1 || $1 > max {max=$1} END {print max}' file

# Count occurrences of each value in column 1
awk '{count[$1]++} END {for (k in count) print k, count[k]}' file
```

---

## 8. awk: BEGIN and END Blocks

```bash
# Print a header before processing
awk 'BEGIN {print "Name\tStatus"} {print $1"\t"$2}' file

# Set field separator in BEGIN
awk 'BEGIN {FS=":"; OFS="\t"} {print $1, $3}' /etc/passwd

# Print a summary footer
awk '{sum += $2} END {printf "Total: %.2f\n", sum}' file

# Combine header, processing, and footer
awk 'BEGIN {print "--- Report ---"}
     /active/ {print $1, $2}
     END {print "--- Done ---"}' file
```

---

## 9. awk: String Operations and Formatting

```bash
# String length
awk '{print length($1)}' file

# Substring
awk '{print substr($1, 1, 3)}' file

# Index of a substring
awk '{print index($0, "pattern")}' file

# printf formatting
awk '{printf "%-20s %5d\n", $1, $2}' file

# Convert to uppercase (gawk only)
awk '{print toupper($0)}' file

# Split a field by a separator into an array
awk '{n=split($3, parts, "/"); print parts[1]}' file
```

---

## 10. Combining awk and sed in Pipelines

```bash
# Strip comments and blank lines, then extract column 2
sed '/^#/d; /^$/d' config.txt | awk '{print $2}'

# Reformat a log: extract timestamp and message
sed -n 's/^\[\(.*\)\] \(.*\)$/\1\t\2/p' app.log | awk -F'\t' '$1 > "2025-01-01" {print}'

# Sum disk usage by directory (from du output)
du -s /var/*/  | awk '{sum += $1} END {printf "%d MB total\n", sum/1024}'

# Count unique IPs from nginx access log
awk '{print $1}' /var/log/nginx/access.log | sort | uniq -c | sort -rn | head -10

# Extract key=value pairs and reformat
sed -n 's/^KEY_\([A-Z]*\)=\(.*\)$/\1: \2/p' .env | awk '{printf "%-20s %s\n", $1, $2}'
```
