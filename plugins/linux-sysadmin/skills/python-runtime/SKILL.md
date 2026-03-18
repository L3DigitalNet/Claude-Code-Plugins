---
name: python-runtime
description: >
  Python runtime management on Linux: version installation, virtual environments,
  pip, uv, pyenv, system vs user packages, PATH configuration, and troubleshooting.
  Covers system Python, pyenv multi-version management, venv/virtualenv, pip, and uv
  as the modern fast alternative.
  MUST consult when installing, configuring, or troubleshooting Python.
triggerPhrases:
  - python
  - python3
  - pip
  - pip3
  - pyenv
  - venv
  - virtualenv
  - uv
  - python version
  - python install
  - python virtual environment
  - python path
  - site-packages
  - python build
  - python compile
  - deadsnakes PPA
  - python alternatives
  - python-is-python3
  - __pycache__
  - pip install
  - pip freeze
  - requirements.txt
  - pyproject.toml
  - python packaging
last_verified: "2026-03"
globs:
  - "**/pyproject.toml"
  - "**/setup.py"
  - "**/setup.cfg"
  - "**/requirements*.txt"
  - "**/Pipfile"
  - "**/uv.lock"
  - "**/.python-version"
  - "**/tox.ini"
---

## Identity

| Field | Value |
|-------|-------|
| System Python binary | `/usr/bin/python3` (distro-managed; do not modify with pip on modern distros) |
| System site-packages | `/usr/lib/python3.x/dist-packages` (Debian/Ubuntu), `/usr/lib/python3.x/site-packages` (Fedora/Arch) |
| User site-packages | `~/.local/lib/python3.x/site-packages` (pip install --user target) |
| User bin | `~/.local/bin` (pip-installed scripts land here; must be on PATH) |
| pyenv root | `~/.pyenv` (versions in `~/.pyenv/versions/`, shims in `~/.pyenv/shims/`) |
| uv data | `~/.local/share/uv` (Python versions in `uv/python/`, tools in `uv/tools/`) |
| uv cache | `~/.cache/uv` (or `$XDG_CACHE_HOME/uv`) |
| uv executables | `~/.local/bin` (tools and Python symlinks) |
| Key env vars | `PYTHONPATH`, `VIRTUAL_ENV`, `PYENV_ROOT`, `UV_CACHE_DIR`, `UV_PYTHON_INSTALL_DIR`, `UV_TOOL_DIR` |

## Quick Start

```bash
# Install pyenv for multi-version management
curl -fsSL https://pyenv.run | bash

# Install Python 3.12 via pyenv
pyenv install 3.12

# Create a virtual environment
python3 -m venv .venv && source .venv/bin/activate
```

## Key Operations

| Task | Command |
|------|---------|
| Check Python version | `python3 --version` |
| Find Python location | `which python3` / `type -a python3` |
| Show sys.path | `python3 -c "import sys; print('\n'.join(sys.path))"` |
| Show site-packages dir | `python3 -m site --user-site` |
| Install Python (Ubuntu/Debian) | `sudo apt install python3.12 python3.12-venv python3.12-dev` |
| Install Python (deadsnakes PPA) | `sudo add-apt-repository ppa:deadsnakes/ppa && sudo apt update && sudo apt install python3.12` |
| Install Python (Fedora) | `sudo dnf install python3.12` |
| Install Python (pyenv) | `pyenv install 3.12` |
| Install Python (uv) | `uv python install 3.12` |
| Create venv | `python3 -m venv .venv` |
| Create venv (uv) | `uv venv` (uses `.python-version` or discovers Python) |
| Activate venv | `source .venv/bin/activate` |
| Deactivate venv | `deactivate` |
| pip install | `pip install requests` (inside a venv) |
| pip from requirements | `pip install -r requirements.txt` |
| pip freeze | `pip freeze > requirements.txt` |
| uv add dependency | `uv add requests` |
| uv sync environment | `uv sync` |
| uv run command | `uv run python main.py` |

## Version Management

### pyenv
Installs multiple Python versions in `~/.pyenv/versions/` using shims to intercept `python` calls.

- **Install pyenv**: `curl -fsSL https://pyenv.run | bash` (then add shell init to `~/.bashrc`)
- **Shell init** (add to `~/.bashrc` or `~/.zshrc`):
  ```bash
  export PYENV_ROOT="$HOME/.pyenv"
  [[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
  eval "$(pyenv init - bash)"
  ```
- **List available versions**: `pyenv install --list`
- **Install a version**: `pyenv install 3.12`
- **Set global default**: `pyenv global 3.12` (writes to `~/.pyenv/version`)
- **Set directory-local version**: `pyenv local 3.12` (writes `.python-version` in cwd)
- **Set shell-session version**: `pyenv shell 3.12` (sets `$PYENV_VERSION`)
- **List installed versions**: `pyenv versions`
- **Uninstall**: `pyenv uninstall 3.12`
- **Rehash shims**: `pyenv rehash` (run after installing packages that provide scripts)

### Build dependencies for pyenv
pyenv compiles Python from source. Install build dependencies first:

