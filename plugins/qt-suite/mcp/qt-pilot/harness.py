#!/usr/bin/env python3
"""Qt Test Harness - Runs inside xvfb to provide Qt testing capabilities.

This script:
1. Loads and runs the user's Qt application
2. Listens on a Unix socket for commands from the MCP server
3. Executes commands using QTest and Qt introspection
4. Returns results as JSON

IMPORTANT: This runs in a separate process from the MCP server,
inside an xvfb virtual display.
"""

import argparse
import fnmatch
import importlib.util
import json
import os
import socket
import sys
import threading
from pathlib import Path

# Must import Qt before creating QApplication
from PySide6.QtCore import QCoreApplication, QTimer, Qt
from PySide6.QtGui import QGuiApplication
from PySide6.QtTest import QTest
from PySide6.QtWidgets import QApplication, QWidget


class CommandHandler:
    """Handles commands from the MCP server."""

    def __init__(self, app: QApplication):
        self.app = app

    def handle(self, command: dict) -> dict:
        """Dispatch command to appropriate handler."""
        cmd = command.get("cmd")

        handlers = {
            "ping": self._handle_ping,
            "screenshot": self._handle_screenshot,
            "click": self._handle_click,
            "click_at": self._handle_click_at,
            "hover": self._handle_hover,
            "type_text": self._handle_type_text,
            "press_key": self._handle_press_key,
            "find_widgets": self._handle_find_widgets,
            "list_all_widgets": self._handle_list_all_widgets,
            "get_widget_info": self._handle_get_widget_info,
            "trigger_action": self._handle_trigger_action,
            "list_actions": self._handle_list_actions,
            "wait_idle": self._handle_wait_idle,
            "quit": self._handle_quit,
        }

        handler = handlers.get(cmd)
        if not handler:
            return {"success": False, "error": f"Unknown command: {cmd}"}

        try:
            return handler(command)
        except Exception as e:
            return {"success": False, "error": str(e)}

    def _handle_ping(self, cmd: dict) -> dict:
        """Simple ping to check if harness is running."""
        return {"success": True, "message": "pong"}

    def _handle_screenshot(self, cmd: dict) -> dict:
        """Capture screenshot of the application."""
        output_path = cmd.get("path", "/tmp/screenshot.png")

        # Get the primary screen
        screen = QGuiApplication.primaryScreen()
        if not screen:
            return {"success": False, "error": "No screen available"}

        # Find visible windows and get the active/topmost one
        windows = self.app.topLevelWidgets()
        visible_windows = [w for w in windows if w.isVisible()]

        # Try to find the active window first (most likely the dialog on top)
        active_window = self.app.activeWindow()

        if active_window and active_window.isVisible():
            # Grab the active window (typically the topmost dialog)
            pixmap = screen.grabWindow(active_window.winId())
        elif visible_windows:
            # Sort by whether they're modal dialogs (dialogs on top)
            # Modal dialogs should be captured preferentially
            dialogs = [w for w in visible_windows if w.isModal()]
            if dialogs:
                pixmap = screen.grabWindow(dialogs[-1].winId())
            else:
                # Grab entire screen to capture all windows
                pixmap = screen.grabWindow(0)
        else:
            # Grab entire screen
            pixmap = screen.grabWindow(0)

        if pixmap.save(output_path):
            return {"success": True, "path": output_path}
        else:
            return {"success": False, "error": "Failed to save screenshot"}

    def _find_widget(self, name: str) -> QWidget | None:
        """Find a widget by its object name."""
        for window in self.app.topLevelWidgets():
            if window.objectName() == name:
                return window
            widget = window.findChild(QWidget, name)
            if widget:
                return widget
        return None

    def _handle_click(self, cmd: dict) -> dict:
        """Click a widget by name."""
        widget_name = cmd.get("widget_name")
        button_str = cmd.get("button", "left")

        widget = self._find_widget(widget_name)
        if not widget:
            return {"success": False, "error": f"Widget not found: {widget_name}"}

        # Map button string to Qt enum
        button_map = {
            "left": Qt.MouseButton.LeftButton,
            "right": Qt.MouseButton.RightButton,
            "middle": Qt.MouseButton.MiddleButton,
        }
        button = button_map.get(button_str, Qt.MouseButton.LeftButton)

        # Process pending events first
        self.app.processEvents()

        # Perform click
        QTest.mouseClick(widget, button)

        # Process events to handle the click
        self.app.processEvents()

        return {"success": True}

    def _handle_click_at(self, cmd: dict) -> dict:
        """Click at specific screen coordinates."""
        x = cmd.get("x", 0)
        y = cmd.get("y", 0)
        button_str = cmd.get("button", "left")

        # Map button string to Qt enum
        button_map = {
            "left": Qt.MouseButton.LeftButton,
            "right": Qt.MouseButton.RightButton,
            "middle": Qt.MouseButton.MiddleButton,
        }
        button = button_map.get(button_str, Qt.MouseButton.LeftButton)

        # Find the widget at the coordinates
        from PySide6.QtCore import QPoint
        global_pos = QPoint(x, y)

        # Get widget at position
        widget = self.app.widgetAt(global_pos)
        if not widget:
            return {"success": False, "error": f"No widget at position ({x}, {y})"}

        # Convert global pos to widget-local pos
        local_pos = widget.mapFromGlobal(global_pos)

        # Process pending events
        self.app.processEvents()

        # Perform click at the specific position
        QTest.mouseClick(widget, button, Qt.KeyboardModifier.NoModifier, local_pos)

        # Process events
        self.app.processEvents()

        return {"success": True, "widget_type": widget.__class__.__name__}

    def _handle_hover(self, cmd: dict) -> dict:
        """Hover over a widget by name."""
        widget_name = cmd.get("widget_name")

        widget = self._find_widget(widget_name)
        if not widget:
            return {"success": False, "error": f"Widget not found: {widget_name}"}

        # Process pending events
        self.app.processEvents()

        # Move mouse to widget center
        QTest.mouseMove(widget)

        # Process events
        self.app.processEvents()

        return {"success": True}

    def _handle_type_text(self, cmd: dict) -> dict:
        """Type text into a widget."""
        text = cmd.get("text", "")
        widget_name = cmd.get("widget_name")

        if widget_name:
            widget = self._find_widget(widget_name)
            if not widget:
                return {"success": False, "error": f"Widget not found: {widget_name}"}
        else:
            # Use focused widget
            widget = self.app.focusWidget()
            if not widget:
                return {"success": False, "error": "No focused widget"}

        # Process pending events
        self.app.processEvents()

        # Type the text
        QTest.keyClicks(widget, text)

        # Process events
        self.app.processEvents()

        return {"success": True}

    def _handle_press_key(self, cmd: dict) -> dict:
        """Press a key with optional modifiers."""
        key_name = cmd.get("key", "")
        modifiers = cmd.get("modifiers", [])

        # Map key names to Qt keys - comprehensive list
        key_map = {
            # Navigation
            "Enter": Qt.Key.Key_Enter,
            "Return": Qt.Key.Key_Return,
            "Tab": Qt.Key.Key_Tab,
            "Escape": Qt.Key.Key_Escape,
            "Backspace": Qt.Key.Key_Backspace,
            "Delete": Qt.Key.Key_Delete,
            "Space": Qt.Key.Key_Space,
            "Up": Qt.Key.Key_Up,
            "Down": Qt.Key.Key_Down,
            "Left": Qt.Key.Key_Left,
            "Right": Qt.Key.Key_Right,
            "Home": Qt.Key.Key_Home,
            "End": Qt.Key.Key_End,
            "PageUp": Qt.Key.Key_PageUp,
            "PageDown": Qt.Key.Key_PageDown,
            "Insert": Qt.Key.Key_Insert,
            # Function keys
            "F1": Qt.Key.Key_F1,
            "F2": Qt.Key.Key_F2,
            "F3": Qt.Key.Key_F3,
            "F4": Qt.Key.Key_F4,
            "F5": Qt.Key.Key_F5,
            "F6": Qt.Key.Key_F6,
            "F7": Qt.Key.Key_F7,
            "F8": Qt.Key.Key_F8,
            "F9": Qt.Key.Key_F9,
            "F10": Qt.Key.Key_F10,
            "F11": Qt.Key.Key_F11,
            "F12": Qt.Key.Key_F12,
            # Punctuation and symbols
            "Comma": Qt.Key.Key_Comma,
            ",": Qt.Key.Key_Comma,
            "Period": Qt.Key.Key_Period,
            ".": Qt.Key.Key_Period,
            "Semicolon": Qt.Key.Key_Semicolon,
            ";": Qt.Key.Key_Semicolon,
            "Colon": Qt.Key.Key_Colon,
            ":": Qt.Key.Key_Colon,
            "Slash": Qt.Key.Key_Slash,
            "/": Qt.Key.Key_Slash,
            "Backslash": Qt.Key.Key_Backslash,
            "\\": Qt.Key.Key_Backslash,
            "Minus": Qt.Key.Key_Minus,
            "-": Qt.Key.Key_Minus,
            "Plus": Qt.Key.Key_Plus,
            "+": Qt.Key.Key_Plus,
            "Equal": Qt.Key.Key_Equal,
            "=": Qt.Key.Key_Equal,
            "BracketLeft": Qt.Key.Key_BracketLeft,
            "[": Qt.Key.Key_BracketLeft,
            "BracketRight": Qt.Key.Key_BracketRight,
            "]": Qt.Key.Key_BracketRight,
            "BraceLeft": Qt.Key.Key_BraceLeft,
            "{": Qt.Key.Key_BraceLeft,
            "BraceRight": Qt.Key.Key_BraceRight,
            "}": Qt.Key.Key_BraceRight,
            "Apostrophe": Qt.Key.Key_Apostrophe,
            "'": Qt.Key.Key_Apostrophe,
            "QuoteDbl": Qt.Key.Key_QuoteDbl,
            '"': Qt.Key.Key_QuoteDbl,
            "Underscore": Qt.Key.Key_Underscore,
            "_": Qt.Key.Key_Underscore,
            "At": Qt.Key.Key_At,
            "@": Qt.Key.Key_At,
            "NumberSign": Qt.Key.Key_NumberSign,
            "#": Qt.Key.Key_NumberSign,
            "Dollar": Qt.Key.Key_Dollar,
            "$": Qt.Key.Key_Dollar,
            "Percent": Qt.Key.Key_Percent,
            "%": Qt.Key.Key_Percent,
            "Ampersand": Qt.Key.Key_Ampersand,
            "&": Qt.Key.Key_Ampersand,
            "Asterisk": Qt.Key.Key_Asterisk,
            "*": Qt.Key.Key_Asterisk,
            "ParenLeft": Qt.Key.Key_ParenLeft,
            "(": Qt.Key.Key_ParenLeft,
            "ParenRight": Qt.Key.Key_ParenRight,
            ")": Qt.Key.Key_ParenRight,
            "Less": Qt.Key.Key_Less,
            "<": Qt.Key.Key_Less,
            "Greater": Qt.Key.Key_Greater,
            ">": Qt.Key.Key_Greater,
            "Question": Qt.Key.Key_Question,
            "?": Qt.Key.Key_Question,
            "Exclam": Qt.Key.Key_Exclam,
            "!": Qt.Key.Key_Exclam,
            "AsciiTilde": Qt.Key.Key_AsciiTilde,
            "~": Qt.Key.Key_AsciiTilde,
            "QuoteLeft": Qt.Key.Key_QuoteLeft,
            "`": Qt.Key.Key_QuoteLeft,
            "Bar": Qt.Key.Key_Bar,
            "|": Qt.Key.Key_Bar,
            "AsciiCircum": Qt.Key.Key_AsciiCircum,
            "^": Qt.Key.Key_AsciiCircum,
        }

        # Single character keys (letters and numbers)
        if len(key_name) == 1:
            if key_name in key_map:
                key = key_map[key_name]
            elif key_name.isalpha():
                key = getattr(Qt.Key, f"Key_{key_name.upper()}", None)
            elif key_name.isdigit():
                key = getattr(Qt.Key, f"Key_{key_name}", None)
            else:
                key = None
        else:
            key = key_map.get(key_name)

        if not key:
            return {"success": False, "error": f"Unknown key: {key_name}"}

        # Map modifiers
        mod_map = {
            "Ctrl": Qt.KeyboardModifier.ControlModifier,
            "Shift": Qt.KeyboardModifier.ShiftModifier,
            "Alt": Qt.KeyboardModifier.AltModifier,
            "Meta": Qt.KeyboardModifier.MetaModifier,
        }

        mod_flags = Qt.KeyboardModifier.NoModifier
        for mod in modifiers:
            if mod in mod_map:
                mod_flags |= mod_map[mod]

        # Get focused widget
        widget = self.app.focusWidget()
        if not widget:
            # Use first visible window
            windows = [w for w in self.app.topLevelWidgets() if w.isVisible()]
            widget = windows[0] if windows else None

        if not widget:
            return {"success": False, "error": "No widget to send key to"}

        # Process pending events
        self.app.processEvents()

        # Press the key
        QTest.keyClick(widget, key, mod_flags)

        # Process events
        self.app.processEvents()

        return {"success": True}

    def _handle_find_widgets(self, cmd: dict) -> dict:
        """Find all widgets matching a pattern."""
        pattern = cmd.get("pattern", "*")
        widgets = []

        def collect_widgets(widget: QWidget):
            """Recursively collect named widgets."""
            name = widget.objectName()
            if name and fnmatch.fnmatch(name, pattern):
                widgets.append({
                    "name": name,
                    "type": widget.__class__.__name__,
                    "visible": widget.isVisible(),
                    "enabled": widget.isEnabled(),
                })
            for child in widget.findChildren(QWidget):
                name = child.objectName()
                if name and fnmatch.fnmatch(name, pattern):
                    # Avoid duplicates
                    if not any(w["name"] == name for w in widgets):
                        widgets.append({
                            "name": name,
                            "type": child.__class__.__name__,
                            "visible": child.isVisible(),
                            "enabled": child.isEnabled(),
                        })

        for window in self.app.topLevelWidgets():
            collect_widgets(window)

        return {"success": True, "widgets": widgets}

    def _handle_list_all_widgets(self, cmd: dict) -> dict:
        """List all widgets with their coordinates (even unnamed ones)."""
        include_invisible = cmd.get("include_invisible", False)
        widgets = []

        def collect_all(widget: QWidget, depth: int = 0):
            """Recursively collect all widgets."""
            if not include_invisible and not widget.isVisible():
                return

            geom = widget.geometry()
            try:
                global_pos = widget.mapToGlobal(widget.rect().topLeft())
                gx, gy = global_pos.x(), global_pos.y()
            except Exception:
                gx, gy = 0, 0

            widgets.append({
                "name": widget.objectName() or "(unnamed)",
                "type": widget.__class__.__name__,
                "visible": widget.isVisible(),
                "enabled": widget.isEnabled(),
                "x": geom.x(),
                "y": geom.y(),
                "width": geom.width(),
                "height": geom.height(),
                "global_x": gx,
                "global_y": gy,
                "depth": depth,
            })

            for child in widget.children():
                if isinstance(child, QWidget):
                    collect_all(child, depth + 1)

        for window in self.app.topLevelWidgets():
            if include_invisible or window.isVisible():
                collect_all(window)

        return {"success": True, "widgets": widgets, "count": len(widgets)}

    def _handle_trigger_action(self, cmd: dict) -> dict:
        """Trigger a QAction by its object name."""
        action_name = cmd.get("action_name")

        if not action_name:
            return {"success": False, "error": "action_name is required"}

        # Search for the action in all windows and menus
        from PySide6.QtGui import QAction
        from PySide6.QtWidgets import QMenuBar, QMenu

        def find_action(widget) -> QAction | None:
            """Recursively find action by name."""
            # Check direct actions
            for action in widget.actions():
                if action.objectName() == action_name:
                    return action
                # Check submenus
                menu = action.menu()
                if menu:
                    found = find_action(menu)
                    if found:
                        return found

            # Check child widgets
            for child in widget.findChildren(QWidget):
                if hasattr(child, 'actions'):
                    for action in child.actions():
                        if action.objectName() == action_name:
                            return action

            return None

        # Search in all windows
        for window in self.app.topLevelWidgets():
            if not window.isVisible():
                continue

            # Check menubar if it's a main window
            if hasattr(window, 'menuBar'):
                menubar = window.menuBar()
                if menubar:
                    action = find_action(menubar)
                    if action:
                        self.app.processEvents()
                        action.trigger()
                        self.app.processEvents()
                        return {"success": True, "action": action_name}

            # Check the window itself
            action = find_action(window)
            if action:
                self.app.processEvents()
                action.trigger()
                self.app.processEvents()
                return {"success": True, "action": action_name}

        return {"success": False, "error": f"Action not found: {action_name}"}

    def _handle_list_actions(self, cmd: dict) -> dict:
        """List all QActions in the application."""
        from PySide6.QtGui import QAction
        from PySide6.QtWidgets import QMenuBar, QMenu

        actions = []

        def collect_actions(widget, path=""):
            """Recursively collect actions."""
            for action in widget.actions():
                action_text = action.text().replace("&", "")  # Remove mnemonics
                action_path = f"{path}/{action_text}" if path else action_text

                if not action.isSeparator():
                    actions.append({
                        "name": action.objectName() or "(unnamed)",
                        "text": action_text,
                        "path": action_path,
                        "enabled": action.isEnabled(),
                        "checkable": action.isCheckable(),
                        "checked": action.isChecked() if action.isCheckable() else None,
                        "shortcut": action.shortcut().toString() if action.shortcut() else "",
                    })

                # Check submenus
                menu = action.menu()
                if menu:
                    collect_actions(menu, action_path)

        # Search in all visible windows
        for window in self.app.topLevelWidgets():
            if not window.isVisible():
                continue

            # Check menubar
            if hasattr(window, 'menuBar'):
                menubar = window.menuBar()
                if menubar:
                    collect_actions(menubar)

        return {"success": True, "actions": actions, "count": len(actions)}

    def _handle_get_widget_info(self, cmd: dict) -> dict:
        """Get detailed info about a widget."""
        widget_name = cmd.get("widget_name")

        widget = self._find_widget(widget_name)
        if not widget:
            return {"success": False, "error": f"Widget not found: {widget_name}"}

        # Get geometry
        geom = widget.geometry()
        global_pos = widget.mapToGlobal(widget.rect().topLeft())

        info = {
            "name": widget.objectName(),
            "type": widget.__class__.__name__,
            "visible": widget.isVisible(),
            "enabled": widget.isEnabled(),
            "width": geom.width(),
            "height": geom.height(),
            "x": geom.x(),
            "y": geom.y(),
            "global_x": global_pos.x(),
            "global_y": global_pos.y(),
            "has_focus": widget.hasFocus(),
        }

        # Add type-specific info
        if hasattr(widget, "text"):
            info["text"] = widget.text()
        if hasattr(widget, "isChecked"):
            info["checked"] = widget.isChecked()
        if hasattr(widget, "currentText"):
            info["current_text"] = widget.currentText()

        return {"success": True, "info": info}

    def _handle_wait_idle(self, cmd: dict) -> dict:
        """Wait for the application to finish processing events."""
        import time

        timeout = cmd.get("timeout", 5.0)
        start_time = time.time()

        # Process events repeatedly until the queue is empty or timeout
        while time.time() - start_time < timeout:
            # Process all pending events
            self.app.processEvents()

            # Small delay to allow async operations to queue new events
            time.sleep(0.05)

            # Process again to check if more events appeared
            self.app.processEvents()

        return {"success": True, "elapsed": time.time() - start_time}

    def _handle_quit(self, cmd: dict) -> dict:
        """Quit the application."""
        # Schedule quit for next event loop iteration
        QTimer.singleShot(0, self.app.quit)
        return {"success": True}


