"""Verify type annotations on key functions."""
import sys
import inspect
import typing
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))
import main as qt_main


def test_cleanup_app_returns_none():
    # typing.get_type_hints() resolves 'None' annotation to NoneType on all Python versions
    hints = typing.get_type_hints(qt_main._cleanup_app)
    assert hints.get("return") is type(None), (
        "_cleanup_app must have '-> None' annotation"
    )


def test_main_returns_none():
    hints = typing.get_type_hints(qt_main.main)
    assert hints.get("return") is type(None), "main() must have '-> None' annotation"


def test_launch_app_script_path_optional():
    """script_path must be str | None, not just str."""
    # Get the underlying function from the FastMCP tool wrapper
    fn = getattr(qt_main.launch_app, "fn", qt_main.launch_app)
    sig = inspect.signature(fn)
    ann = sig.parameters["script_path"].annotation
    args = getattr(ann, "__args__", ())
    assert type(None) in args, (
        f"launch_app 'script_path' should be 'str | None', got {ann!r}"
    )


def test_launch_app_module_optional():
    fn = getattr(qt_main.launch_app, "fn", qt_main.launch_app)
    sig = inspect.signature(fn)
    ann = sig.parameters["module"].annotation
    args = getattr(ann, "__args__", ())
    assert type(None) in args, (
        f"launch_app 'module' should be 'str | None', got {ann!r}"
    )


def test_launch_app_working_dir_optional():
    fn = getattr(qt_main.launch_app, "fn", qt_main.launch_app)
    sig = inspect.signature(fn)
    ann = sig.parameters["working_dir"].annotation
    args = getattr(ann, "__args__", ())
    assert type(None) in args, (
        f"launch_app 'working_dir' should be 'str | None', got {ann!r}"
    )


def test_launch_app_python_paths_optional():
    fn = getattr(qt_main.launch_app, "fn", qt_main.launch_app)
    sig = inspect.signature(fn)
    ann = sig.parameters["python_paths"].annotation
    args = getattr(ann, "__args__", ())
    assert type(None) in args, (
        f"launch_app 'python_paths' should be 'list[str] | None', got {ann!r}"
    )
