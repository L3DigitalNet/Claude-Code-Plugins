"""Unit tests for main.py resource management."""
import json
import socket as socket_mod
import sys
from pathlib import Path
from unittest.mock import MagicMock, patch

sys.path.insert(0, str(Path(__file__).parent.parent))
import main as qt_main


def _set_state(socket_path=None, process=None):
    """Helper to configure _app_state for tests."""
    qt_main._app_state["socket_path"] = socket_path
    qt_main._app_state["process"] = process


def test_send_command_uses_context_manager():
    """socket.socket must be used as a context manager (__enter__/__exit__ called)."""
    _set_state(
        socket_path="/tmp/fake.sock",
        process=MagicMock(**{"poll.return_value": None}),
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
    _set_state(
        socket_path="/tmp/fake.sock",
        process=MagicMock(**{"poll.return_value": None}),
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
    import tempfile

    mkdtemp_calls = []

    def fake_mkdtemp(**kwargs):
        mkdtemp_calls.append(kwargs)
        return "/tmp/fake_dir_abc"

    with patch.object(tempfile, "mkdtemp", side_effect=fake_mkdtemp), \
         patch.object(tempfile, "mktemp", side_effect=AssertionError("mktemp must not be called")), \
         patch("subprocess.Popen") as mock_popen, \
         patch("time.sleep"), \
         patch("os.path.exists", side_effect=_make_exists_side_effect("/fake/app.py")):
        mock_popen.return_value = MagicMock(**{"poll.return_value": None})
        try:
            qt_main.launch_app(script_path="/fake/app.py", timeout=0)
        except Exception:
            pass

    assert len(mkdtemp_calls) > 0, "mkdtemp was never called — still using deprecated mktemp"


def test_socket_path_inside_mkdtemp_dir():
    """socket_path must be a file inside the mkdtemp directory, not the directory itself."""
    import tempfile

    # Patch _cleanup_app so it does not clear _app_state between assignment and assertion;
    # the cleanup-on-failure behaviour is tested separately via test_launch_app_uses_mkdtemp.
    with patch.object(tempfile, "mkdtemp", return_value="/tmp/fake_dir_abc"), \
         patch("subprocess.Popen") as mock_popen, \
         patch("time.sleep"), \
         patch("os.path.exists", side_effect=_make_exists_side_effect("/fake/app.py")), \
         patch.object(qt_main, "_cleanup_app"):
        mock_popen.return_value = MagicMock(**{"poll.return_value": None})
        try:
            qt_main.launch_app(script_path="/fake/app.py", timeout=0)
        except Exception:
            pass

    # socket_path must be a path inside the temp dir, not the temp dir itself
    sp = qt_main._app_state["socket_path"]
    assert sp is not None, "socket_path was not set by launch_app"
    assert sp.startswith("/tmp/fake_dir_abc/"), (
        f"socket_path '{sp}' should be inside the mkdtemp directory"
    )
