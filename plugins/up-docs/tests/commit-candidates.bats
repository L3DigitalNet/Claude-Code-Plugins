#!/usr/bin/env bats
# commit-candidates.bats — git-ground-truth candidate surfacing for the Step 6 commit offer.
bats_require_minimum_version 1.5.0
load helpers

setup() {
  setup_test_env   # exports SCRIPTS_DIR + GIT_CONFIG_GLOBAL=/dev/null + GIT_CONFIG_NOSYSTEM=1
                   # (TEST-003: neutralizes the global noreply-email hook + GPG signing so the
                   # temp-repo `git commit` below is not rejected/blocked — CR-NEW-002).
  REPO="$(mktemp -d)"
  git -C "$REPO" init -q
  git -C "$REPO" config user.email t@e.x
  git -C "$REPO" config user.name t
  echo base > "$REPO/tracked.md"
  git -C "$REPO" add tracked.md
  git -C "$REPO" commit -qm base
  BASE="$(mktemp)"
}
teardown() { teardown_test_env; rm -rf "$REPO" "$BASE"; }

@test "clean baseline: a newly written file is a candidate" {
  bash "$SCRIPTS_DIR/commit-candidates.sh" snapshot "$REPO" > "$BASE"   # empty
  echo new > "$REPO/written.md"
  run bash "$SCRIPTS_DIR/commit-candidates.sh" candidates "$REPO" "$BASE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"written.md"* ]]
}

@test "baseline-dirty different path is excluded from candidates" {
  echo pre > "$REPO/preexisting.md"                                     # dirty before baseline
  bash "$SCRIPTS_DIR/commit-candidates.sh" snapshot "$REPO" > "$BASE"
  echo new > "$REPO/written.md"
  run bash "$SCRIPTS_DIR/commit-candidates.sh" candidates "$REPO" "$BASE"
  [[ "$output" == *"written.md"* ]]
  [[ "$output" != *"preexisting.md"* ]]
}

@test "same-path collision (dirty at baseline AND written) is excluded" {
  echo pre >> "$REPO/tracked.md"                                        # tracked.md dirty at baseline
  bash "$SCRIPTS_DIR/commit-candidates.sh" snapshot "$REPO" > "$BASE"
  echo more >> "$REPO/tracked.md"                                       # written again this "run"
  run bash "$SCRIPTS_DIR/commit-candidates.sh" candidates "$REPO" "$BASE"
  [[ "$output" != *"tracked.md"* ]]
}

@test "path dirtied AFTER baseline is surfaced as a candidate (human approves)" {
  bash "$SCRIPTS_DIR/commit-candidates.sh" snapshot "$REPO" > "$BASE"
  echo a > "$REPO/written.md"
  echo z > "$REPO/unrelated.md"                                         # appeared post-baseline
  run bash "$SCRIPTS_DIR/commit-candidates.sh" candidates "$REPO" "$BASE"
  [[ "$output" == *"written.md"* ]]
  [[ "$output" == *"unrelated.md"* ]]   # surfaced; the template's per-path approval is the gate
}

@test "paths with spaces survive (NUL-safe parsing)" {
  bash "$SCRIPTS_DIR/commit-candidates.sh" snapshot "$REPO" > "$BASE"
  echo x > "$REPO/a b.md"
  run bash "$SCRIPTS_DIR/commit-candidates.sh" candidates "$REPO" "$BASE"
  [[ "$output" == *"a b.md"* ]]
}

@test "deleted and untracked files appear as candidates" {
  bash "$SCRIPTS_DIR/commit-candidates.sh" snapshot "$REPO" > "$BASE"
  rm "$REPO/tracked.md"                                                 # deletion
  echo u > "$REPO/untracked.md"                                         # untracked
  run bash "$SCRIPTS_DIR/commit-candidates.sh" candidates "$REPO" "$BASE"
  [[ "$output" == *"tracked.md"* ]]
  [[ "$output" == *"untracked.md"* ]]
}

@test "fingerprint changes when an approved path's content changes (CR-001)" {
  echo a > "$REPO/written.md"
  fp1=$(bash "$SCRIPTS_DIR/commit-candidates.sh" fingerprint "$REPO" written.md)
  echo b >> "$REPO/written.md"          # content mutated after "disclosure"
  fp2=$(bash "$SCRIPTS_DIR/commit-candidates.sh" fingerprint "$REPO" written.md)
  [ "$fp1" != "$fp2" ]
}

@test "fingerprint is stable when content is unchanged (CR-001)" {
  echo a > "$REPO/written.md"
  fp1=$(bash "$SCRIPTS_DIR/commit-candidates.sh" fingerprint "$REPO" written.md)
  fp2=$(bash "$SCRIPTS_DIR/commit-candidates.sh" fingerprint "$REPO" written.md)
  [ "$fp1" = "$fp2" ]
}

@test "nested untracked file under a new directory is surfaced per-file, not as the dir (CR-001)" {
  bash "$SCRIPTS_DIR/commit-candidates.sh" snapshot "$REPO" > "$BASE"
  mkdir -p "$REPO/wiki/newdir"
  echo page > "$REPO/wiki/newdir/page.md"          # propagator-style new draft page in a new dir
  run bash "$SCRIPTS_DIR/commit-candidates.sh" candidates "$REPO" "$BASE"
  [[ "$output" == *"wiki/newdir/page.md"* ]]        # the FILE is the candidate
  run bash -c "bash '$SCRIPTS_DIR/commit-candidates.sh' candidates '$REPO' '$BASE' | grep -xF 'wiki/newdir/'"
  [ "$status" -ne 0 ]                                # the bare directory is NOT a candidate line
}

@test "fingerprint fails closed on a directory candidate (CR-001)" {
  mkdir -p "$REPO/adir"
  run bash "$SCRIPTS_DIR/commit-candidates.sh" fingerprint "$REPO" adir
  [ "$status" -eq 3 ]
}

@test "candidate name with pathspec magic is handled literally (CR-NEW-004)" {
  bash "$SCRIPTS_DIR/commit-candidates.sh" snapshot "$REPO" > "$BASE"
  printf 'x' > "$REPO/star*.md"                    # a file literally named star*.md
  run bash "$SCRIPTS_DIR/commit-candidates.sh" candidates "$REPO" "$BASE"
  [[ "$output" == *'star*.md'* ]]
  run bash "$SCRIPTS_DIR/commit-candidates.sh" fingerprint "$REPO" 'star*.md'
  [ "$status" -eq 0 ]                               # literal, no pattern expansion or error
}

@test "fingerprint changes on a post-disclosure mode (exec-bit) change (CR-NEW-004)" {
  echo a > "$REPO/m.sh"
  fp1=$(bash "$SCRIPTS_DIR/commit-candidates.sh" fingerprint "$REPO" m.sh)
  chmod +x "$REPO/m.sh"
  fp2=$(bash "$SCRIPTS_DIR/commit-candidates.sh" fingerprint "$REPO" m.sh)
  [ "$fp1" != "$fp2" ]                              # mode is part of the fingerprint
}
