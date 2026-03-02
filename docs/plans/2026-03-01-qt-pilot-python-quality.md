# Qt Pilot Python Quality Improvements

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Apply all Python quality skills to `plugins/qt-suite/mcp/qt-pilot/` — fixing unsafe resource management, import hygiene, type annotations, global state structure, magic numbers, and adding a unit test suite.

**Architecture:** The qt-pilot MCP server (`main.py`) communicates with a test harness process (`harness.py`) via Unix socket. `main.py` manages subprocess lifetimes (Xvfb + harness) and owns the global `_app_state` dict. All fixes are backward-compatible — no MCP tool signatures change.

**Tech Stack:** Python 3.11+, FastMCP (`mcp.server.fastmcp`), PySide6, pytest, pytest-mock, `tempfile`, `socket`, `subprocess`

---

### Task 1: Import cleanup

**Files:**
- Modify: `plugins/qt-suite/mcp/qt-pilot/main.py:14-19`
- Modify: `plugins/qt-suite/mcp/qt-pilot/harness.py:14-22, 161, 463-464, 516-517, 594`

**Background:** `main.py` imports `asyncio`, `base64`, and `signal` but uses none of them. `harness.py` has four imports inside methods (`QPoint`, `QAction`, `QMenuBar`, `QMenu`, `time`) that should be at module level. Inline imports run on every call and hide dependencies.

**Step 1: Write the failing test (import linting)**

Create `plugins/qt-suite/mcp/qt-pilot/tests/test_imports.py`:

```python
"""Verify no unused top-level imports and no late imports inside methods."""
import ast
import pathlib
import pytest

SRC = pathlib.Path(__file__).parent.parent


def _get_module_imports(path: pathlib.Path) -> set[str]:
    """Return set of top-level imported names."""
    tree = ast.parse(path.read_text())
    names = set()
    for node in ast.walk(tree):
        if isinstance(node, (ast.Import, ast.ImportFrom)) and isinstance(
            node.col_offset == 0 or True, bool
        ):
            if node.col_offset == 0:
                if isinstance(node, ast.Import):
                    names.update(a.asname or a.name for a in node.names)
                else:
                    names.update(a.asname or a.name for a in node.names)
    return names


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
    # Import present but name never used
    if f"import {name}" in src:
        # If it's imported, it must be referenced somewhere beyond the import line
        lines = [l for l in src.splitlines() if f"import {name}" not in l]
        body = "\n".join(lines)
        assert name in body, f"'{name}' is imported but never used in main.py"
```

**Step 2: Run test to verify it fails**

```bash
cd plugins/qt-suite/mcp/qt-pilot
python -m pytest tests/test_imports.py -v
```

Expected: `FAIL` — late imports exist in harness.py, unused imports in main.py.

**Step 3: Fix main.py — remove unused imports**

Remove lines 14 (`import asyncio`), 15 (`import base64`), and 19 (`import signal`).

After edit, lines 14-24 should read:
```python
import json
import logging
import os
import socket
import subprocess
import sys
import tempfile
import time
from pathlib import Path
```

**Step 4: Fix harness.py — move late imports to module level**

In `harness.py`, at lines 24-28 (after the existing Qt imports block), add:
```python
from PySide6.QtCore import QPoint
from PySide6.QtGui import QAction
from PySide6.QtWidgets import QMenuBar, QMenu
```

Then remove the four inline import statements:
- Line ~161: `from PySide6.QtCore import QPoint`
- Lines ~463-464: `from PySide6.QtGui import QAction` / `from PySide6.QtWidgets import QMenuBar, QMenu`
- Lines ~516-517: same two imports (duplicate)
- Line ~594: `import time` (already at module level in main.py; add to harness.py module level imports block at line ~22)

**Step 5: Run tests to verify they pass**

```bash
cd plugins/qt-suite/mcp/qt-pilot
python -m pytest tests/test_imports.py -v
```

Expected: `PASS` — 5 tests.

**Step 6: Commit**

