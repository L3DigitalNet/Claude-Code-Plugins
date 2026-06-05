#!/usr/bin/env python3
"""Regenerate docs/handoff/bugs/INDEX.md from frontmatter of all bug files."""
import re
from pathlib import Path

BUGS = Path(__file__).parent

def parse_frontmatter(text):
    m = re.match(r'^---\n(.*?)\n---\n', text, re.DOTALL)
    if not m:
        return {}
    fm = {}
    for line in m.group(1).splitlines():
        if ':' not in line:
            continue
        k, _, v = line.partition(':')
        fm[k.strip()] = v.strip().strip('"')
    return fm

def main():
    rows = []
    for p in sorted(BUGS.glob('[0-9][0-9][0-9]-*.md')):
        fm = parse_frontmatter(p.read_text())
        rows.append((
            fm.get('bug_id', '?'),
            fm.get('date', '?'),
            fm.get('title', '?').strip('"'),
            fm.get('services', '[]').strip('[]'),
            fm.get('status', '?'),
        ))
    out = ['# Bug Index', '',
           'Generated from frontmatter. Regenerate with `python3 docs/handoff/bugs/_regen_index.py`.', '',
           '| # | Date | Title | Services | Status |',
           '|---|---|---|---|---|']
    for r in rows:
        out.append('| ' + ' | '.join(str(x) for x in r) + ' |')
    (BUGS / 'INDEX.md').write_text('\n'.join(out) + '\n')
    print(f"wrote {BUGS / 'INDEX.md'} with {len(rows)} rows")

if __name__ == '__main__':
    main()
