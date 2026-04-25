#!/usr/bin/env bats
# profile-shape.bats — [P4] Profile-Driven Stack Knowledge.
# Adding a new stack must be a one-file change. Each profile must have a
# consistent shape so the loader / agents can rely on it.
bats_require_minimum_version 1.5.0
PLUGIN_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

@test "every profile has a description line + --- separator structure (PS1)" {
  # Profile shape (current convention): a one-line description on line 1,
  # blank line, '---' separator, then the body. This is NOT YAML frontmatter
  # in the standard sense — it's a documented shape unique to this plugin.
  result=$(python3 -c "
from pathlib import Path
problems = []
for p in sorted(Path('$PLUGIN_ROOT/references/profiles').glob('*.md')):
    lines = p.read_text().splitlines()
    if not lines:
        problems.append(f'{p.name}: empty file')
        continue
    # Look for a '---' separator within the first 5 lines.
    has_sep = any(line.strip() == '---' for line in lines[:5])
    if not has_sep:
        problems.append(f'{p.name}: no --- separator in first 5 lines')
print('\n'.join(problems) if problems else 'OK')
")
  [ "$result" = "OK" ]
}

@test "every profile has a # Stack Profile heading (PS2)" {
  result=$(python3 -c "
from pathlib import Path
problems = []
for p in sorted(Path('$PLUGIN_ROOT/references/profiles').glob('*.md')):
    text = p.read_text()
    if '# Stack Profile' not in text:
        problems.append(f'{p.name}: no \"# Stack Profile\" heading')
print('\n'.join(problems) if problems else 'OK')
")
  [ "$result" = "OK" ]
}

@test "profile filenames match documented stack identifiers (PS3)" {
  # Filenames should be lowercase-hyphen-separated for stable detection.
  result=$(python3 -c "
import re
from pathlib import Path
problems = []
for p in sorted(Path('$PLUGIN_ROOT/references/profiles').glob('*.md')):
    if not re.match(r'^[a-z0-9]+(-[a-z0-9]+)*\.md$', p.name):
        problems.append(p.name)
print('\n'.join(problems) if problems else 'OK')
")
  [ "$result" = "OK" ]
}
