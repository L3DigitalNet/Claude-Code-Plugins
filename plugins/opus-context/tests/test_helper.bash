#!/usr/bin/env bash
# Shared bats helpers for opus-context tests.

# TEST-003: bypass workstation's global ~/.gitconfig (core.hooksPath GH007 noreply
# regex hook + commit.gpgsign + tag.gpgsign) so tmpdir test repos don't silently
# reject test@*.com commits. Defense-in-depth: no git ops in current tests but
# applied so future additions don't regress. See docs/conventions.md TEST-003.
export GIT_CONFIG_GLOBAL=/dev/null
export GIT_CONFIG_NOSYSTEM=1

PLUGIN_ROOT="${PLUGIN_ROOT:-$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)}"

# Build a minimal fake plugin tree in BATS_TEST_TMPDIR with the real
# session-start.sh copied in and a controllable SKILL.md.
# Echoes the path to the cloned session-start.sh so tests can invoke it.
make_fake_plugin() {
  local skill_body="${1:-default body}"
  local include_frontmatter="${2:-yes}"
  local fake_root="$BATS_TEST_TMPDIR/fake-plugin"
  mkdir -p "$fake_root/scripts" "$fake_root/skills/deep-context"
  cp "$PLUGIN_ROOT/scripts/session-start.sh" "$fake_root/scripts/"
  if [[ "$include_frontmatter" == "yes" ]]; then
    cat > "$fake_root/skills/deep-context/SKILL.md" <<EOF
---
name: deep-context
description: test description
---

$skill_body
EOF
  else
    printf '%s\n' "$skill_body" > "$fake_root/skills/deep-context/SKILL.md"
  fi
  echo "$fake_root/scripts/session-start.sh"
}

# Same as make_fake_plugin but does NOT create SKILL.md (tests the missing-file path).
make_fake_plugin_no_skill() {
  local fake_root="$BATS_TEST_TMPDIR/fake-plugin"
  mkdir -p "$fake_root/scripts" "$fake_root/skills/deep-context"
  cp "$PLUGIN_ROOT/scripts/session-start.sh" "$fake_root/scripts/"
  echo "$fake_root/scripts/session-start.sh"
}
