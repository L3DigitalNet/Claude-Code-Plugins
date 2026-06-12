#!/usr/bin/env python3
"""
Canonical SessionStart hook (handoff system v3.2).

Tracked source: agent-configs/global/hooks/session_start.py. Installed into
each Claude-managed repo as a byte-identical copy by scripts/handoff/install-globals.sh and
verified by hash by scripts/handoff/validate-layout.sh. Do NOT hand-edit the per-repo copy:
divergent copies were the 2026-05-29 hook-drift finding this version eliminates.

Emits lean startup context (docs/state.md + git branch/log/status + pointers) as JSON
`additionalContext` (Claude) or plain text on stdout (Codex — a documented context path
that avoids render bug #16933; `systemMessage` is rejected per official docs as a UI warning,
not context). Harness detected by `$CLAUDE_PROJECT_DIR` presence; the root is canonicalized
via `git rev-parse --show-toplevel`. Self-budget <=4096 bytes, well under the
platform's 10,000-char output cap.

v3.0 fixes over the drifted per-repo copies:
- Resolves the project root explicitly ($CLAUDE_PROJECT_DIR -> stdin `cwd` -> ".")
  instead of assuming the process cwd is the repo root. A SessionStart hook is not
  guaranteed to run from the project root.
- Truncates docs/state.md by *bytes* on a UTF-8 boundary (never splits a multibyte
  character), not by character count.
- Truncation is not silent: it appends a one-line note to additionalContext.

v3.2 additions:
- Harness-branched output: JSON additionalContext for Claude, plain stdout for Codex.
- git_toplevel() canonicalizes a subdir launch cwd to the worktree root so state.md
  is always found regardless of which directory Codex was started from.

Exit codes:
  0 — always. Errors are embedded in context output as "(unavailable)"/"(failed)"
      markers so a hook bug never blocks session start.
"""

import json
import os
import subprocess
import sys
import traceback
from pathlib import Path

STATE_CANDIDATES = ("docs/handoff/state.md", "docs/state.md")
MAX_STATE_BYTES = 2048
MAX_STATUS_LINES = 10


def project_root() -> Path:
    """Resolve the repo root the hook should report on.

    Precedence matches the Claude Code hooks contract: CLAUDE_PROJECT_DIR is
    exported to the hook process and points at the project root; the SessionStart
    stdin payload also carries a `cwd` field. Fall back to "." only when neither is
    available. stdin is consulted only when env is unset AND stdin is piped (not a
    TTY), so a manual `python3 session_start.py | json.tool` check never blocks
    waiting for terminal input.
    """
    env = os.environ.get("CLAUDE_PROJECT_DIR")
    if env:
        return Path(env)
    try:
        if not sys.stdin.isatty():
            data = json.loads(sys.stdin.read() or "{}")
            cwd = data.get("cwd")
            if cwd:
                return Path(cwd)
    except Exception:
        pass
    return Path(".")


def resolve_state(root: Path) -> tuple[Path | None, str]:
    """Locate state.md under dual-read preference and report its handoff dir.

    Prefers docs/handoff/ (post-migration) over docs/ (legacy). The returned base
    ("docs/handoff" or "docs") prefixes the pointer block so emitted pointers
    always match the repo's real layout. When neither exists, default the base to
    "docs/handoff" (the canonical target) so a fresh/unmigrated repo still points
    operators at the intended location.
    """
    for rel in STATE_CANDIDATES:
        candidate = root / rel
        if candidate.exists():
            return candidate, str(Path(rel).parent)
    return None, "docs/handoff"


def read_state_text(state_file: Path | None) -> str:
    if state_file is None:
        return "(no state.md — repo may not be migrated)"
    try:
        raw = state_file.read_bytes()
        if len(raw) <= MAX_STATE_BYTES:
            return raw.decode("utf-8", errors="replace")
        # Byte-accurate truncation: keep MAX_STATE_BYTES bytes, then drop a trailing
        # partial UTF-8 sequence (a char is at most 4 bytes) so we never split one.
        chunk = raw[:MAX_STATE_BYTES]
        text = None
        for back in range(4):
            try:
                text = chunk[: len(chunk) - back].decode("utf-8")
                break
            except UnicodeDecodeError:
                continue
        if text is None:
            text = chunk.decode("utf-8", errors="replace")
        return (
            text + f"\n\n... state.md truncated at {MAX_STATE_BYTES} bytes "
            "— route long-lived content out"
        )
    except Exception as exc:
        return f"(failed to read {state_file}: {exc})"


