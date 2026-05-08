#!/usr/bin/env python3
"""Helper for capture-transcript.sh — redact a PostToolUse JSON payload from
stdin, write one JSONL entry to argv[1], or fail open on any error.

Not invoked directly. Sibling to capture-transcript.sh; lives next to it
because mixing inline Python heredoc with stdin-piped JSON in one bash
script causes the heredoc to override stdin (heredoc-vs-pipe precedence)
and silently drop the data.
"""
from __future__ import annotations
import json
import re
import sys

if len(sys.argv) != 2:
    sys.exit(0)

LOG_PATH = sys.argv[1]
REDACT = "[REDACTED]"

# Compile-once secret patterns. Each captures the prefix in group 1 so we
# replace just the secret value, leaving diagnostic context.
SECRET_PATTERNS = [
    re.compile(r'(Bearer\s+)([A-Za-z0-9._\-]{20,})', re.IGNORECASE),
    re.compile(r'(BAO_TOKEN\s*[=:]\s*)([^\s\'"&;]+)', re.IGNORECASE),
    re.compile(r'(password\s*[=:]\s*)([^\s\'"&;]{4,})', re.IGNORECASE),
    re.compile(r'(token\s*[=:]\s*)([^\s\'"&;]{8,})', re.IGNORECASE),
    re.compile(r'(api[_-]?key\s*[=:]\s*)([^\s\'"&;]{8,})', re.IGNORECASE),
    re.compile(r'(?<![A-Za-z0-9])(gh[ps]_)([A-Za-z0-9]{36,})'),
    # Anthropic API keys: sk-ant-<version>-<base64url-secret>; separator is hyphen, not underscore.
    # Pattern carried from the research report had `_` as group-1 terminator — would silently
    # miss real keys (verified against documented format: sk-ant-api03-...). Fixed to `-`.
    re.compile(r'(?<![A-Za-z0-9])(sk-ant-[a-zA-Z0-9-]+-)([A-Za-z0-9_\-]{20,})'),
    re.compile(r'(?<![A-Za-z0-9])(AKIA)([A-Z0-9]{16})'),
    re.compile(r'(aws_secret(?:_access)?_key\s*[=:]\s*)([^\s\'"&;]+)', re.IGNORECASE),
]


def redact(s):
    if not isinstance(s, str):
        return s
    for pat in SECRET_PATTERNS:
        s = pat.sub(lambda m: m.group(1) + REDACT, s)
    return s


try:
    data = json.loads(sys.stdin.read())
except Exception:
    sys.exit(0)  # fail open

# tool_response can be a string OR an object with .output / .isError
resp = data.get("tool_response", {})
if isinstance(resp, dict):
    output = resp.get("output", "") or ""
    is_error = bool(resp.get("isError", False))
else:
    output = str(resp)
    is_error = False

# Truncate output to 4 KiB before redaction (cheap; redaction would be slower on huge logs)
output = output[:4096]

entry = {
    "session_id": data.get("session_id", ""),
    "tool_use_id": data.get("tool_use_id", ""),
    "tool_name": data.get("tool_name", ""),
    "command": redact(data.get("tool_input", {}).get("command", "")),
    "output": redact(output),
    "is_error": is_error,
    "agent_id": data.get("agent_id", ""),
    "agent_type": data.get("agent_type", ""),
}

try:
    with open(LOG_PATH, "a") as f:
        f.write(json.dumps(entry) + "\n")
except Exception:
    sys.exit(0)