```bash
cd plugins/qt-suite/mcp/qt-pilot
git add main.py harness.py tests/test_imports.py
git commit -m "fix(qt-pilot): remove unused imports; move late imports to module level"
```

---

### Task 2: Type annotations

**Files:**
- Modify: `plugins/qt-suite/mcp/qt-pilot/main.py:52, 156-162, 663`

**Background:** Three issues: (a) `launch_app` parameters typed `str = None` instead of `str | None = None`; (b) `_cleanup_app()` and `main()` missing `-> None` return annotations.

**Step 1: Write the failing test**

Create `plugins/qt-suite/mcp/qt-pilot/tests/test_annotations.py`:

```python
"""Verify type annotations on key functions."""
import inspect
import sys
from pathlib import Path

# Add parent to path so main can be imported without a package install
sys.path.insert(0, str(Path(__file__).parent.parent))
import main as qt_main


def test_cleanup_app_returns_none():
    hints = qt_main._cleanup_app.__annotations__
    assert hints.get("return") is type(None), (
        "_cleanup_app must have '-> None' annotation"
    )


def test_main_returns_none():
    hints = qt_main.main.__annotations__
    assert hints.get("return") is type(None), "main() must have '-> None' annotation"


def test_launch_app_optional_str_params():
    sig = inspect.signature(qt_main.launch_app.fn)  # unwrap FastMCP decorator
    for param_name in ("script_path", "module", "working_dir"):
        param = sig.parameters[param_name]
        ann = param.annotation
        # annotation should allow None (i.e., be Optional/Union with None)
        import typing
        args = getattr(ann, "__args__", ())
        assert type(None) in args, (
            f"launch_app param '{param_name}' should be 'str | None', got {ann}"
        )


def test_launch_app_python_paths_optional():
    sig = inspect.signature(qt_main.launch_app.fn)
    ann = sig.parameters["python_paths"].annotation
    import typing
    args = getattr(ann, "__args__", ())
    assert type(None) in args, (
        "launch_app param 'python_paths' should be 'list[str] | None', got {ann}"
    )
```

**Step 2: Run test to verify it fails**

```bash
cd plugins/qt-suite/mcp/qt-pilot
python -m pytest tests/test_annotations.py -v
```

Expected: `FAIL` — annotations missing.

**Step 3: Fix annotations in main.py**

Change `_cleanup_app` signature at line 52:
```python
def _cleanup_app() -> None:
```

Change `main` signature at line 663:
```python
def main() -> None:
```

Change `launch_app` parameter annotations (lines 157-162):
```python
@mcp.tool()
def launch_app(
    script_path: str | None = None,
    module: str | None = None,
    working_dir: str | None = None,
    python_paths: list[str] | None = None,
    timeout: int = 10,
) -> dict:
```

**Step 4: Run tests to verify they pass**

```bash
cd plugins/qt-suite/mcp/qt-pilot
python -m pytest tests/test_annotations.py -v
```

Expected: `PASS` — 4 tests.

**Step 5: Commit**

```bash
git add plugins/qt-suite/mcp/qt-pilot/main.py plugins/qt-suite/mcp/qt-pilot/tests/test_annotations.py
git commit -m "fix(qt-pilot): add missing type annotations — Optional params and return types"
```

---

### Task 3: Resource management — tempfile and socket

**Files:**
- Modify: `plugins/qt-suite/mcp/qt-pilot/main.py:70-77, 120-153, 197-198`

**Background:** Two issues:

1. `tempfile.mktemp()` at line 197 is deprecated and has a TOCTOU race: it returns a filename without creating the file, so another process could claim that path before the harness creates the socket. Fix: `tempfile.mkdtemp()` atomically creates a directory; the socket goes inside it.

2. `_send_command()` at lines 120-153 opens a `socket.socket()` and calls `sock.close()` only on the happy path. Any exception between `connect()` and `close()` leaks the socket. Fix: `with socket.socket(...) as sock:` guarantees close on all paths.

**Step 1: Write the failing test**