class SocketServer:
    """Unix socket server for receiving commands."""

    def __init__(self, socket_path: str, handler: CommandHandler):
        self.socket_path = socket_path
        self.handler = handler
        self.running = False
        self.server_socket = None

    def start(self):
        """Start the socket server in a background thread."""
        # Remove existing socket file
        if os.path.exists(self.socket_path):
            os.unlink(self.socket_path)

        self.server_socket = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.server_socket.bind(self.socket_path)
        self.server_socket.listen(5)
        self.server_socket.settimeout(1.0)
        self.running = True

        thread = threading.Thread(target=self._server_loop, daemon=True)
        thread.start()

    def stop(self):
        """Stop the socket server."""
        self.running = False
        if self.server_socket:
            self.server_socket.close()
        if os.path.exists(self.socket_path):
            os.unlink(self.socket_path)

    def _server_loop(self):
        """Main server loop."""
        while self.running:
            try:
                conn, _ = self.server_socket.accept()
                self._handle_connection(conn)
            except socket.timeout:
                continue
            except Exception as e:
                if self.running:
                    print(f"Socket error: {e}", file=sys.stderr)

    def _handle_connection(self, conn: socket.socket):
        """Handle a single connection."""
        try:
            conn.settimeout(30.0)
            data = b""
            while True:
                chunk = conn.recv(4096)
                if not chunk:
                    break
                data += chunk
                if b"\n" in data:
                    break

            if data:
                command = json.loads(data.decode().strip())
                # Execute command in the main thread via Qt
                result = self.handler.handle(command)
                response = json.dumps(result) + "\n"
                conn.sendall(response.encode())

        except Exception as e:
            error_response = json.dumps({"success": False, "error": str(e)}) + "\n"
            try:
                conn.sendall(error_response.encode())
            except Exception:
                pass
        finally:
            conn.close()


