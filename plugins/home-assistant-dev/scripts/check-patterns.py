#!/usr/bin/env python3
"""Check for common anti-patterns in Home Assistant integrations.

Detects:
- Deprecated patterns (hass.data[DOMAIN], old imports)
- Blocking I/O in async code
- Deprecated syntax
- Common mistakes
"""
from __future__ import annotations

import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Callable

@dataclass
class Pattern:
    """Represents an anti-pattern to detect."""

    name: str
    pattern: re.Pattern[str]
    message: str
    severity: str = "warning"  # "error" or "warning"
    replacement: str | None = None
    skip_in_comments: bool = True


@dataclass
class Match:
    """Represents a pattern match."""

    file: Path
    line_num: int
    line: str
    pattern: Pattern


# Define anti-patterns to detect
PATTERNS: list[Pattern] = [
    # Storage patterns
    Pattern(
        name="hass.data[DOMAIN]",
        pattern=re.compile(r"hass\.data\s*\[\s*DOMAIN\s*\]"),
        message="Use entry.runtime_data instead of hass.data[DOMAIN]",
        replacement="entry.runtime_data",
        severity="warning",
    ),
    Pattern(
        name="hass.data.setdefault",
        pattern=re.compile(r"hass\.data\.setdefault\s*\(\s*DOMAIN"),
        message="Use entry.runtime_data instead of hass.data.setdefault(DOMAIN, ...)",
        severity="warning",
    ),
    # Old ServiceInfo imports (deprecated in 2025.1, removed in 2026.2)
    Pattern(
        name="old-zeroconf-import",
        pattern=re.compile(r"from homeassistant\.components\.zeroconf import.*ServiceInfo"),
        message="Import ZeroconfServiceInfo from homeassistant.helpers.service_info.zeroconf (changed in 2025.1)",
        severity="warning",
    ),
    Pattern(
        name="old-ssdp-import",
        pattern=re.compile(r"from homeassistant\.components\.ssdp import.*ServiceInfo"),
        message="Import SsdpServiceInfo from homeassistant.helpers.service_info.ssdp (changed in 2025.1)",
        severity="warning",
    ),
    Pattern(
        name="old-dhcp-import",
        pattern=re.compile(r"from homeassistant\.components\.dhcp import.*ServiceInfo"),
        message="Import DhcpServiceInfo from homeassistant.helpers.service_info.dhcp (changed in 2025.1)",
        severity="warning",
    ),
    Pattern(
        name="old-usb-import",
        pattern=re.compile(r"from homeassistant\.components\.usb import.*ServiceInfo"),
        message="Import UsbServiceInfo from homeassistant.helpers.service_info.usb (changed in 2025.1)",
        severity="warning",
    ),
    # Blocking I/O
    Pattern(
        name="blocking-requests",
        pattern=re.compile(r"\brequests\.(get|post|put|delete|patch|head)\s*\("),
        message="Use aiohttp instead of blocking requests library",
        severity="error",
    ),
    Pattern(
        name="blocking-sleep",
        pattern=re.compile(r"\btime\.sleep\s*\("),
        message="Use asyncio.sleep instead of blocking time.sleep",
        severity="error",
    ),
    # Intentionally narrow: only flags open(...).read(...) chained on one line.
    # The argument class allows one level of nested parens so calls like
    # open(os.path.join(a, b)).read() still match (a bare [^)]+ stopped at the
    # first ")" and missed the trailing .read). It deliberately does NOT catch
    # the f = open(...) / f.read() split-across-lines form to avoid the false
    # positives that a bare "open(" would produce on non-async/sync setup code.
    Pattern(
        name="blocking-open",
        pattern=re.compile(r"\bopen\s*\((?:[^()]|\([^()]*\))+\)\.read\s*\("),
        message="Use aiofiles or hass.async_add_executor_job for file I/O",
        severity="warning",
    ),
    Pattern(
        name="blocking-urlopen",
        pattern=re.compile(r"\burllib\.request\.urlopen\s*\("),
        message="Use aiohttp instead of blocking urllib",
        severity="error",
    ),
    # Deprecated type syntax (Python 3.9+ has native generics)
    # Leading (?<![.\w]) anchors to a typing-alias context: it rejects dotted
    # attribute access (foo.Set[...], module.List[...]) that \b would falsely
    # flag, since "." is a word boundary but not a deprecated typing import.
    Pattern(
        name="typing-List",
        pattern=re.compile(r"(?<![.\w])List\s*\["),
        message="Use list[] instead of List[] (Python 3.9+)",
        severity="warning",
    ),
    Pattern(
        name="typing-Dict",
        pattern=re.compile(r"(?<![.\w])Dict\s*\["),
        message="Use dict[] instead of Dict[] (Python 3.9+)",
        severity="warning",
    ),
    Pattern(
        name="typing-Optional",
        pattern=re.compile(r"(?<![.\w])Optional\s*\["),
        message="Use X | None instead of Optional[X] (Python 3.10+)",
        severity="warning",
    ),
    Pattern(
        name="typing-Union",
        pattern=re.compile(r"(?<![.\w])Union\s*\["),
        message="Use X | Y instead of Union[X, Y] (Python 3.10+)",
        severity="warning",
    ),
    Pattern(
        name="typing-Tuple",
        pattern=re.compile(r"(?<![.\w])Tuple\s*\["),
        message="Use tuple[] instead of Tuple[] (Python 3.9+)",
        severity="warning",
    ),
    Pattern(
        name="typing-Set",
        pattern=re.compile(r"(?<![.\w])Set\s*\["),
        message="Use set[] instead of Set[] (Python 3.9+)",
        severity="warning",
    ),
    # Deprecated async patterns
    Pattern(
        name="yield-from",
        pattern=re.compile(r"\byield\s+from\b"),
        message="Use 'await' instead of 'yield from' for coroutines",
        severity="warning",
    ),
    Pattern(
        name="asyncio-coroutine",
        pattern=re.compile(r"@asyncio\.coroutine"),
        message="Use 'async def' instead of @asyncio.coroutine decorator",
        severity="error",
    ),
    # Entity patterns (unique_id check moved to file-level checks below)
    # Config entry patterns
    Pattern(
        name="options-flow-init",
        pattern=re.compile(r"class\s+\w*OptionsFlow[^:]*:[^}]*def\s+__init__\s*\("),
        message="OptionsFlow __init__ is deprecated (HA 2025.12+), self.config_entry is auto-available",
        severity="warning",
    ),
    # Coordinator patterns
    Pattern(
        name="coordinator-no-generic",
        pattern=re.compile(r"class\s+\w+Coordinator\s*\(\s*DataUpdateCoordinator\s*\)"),
        message="DataUpdateCoordinator should have a generic type: DataUpdateCoordinator[YourDataType]",
        severity="warning",
    ),
    # Service registration patterns
    Pattern(
        name="service-in-setup-entry",
        pattern=re.compile(r"async_setup_entry[^}]*hass\.services\.async_register"),
        message="Services should be registered in async_setup, not async_setup_entry (IQS Bronze: action-setup)",
        severity="warning",
    ),
]


