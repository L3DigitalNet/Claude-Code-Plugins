"""Verify no unused top-level imports and no late imports inside methods."""
import ast
import pathlib
import pytest

SRC = pathlib.Path(__file__).parent.parent


def _has_late_imports(path: pathlib.Path) -> list[tuple[int, str]]:
    """Return (lineno, name) for any import inside a function/method body."""
    tree = ast.parse(path.read_text())
    late = []
    for node in ast.walk(tree):
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            for child in ast.walk(node):
                if isinstance(child, (ast.Import, ast.ImportFrom)) and child is not node:
                    late.append((child.lineno, ast.unparse(child)))
    return late


def test_main_no_late_imports():
    late = _has_late_imports(SRC / "main.py")
    assert late == [], f"main.py has late imports: {late}"


def test_harness_no_late_imports():
    late = _has_late_imports(SRC / "harness.py")
    assert late == [], f"harness.py has late imports: {late}"


@pytest.mark.parametrize("name", ["asyncio", "base64", "signal"])
def test_main_no_unused_stdlib_imports(name):
    """The three stdlib imports that are not referenced anywhere in main.py."""
    src = (SRC / "main.py").read_text()
    # If the name appears ONLY in an import line and nowhere else, it's unused
    lines_without_import = [l for l in src.splitlines() if f"import {name}" not in l]
    body = "\n".join(lines_without_import)
    assert f"import {name}" not in src or name in body, (
        f"'{name}' import exists but is never used in main.py body"
    )