def load_script(script_path: str):
    """Load and execute a Python script."""
    script_path = Path(script_path).resolve()

    # Add script directory to path
    sys.path.insert(0, str(script_path.parent))

    # Load the module
    spec = importlib.util.spec_from_file_location("__main__", script_path)
    module = importlib.util.module_from_spec(spec)

    # Set up __main__ module
    sys.modules["__main__"] = module
    module.__file__ = str(script_path)

    # Execute the script
    spec.loader.exec_module(module)


def load_module(module_path: str):
    """Load and run a Python module (like python -m)."""
    # Import the module
    parts = module_path.split(".")
    module = __import__(module_path)
    for part in parts[1:]:
        module = getattr(module, part)

    # If it has a main() function, call it
    if hasattr(module, "main"):
        module.main()


def main():
    parser = argparse.ArgumentParser(description="Qt Test Harness")
    parser.add_argument("--socket", required=True, help="Unix socket path for commands")
    parser.add_argument("--script", help="Python script to run")
    parser.add_argument("--module", help="Python module to run (like -m)")
    parser.add_argument("--working-dir", help="Working directory (added to sys.path)")
    parser.add_argument(
        "--python-path",
        action="append",
        dest="python_paths",
        help="Additional Python paths to add to sys.path (can be repeated)",
    )
    args = parser.parse_args()

    # Add additional Python paths FIRST (in reverse order so first arg is first in path)
    if args.python_paths:
        for path in reversed(args.python_paths):
            abs_path = os.path.abspath(path)
            if abs_path not in sys.path:
                sys.path.insert(0, abs_path)
                print(f"Added to sys.path: {abs_path}", file=sys.stderr)

    # Add working directory to Python path if specified
    if args.working_dir:
        sys.path.insert(0, args.working_dir)
        os.chdir(args.working_dir)

    # Don't create QApplication yet - let the script create it
    # We'll hook into the existing one after the script loads

    socket_path = args.socket
    handler = None
    server = None

    def setup_harness():
        """Set up the harness after QApplication exists."""
        nonlocal handler, server
        app = QApplication.instance()
        if app:
            handler = CommandHandler(app)
            server = SocketServer(socket_path, handler)
            server.start()
            print(f"Harness started, socket: {socket_path}", file=sys.stderr)

    # Patch QApplication to hook our setup after it's created
    original_init = QApplication.__init__

    def patched_init(self, *args_init, **kwargs):
        original_init(self, *args_init, **kwargs)
        # Set up harness after QApplication is created
        QTimer.singleShot(100, setup_harness)

    QApplication.__init__ = patched_init

    # Load the user's application
    try:
        if args.script:
            load_script(args.script)
        elif args.module:
            load_module(args.module)
    except SystemExit as e:
        # Script called sys.exit() or app.exec() returned
        # This is normal - the script ran and exited
        if server:
            server.stop()
        sys.exit(e.code if e.code is not None else 0)
    except Exception as e:
        print(f"Error loading app: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc(file=sys.stderr)
        if server:
            server.stop()
        sys.exit(1)

    # If we get here, the script didn't start an event loop
    # Check if QApplication exists and start it
    app = QApplication.instance()
    if app and not app.closingDown():
        setup_harness()  # Make sure harness is set up
        sys.exit(app.exec())


if __name__ == "__main__":
    main()
