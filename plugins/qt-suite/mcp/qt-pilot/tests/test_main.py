"""Unit tests for main.py resource management."""
import dataclasses
import json
import os
import socket as socket_mod
import sys
import tempfile
from pathlib import Path
from unittest.mock import MagicMock, patch

sys.path.insert(0, str(Path(__file__).parent.parent))
import main as qt_main


def _set_state(socket_path=None, process=None):
    """Helper to configure _app_state for tests."""
    qt_main._app_state.socket_path = socket_path
    qt_main._app_state.process = process


def test_send_command_uses_context_manager():
    """socket.socket must be used as a context manager (__enter__/__exit__ called)."""
    _mock_proc = MagicMock()
    _mock_proc.poll.return_value = None
    _set_state(
        socket_path="/tmp/fake.sock",
        process=_mock_proc,
    )
    mock_sock = MagicMock()
    mock_sock.__enter__ = MagicMock(return_value=mock_sock)
    mock_sock.__exit__ = MagicMock(return_value=False)
    mock_sock.recv.return_value = json.dumps({"success": True}).encode() + b"\n"

    with patch("socket.socket", return_value=mock_sock):
        qt_main._send_command({"action": "ping"})

    mock_sock.__enter__.assert_called_once()
    mock_sock.__exit__.assert_called_once()


def test_send_command_timeout_returns_error():
    """socket.timeout must map to the correct error dict."""
    _mock_proc = MagicMock()
    _mock_proc.poll.return_value = None
    _set_state(
        socket_path="/tmp/fake.sock",
        process=_mock_proc,
    )
    mock_sock = MagicMock()
    mock_sock.__enter__ = MagicMock(return_value=mock_sock)
    mock_sock.__exit__ = MagicMock(return_value=False)
    mock_sock.recv.side_effect = socket_mod.timeout

    with patch("socket.socket", return_value=mock_sock):
        result = qt_main._send_command({"action": "ping"})

    assert result == {"success": False, "error": "Command timed out"}


def _make_exists_side_effect(script_path: str):
    """Return True for the script existence check, False for the socket path.

    launch_app validates os.path.exists(script_path) before calling mkdtemp, so
    the patch must return True for that one call and False afterwards so the
    socket-wait loop exits immediately rather than spinning.
    """
    calls = []

    def side_effect(path):
        calls.append(path)
        # First call is always the script_path validation — let it pass.
        # Subsequent calls (X lock files, socket path) return False so the
        # wait loop exits on the first iteration.
        return path == script_path and len(calls) == 1

    return side_effect


def test_launch_app_uses_mkdtemp():
    """launch_app must call tempfile.mkdtemp(), not the deprecated mktemp()."""
    mkdtemp_calls = []

    def fake_mkdtemp(**kwargs):
        mkdtemp_calls.append(kwargs)
        return "/tmp/fake_dir_abc"

    with patch.object(tempfile, "mkdtemp", side_effect=fake_mkdtemp), \
         patch.object(tempfile, "mktemp", side_effect=AssertionError("mktemp must not be called")), \
         patch("subprocess.Popen") as mock_popen, \
         patch("time.sleep"), \
         patch("os.path.exists", side_effect=_make_exists_side_effect("/fake/app.py")):
        _mock_proc = MagicMock()
        _mock_proc.poll.return_value = None
        mock_popen.return_value = _mock_proc
        try:
            qt_main.launch_app(script_path="/fake/app.py", timeout=0)
        except Exception:
            pass

    assert len(mkdtemp_calls) > 0, "mkdtemp was never called — still using deprecated mktemp"


def test_socket_path_inside_mkdtemp_dir():
    """socket_path must be a file inside the mkdtemp directory, not the directory itself."""
    # Patch _cleanup_app so it does not clear _app_state between assignment and assertion;
    # the cleanup-on-failure behaviour is tested separately via test_launch_app_uses_mkdtemp.
    with patch.object(tempfile, "mkdtemp", return_value="/tmp/fake_dir_abc"), \
         patch("subprocess.Popen") as mock_popen, \
         patch("time.sleep"), \
         patch("os.path.exists", side_effect=_make_exists_side_effect("/fake/app.py")), \
         patch.object(qt_main, "_cleanup_app"):
        _mock_proc = MagicMock()
        _mock_proc.poll.return_value = None
        mock_popen.return_value = _mock_proc
        try:
            qt_main.launch_app(script_path="/fake/app.py", timeout=0)
        except Exception:
            pass

    # socket_path must be a path inside the temp dir, not the temp dir itself
    sp = qt_main._app_state.socket_path
    assert sp is not None, "socket_path was not set by launch_app"
    assert sp.startswith("/tmp/fake_dir_abc/"), (
        f"socket_path '{sp}' should be inside the mkdtemp directory"
    )


def test_app_state_is_dataclass():
    """_app_state must be a dataclass instance, not a dict."""
    assert dataclasses.is_dataclass(qt_main._app_state), (
        "_app_state should be an AppState dataclass instance"
    )


def test_app_state_has_expected_fields():
    """AppState must have exactly the five expected fields."""
    field_names = {f.name for f in dataclasses.fields(qt_main._app_state)}
    expected = {"process", "socket_path", "socket_dir", "display", "xvfb_process"}
    assert expected == field_names, f"AppState fields mismatch: {field_names}"


def test_constants_defined():
    """Named constants must exist at module level."""
    assert hasattr(qt_main, "_XVFB_DISPLAY_START"), "Missing _XVFB_DISPLAY_START"
    assert hasattr(qt_main, "_XVFB_STARTUP_WAIT_SECS"), "Missing _XVFB_STARTUP_WAIT_SECS"
    assert isinstance(qt_main._XVFB_DISPLAY_START, int), "_XVFB_DISPLAY_START must be int"
    assert isinstance(qt_main._XVFB_STARTUP_WAIT_SECS, float), (
        "_XVFB_STARTUP_WAIT_SECS must be float"
    )


def test_launch_app_uses_display_start_constant():
    """launch_app must read display start from the constant, not a literal."""
    display_nums_seen = []

    original_exists = os.path.exists

    def mock_exists(path):
        if path == "/fake/app.py":
            return True  # pass script validation — must happen before display check
        if path.startswith("/tmp/.X") and "-lock" in path:
            num = int(path.split(".X")[1].split("-")[0])
            display_nums_seen.append(num)
            return False  # pretend display is free
        return original_exists(path)

    _mock_proc = MagicMock()
    _mock_proc.poll.return_value = None

    with patch.object(tempfile, "mkdtemp", return_value="/tmp/fake_dir_abc"), \
         patch("os.path.exists", side_effect=mock_exists), \
         patch("subprocess.Popen", return_value=_mock_proc), \
         patch("time.sleep"), \
         patch.object(qt_main, "_XVFB_DISPLAY_START", 150):
        try:
            qt_main.launch_app(script_path="/fake/app.py", timeout=0)
        except Exception:
            pass

    assert 150 in display_nums_seen, (
        f"launch_app did not check display 150 — constant not used (saw: {display_nums_seen})"
    )
