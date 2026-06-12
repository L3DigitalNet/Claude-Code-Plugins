#!/usr/bin/env bash
set -euo pipefail

# Parse every fenced toml/json/yaml block in the skill markdown with the
# matching parser — agents copy these blocks verbatim, so a typo here
# becomes a broken pyproject.toml in a user's repo.

plugin_root="$(cd "$(dirname "$0")/.." && pwd)"

python3 - "$plugin_root/skills/uv-strict-python" <<'PY'
import json
import pathlib
import re
import sys
import tomllib

try:
    import yaml  # type: ignore[import-untyped]
except ImportError:  # PyYAML is optional — yaml blocks are skipped without it
    yaml = None

root = pathlib.Path(sys.argv[1])
fence = re.compile(r"^```(toml|json|yaml)\n(.*?)^```$", re.M | re.S)
failures: list[str] = []
checked = 0
skipped = 0

for md in sorted(root.rglob("*.md")):
    for lang, body in fence.findall(md.read_text(encoding="utf-8")):
        if lang == "yaml" and yaml is None:
            skipped += 1
            continue
        checked += 1
        try:
            if lang == "toml":
                tomllib.loads(body)
            elif lang == "json":
                json.loads(body)
            else:
                yaml.safe_load(body)
        except Exception as exc:  # report every parse failure, whatever the parser raises
            failures.append(f"{md.relative_to(root)}: {lang} block: {exc}")

note = f" ({skipped} yaml skipped — PyYAML unavailable)" if skipped else ""
print(f"fenced-blocks: {checked} parsed OK{note}" if not failures else f"fenced-blocks: {len(failures)} FAILED")
if failures:
    print("\n".join(failures), file=sys.stderr)
    sys.exit(1)
PY
