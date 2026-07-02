"""Local CI gate: run every check tool in order and exit with the first failure's code.

Mirrors the full CI check suite (format → lint → type-check → test → coverage → audit)
so developers and agents can run a single command to replicate what CI will see.
"""

# Byte-identical twin contract: this file exists at BOTH
# src/project_standards/bundles/python-tooling/check.py (the adopt bundle
# artifact) and scripts/check.py (this repo's dogfooded copy).
# test_adopt_dogfood.py asserts byte equality — edit both copies together or
# that test fails in CI.

import subprocess
import sys
from collections.abc import Sequence

# Order matters: `coverage run` must precede `coverage report` (the report reads the
# data written by the run step — swapping them would report stale or missing data).
COMMANDS: tuple[tuple[str, ...], ...] = (
    ("uv", "run", "ruff", "format", "--check", "."),
    ("uv", "run", "ruff", "check", "."),
    ("uv", "run", "basedpyright"),
    ("uv", "run", "coverage", "run", "-m", "pytest"),
    ("uv", "run", "coverage", "report"),
    ("uv", "run", "pip-audit"),
)


def run_command(command: Sequence[str]) -> int:
    """Run *command* and return its exit code without raising on failure.

    Using check=False rather than check=True preserves the original exit code for the
    caller — check=True would raise CalledProcessError and lose that code, which matters
    for CI systems that inspect the specific exit value.
    """
    # flush=True so the `$` prefix prints before subprocess output, not buffered after.
    print(f"\n$ {' '.join(command)}", flush=True)
    completed = subprocess.run(command, check=False)
    return completed.returncode


def main() -> int:
    """Run all check commands in sequence; stop and propagate the exit code on first failure."""
    for command in COMMANDS:
        return_code = run_command(command)
        if return_code != 0:
            return return_code
    return 0


if __name__ == "__main__":
    sys.exit(main())
