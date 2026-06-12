#!/usr/bin/env bash
set -euo pipefail

# Standard-sync check: this plugin copy-adopts the project-standards
# python-tooling bundle, and copies drift silently when the standard moves.
# Two layers of protection:
#   1. Pin freshness — fail when the standards repo has commits past the
#      sync pin recorded in SKILL.md for the python standards paths.
#   2. Byte parity — fail when a template no longer matches its canonical
#      adopt-bundle artifact.
# Skips cleanly when the standards checkout is unavailable (CI, consumers).

plugin_root="$(cd "$(dirname "$0")/.." && pwd)"
std_repo="${PROJECT_STANDARDS_DIR:-$HOME/projects/project-standards}"

if [[ ! -d "$std_repo/.git" ]]; then
  echo "standard-sync: SKIP — project-standards checkout not found at $std_repo" >&2
  exit 0
fi

skill_md="$plugin_root/skills/uv-strict-python/SKILL.md"

# The SKILL.md sync-pin line names the tooling pin first, the coding pin second.
mapfile -t pins < <(grep -oP '(?<=commit `)[0-9a-f]{7,40}(?=`)' "$skill_md" | head -2)
if [[ ${#pins[@]} -lt 2 ]]; then
  echo "standard-sync: FAIL — could not parse sync-pin commits from SKILL.md" >&2
  exit 1
fi
tooling_pin="${pins[0]}"
coding_pin="${pins[1]}"

fail=0

check_pin() {
  local pin="$1" label="$2"
  shift 2
  if ! git -C "$std_repo" cat-file -e "${pin}^{commit}" 2>/dev/null; then
    echo "standard-sync: FAIL — $label pin $pin not found locally (git -C $std_repo fetch?)" >&2
    fail=1
    return
  fi
  local moved
  moved="$(git -C "$std_repo" log --oneline "${pin}..HEAD" -- "$@")"
  if [[ -n "$moved" ]]; then
    echo "standard-sync: FAIL — $label standard moved past pin $pin:" >&2
    echo "$moved" >&2
    echo "  Re-sync the plugin content and bump the SKILL.md sync pin." >&2
    fail=1
  fi
}

check_pin "$tooling_pin" "python-tooling" \
  standards/python-tooling \
  src/project_standards/bundles/python-tooling \
  src/project_standards/bundles/_shared
check_pin "$coding_pin" "python-coding" \
  standards/python-coding

# Byte parity: plugin templates against the canonical adopt-bundle artifacts.
bundle="$std_repo/src/project_standards/bundles/python-tooling"
shared="$std_repo/src/project_standards/bundles/_shared"
templates="$plugin_root/skills/uv-strict-python/templates"

declare -A parity=(
  ["$templates/check.py"]="$bundle/check.py"
  ["$templates/check.yml"]="$bundle/check.yml"
  ["$templates/python-version"]="$bundle/python-version"
  ["$templates/pyproject.python-tooling.toml"]="$bundle/pyproject.python-tooling.toml"
  ["$templates/editorconfig"]="$shared/editorconfig"
  ["$templates/vscode-extensions.json"]="$shared/vscode-extensions.json"
)

for plugin_file in "${!parity[@]}"; do
  canonical="${parity[$plugin_file]}"
  if [[ ! -f "$canonical" ]]; then
    echo "standard-sync: FAIL — canonical artifact missing: $canonical" >&2
    fail=1
  elif ! diff -q "$plugin_file" "$canonical" >/dev/null; then
    echo "standard-sync: FAIL — template diverges from bundle: ${plugin_file#"$plugin_root"/} vs ${canonical#"$std_repo"/}" >&2
    fail=1
  fi
done

if [[ $fail -ne 0 ]]; then
  exit 1
fi
echo "standard-sync: OK (pins $tooling_pin / $coding_pin; ${#parity[@]} templates byte-identical)"