# File-level patterns checked once per file (not per-line)
FILE_LEVEL_CHECKS: list[tuple[str, Callable[[str], bool], str, str]] = [
    # (name, condition_fn, message, severity)
    # condition_fn returns True if the issue IS present
    (
        "missing-future-annotations",
        lambda content: (
            "from __future__ import annotations" not in content
            and re.search(r"\bdef\s+\w+\s*\([^)]*:\s*\w+", content) is not None
        ),
        "Add 'from __future__ import annotations' for modern type syntax",
        "warning",
    ),
    (
        "missing-unique-id",
        lambda content: (
            # Only flag concrete entity classes (inherit from platform entities),
            # not base entity classes (which inherit from CoordinatorEntity).
            # Base classes intentionally delegate unique_id to subclasses.
            re.search(
                r"class\s+\w+\([^)]*\b(?:Sensor|Switch|BinarySensor|Light|Cover|Climate|"
                r"Button|Number|Select|Fan|Lock|MediaPlayer|Vacuum|Event|Text|"
                r"Update|Image|Siren|Lawn[Mm]ower)Entity",
                content,
            ) is not None
            and not re.search(
                r"_attr_unique_id\s*=|self\.unique_id\s*=|def\s+unique_id\b"
                r"|async_set_unique_id\s*\(|unique_id\s*=",
                content,
            )
        ),
        "Entity class may be missing unique_id",
        "warning",
    ),
]


def _strip_inline_comment(line: str) -> str:
    """Remove a trailing ``#`` comment, ignoring ``#`` inside string literals.

    Walks the line tracking single/double quote state so a ``#`` that lives
    inside a string (e.g. ``url = "http://x#y"``) is preserved and only a real
    code comment is dropped. Returns the line up to the comment marker.
    """
    in_quote = ""  # the active quote char, or "" when outside a string
    escaped = False
    for idx, char in enumerate(line):
        if in_quote:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == in_quote:
                in_quote = ""
        elif char in ("'", '"'):
            in_quote = char
        elif char == "#":
            return line[:idx]
    return line