Add to `plugins/qt-suite/mcp/qt-pilot/tests/test_main.py` (create if not present):

```python
"""Unit tests for main.py resource management."""
import json
import socket as socket_mod
import sys
from pathlib import Path
from unittest.mock import MagicMock, patch, call
import pytest

sys.path.insert(0, str(Path(__file__).parent.parent))
import main as qt_main
from main import AppState  # will exist after Task 4; for now use _app_state dict


def test_send_command_uses_context_manager(monkeypatch):
    """socket.socket must be used as a context manager."""
    state = qt_main._app_state
    # Temporarily set a socket path so we don't hit the "not running" guard
    if isinstance(state, dict):
        state["socket_path"] = "/tmp/fake.sock"
        state["process"] = MagicMock(**{"poll.return_value": None})
    else:
        state.socket_path = "/tmp/fake.sock"
        state.process = MagicMock(**{"poll.return_value": None})

    mock_sock = MagicMock()
    mock_sock.__enter__ = MagicMock(return_value=mock_sock)
    mock_sock.__exit__ = MagicMock(return_value=False)
    mock_sock.recv.return_value = json.dumps({"success": True}).encode() + b"\n"

    with patch("socket.socket", return_value=mock_sock) as mock_socket_cls:
        qt_main._send_command({"action": "ping"})

    # Verify it was used as a context manager (with statement calls __enter__/__exit__)
    mock_sock.__enter__.assert_called_once()
    mock_sock.__exit__.assert_called_once()


def test_send_command_timeout_returns_error(monkeypatch):
    """socket.timeout must map to the expected error dict."""
    state = qt_main._app_state
    if isinstance(state, dict):
        state["socket_path"] = "/tmp/fake.sock"
        state["process"] = MagicMock(**{"poll.return_value": None})
    else:
        state.socket_path = "/tmp/fake.sock"
        state.process = MagicMock(**{"poll.return_value": None})

    mock_sock = MagicMock()
    mock_sock.__enter__ = MagicMock(return_value=mock_sock)
    mock_sock.__exit__ = MagicMock(return_value=False)
    mock_sock.recv.side_effect = socket_mod.timeout

    with patch("socket.socket", return_value=mock_sock):
        result = qt_main._send_command({"action": "ping"})

    assert result == {"success": False, "error": "Command timed out"}


def test_launch_app_uses_mkdtemp(monkeypatch):
    """launch_app must use mkdtemp, not mktemp."""
    import tempfile
    calls = []

    def fake_mkdtemp(**kwargs):
        calls.append(kwargs)
        return "/tmp/fake_dir_abc"

    monkeypatch.setattr(tempfile, "mkdtemp", fake_mkdtemp)
    monkeypatch.setattr(tempfile, "mktemp", lambda **kw: (_ for _ in ()).throw(
        AssertionError("mktemp must not be called")
    ))
    # Patch subprocess.Popen to avoid actually spawning processes
    with patch("subprocess.Popen") as mock_popen, \
         patch("time.sleep"), \
         patch("os.path.exists", return_value=True):
        mock_popen.return_value = MagicMock(**{"poll.return_value": None})
        try:
            qt_main.launch_app(script_path="/fake/app.py")
        except Exception:
            pass  # We just care that mkdtemp was called
    assert len(calls) > 0, "mkdtemp was never called — still using deprecated mktemp"
```

**Step 2: Run test to verify it fails**

```bash
cd plugins/qt-suite/mcp/qt-pilot
python -m pytest tests/test_main.py::test_send_command_uses_context_manager \
                 tests/test_main.py::test_launch_app_uses_mkdtemp -v
```

Expected: `FAIL`.

**Step 3: Fix tempfile.mktemp → mkdtemp**

In `main.py`, replace lines 196-198:

```python
# Create temp directory for socket communication (mkdtemp is atomic and safe)
socket_dir = tempfile.mkdtemp(prefix="qt_gui_tester_")
socket_path = os.path.join(socket_dir, "qt.sock")
_app_state["socket_path"] = socket_path
_app_state["socket_dir"] = socket_dir
```