**Ubuntu/Debian:**
```bash
sudo apt install make build-essential libssl-dev zlib1g-dev libbz2-dev \
  libreadline-dev libsqlite3-dev curl git libncursesw5-dev xz-utils \
  tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev
```

**Fedora:**
```bash
sudo dnf install make gcc patch zlib-devel bzip2 bzip2-devel readline-devel \
  sqlite sqlite-devel openssl-devel tk-devel libffi-devel xz-devel \
  libuuid-devel gdbm-libs libnsl2
```

### uv python management
uv can install and manage Python versions directly, with no build dependencies needed (it downloads prebuilt binaries).

- **Install latest**: `uv python install`
- **Install specific version**: `uv python install 3.12`
- **Install multiple**: `uv python install 3.11 3.12 3.13`
- **List installed and available**: `uv python list`
- **Pin version for project**: `uv python pin 3.12` (writes `.python-version`)
- **Upgrade patch version**: `uv python upgrade 3.12`

### deadsnakes PPA (Ubuntu only)
Provides prebuilt Python packages for versions not in the default Ubuntu repos.

```bash
sudo add-apt-repository ppa:deadsnakes/ppa
sudo apt update
sudo apt install python3.11 python3.11-venv python3.11-dev
```

Deadsnakes packages install alongside system Python without replacing it. Each version gets its own binary (e.g., `python3.11`). Not recommended for security-critical production environments since updates depend on the PPA maintainers.

### update-alternatives (Debian/Ubuntu)
Manages the `python3` symlink when multiple system-installed versions exist.

```bash
sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.10 1
sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 2
sudo update-alternatives --config python3   # interactive selection
```

Higher priority number wins in auto mode. Use with caution: changing system `python3` can break distro tools that depend on a specific version.

### Building Python from source
When the distro version is too old and pyenv/uv are not an option.

```bash
# Install build deps (Ubuntu/Debian)
sudo apt install build-essential libssl-dev zlib1g-dev libbz2-dev \
  libreadline-dev libsqlite3-dev libffi-dev liblzma-dev

# Download, configure, build
wget https://www.python.org/ftp/python/3.12.0/Python-3.12.0.tgz
tar xzf Python-3.12.0.tgz
cd Python-3.12.0
./configure --prefix=/opt/python-3.12 --enable-optimizations --with-ensurepip=install
make -j$(nproc)
sudo make altinstall    # altinstall avoids overwriting /usr/bin/python3
```

`--enable-optimizations` enables profile-guided optimization (PGO): compiles twice with profiling, yielding ~10-20% faster runtime at the cost of significantly longer build time. `altinstall` installs as `python3.12` instead of overwriting `python3`.

## Virtual Environments

### Why venvs matter
Virtual environments isolate project dependencies from the system Python and from other projects. Each venv has its own `site-packages`, `pip`, and a `python` symlink pointing to the base interpreter.

### python -m venv (stdlib)
```bash
python3 -m venv .venv              # create
source .venv/bin/activate           # activate (bash/zsh)
source .venv/bin/activate.fish      # activate (fish)
.venv/bin/python script.py          # run without activating
deactivate                          # return to system Python
```

### uv venv
```bash
uv venv                            # creates .venv using discovered Python
uv venv --python 3.12              # creates .venv with specific version
uv venv myenv                      # creates named venv directory
```

### PATH mechanics
Activation prepends `.venv/bin` to `$PATH`, making the venv's `python` and `pip` resolve first. The `VIRTUAL_ENV` environment variable is set to the venv root. `deactivate` reverses both changes.

Without activation, use absolute paths: `.venv/bin/python`, `.venv/bin/pip`. uv commands (`uv run`, `uv sync`) detect and use `.venv` automatically without activation.

### virtualenv (third-party)
`virtualenv` is an older, more featureful alternative to `venv`. It creates venvs faster (caches seed packages), supports Python 2, and works with Pythons that lack `ensurepip`. Mostly replaced by `python -m venv` for Python 3 work.

```bash
pip install virtualenv
virtualenv .venv
```

## Package Installation

### pip
```bash
pip install requests                         # install from PyPI
pip install 'requests>=2.28,<3'              # version constraints
pip install -r requirements.txt              # from requirements file
pip install -c constraints.txt -r reqs.txt   # with constraints
pip install -e .                             # editable install (dev mode)
pip install -e '.[dev,test]'                 # editable with extras
pip install --index-url https://custom.pypi.org/simple/ pkg   # custom index
pip freeze > requirements.txt               # snapshot installed versions
pip uninstall requests                       # remove
pip list --outdated                          # show upgradeable packages
pip install --upgrade requests               # upgrade single package
```

### uv (pip-compatible interface)
Drop-in replacement for pip commands, 10-100x faster.

```bash
uv pip install requests                      # install
uv pip install -r requirements.txt           # from requirements
uv pip compile requirements.in -o requirements.txt   # lock deps (like pip-tools)
uv pip sync requirements.txt                 # sync env to match lockfile exactly
uv pip freeze                                # list installed
uv pip list                                  # list with metadata
uv pip uninstall requests                    # remove
```

