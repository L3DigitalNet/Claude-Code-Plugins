"""Shared fixtures for qt-pilot unit tests."""
import sys
from pathlib import Path

# Ensure main.py is importable without installing as a package
sys.path.insert(0, str(Path(__file__).parent.parent))