Add `"socket_dir": None` to the `_app_state` dict at line 41:

```python
_app_state = {
    "process": None,
    "socket_path": None,
    "socket_dir": None,
    "display": None,
    "xvfb_process": None,
}
```

Update `_cleanup_app()` to also remove the temp directory (after removing the socket file):

```python
    if _app_state["socket_path"] and os.path.exists(_app_state["socket_path"]):
        try:
            os.unlink(_app_state["socket_path"])
        except OSError as e:
            logger.warning(f"Error removing socket: {e}")
    _app_state["socket_path"] = None

    if _app_state.get("socket_dir") and os.path.exists(_app_state["socket_dir"]):
        try:
            os.rmdir(_app_state["socket_dir"])
        except OSError as e:
            logger.warning(f"Error removing socket dir: {e}")
    _app_state["socket_dir"] = None
```

**Step 4: Fix socket context manager in _send_command**

Replace lines 120-153 with context manager form:

```python
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
            sock.settimeout(timeout)
            sock.connect(_app_state["socket_path"])

            data = json.dumps(command).encode() + b"\n"
            sock.sendall(data)

            response_data = b""
            while True:
                chunk = sock.recv(4096)
                if not chunk:
                    break
                response_data += chunk
                if b"\n" in response_data:
                    break

        return json.loads(response_data.decode().strip())
    except socket.timeout:
        return {"success": False, "error": "Command timed out"}
    except ConnectionRefusedError:
        proc_info = _get_process_output()
        if not proc_info["running"]:
            error_msg = f"App crashed (exit code: {proc_info['exit_code']})"
            if proc_info["stderr"]:
                error_msg += f"\nstderr: {proc_info['stderr'][:500]}"
            return {"success": False, "error": error_msg}
        return {"success": False, "error": "App not responding (connection refused)"}
    except Exception as e:
        return {"success": False, "error": str(e)}
```

**Step 5: Run tests to verify they pass**

```bash
cd plugins/qt-suite/mcp/qt-pilot
python -m pytest tests/test_main.py -v
```

Expected: `PASS` — 3 tests.

**Step 6: Commit**

```bash
git add plugins/qt-suite/mcp/qt-pilot/main.py plugins/qt-suite/mcp/qt-pilot/tests/test_main.py
git commit -m "fix(qt-pilot): replace mktemp with mkdtemp; use socket context manager"
```

---

### Task 4: Replace `_app_state` dict with `AppState` dataclass

**Files:**
- Modify: `plugins/qt-suite/mcp/qt-pilot/main.py` (multiple locations)

**Background:** `_app_state = {"process": None, ...}` is an untyped global dict. A `@dataclass` gives type-checked field access, IDE support, and makes `None` defaults explicit. All `_app_state["key"]` accesses become `_app_state.key`.

**Step 1: Write the failing test**

Add to `tests/test_main.py`:

```python
def test_app_state_is_dataclass():
    """_app_state must be a dataclass instance, not a dict."""
    import dataclasses
    assert dataclasses.is_dataclass(qt_main._app_state), (
        "_app_state should be an AppState dataclass instance"
    )


def test_app_state_has_expected_fields():
    import dataclasses
    field_names = {f.name for f in dataclasses.fields(qt_main._app_state)}
    expected = {"process", "socket_path", "socket_dir", "display", "xvfb_process"}
    assert expected == field_names, f"AppState fields mismatch: {field_names}"
```

**Step 2: Run test to verify it fails**

```bash
cd plugins/qt-suite/mcp/qt-pilot
python -m pytest tests/test_main.py::test_app_state_is_dataclass \
                 tests/test_main.py::test_app_state_has_expected_fields -v
```

Expected: `FAIL`.

**Step 3: Add the AppState dataclass**

In `main.py`, after the imports block and before line 37 (`# Create MCP server`), add:

