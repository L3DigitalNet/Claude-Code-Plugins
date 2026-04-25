#!/usr/bin/env bats
# guides-shape.bats — Structural integrity of the 163-guide content tree.
# Encodes [P2] One Guide, One Service mechanically.
bats_require_minimum_version 1.5.0
load test_helper

@test "every guides/<topic>/ has exactly one guide.md (GS1)" {
  result=$(python3 -c "
from pathlib import Path
root = Path('$PLUGIN_ROOT/guides')
problems = []
for d in sorted(p for p in root.iterdir() if p.is_dir()):
    guide = d / 'guide.md'
    if not guide.is_file():
        problems.append(f'{d.name}: missing guide.md')
print('\n'.join(problems) if problems else 'OK')
")
  [ "$result" = "OK" ]
}

@test "no duplicate topic-directory names (GS2)" {
  # Filesystem-level uniqueness is structural; this asserts there's no
  # case-folding collision or symlink loop creating effective duplicates.
  result=$(python3 -c "
from pathlib import Path
root = Path('$PLUGIN_ROOT/guides')
names = [p.name.lower() for p in root.iterdir() if p.is_dir()]
dupes = [n for n in set(names) if names.count(n) > 1]
print(','.join(dupes) if dupes else 'OK')
")
  [ "$result" = "OK" ]
}

@test "guide count matches README claim (163 guides) (GS3)" {
  count=$(find "$PLUGIN_ROOT/guides" -mindepth 1 -maxdepth 1 -type d | wc -l)
  [ "$count" -eq 163 ]
}

@test "every guide.md is non-empty (GS4)" {
  empty=$(python3 -c "
from pathlib import Path
empties = [str(p) for p in Path('$PLUGIN_ROOT/guides').glob('*/guide.md') if p.stat().st_size == 0]
print('\n'.join(empties) if empties else 'OK')
")
  [ "$empty" = "OK" ]
}
