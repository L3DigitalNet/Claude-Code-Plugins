#!/usr/bin/env bats
# auto-build-plugins.bats — [P2] Scope Fidelity (build all N affected plugins)
# Hook reads JSON on stdin, routes only on `git commit`, builds via `npm run build`.
load test_helper

setup() {
  SCRIPT="$PLUGIN_ROOT/scripts/auto-build-plugins.sh"
  WORK=$(make_git_repo)
  # Two plugins under plugins/, each with a 'build' script and a staged TS file.
  for p in sampleA sampleB; do
    mkdir -p "$WORK/plugins/$p/src"
    printf '{"scripts":{"build":"echo built"}}' > "$WORK/plugins/$p/package.json"
    echo "// stub" > "$WORK/plugins/$p/src/index.ts"
  done
  git -C "$WORK" add . >/dev/null
}

# Helper: invoke the hook with composed JSON via stdin tmpfile.
invoke_hook() {
  local cmd="$1"
  local in="$BATS_TEST_TMPDIR/in.json"
  python3 -c "import json,sys; print(json.dumps({'tool_input':{'command':sys.argv[1]},'cwd':sys.argv[2]}))" \
    "$cmd" "$WORK" > "$in"
  bash "$SCRIPT" < "$in"
}

@test "non-commit command (ls) is a no-op (AB1)" {
  run invoke_hook "ls"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "git commit with no staged TS files is a no-op (AB2)" {
  git -C "$WORK" reset >/dev/null 2>&1
  echo "doc" > "$WORK/README.md"
  git -C "$WORK" add README.md >/dev/null
  run invoke_hook "git commit -m x"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "[P2] git commit with N staged TS files builds all N plugins (AB3)" {
  path_prepend_stubs
  NPM_STUB_MODE=success run invoke_hook "git commit -m x"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Auto-building sampleA"* ]]
  [[ "$output" == *"Auto-building sampleB"* ]]
  [[ "$output" == *"2 plugin(s)"* ]]
}

@test "duplicate TS files in same plugin → built once (AB4 deduplication)" {
  path_prepend_stubs
  echo "// extra" > "$WORK/plugins/sampleA/src/extra.ts"
  echo "// more"  > "$WORK/plugins/sampleA/src/more.ts"
  git -C "$WORK" reset >/dev/null
  git -C "$WORK" add plugins/sampleA/src/ >/dev/null
  NPM_STUB_MODE=success run invoke_hook "git commit -m x"
  [ "$status" -eq 0 ]
  count=$(grep -c "Auto-building sampleA" <<<"$output" || true)
  [ "$count" -eq 1 ]
}

@test "[P3] failed npm build emits decision:block JSON + exit 2 (AB5)" {
  path_prepend_stubs
  NPM_STUB_MODE=fail run invoke_hook "git commit -m x"
  [ "$status" -eq 2 ]
  [[ "$output" == *'"decision":"block"'* ]]
  [[ "$output" == *"Build failed for"* ]]
}

@test "plugin without 'build' script is skipped silently (AB6)" {
  path_prepend_stubs
  for p in sampleA sampleB; do
    printf '{"scripts":{"start":"echo hi"}}' > "$WORK/plugins/$p/package.json"
  done
  git -C "$WORK" add . >/dev/null
  NPM_STUB_MODE=success run invoke_hook "git commit -m x"
  [ "$status" -eq 0 ]
  [[ "$output" != *"Auto-building"* ]]
}

@test "non-plugins TS file does not trigger build (AB7 path-pattern guard)" {
  path_prepend_stubs
  mkdir -p "$WORK/notplugins"
  echo "x" > "$WORK/notplugins/foo.ts"
  git -C "$WORK" add notplugins/foo.ts >/dev/null
  NPM_STUB_MODE=success run invoke_hook "git commit -m x"
  [ "$status" -eq 0 ]
  # sampleA/sampleB src/*.ts are also still staged (from setup) so they DO build —
  # the assertion that matters: the hook does NOT mention 'notplugins' anywhere.
  [[ "$output" != *"notplugins"* ]]
}