```python
import dataclasses
import subprocess as _subprocess


@dataclasses.dataclass
class AppState:
    """Mutable state for a single launched Qt application session."""

    process: "_subprocess.Popen[bytes] | None" = None
    socket_path: str | None = None
    socket_dir: str | None = None
    display: str | None = None
    xvfb_process: "_subprocess.Popen[bytes] | None" = None
```

Replace the `_app_state = {…}` dict (lines 40-46) with:

```python
_app_state = AppState()
```

**Step 4: Update all dict-style accesses to attribute-style**

Search for every `_app_state["…"]` and `_app_state.get("…")` in `main.py` and replace with `_app_state.field_name`. The affected locations are `_cleanup_app()`, `_send_command()`, `_get_process_output()`, `launch_app()`, and `close_app()`.

Example replacements:
- `_app_state["process"]` → `_app_state.process`
- `_app_state["socket_path"]` → `_app_state.socket_path`
- `_app_state["socket_dir"]` → `_app_state.socket_dir`
- `_app_state["display"]` → `_app_state.display`
- `_app_state["xvfb_process"]` → `_app_state.xvfb_process`
- `_app_state.get("socket_dir")` → `_app_state.socket_dir` (the `.get()` guard is now just `if _app_state.socket_dir:`)

**Step 5: Run all tests to verify they pass**

```bash
cd plugins/qt-suite/mcp/qt-pilot
python -m pytest tests/ -v
```

Expected: `PASS` — all prior tests still green, 2 new tests added.

**Step 6: Commit**

```bash
git add plugins/qt-suite/mcp/qt-pilot/main.py plugins/qt-suite/mcp/qt-pilot/tests/test_main.py
git commit -m "refactor(qt-pilot): replace _app_state dict with AppState dataclass"
```

---

### Task 5: Extract magic numbers to named constants

**Files:**
- Modify: `plugins/qt-suite/mcp/qt-pilot/main.py:200-215`

**Background:** `display_num = 99` and `time.sleep(0.5)` are unexplained magic numbers. Making them named constants documents intent (Xvfb display numbering convention) and makes tuning straightforward.

**Step 1: Write the failing test**

Add to `tests/test_main.py`:

```python
def test_constants_defined():
    """Named constants must exist at module level."""
    assert hasattr(qt_main, "_XVFB_DISPLAY_START"), "Missing _XVFB_DISPLAY_START"
    assert hasattr(qt_main, "_XVFB_STARTUP_WAIT_SECS"), "Missing _XVFB_STARTUP_WAIT_SECS"
    assert isinstance(qt_main._XVFB_DISPLAY_START, int), "_XVFB_DISPLAY_START must be int"
    assert isinstance(qt_main._XVFB_STARTUP_WAIT_SECS, float), (
        "_XVFB_STARTUP_WAIT_SECS must be float"
    )


def test_launch_app_uses_display_start_constant(monkeypatch):
    """launch_app must read display start from the constant, not a literal."""
    import tempfile
    monkeypatch.setattr(tempfile, "mkdtemp", lambda **kw: "/tmp/fake_dir")
    monkeypatch.setattr(qt_main, "_XVFB_DISPLAY_START", 150)

    display_nums_seen = []

    original_exists = os.path.exists
    def mock_exists(path):
        if path.startswith("/tmp/.X"):
            num = int(path.split(".X")[1].split("-")[0])
            display_nums_seen.append(num)
            return False  # pretend display is free
        return original_exists(path)

    with patch("os.path.exists", side_effect=mock_exists), \
         patch("subprocess.Popen") as mock_popen, \
         patch("time.sleep"):
        mock_popen.return_value = MagicMock(**{"poll.return_value": None})
        try:
            qt_main.launch_app(script_path="/fake/app.py")
        except Exception:
            pass

    assert 150 in display_nums_seen, (
        "launch_app checked display 150 — constant not used"
    )
```

**Step 2: Run test to verify it fails**

```bash
cd plugins/qt-suite/mcp/qt-pilot
python -m pytest tests/test_main.py::test_constants_defined \
                 tests/test_main.py::test_launch_app_uses_display_start_constant -v
```

