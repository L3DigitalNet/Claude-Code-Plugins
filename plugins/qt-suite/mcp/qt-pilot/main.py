#!/usr/bin/env python3
"""Qt GUI Testing MCP Server.

Provides headless Qt application testing capabilities:
- Launch Qt apps via xvfb
- Capture screenshots
- Simulate clicks, hovers, keyboard input
- Find and inspect widgets by name

IMPORTANT: This is a stdio MCP server - NEVER use print() or write to stdout!
All logging must go to stderr or a file.
"""

import dataclasses
import json
import logging
import os
import shutil
import socket
import subprocess
import sys
import tempfile
import time
from pathlib import Path

from mcp.server.fastmcp import FastMCP

# Configure logging to stderr (NEVER stdout for stdio MCP servers)
logging.basicConfig(
    level=logging.DEBUG,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    stream=sys.stderr,
)
logger = logging.getLogger("qt-pilot")

@dataclasses.dataclass
class AppState:
    """Mutable state for a single launched Qt application session.

    All fields default to None; set during launch_app() and cleared by _cleanup_app().
    """

    process: "subprocess.Popen[bytes] | None" = None
    socket_path: str | None = None
    socket_dir: str | None = None
    display: str | None = None
    xvfb_process: "subprocess.Popen[bytes] | None" = None


# Create MCP server
mcp = FastMCP("qt-pilot")

# Global state for tracking launched apps
_app_state = AppState()

# Xvfb display numbering: start at 99 to avoid conflicts with user displays (0-10 range)
_XVFB_DISPLAY_START: int = 99
# Seconds to wait after starting Xvfb before launching the harness
_XVFB_STARTUP_WAIT_SECS: float = 0.5

# Path to the test harness script (same directory as this file)
HARNESS_PATH = Path(__file__).parent / "harness.py"


def _cleanup_app() -> None:
    """Clean up any running app and xvfb."""
    if _app_state.process:
        try:
            _app_state.process.terminate()
            _app_state.process.wait(timeout=5)
        except Exception as e:
            logger.warning(f"Error terminating app: {e}")
        _app_state.process = None

    if _app_state.xvfb_process:
        try:
            _app_state.xvfb_process.terminate()
            _app_state.xvfb_process.wait(timeout=5)
        except Exception as e:
            logger.warning(f"Error terminating xvfb: {e}")
        _app_state.xvfb_process = None

    socket_path = _app_state.socket_path
    if socket_path and os.path.exists(socket_path):
        try:
            os.unlink(socket_path)
        except OSError as e:
            logger.warning(f"Error removing socket: {e}")
    _app_state.socket_path = None

    socket_dir = _app_state.socket_dir
    if socket_dir:
        shutil.rmtree(socket_dir, ignore_errors=True)
    _app_state.socket_dir = None


def _get_process_output() -> dict:
    """Get any available output from the app process."""
    if not _app_state.process:
        return {"stdout": "", "stderr": "", "running": False, "exit_code": None}

    # Check if process is still running
    exit_code = _app_state.process.poll()
    running = exit_code is None

    stdout = ""
    stderr = ""

    if not running:
        # Process has exited, get all output
        try:
            out, err = _app_state.process.communicate(timeout=1)
            stdout = out.decode() if out else ""
            stderr = err.decode() if err else ""
        except Exception:
            pass

    return {
        "stdout": stdout,
        "stderr": stderr,
        "running": running,
        "exit_code": exit_code,
    }


def _send_command(command: dict, timeout: float = 10.0) -> dict:
    """Send a command to the test harness via Unix socket."""
    if not _app_state.socket_path:
        return {"success": False, "error": "No app is running"}

    # Check if process is still alive before attempting communication
    proc_info = _get_process_output()
    if not proc_info["running"]:
        error_msg = f"App has exited (code: {proc_info['exit_code']})"
        if proc_info["stderr"]:
            error_msg += f"\nstderr: {proc_info['stderr'][:500]}"
        return {"success": False, "error": error_msg}

    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
            sock.settimeout(timeout)
            sock.connect(_app_state.socket_path)

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


