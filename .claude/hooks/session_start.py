#!/usr/bin/env python3
"""
Canonical SessionStart hook (handoff system v3.0).

Tracked source: agent-configs/global/claude/hooks/session_start.py. Installed into
each Claude-managed repo as a byte-identical copy by scripts/install-globals.sh and
verified by hash by scripts/validate-layout.sh. Do NOT hand-edit the per-repo copy:
divergent copies were the 2026-05-29 hook-drift finding this version eliminates.

Emits lean startup context (docs/state.md + git branch/log/status + pointers) via
hookSpecificOutput.additionalContext. Self-budget <=4096 bytes, well under the
platform's 10,000-char output cap.

v3.0 fixes over the drifted per-repo copies:
- Resolves the project root explicitly ($CLAUDE_PROJECT_DIR -> stdin `cwd` -> ".")
  instead of assuming the process cwd is the repo root. A SessionStart hook is not
  guaranteed to run from the project root.
- Truncates docs/state.md by *bytes* on a UTF-8 boundary (never splits a multibyte
  character), not by character count.
- Truncation is not silent: it appends a one-line note to additionalContext.

Exit codes:
  0 — always. Errors are embedded in additionalContext as "(unavailable)"/"(failed)"
      markers so a hook bug never blocks session start.
"""
import json
import os
import subprocess
import sys
import traceback
from pathlib import Path

STATE_REL = "docs/state.md"
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


def read_state(root: Path) -> str:
    state_file = root / STATE_REL
    try:
        if not state_file.exists():
            return "(no docs/state.md — repo may not be migrated)"
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
            text
            + f"\n\n... state.md truncated at {MAX_STATE_BYTES} bytes "
            "— route long-lived content out"
        )
    except Exception as exc:
        return f"(failed to read docs/state.md: {exc})"


def run(cmd: list[str], root: Path) -> str:
    try:
        return subprocess.check_output(
            cmd, cwd=str(root), text=True, stderr=subprocess.DEVNULL, timeout=5
        ).strip()
    except Exception:
        return ""


def working_tree(root: Path) -> str:
    out = run(["git", "status", "--short"], root)
    if not out:
        return "(clean)"
    lines = out.splitlines()
    if len(lines) > MAX_STATUS_LINES:
        return "\n".join(lines[:MAX_STATUS_LINES]) + \
               f"\n... +{len(lines) - MAX_STATUS_LINES} more"
    return out


def build_context() -> str:
    root = project_root()
    branch = run(["git", "rev-parse", "--abbrev-ref", "HEAD"], root) or "(unknown)"
    commits = run(["git", "log", "--oneline", "-5", "--no-color"], root) \
        or "(git log unavailable)"
    return (
        "=== SESSION START CONTEXT ===\n\n"
        f"## Branch\n{branch}\n\n"
        f"## State (docs/state.md)\n{read_state(root)}\n\n"
        f"## Last 5 commits\n{commits}\n\n"
        f"## Working tree\n{working_tree(root)}\n\n"
        "## Pointers (read as needed)\n"
        "- docs/deployed.md — deployment truth\n"
        "- docs/architecture.md — system graph\n"
        "- docs/conventions.md — pattern library\n"
        "- docs/credentials.md — credential references (OpenBao paths)\n"
        "- docs/specs-plans.md — specs/plans pointer table\n"
        "- docs/bugs/ — bug KB (grep by service or tag)\n"
        "- docs/sessions/ — session log (grep by date)\n\n"
        "=== END ==="
    )


def main() -> None:
    try:
        ctx = build_context()
    except Exception:
        # Last-resort guard so a hook bug never blocks session start.
        ctx = "(session_start.py failed: " + traceback.format_exc(limit=1) + ")"
    output = {
        "hookSpecificOutput": {
            "hookEventName": "SessionStart",
            "additionalContext": ctx,
        }
    }
    print(json.dumps(output))
    sys.exit(0)


if __name__ == "__main__":
    main()