def _toggle_docstring(
    line: str, in_docstring: bool, delim: str
) -> tuple[bool, str, bool]:
    """Update triple-quote docstring state for one line.

    Args:
        line: The raw source line.
        in_docstring: Whether a triple-quoted block was already open.
        delim: The opening triple-quote (``\"\"\"`` or ``'''``) when open.

    Returns:
        (new_in_docstring, new_delim, line_in_docstring) where the last value
        is True when this line falls inside a docstring region and should be
        skipped by the per-line pattern checks.
    """
    # If a block is already open, this line is inside it; it stays inside
    # unless the closing delimiter appears.
    if in_docstring:
        if delim in line:
            return False, "", True
        return True, delim, True

    # Not currently open: detect a docstring that opens on this line.
    for candidate in ('"""', "'''"):
        first = line.find(candidate)
        if first == -1:
            continue
        # Single-line docstring (opens and closes on the same line) — treat the
        # whole line as a docstring region but leave state closed.
        if line.find(candidate, first + len(candidate)) != -1:
            return False, "", True
        # Opens a multi-line block that continues onto following lines.
        return True, candidate, True

    return False, "", False


def check_file(file_path: Path, patterns: list[Pattern]) -> list[Match]:
    """Check a file for anti-patterns.

    Args:
        file_path: Path to Python file
        patterns: List of patterns to check

    Returns:
        List of matches found
    """
    matches: list[Match] = []

    try:
        content = file_path.read_text()
        lines = content.split("\n")
    except (OSError, UnicodeDecodeError):
        return matches

    # Per-line pattern checks
    in_docstring = False  # True while inside a triple-quoted block
    docstring_delim = ""  # the """ or ''' that opened the current block
    for line_num, line in enumerate(lines, 1):
        # Skip comments for most patterns
        stripped = line.lstrip()
        is_comment = stripped.startswith("#")

        # Track triple-quote (docstring) state so example code inside docstrings
        # (e.g. a `time.sleep(` snippet) is not reported as a real anti-pattern.
        # _toggle_docstring returns whether THIS line lies in a docstring region
        # and updates the open/closed state for following lines.
        in_docstring, docstring_delim, line_in_docstring = _toggle_docstring(
            line, in_docstring, docstring_delim
        )

        # Strip an inline trailing comment so a `# requests.get(` example after
        # real code is not flagged; preserves the leading-# whole-comment case.
        scan_line = _strip_inline_comment(line)

        for pattern in patterns:
            if pattern.skip_in_comments and (is_comment or line_in_docstring):
                continue

            if pattern.pattern.search(scan_line):
                matches.append(
                    Match(
                        file=file_path,
                        line_num=line_num,
                        line=line.strip(),
                        pattern=pattern,
                    )
                )

    # File-level checks (checked once per file, not per line)
    for name, condition_fn, message, severity in FILE_LEVEL_CHECKS:
        if condition_fn(content):
            matches.append(
                Match(
                    file=file_path,
                    line_num=1,
                    line="(file-level check)",
                    pattern=Pattern(
                        # Non-matching sentinel: this Pattern is only a carrier
                        # for the file-level result. re.compile("") matched every
                        # line, so any accidental reuse in the per-line loop would
                        # flag the whole file; r"(?!)" never matches.
                        name=name,
                        pattern=re.compile(r"(?!)"),
                        message=message,
                        severity=severity,
                    ),
                )
            )

    return matches


def check_directory(
    directory: Path,
    patterns: list[Pattern],
    exclude_dirs: set[str] | None = None,
) -> list[Match]:
    """Check all Python files in a directory.

    Args:
        directory: Directory to check
        patterns: List of patterns to check
        exclude_dirs: Directory names to exclude

    Returns:
        List of matches found
    """
    if exclude_dirs is None:
        exclude_dirs = {".git", "__pycache__", ".venv", "venv", "node_modules"}

    matches: list[Match] = []

    for path in directory.rglob("*.py"):
        # Skip excluded directories
        if any(excluded in path.parts for excluded in exclude_dirs):
            continue

        matches.extend(check_file(path, patterns))

    return matches


def main() -> int:
    """Main entry point."""
    if len(sys.argv) < 2:
        # Default to current directory or custom_components
        if Path("custom_components").exists():
            target = Path("custom_components")
        else:
            target = Path(".")
    else:
        target = Path(sys.argv[-1])

    if target.is_file():
        matches = check_file(target, PATTERNS)
    else:
        matches = check_directory(target, PATTERNS)

    if not matches:
        return 0

    # Group by severity
    errors = [m for m in matches if m.pattern.severity == "error"]
    warnings = [m for m in matches if m.pattern.severity == "warning"]

    # Print errors first
    if errors:
        print("ERRORS:")
        print("-" * 60)
        for match in errors:
            print(f"{match.file}:{match.line_num}")
            print(f"  {match.pattern.message}")
            print(f"  > {match.line}")
            if match.pattern.replacement:
                print(f"  Fix: {match.pattern.replacement}")
            print()

    if warnings:
        print("WARNINGS:")
        print("-" * 60)
        for match in warnings:
            print(f"{match.file}:{match.line_num}")
            print(f"  {match.pattern.message}")
            print(f"  > {match.line}")
            if match.pattern.replacement:
                print(f"  Fix: {match.pattern.replacement}")
            print()

    print(f"Found {len(errors)} error(s), {len(warnings)} warning(s)")

    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