### uv (project interface)
Higher-level project management with lockfiles.

```bash
uv init myproject                            # scaffold project with pyproject.toml
uv add requests                              # add dependency (updates pyproject.toml + uv.lock)
uv add --dev pytest                          # add dev dependency
uv add 'requests>=2.28'                      # with version constraint
uv remove requests                           # remove dependency
uv lock                                      # regenerate uv.lock
uv lock --upgrade-package requests           # upgrade specific package in lock
uv sync                                      # install all deps from lockfile
uv sync --frozen                             # sync without checking lockfile freshness
uv sync --no-dev                             # production: skip dev dependencies
uv run python main.py                        # run in project environment (auto-syncs)
uv run -- flask run -p 3000                  # pass flags with --
```

### pyproject.toml vs requirements.txt
`pyproject.toml` is the modern standard (PEP 621) for declaring project metadata and dependencies. `requirements.txt` is a flat list of pinned versions, best used as a lockfile output. Use `uv lock` or `pip-compile` (from pip-tools) to generate locked requirements from `pyproject.toml`.

### Constraint files
Pin transitive dependency versions without declaring direct dependencies: `pip install -c constraints.txt -r requirements.txt`. The constraint file restricts versions but does not cause packages to be installed.

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `error: externally-managed-environment` | PEP 668: distro blocks global pip install | Use a venv: `python3 -m venv .venv && source .venv/bin/activate` |
| `ModuleNotFoundError: No module named '_ssl'` | Python built without OpenSSL headers | Install `libssl-dev` (apt) or `openssl-devel` (dnf), rebuild Python |
| `pip: command not found` (inside venv) | venv created without ensurepip | `python3 -m ensurepip --upgrade` inside the venv, or install `python3.x-venv` package |
| `No module named 'venv'` | Missing venv package on Debian/Ubuntu | `sudo apt install python3.x-venv` (replace x with version) |
| `ERROR: Could not build wheels` | Missing C compiler or dev headers | Install `build-essential` and `python3.x-dev` |
| pip installs to wrong Python | Multiple Pythons; pip resolves to system | Use `python3.12 -m pip install` to target exact version, or activate a venv |
| `SSL: CERTIFICATE_VERIFY_FAILED` | Stale CA bundle or corporate proxy | `pip install --trusted-host pypi.org --trusted-host files.pythonhosted.org`, or update `ca-certificates` |
| pip version conflict on upgrade | pip tries to overwrite itself mid-upgrade | `python3 -m pip install --upgrade pip` (invoke via module, not binary) |
| `pyenv: python3.12 not found` | Build deps missing; pyenv compile failed silently | Check `~/.pyenv/build.log`; install build deps (see Version Management section) |
| Broken system Python after pip install | pip overwrote distro-managed packages | Reinstall distro Python packages: `sudo apt install --reinstall python3 python3-minimal` |

## Pain Points
- **System Python is not yours**: On modern distros (Ubuntu 23.04+, Debian 12+, Arch), PEP 668 blocks `pip install` outside a venv. This is deliberate: system Python packages are managed by apt/dnf/pacman. Always use a venv.
- **PEP 668 distro enforcement**: Ubuntu 23.04+, Debian 12+ (Bookworm), and Arch Linux enforce PEP 668. Fedora proposed it for Fedora 38 but has not implemented it. The marker file lives at `/usr/lib/python3.x/EXTERNALLY-MANAGED`. Deleting it bypasses the check but risks breaking system tools. Prefer `--break-system-packages` over deleting the file if you must override (at least it signals intent).
- **`pip install --user` is also blocked by PEP 668**: Not just system-wide installs. Use a venv instead of `~/.local/lib/`.
- **uv vs pip speed**: uv is 10-100x faster than pip for resolution and installation. It also handles Python version management, replacing pyenv for many workflows. Consider uv as the default for new projects.
- **Reproducible installs need lockfiles**: `pip freeze` captures the current state but drifts over time. Use `uv lock` (generates `uv.lock`) or `pip-compile` (generates `requirements.txt` from `requirements.in`/`pyproject.toml`) for reproducible builds.
- **`python` vs `python3`**: Some distros only ship `python3`. The `python-is-python3` package (Ubuntu/Debian) creates the `python` -> `python3` symlink. In venvs, both `python` and `python3` always work.
- **`__pycache__` and `.pyc` files**: Bytecode cache dirs created automatically. Safe to delete. Add to `.gitignore`. Suppress creation with `PYTHONDONTWRITEBYTECODE=1`.

## See Also

- `package-managers` — System package managers (apt, dnf, pacman) for installing Python itself
- `docker` — Containerized Python environments and multi-stage builds
- `node-runtime` — Node.js runtime management (similar version/env patterns)
- **rust-runtime** — Rust toolchain management; systems programming complement to Python

## References
See `references/` for:
- `docs.md` — official documentation links (Python, pip, uv, pyenv, PEP 668)
- `cheatsheet.md` — side-by-side command comparison: pip vs uv vs pyenv
- `common-patterns.md` — practical workflows: new project setup, migration, CI/CD, Docker, multi-version testing
