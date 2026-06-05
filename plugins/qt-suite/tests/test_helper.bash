#!/usr/bin/env bash
# TEST-003: bypass workstation's global ~/.gitconfig (core.hooksPath GH007 noreply
# regex hook + commit.gpgsign + tag.gpgsign) so tmpdir test repos don't silently
# reject test@*.com commits. Defense-in-depth: no git ops in current tests but
# applied so future additions don't regress. See docs/handoff/conventions.md TEST-003.
export GIT_CONFIG_GLOBAL=/dev/null
export GIT_CONFIG_NOSYSTEM=1

PLUGIN_ROOT="${PLUGIN_ROOT:-$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)}"
STUBS_DIR="$PLUGIN_ROOT/tests/fixtures/stubs"
path_prepend_stubs() { export PATH="$STUBS_DIR:$PATH"; }
