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
    Pattern(
        name="blocking-open",
        pattern=re.compile(r"\bopen\s*\([^)]+\)\.read\s*\("),
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
    Pattern(
        name="typing-List",
        pattern=re.compile(r"\bList\s*\["),
        message="Use list[] instead of List[] (Python 3.9+)",
        severity="warning",
    ),
    Pattern(
        name="typing-Dict",
        pattern=re.compile(r"\bDict\s*\["),
        message="Use dict[] instead of Dict[] (Python 3.9+)",
        severity="warning",
    ),
    Pattern(
        name="typing-Optional",
        pattern=re.compile(r"\bOptional\s*\["),
        message="Use X | None instead of Optional[X] (Python 3.10+)",
        severity="warning",
    ),
    Pattern(
        name="typing-Union",
        pattern=re.compile(r"\bUnion\s*\["),
        message="Use X | Y instead of Union[X, Y] (Python 3.10+)",
        severity="warning",
    ),
    Pattern(
        name="typing-Tuple",
        pattern=re.compile(r"\bTuple\s*\["),
        message="Use tuple[] instead of Tuple[] (Python 3.9+)",
        severity="warning",
    ),
    Pattern(
        name="typing-Set",
        pattern=re.compile(r"\bSet\s*\["),
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
    # Entity patterns
    Pattern(
        name="missing-unique-id",
        pattern=re.compile(r"class\s+\w+Entity[^:]*:(?:(?!_attr_unique_id|unique_id).)*$", re.MULTILINE | re.DOTALL),
        message="Entity class may be missing unique_id",
        severity="warning",
        skip_in_comments=True,
    ),
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
    # Missing future annotations
    Pattern(
        name="missing-future-annotations",
        pattern=re.compile(r"^(?!.*from __future__ import annotations).*\bdef\s+\w+\s*\([^)]*:\s*\w+"),
        message="Add 'from __future__ import annotations' for modern type syntax",
        severity="warning",
    ),
]


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

    for line_num, line in enumerate(lines, 1):
        # Skip comments for most patterns
        stripped = line.lstrip()
        is_comment = stripped.startswith("#")

        for pattern in patterns:
            if pattern.skip_in_comments and is_comment:
                continue

            if pattern.pattern.search(line):
                matches.append(
                    Match(
                        file=file_path,
                        line_num=line_num,
                        line=line.strip(),
                        pattern=pattern,
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

    print(f"Checking: {target}")
    print()

    if target.is_file():
        matches = check_file(target, PATTERNS)
    else:
        matches = check_directory(target, PATTERNS)

    if not matches:
        print("✅ No anti-patterns detected!")
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
