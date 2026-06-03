"""Put the plugin's scripts/ dir on sys.path so tests can import the
PEP 723 helper modules (build_research_index, validate_research_frontmatter,
_frontmatter) by name."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