def run(cmd: list[str], root: Path) -> str:
    try:
        return subprocess.check_output(
            cmd, cwd=str(root), text=True, stderr=subprocess.DEVNULL, timeout=5
        ).strip()
    except Exception:
        return ""


def git_toplevel(start: Path) -> Path:
    """Canonicalize a launch dir to its git worktree root.

    Codex passes its launch `cwd` (which may be a subdirectory) on stdin; Claude's
    $CLAUDE_PROJECT_DIR is already the root. Resolving the worktree root makes the
    state read correct regardless of which subdir Codex was started from. Falls back
    to `start` when git is unavailable or `start` is not inside a worktree.
    """
    out = run(["git", "rev-parse", "--show-toplevel"], start)
    return Path(out) if out else start


def detect_harness() -> str:
    """Claude exports $CLAUDE_PROJECT_DIR to the hook; Codex does not (it has no
    env-var equivalent). Presence is the harness signal that drives the output
    framing below."""
    return "claude" if os.environ.get("CLAUDE_PROJECT_DIR") else "codex"


def emit(ctx: str, harness: str) -> None:
    """Print the SessionStart payload in the channel each harness reads as context.

    Claude: JSON hookSpecificOutput.additionalContext (proven, silent). Codex: the
    raw context text on stdout — a *documented* SessionStart context path that
    sidesteps the additionalContext-JSON visible-render bug (openai/codex#16933).
    systemMessage is NOT used: official Codex docs class it as a UI/event warning,
    not a context channel.
    """
    if harness == "codex":
        print(ctx)
    else:
        print(
            json.dumps(
                {"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": ctx}}
            )
        )


def working_tree(root: Path) -> str:
    out = run(["git", "status", "--short"], root)
    if not out:
        return "(clean)"
    lines = out.splitlines()
    if len(lines) > MAX_STATUS_LINES:
        return (
            "\n".join(lines[:MAX_STATUS_LINES])
            + f"\n... +{len(lines) - MAX_STATUS_LINES} more"
        )
    return out


def build_context() -> str:
    root = git_toplevel(project_root())
    state_file, base = resolve_state(root)
    branch = run(["git", "rev-parse", "--abbrev-ref", "HEAD"], root) or "(unknown)"
    commits = (
        run(["git", "log", "--oneline", "-5", "--no-color"], root)
        or "(git log unavailable)"
    )
    return (
        "=== SESSION START CONTEXT ===\n\n"
        f"## Branch\n{branch}\n\n"
        f"## State ({base}/state.md)\n{read_state_text(state_file)}\n\n"
        f"## Last 5 commits\n{commits}\n\n"
        f"## Working tree\n{working_tree(root)}\n\n"
        "## Pointers (read as needed)\n"
        f"- {base}/deployed.md — deployment truth\n"
        f"- {base}/architecture.md — system graph\n"
        f"- {base}/conventions.md — pattern library\n"
        f"- {base}/credentials.md — credential references (OpenBao paths)\n"
        f"- {base}/specs-plans.md — specs/plans pointer table\n"
        f"- {base}/bugs/ — bug KB (grep by service or tag)\n"
        f"- {base}/sessions/ — session log (grep by date)\n\n"
        "=== END ==="
    )


def main() -> None:
    harness = detect_harness()
    try:
        ctx = build_context()
    except Exception:
        # Last-resort guard so a hook bug never blocks session start.
        ctx = "(session_start.py failed: " + traceback.format_exc(limit=1) + ")"
    emit(ctx, harness)
    sys.exit(0)


if __name__ == "__main__":
    main()
