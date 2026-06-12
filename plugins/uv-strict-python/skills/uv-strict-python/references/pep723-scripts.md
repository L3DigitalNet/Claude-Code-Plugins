# PEP 723: Inline Script Metadata

PEP 723 allows embedding dependency metadata directly in Python scripts, eliminating the need for separate `requirements.txt` or `pyproject.toml` files for simple scripts.

**Scope note:** the Python Tooling SSOT Standard does not (yet) cover single-file scripts — its §19.4 governs script *projects*, which use uv + `pyproject.toml`. This PEP 723 path is a plugin extension for genuinely single-file scripts. The moment a script grows past one file, gains tests, or needs CI, it becomes a project and follows the full standard.

## When to Use PEP 723

**Use for:**

- Single-file scripts with external dependencies
- Quick automation scripts
- Utility scripts shared between projects
- Scripts that need to be self-contained

**Don't use for:**

- Multi-file projects (use `pyproject.toml`)
- Reusable packages/libraries
- Projects requiring complex configuration

## Basic Syntax

The metadata block uses TOML format embedded in a special comment:

```python
#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = [
#     "requests",
#     "rich",
# ]
# ///

import requests
from rich import print

response = requests.get("https://api.example.com/data")
print(response.json())
```

## Running Scripts

```bash
# With uv (recommended)
uv run script.py

# Script handles its own dependencies automatically
./script.py  # If shebang is set
```

## Metadata Fields

### Required Python Version

```python
# /// script
# requires-python = ">=3.14"
# ///
```

### Dependencies

```python
# /// script
# dependencies = [
#     "requests",
#     "click",
#     "rich",
# ]
# ///
```

### Private Package Index

```python
# /// script
# dependencies = ["httpx"]
#
# [tool.uv]
# extra-index-url = ["https://pypi.company.com/simple/"]
# ///
```

## Complete Example

The coding standard applies to scripts too: `argparse` by default (Typer/Click only when the CLI is complex enough to justify them), a typed `main()` that returns an exit code, and parsing kept at the boundary.

```python
#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = [
#     "httpx",
#     "rich",
# ]
# ///

"""Fetch and display API data with nice formatting."""

import argparse
import sys
from collections.abc import Sequence

import httpx
from rich.console import Console
from rich.table import Table

console = Console()


def render(data: object, output_format: str) -> None:
    """Render the payload as a table when possible, JSON otherwise."""
    if output_format == "table" and isinstance(data, list) and data:
        table = Table()
        for key in data[0]:
            table.add_column(str(key))
        for item in data:
            table.add_row(*[str(value) for value in item.values()])
        console.print(table)
    else:
        console.print_json(data=data)


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Fetch and display API data.")
    parser.add_argument("url")
    parser.add_argument("--format", dest="output_format", default="table", choices=["table", "json"])
    args = parser.parse_args(argv)

    try:
        with httpx.Client() as client:
            response = client.get(args.url)
            response.raise_for_status()
            data = response.json()
    except httpx.HTTPError as exc:
        print(f"Request failed: {exc}", file=sys.stderr)
        return 1

    render(data, args.output_format)
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

## Creating Scripts with uv

```bash
# Create new script with metadata
uv init --script myscript.py

# Add dependency to existing script
uv add --script myscript.py requests

# Remove dependency from script
uv remove --script myscript.py requests
```

## Shebang Options

### Basic (requires uv in PATH)

```python
#!/usr/bin/env -S uv run --script
```

### With specific Python version

Only when the script genuinely needs a non-baseline interpreter — the standard's baseline is 3.14:

```python
#!/usr/bin/env -S uv run --python 3.14 --script
```

### Quiet mode (suppress uv output)

```python
#!/usr/bin/env -S uv run --quiet --script
```

## Examples by Use Case

### Data Processing Script

```python
#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = ["pandas", "openpyxl"]
# ///

import pandas as pd
import sys

df = pd.read_excel(sys.argv[1])
print(df.describe())
```

### Web Scraping Script

```python
#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = ["httpx", "beautifulsoup4", "lxml"]
# ///

import httpx
from bs4 import BeautifulSoup

response = httpx.get("https://example.com")
soup = BeautifulSoup(response.text, "lxml")
print(soup.title.string)
```

### CLI Tool Script

`argparse` is the default for small CLIs; reach for Typer/Click only when complexity justifies it (subcommand trees, rich completion):

```python
#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = ["rich"]
# ///

import argparse
import sys

from rich import print


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("name")
    args = parser.parse_args()
    print(f"[green]Hello, {args.name}![/green]")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

### Async Script

```python
#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = ["httpx"]
# ///

import asyncio
import httpx

async def main() -> None:
    async with httpx.AsyncClient() as client:
        urls = ["https://api1.example.com", "https://api2.example.com"]
        tasks = [client.get(url) for url in urls]
        responses = await asyncio.gather(*tasks)
        for r in responses:
            print(r.status_code)

asyncio.run(main())
```

## Best Practices

1. **Always specify `requires-python`** - Ensures compatibility
2. **Pin major versions for Python** - Use `>=3.14` not `==3.14`
3. **Omit version constraints for dependencies** - Use `uv add --script` to add dependencies; let uv select versions
4. **Keep scripts focused** - One script, one purpose
5. **Add docstring** - Document what the script does
6. **Use type hints** - Improves readability and catches errors

## Limitations

- No support for dependency groups
- No support for editable installs
- No support for local dependencies (use relative imports)
- No lockfile (versions may vary between runs)

For projects needing these features, use a full `pyproject.toml` setup instead.