Expected: `FAIL`.

**Step 3: Add constants and update launch_app**

After the `_app_state = AppState()` line, add:

```python
# Xvfb display numbering: start at 99 to avoid conflicts with user displays (0-10 range)
_XVFB_DISPLAY_START: int = 99
# Seconds to wait after starting Xvfb before launching the harness
_XVFB_STARTUP_WAIT_SECS: float = 0.5
```

In `launch_app()`, replace:
```python
display_num = 99
```
with:
```python
display_num = _XVFB_DISPLAY_START
```

Replace:
```python
time.sleep(0.5)  # Wait for Xvfb to start
```
with:
```python
time.sleep(_XVFB_STARTUP_WAIT_SECS)
```

**Step 4: Run tests to verify they pass**

```bash
cd plugins/qt-suite/mcp/qt-pilot
python -m pytest tests/ -v
```

Expected: all tests `PASS`.

**Step 5: Commit**

```bash
git add plugins/qt-suite/mcp/qt-pilot/main.py plugins/qt-suite/mcp/qt-pilot/tests/test_main.py
git commit -m "refactor(qt-pilot): extract magic numbers to named constants"
```

---

### Task 6: Test infrastructure and cleanup checks

**Files:**
- Create: `plugins/qt-suite/mcp/qt-pilot/pyproject.toml`
- Create: `plugins/qt-suite/mcp/qt-pilot/requirements-dev.txt`
- Create: `plugins/qt-suite/mcp/qt-pilot/tests/__init__.py`
- Create: `plugins/qt-suite/mcp/qt-pilot/tests/conftest.py`

**Background:** There is no test runner config — `pytest` needs `pythonpath` set so `import main` works from the tests directory. A `requirements-dev.txt` separates dev deps from `requirements.txt` (which is used by the `start-qt-pilot.sh` venv).

**Step 1: Create test infrastructure files**

`pyproject.toml`:
```toml
[tool.pytest.ini_options]
testpaths = ["tests"]
pythonpath = ["."]
```

`requirements-dev.txt`:
```
pytest>=8.0
pytest-mock>=3.14
```

`tests/__init__.py`: empty file.

`tests/conftest.py`:
```python
"""Shared fixtures for qt-pilot unit tests."""
import sys
from pathlib import Path

# Ensure main.py is importable without installing as a package
sys.path.insert(0, str(Path(__file__).parent.parent))
```

**Step 2: Verify the full test suite runs cleanly**

```bash
cd plugins/qt-suite/mcp/qt-pilot
pip install pytest pytest-mock  # or: pip install -r requirements-dev.txt
python -m pytest tests/ -v
```

Expected: all tests `PASS`.

**Step 3: Run the import linting test as a final check**

```bash
python -m pytest tests/test_imports.py -v
```

Expected: `PASS` — verifies no regressions on imports.

**Step 4: Commit**

```bash
git add plugins/qt-suite/mcp/qt-pilot/pyproject.toml \
        plugins/qt-suite/mcp/qt-pilot/requirements-dev.txt \
        plugins/qt-suite/mcp/qt-pilot/tests/__init__.py \
        plugins/qt-suite/mcp/qt-pilot/tests/conftest.py
git commit -m "chore(qt-pilot): add pytest config and dev dependencies"
```

---

## Summary of changes

| File | Changes |
|------|---------|
| `main.py` | Remove 3 unused imports; fix 4 type annotations; `mktemp` → `mkdtemp` + socket dir cleanup; socket context manager; `AppState` dataclass replacing global dict; 2 named constants |
| `harness.py` | Move 5 late imports to module level |
| `tests/test_imports.py` | New — AST-based import linting |
| `tests/test_annotations.py` | New — annotation coverage |
| `tests/test_main.py` | New — resource management, dataclass, constants |
| `tests/conftest.py` | New — path setup fixture |
| `tests/__init__.py` | New — empty package marker |
| `pyproject.toml` | New — pytest config with pythonpath |
| `requirements-dev.txt` | New — dev dependencies |