@mcp.tool()
def launch_app(
    script_path: str | None = None,
    module: str | None = None,
    working_dir: str | None = None,
    python_paths: list[str] | None = None,
    timeout: int = 10,
) -> dict:
    """Launch a Qt application headlessly via xvfb.

    Supports two modes:
    1. Script mode: Run a Python script directly
       launch_app(script_path="/path/to/test_gui.py")

    2. Module mode: Run as Python module (like `python -m`)
       launch_app(module="src.gui.main", working_dir="/path/to/project")

    Args:
        script_path: Path to Python script (mode 1)
        module: Python module path to run with -m (mode 2)
        working_dir: Working directory (required for module mode)
        python_paths: Additional paths to add to Python's sys.path (for finding modules)
        timeout: Seconds to wait for app window to appear

    Returns:
        {"success": bool, "message": str, "socket_path": str}
    """
    # Validate inputs
    if not script_path and not module:
        return {"success": False, "message": "Must provide either script_path or module"}

    if module and not working_dir:
        return {"success": False, "message": "working_dir is required for module mode"}

    if script_path and not os.path.exists(script_path):
        return {"success": False, "message": f"Script not found: {script_path}"}

    # Clean up any existing app
    _cleanup_app()

    # Create socket path for communication — mkdtemp atomically creates the dir,
    # eliminating the TOCTOU race that mktemp() had between name generation and use.
    socket_dir = tempfile.mkdtemp(prefix="qt_gui_tester_")
    socket_path = os.path.join(socket_dir, "qt.sock")
    _app_state.socket_path = socket_path
    _app_state.socket_dir = socket_dir

    # Find available display number
    display_num = _XVFB_DISPLAY_START
    while os.path.exists(f"/tmp/.X{display_num}-lock"):
        display_num += 1
    display = f":{display_num}"
    _app_state.display = display

    try:
        # Start Xvfb
        xvfb_cmd = ["Xvfb", display, "-screen", "0", "1280x1024x24"]
        _app_state.xvfb_process = subprocess.Popen(
            xvfb_cmd,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        time.sleep(_XVFB_STARTUP_WAIT_SECS)

        # Build harness command
        env = os.environ.copy()
        env["DISPLAY"] = display
        env["QT_QPA_PLATFORM"] = "xcb"  # Use X11 backend

        harness_cmd = [sys.executable, str(HARNESS_PATH), "--socket", socket_path]

        if script_path:
            harness_cmd.extend(["--script", script_path])
        elif module:
            harness_cmd.extend(["--module", module])

        # Determine working directory
        cwd = working_dir or (os.path.dirname(script_path) if script_path else None)

        # Pass working directory to harness for sys.path setup
        if cwd:
            harness_cmd.extend(["--working-dir", cwd])

        # Add additional Python paths for module discovery
        if python_paths:
            for path in python_paths:
                harness_cmd.extend(["--python-path", path])

        logger.info(f"Launching harness: {' '.join(harness_cmd)}")
        logger.info(f"Working dir: {cwd}")
        logger.info(f"Display: {display}")
        if python_paths:
            logger.info(f"Python paths: {python_paths}")

        # Start the harness
        _app_state.process = subprocess.Popen(
            harness_cmd,
            cwd=cwd,
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )

        # Wait for socket to be ready
        start_time = time.time()
        while time.time() - start_time < timeout:
            if os.path.exists(socket_path):
                # Try to connect
                result = _send_command({"cmd": "ping"}, timeout=2)
                if result.get("success"):
                    return {
                        "success": True,
                        "message": "App launched successfully",
                        "socket_path": socket_path,
                        "display": display,
                    }
            time.sleep(0.5)

        # Check if process died
        if _app_state.process.poll() is not None:
            _, stderr = _app_state.process.communicate()
            _cleanup_app()
            return {
                "success": False,
                "message": f"App exited unexpectedly. stderr: {stderr.decode()[:500]}",
            }

        _cleanup_app()
        return {"success": False, "message": f"Timeout waiting for app (socket: {socket_path})"}

    except Exception as e:
        _cleanup_app()
        return {"success": False, "message": f"Failed to launch: {str(e)}"}


@mcp.tool()
def capture_screenshot(output_path: str | None = None) -> dict:
    """Capture screenshot of current application.

    Args:
        output_path: Optional path to save PNG file

    Returns:
        {"success": bool, "path": str, "message": str}
    """
    if not _app_state.process:
        return {"success": False, "message": "No app is running"}

    # Generate output path if not provided — mkstemp atomically creates the file,
    # avoiding the TOCTOU race that mktemp() has between name generation and use.
    if not output_path:
        fd, output_path = tempfile.mkstemp(suffix=".png", prefix="screenshot_")
        os.close(fd)

    result = _send_command({
        "cmd": "screenshot",
        "path": output_path,
    })

    if result.get("success"):
        return {
            "success": True,
            "path": output_path,
            "message": f"Screenshot saved to {output_path}",
        }
    else:
        return {
            "success": False,
            "message": result.get("error", "Screenshot failed"),
        }


@mcp.tool()
def click_widget(widget_name: str, button: str = "left") -> dict:
    """Click a widget by its object name.

    Args:
        widget_name: The objectName of the target widget
        button: "left", "right", or "middle"

    Returns:
        {"success": bool, "message": str}
    """
    if not _app_state.process:
        return {"success": False, "message": "No app is running"}

    result = _send_command({
        "cmd": "click",
        "widget_name": widget_name,
        "button": button,
    })

    if result.get("success"):
        return {"success": True, "message": f"Clicked widget '{widget_name}'"}
    else:
        return {"success": False, "message": result.get("error", "Click failed")}


@mcp.tool()
def hover_widget(widget_name: str) -> dict:
    """Hover over a widget by its object name.

    Args:
        widget_name: The objectName of the target widget

    Returns:
        {"success": bool, "message": str}
    """
    if not _app_state.process:
        return {"success": False, "message": "No app is running"}

    result = _send_command({
        "cmd": "hover",
        "widget_name": widget_name,
    })

    if result.get("success"):
        return {"success": True, "message": f"Hovering over widget '{widget_name}'"}
    else:
        return {"success": False, "message": result.get("error", "Hover failed")}


@mcp.tool()
def type_text(text: str, widget_name: str | None = None) -> dict:
    """Type text into a widget or the currently focused widget.

    Args:
        text: Text to type
        widget_name: Optional target widget (uses focused widget if None)

    Returns:
        {"success": bool, "message": str}
    """
    if not _app_state.process:
        return {"success": False, "message": "No app is running"}

    result = _send_command({
        "cmd": "type_text",
        "text": text,
        "widget_name": widget_name,
    })

    if result.get("success"):
        target = f"widget '{widget_name}'" if widget_name else "focused widget"
        return {"success": True, "message": f"Typed text into {target}"}
    else:
        return {"success": False, "message": result.get("error", "Type failed")}


@mcp.tool()
def press_key(key: str, modifiers: list[str] | None = None) -> dict:
    """Simulate a key press.

    Args:
        key: Key name (e.g., "Enter", "Tab", "Escape", "A", "F1")
        modifiers: Optional list of modifiers ("Ctrl", "Shift", "Alt")

    Returns:
        {"success": bool, "message": str}
    """
    if not _app_state.process:
        return {"success": False, "message": "No app is running"}

    result = _send_command({
        "cmd": "press_key",
        "key": key,
        "modifiers": modifiers or [],
    })

    if result.get("success"):
        mod_str = "+".join(modifiers) + "+" if modifiers else ""
        return {"success": True, "message": f"Pressed {mod_str}{key}"}
    else:
        return {"success": False, "message": result.get("error", "Key press failed")}


@mcp.tool()
def find_widgets(name_pattern: str = "*") -> dict:
    """List widgets matching a name pattern.

    Args:
        name_pattern: Glob pattern for widget names (* = all named widgets)

    Returns:
        {"success": bool, "widgets": list[dict]}
    """
    if not _app_state.process:
        return {"success": False, "message": "No app is running"}

    result = _send_command({
        "cmd": "find_widgets",
        "pattern": name_pattern,
    })

    if result.get("success"):
        return {
            "success": True,
            "widgets": result.get("widgets", []),
            "count": len(result.get("widgets", [])),
        }
    else:
        return {"success": False, "message": result.get("error", "Find failed")}


@mcp.tool()
def click_at(x: int, y: int, button: str = "left") -> dict:
    """Click at specific screen coordinates.

    Useful for clicking widgets that don't have object names.

    Args:
        x: X coordinate (global screen position)
        y: Y coordinate (global screen position)
        button: "left", "right", or "middle"

    Returns:
        {"success": bool, "message": str, "widget_type": str}
    """
    if not _app_state.process:
        return {"success": False, "message": "No app is running"}

    result = _send_command({
        "cmd": "click_at",
        "x": x,
        "y": y,
        "button": button,
    })

    if result.get("success"):
        widget_type = result.get("widget_type", "unknown")
        return {"success": True, "message": f"Clicked at ({x}, {y}) on {widget_type}"}
    else:
        return {"success": False, "message": result.get("error", "Click failed")}


@mcp.tool()
def list_all_widgets(include_invisible: bool = False) -> dict:
    """List all widgets with their coordinates (including unnamed ones).

    Useful for understanding the complete widget hierarchy and finding
    click targets by position.

    Args:
        include_invisible: Whether to include invisible widgets

    Returns:
        {"success": bool, "widgets": list[dict], "count": int}
    """
    if not _app_state.process:
        return {"success": False, "message": "No app is running"}

    result = _send_command({
        "cmd": "list_all_widgets",
        "include_invisible": include_invisible,
    })

    if result.get("success"):
        return {
            "success": True,
            "widgets": result.get("widgets", []),
            "count": result.get("count", 0),
        }
    else:
        return {"success": False, "message": result.get("error", "List failed")}


@mcp.tool()
def trigger_action(action_name: str) -> dict:
    """Trigger a QAction by its object name.

    This directly triggers menu actions without needing to click through menus.
    Useful for menu items and toolbar actions.

    Args:
        action_name: The objectName of the QAction to trigger

    Returns:
        {"success": bool, "message": str}
    """
    if not _app_state.process:
        return {"success": False, "message": "No app is running"}

    result = _send_command({
        "cmd": "trigger_action",
        "action_name": action_name,
    })

    if result.get("success"):
        return {"success": True, "message": f"Triggered action '{action_name}'"}
    else:
        return {"success": False, "message": result.get("error", "Trigger failed")}


@mcp.tool()
def list_actions() -> dict:
    """List all QActions in the application.

    Returns menu items, toolbar actions, etc. with their names, text,
    shortcuts, and enabled/checked state.

    Returns:
        {"success": bool, "actions": list[dict], "count": int}
    """
    if not _app_state.process:
        return {"success": False, "message": "No app is running"}

    result = _send_command({
        "cmd": "list_actions",
    })

    if result.get("success"):
        return {
            "success": True,
            "actions": result.get("actions", []),
            "count": result.get("count", 0),
        }
    else:
        return {"success": False, "message": result.get("error", "List failed")}


@mcp.tool()
def get_widget_info(widget_name: str) -> dict:
    """Get detailed information about a specific widget.

    Args:
        widget_name: The objectName of the target widget

    Returns:
        {"success": bool, "info": dict} with size, position, visible, enabled, etc.
    """
    if not _app_state.process:
        return {"success": False, "message": "No app is running"}

    result = _send_command({
        "cmd": "get_widget_info",
        "widget_name": widget_name,
    })

    if result.get("success"):
        return {"success": True, "info": result.get("info", {})}
    else:
        return {"success": False, "message": result.get("error", "Get info failed")}


@mcp.tool()
def get_app_status() -> dict:
    """Check if the application is still running and get diagnostics.

    Use this to check app health without attempting a command.

    Returns:
        {"running": bool, "exit_code": int|None, "stderr": str, "display": str}
    """
    if not _app_state.process:
        return {
            "running": False,
            "exit_code": None,
            "stderr": "",
            "message": "No app has been launched",
        }

    proc_info = _get_process_output()
    return {
        "running": proc_info["running"],
        "exit_code": proc_info["exit_code"],
        "stderr": proc_info["stderr"][:1000] if proc_info["stderr"] else "",
        "display": _app_state.display or "",
        "socket_path": _app_state.socket_path or "",
    }


@mcp.tool()
def wait_for_idle(timeout: float = 5.0) -> dict:
    """Wait for the Qt application to process pending events.

    Useful after clicks or other actions to let the UI settle.

    Args:
        timeout: Maximum seconds to wait

    Returns:
        {"success": bool, "message": str}
    """
    if not _app_state.process:
        return {"success": False, "message": "No app is running"}

    result = _send_command({
        "cmd": "wait_idle",
        "timeout": timeout,
    }, timeout=timeout + 2)

    if result.get("success"):
        return {"success": True, "message": "App is idle"}
    else:
        return {"success": False, "message": result.get("error", "Wait failed")}


@mcp.tool()
def close_app() -> dict:
    """Close the currently running application.

    Returns:
        {"success": bool, "message": str}
    """
    if not _app_state.process:
        return {"success": False, "message": "No app is running"}

    # Try graceful shutdown first
    _send_command({"cmd": "quit"}, timeout=2)

    _cleanup_app()
    return {"success": True, "message": "App closed"}


def main() -> None:
    """Run the MCP server."""
    logger.info("Starting Qt GUI Testing MCP Server")
    mcp.run(transport="stdio")


if __name__ == "__main__":
    main()
