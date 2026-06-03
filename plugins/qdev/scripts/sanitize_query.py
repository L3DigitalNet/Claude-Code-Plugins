# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Deterministic egress sanitizer for the qdev grounding skill (D2).

Pure, no network. The skill pipes any outbound payload (a light-path query or
the medium-path handoff) to this script over stdin before any external call or
Agent dispatch, then acts on the JSON contract printed here.
"""
from __future__ import annotations

import json
import re
import sys

_PROVIDERS = ("brave", "context7", "tavily", "serper")

# Tier 1: sensitive data is removed from safe_query and triggers approval.
_SENSITIVE_PATTERNS: list[tuple[str, re.Pattern[str]]] = [
    (
        "secret:pem",
        re.compile(
            r"-----BEGIN [A-Z ]*PRIVATE KEY-----.*?-----END [A-Z ]*PRIVATE KEY-----",
            re.DOTALL,
        ),
    ),
    ("secret:openai-key", re.compile(r"sk-[A-Za-z0-9][A-Za-z0-9_\-]{18,}")),
    ("secret:github-token", re.compile(r"gh[pousr]_[A-Za-z0-9_.\-]{20,}")),
    ("secret:github-pat", re.compile(r"github_pat_[A-Za-z0-9_]{20,}")),
    ("secret:aws-access-key", re.compile(r"A(?:KIA|SIA)[0-9A-Z]{16}")),
    ("secret:google-key", re.compile(r"AIza[0-9A-Za-z_\-]{35}")),
    ("secret:slack-token", re.compile(r"(?:xox[baprs]|xapp|xwfp)-[0-9A-Za-z-]{10,}")),
    ("secret:jwt", re.compile(r"eyJ[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+")),
    ("secret:bearer", re.compile(r"(?i)bearer\s+[A-Za-z0-9._\-]{10,}")),
    (
        "secret:signed-url",
        re.compile(
            r"(?i)[?&](?:X-Amz-Signature|X-Amz-Credential|X-Amz-Security-Token|Signature|sig)=[^&\s]+"
        ),
    ),
    (
        # value capture is `.+` (to end of line, no DOTALL) — NOT `\S+`: a
        # spaced passphrase must be redacted whole, never just its first token.
        "secret:assignment",
        re.compile(r"(?i)(?:password|passwd|api[_-]?key|secret|token)\s*[=:]\s*.+"),
    ),
    (
        "customer:identifier",
        re.compile(r"(?i)(?:customer|account|client|acct|user)[ _-]?(?:id|no|number|uuid)\s*[=:]\s*.+"),
    ),
]

# Tier 2: private identifiers are stripped silently and do not trigger approval.
_IDENTIFIER_PATTERNS: list[tuple[str, re.Pattern[str]]] = [
    (
        "host:tailscale-ip",
        re.compile(r"\b100\.(?:6[4-9]|[7-9]\d|1[01]\d|12[0-7])\.\d{1,3}\.\d{1,3}\b"),
    ),
    ("path:home-dir", re.compile(r"/home/[^/\s]+(?:/\S*)?")),
    ("pii:email", re.compile(r"\b[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}\b")),
    ("host:internal", re.compile(r"\b(?:[a-z0-9\-]+\.)+(?:local|lan|internal|tailnet)\b", re.I)),
]

_CODE_CHARS = set("{};()=<>")
_CODE_KEYWORD_PATTERNS = [
    re.compile(r"^\s*(?:def|class)\s+\w+.*[:(]"),
    re.compile(r"^\s*(?:if|elif|else|for|while|try|except|with)\b.*:\s*$"),
    re.compile(r"^\s*import\s+[\w.]+(?:\s+as\s+\w+)?\s*$"),
    re.compile(r"^\s*from\s+[\w.]+\s+import\s+[\w.*,\s]+$"),
    re.compile(r"^\s*return(?:\s+[\w.\[\]\"'()]+)?\s*$"),
    re.compile(r"^\s*(?:public|private|protected|func|const|let|var|async|await|package|#include)\b"),
]
_YAML_KEYISH = re.compile(r"^\s*([a-z0-9_.-]+):\s+(.+?)\s*$")
_YAML_CONFIG_KEYS = {
    "api-key",
    "api_key",
    "args",
    "command",
    "database",
    "db",
    "host",
    "image",
    "mode",
    "name",
    "networks",
    "password",
    "passwd",
    "pool",
    "port",
    "secret",
    "secrets",
    "service",
    "token",
    "user",
    "username",
    "volumes",
}
_TRACE_HEADER = "Traceback (most recent call last):"
_EXCEPTION_GROUP_HEADER = "Exception Group Traceback (most recent call last):"
_EXCEPTION_SUMMARY = re.compile(r"^(?:[\w.]+)?(?:Error|Exception|Warning|Interrupt|Exit|ExceptionGroup)\b: .+")


def _is_code_line(line: str) -> bool:
    return (
        sum(c in _CODE_CHARS for c in line) >= 2
        or _is_code_keyword_line(line)
        or _is_yaml_config_line(line)
    )


def _is_code_keyword_line(line: str) -> bool:
    return any(pattern.match(line) for pattern in _CODE_KEYWORD_PATTERNS)


def _is_yaml_config_line(line: str) -> bool:
    match = _YAML_KEYISH.match(line)
    if not match:
        return False
    key = match.group(1)
    value = match.group(2)
    return key in _YAML_CONFIG_KEYS and len(value.split()) <= 3


def _trace_content(line: str) -> str:
    return line.strip().lstrip("+|- ")


def _is_trace_header(content: str) -> bool:
    return content.startswith(_TRACE_HEADER) or content.startswith(_EXCEPTION_GROUP_HEADER)


def _is_trace_noise(content: str) -> bool:
    return (
        content == ""
        or content.startswith("File ")
        or content.startswith("^")
        or set(content) <= {"-", "+"}
        or bool(re.match(r"^\d+\s+-+$", content))
        or bool(re.match(r"^[A-Za-z_][\w.]*\([^)]*\)$", content))
    )


def _is_trace_prefixed(line: str) -> bool:
    return line.startswith((" ", "\t", "|", "+", "-"))


def _collapse_tracebacks(text: str) -> tuple[str, bool]:
    lines = text.splitlines()
    out: list[str] = []
    collapsed = False
    in_tb = False

    for line in lines:
        content = _trace_content(line)
        if _is_trace_header(content):
            in_tb = True
            collapsed = True
            continue
        if in_tb:
            if _is_trace_header(content) or _is_trace_noise(content):
                continue
            if _EXCEPTION_SUMMARY.match(content):
                out.append(content)
                continue
            if _is_trace_prefixed(line):
                continue
            out.append(line)
            in_tb = False
            continue
        out.append(line)

    return "\n".join(out), collapsed


def _strip_code_excerpt(text: str) -> tuple[str, bool]:
    lines = text.splitlines()
    if sum(_is_code_line(line) for line in lines) < 6:
        return text, False

    stripped = ["[code removed]" if _is_code_line(line) else line for line in lines]
    return "\n".join(stripped), True


def _dedupe(labels: list[str]) -> list[str]:
    seen: set[str] = set()
    return [label for label in labels if not (label in seen or seen.add(label))]


def _sensitive_labels(text: str) -> list[str]:
    return [label for label, pattern in _SENSITIVE_PATTERNS if pattern.search(text)]


def sanitize(text: str) -> dict:
    dropped: list[str] = []
    flagged = False

    safe, tb_collapsed = _collapse_tracebacks(text)
    if tb_collapsed:
        dropped.append("trace:frames")

    labels = _sensitive_labels(safe)
    if labels:
        dropped.extend(labels)
        flagged = True

    safe, code_removed = _strip_code_excerpt(safe)
    if code_removed:
        dropped.append("proprietary:code-excerpt")
        flagged = True

    for label, pattern in _SENSITIVE_PATTERNS:
        if pattern.search(safe):
            safe = pattern.sub("[REDACTED]", safe)
            dropped.append(label)
            flagged = True

    for label, pattern in _IDENTIFIER_PATTERNS:
        if pattern.search(safe):
            safe = pattern.sub(f"<{label.split(':', 1)[0]}>", safe)
            dropped.append(label)

    allowed = not flagged
    return {
        "safe_query": safe.strip(),
        "dropped_fields": _dedupe(dropped),
        "provider_allowed": {provider: allowed for provider in _PROVIDERS},
        "requires_human_approval": flagged,
    }


def main(argv: list[str]) -> int:
    del argv
    print(json.dumps(sanitize(sys.stdin.read())))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
