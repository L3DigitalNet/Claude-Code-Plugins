#!/usr/bin/env bash
# commit-candidates.sh — git-ground-truth helper for the up-docs Step 6 commit offer.
# Pure git + python, so it runs wherever it is invoked: locally for the project repo,
# and ON the remote wiki LXC (CT 103) when piped over SSH —
#   ssh llm-wiki 'bash -s' snapshot /srv/workspaces/llm-wiki < this-script
# (the git -C <repo> below then runs against the CT's working tree).
# Surfaces paths CHANGED SINCE A BASELINE in a repo. It does NOT assert run-ownership
# (a hook/editor/other process could dirty a clean-baseline file too) — the orchestrator
# discloses each candidate's diff for explicit human approval (post-propagation-steps.md
# part (c)). git is the candidate surface; the human's diff review is the ownership guard.
#
# Subcommands:
#   snapshot    <repo>                  Print the repo's current dirty path set (one per line).
#   candidates  <repo> <baseline-file>  Print (dirty now) − (baseline paths) = changed since baseline.
#   fingerprint <repo> <path>           Stable content+status fingerprint for ONE candidate path
#                                       (captured at disclosure, re-checked before staging).
set -euo pipefail
PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null) \
  || { echo "python3 not found" >&2; exit 1; }

# Emit NUL-safe dirty paths for the repo, one per line. Rename/copy records (R/C) carry
# the OLD path in the following NUL field; we keep the NEW path and skip the old one.
# --no-optional-locks: `git status` may otherwise refresh/write the index; a read-only
# candidate-surfacing helper must not mutate git metadata before user consent (CR-004).
# --untracked-files=all: without it git collapses a NEW untracked directory to a single
# `?? dir/` entry; the wiki propagator can Write a new page into a new dir, and we must
# surface (and later fingerprint/stage) the individual FILE, not the directory (CR-001).
dirty_paths() {
  git --no-optional-locks --literal-pathspecs -C "$1" status --porcelain=v1 -z --untracked-files=all | "$PYTHON" -c '
import sys
data = sys.stdin.buffer.read().split(b"\0")
i = 0
while i < len(data):
    rec = data[i]
    if not rec:
        i += 1; continue
    xy, path = rec[:2], rec[3:]
    i += 2 if xy[:1] in (b"R", b"C") else 1
    sys.stdout.buffer.write(path + b"\n")   # raw bytes: any filename byte sequence survives
'
}

case "${1:-}" in
  snapshot)
    dirty_paths "${2:?usage: snapshot <repo>}"
    ;;
  candidates)
    repo="${2:?usage: candidates <repo> <baseline-file>}"
    baseline="${3:?usage: candidates <repo> <baseline-file>}"
    # set difference on exact path lines (doc paths contain no newlines in practice; non-newline bytes incl. non-UTF-8 survive via raw-byte emission + LC_ALL=C)
    LC_ALL=C comm -23 <(dirty_paths "$repo" | LC_ALL=C sort -u) <(LC_ALL=C sort -u "$baseline")
    ;;
  fingerprint)
    repo="${2:?usage: fingerprint <repo> <path>}"
    path="${3:?usage: fingerprint <repo> <path>}"
    # Stable content+status fingerprint for ONE candidate path. Captured at disclosure and
    # re-checked immediately before staging (CR-001): if the worktree content changes after
    # the user approved the shown diff — even under the same path/status — the fingerprint
    # differs, and the offer must re-disclose instead of staging undisclosed content.
    if [ -d "$repo/$path" ]; then
      echo "ERROR: candidate '$path' is a directory — candidates must be per-file (re-run with --untracked-files=all)" >&2
      exit 3   # fail closed: never fingerprint/stage a whole directory (CR-001)
    fi
    # --literal-pathspecs: a candidate name with pathspec magic (`*`, `?`, `[`, `:(...)`) must be
    # taken literally, never as a pattern, by status/hash-object/add (CR-NEW-004).
    xy=$(git --no-optional-locks --literal-pathspecs -C "$repo" status --porcelain=v1 --untracked-files=all -- "$path" | cut -c1-2)
    if [ -e "$repo/$path" ]; then
      blob=$(git --literal-pathspecs -C "$repo" hash-object -- "$path")
      mode=$(stat -c '%a' "$repo/$path" 2>/dev/null || echo '-')   # include file mode: a post-disclosure
    else                                                            # chmod (exec bit) changes the fingerprint
      blob="DELETED"; mode='-'
    fi
    printf '%s:%s:%s\n' "${xy:-??}" "$mode" "$blob"
    ;;
  *)
    echo "usage: commit-candidates.sh {snapshot <repo> | candidates <repo> <baseline-file> | fingerprint <repo> <path>}" >&2
    exit 2
    ;;
esac
