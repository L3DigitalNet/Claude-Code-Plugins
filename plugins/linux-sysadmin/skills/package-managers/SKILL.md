---
name: package-managers
description: >
  Linux package management: apt (Debian/Ubuntu), dnf (Fedora/RHEL), pacman (Arch),
  and apk (Alpine). Installation, removal, upgrades, repository management, pinning,
  cache maintenance, and troubleshooting.
  MUST consult when managing packages with apt, dnf, pacman, or apk.
triggerPhrases:
  - apt
  - apt-get
  - dnf
  - yum
  - pacman
  - apk
  - package manager
  - install package
  - remove package
  - upgrade packages
  - repository
  - PPA
  - COPR
  - AUR
  - package search
  - dependency resolution
  - held packages
  - package pinning
last_verified: "2026-03"
globs:
  - "**/sources.list"
  - "**/sources.list.d/*.list"
  - "**/sources.list.d/*.sources"
  - "**/dnf.conf"
  - "**/yum.repos.d/*.repo"
  - "**/pacman.conf"
  - "**/apk/repositories"
---

## Identity

| Distro family | Manager | Config | Cache | Lock files |
|---------------|---------|--------|-------|------------|
| Debian/Ubuntu | `apt` / `apt-get` / `dpkg` | `/etc/apt/sources.list`, `/etc/apt/sources.list.d/`, `/etc/apt/apt.conf.d/` | `/var/cache/apt/archives/` | `/var/lib/dpkg/lock`, `/var/lib/dpkg/lock-frontend`, `/var/lib/apt/lists/lock`, `/var/cache/apt/archives/lock` |
| Fedora/RHEL | `dnf` (successor to `yum`) | `/etc/dnf/dnf.conf`, `/etc/yum.repos.d/*.repo` | `/var/cache/dnf/` | `/var/cache/dnf/metadata_lock.pid` |
| Arch | `pacman` | `/etc/pacman.conf`, `/etc/pacman.d/mirrorlist` | `/var/cache/pacman/pkg/` | `/var/lib/pacman/db.lck` |
| Alpine | `apk` | `/etc/apk/repositories`, `/etc/apk/world` | `/var/cache/apk/` | No traditional lock file; apk uses atomic operations |

## Quick Start

```bash
# Update package index (Debian/Ubuntu)
sudo apt update

# Install a package
sudo apt install vim

# Search for a package
apt search nginx
```

## Key Operations

### Install

| Task | Command |
|------|---------|
| Install (apt) | `apt install <pkg>` |
| Install (dnf) | `dnf install <pkg>` |
| Install (pacman) | `pacman -S <pkg>` |
| Install (apk) | `apk add <pkg>` |

### Remove

| Task | Command |
|------|---------|
| Remove only (apt) | `apt remove <pkg>` |
| Remove + unused deps (apt) | `apt autoremove <pkg>` |
| Remove (dnf) | `dnf remove <pkg>` (auto-removes unused deps when `clean_requirements_on_remove=True`) |
| Remove only (pacman) | `pacman -R <pkg>` |
| Remove + deps + config (pacman) | `pacman -Rns <pkg>` |
| Remove (apk) | `apk del <pkg>` (auto-removes unused deps) |

### Search

| Task | Command |
|------|---------|
| Search repos (apt) | `apt search <term>` |
| Search installed (apt) | `apt list --installed \| grep <term>` |
| Search repos (dnf) | `dnf search <term>` |
| Search installed (dnf) | `dnf list installed \| grep <term>` |
| Search repos (pacman) | `pacman -Ss <term>` |
| Search installed (pacman) | `pacman -Qs <term>` |
| Search repos (apk) | `apk search <term>` |
| Search installed (apk) | `apk info -vv \| grep <term>` |

### Update Index / Upgrade All

| Task | Command |
|------|---------|
| Update index (apt) | `apt update` |
| Upgrade all (apt) | `apt upgrade` |
| Combined (apt) | `apt update && apt upgrade` |
| Upgrade all (dnf) | `dnf upgrade` (index updated automatically) |
| Full sync (pacman) | `pacman -Syu` (never `pacman -Sy` alone!) |
| Update + upgrade (apk) | `apk update && apk upgrade` |

**pacman warning**: Never run `pacman -Sy` without `-u`. Partial upgrades (`-Sy` then installing packages) break Arch systems because libraries won't match. Always use `pacman -Syu`.

### List Installed

| Task | Command |
|------|---------|
| List installed (apt) | `apt list --installed` or `dpkg -l` |
| List installed (dnf) | `dnf list installed` |
| List installed (pacman) | `pacman -Q` |
| List installed (apk) | `apk info` or `apk list --installed` |

### Show Package Info

| Task | Command |
|------|---------|
| Info from repos (apt) | `apt show <pkg>` |
| Info installed (apt) | `dpkg -s <pkg>` |
| Info (dnf) | `dnf info <pkg>` |
| Info from repos (pacman) | `pacman -Si <pkg>` |
| Info installed (pacman) | `pacman -Qi <pkg>` |
| Info (apk) | `apk info <pkg>` |

### Clean Cache

| Task | Command |
|------|---------|
| Partial clean (apt) | `apt autoclean` (only obsolete) |
| Full clean (apt) | `apt clean` (all cached .debs) |
| Clean packages (dnf) | `dnf clean packages` |
| Full clean (dnf) | `dnf clean all` |
| Keep last 3 (pacman) | `paccache -r` (from pacman-contrib) |
| Full clean (pacman) | `pacman -Scc` |
| Clean (apk) | `apk cache clean` or `rm -rf /var/cache/apk/*` |

### List Files in Package / Find Owner

| Task | Command |
|------|---------|
| List files (apt) | `dpkg -L <pkg>` |
| Find owner (apt) | `dpkg -S /path/to/file` |
| List files (dnf) | `dnf repoquery -l <pkg>` or `rpm -ql <pkg>` |
| Find owner (dnf) | `dnf provides /path/to/file` or `rpm -qf /path/to/file` |
| List files (pacman) | `pacman -Ql <pkg>` |
| Find owner (pacman) | `pacman -Qo /path/to/file` |
| List files (apk) | `apk info -L <pkg>` |
| Find owner (apk) | `apk info --who-owns /path/to/file` |

### Hold / Pin Version

| Task | Command |
|------|---------|
| Hold (apt) | `apt-mark hold <pkg>` |
| Unhold (apt) | `apt-mark unhold <pkg>` |
| List held (apt) | `apt-mark showhold` |
| Hold (dnf) | `dnf versionlock add <pkg>` (requires `dnf-plugins-core`) |
| Unhold (dnf) | `dnf versionlock delete <pkg>` |
| List held (dnf) | `dnf versionlock list` |
| Hold (pacman) | Add to `IgnorePkg` in `/etc/pacman.conf` |
| Hold (apk) | `apk add <pkg>=<version>` (exact pin in world file) |
| Unhold (apk) | `apk add <pkg>` (unpins) |

## Repository Management

### apt (Debian/Ubuntu)

**Modern method** (Ubuntu 22.04+, Debian 12+; `apt-key` is deprecated and removed in Ubuntu 24.04):
```bash
# Download and store GPG key (dearmored) in /etc/apt/keyrings/
curl -fsSL https://example.com/key.gpg | sudo gpg --dearmor -o /etc/apt/keyrings/example.gpg

# Add repo with signed-by pointing to the key
echo "deb [signed-by=/etc/apt/keyrings/example.gpg] https://repo.example.com/apt stable main" \
  | sudo tee /etc/apt/sources.list.d/example.list
```

**DEB822 format** (newer default in Ubuntu 24.04+, files in `/etc/apt/sources.list.d/*.sources`):
```
Types: deb
URIs: https://repo.example.com/apt
Suites: stable
Components: main
Signed-By: /etc/apt/keyrings/example.gpg
```

**PPAs** (Ubuntu only): `sudo add-apt-repository ppa:user/ppa-name`

### dnf (Fedora/RHEL)

**COPR repos** (Fedora's community build system): `sudo dnf copr enable user/project`

**Manual repo file** (`/etc/yum.repos.d/example.repo`):
```ini
[example]
name=Example Repo
baseurl=https://repo.example.com/fedora/$releasever/$basearch
enabled=1
gpgcheck=1
gpgkey=https://repo.example.com/RPM-GPG-KEY
```

**Repo management**: `dnf repolist` (enabled), `dnf repolist --all`, `dnf config-manager --add-repo <url>`

### pacman (Arch)

**Official repos** are configured in `/etc/pacman.conf` with corresponding mirrors in `/etc/pacman.d/mirrorlist`.

**AUR** (Arch User Repository) requires an AUR helper (not part of pacman). Popular helpers:
- **yay**: `yay -S <aur-package>` (Go, most popular)
- **paru**: `paru -S <aur-package>` (Rust)

Install yay: `sudo pacman -S --needed git base-devel && git clone https://aur.archlinux.org/yay-bin.git && cd yay-bin && makepkg -si`

**Custom repo** in `pacman.conf`:
```ini
[custom]
SigLevel = Optional TrustAll
Server = https://repo.example.com/$arch
```

### apk (Alpine)

**Repository configuration** in `/etc/apk/repositories` (one URL per line):
```
https://dl-cdn.alpinelinux.org/alpine/v3.21/main
https://dl-cdn.alpinelinux.org/alpine/v3.21/community
@testing https://dl-cdn.alpinelinux.org/alpine/edge/testing
```

**Tagged repos**: Prefix with `@tag` to pin packages to specific repos:
```bash
apk add somepackage@testing    # installs from @testing, recorded in /etc/apk/world
```

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `Could not get lock /var/lib/dpkg/lock` (apt) | Another apt/dpkg process running | Wait for it to finish; if dead: `sudo rm /var/lib/dpkg/lock /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock /var/cache/apt/archives/lock && sudo dpkg --configure -a` |
| `This system is not registered` / repo 404 (dnf) | Subscription or repo URL stale | Check `subscription-manager status` (RHEL); `dnf repolist` to verify URLs |
| `failed to synchronize all databases` (pacman) | Bad mirror or network issue | Update mirrorlist: `sudo reflector --latest 10 --sort rate --save /etc/pacman.d/mirrorlist` |
| `ERROR: unable to select packages` (apk) | Package not in enabled repos | Check `/etc/apk/repositories`; ensure community or testing repos are enabled |
| `Hash Sum mismatch` (apt) | Mirror sync issue or MITM | `sudo rm -rf /var/lib/apt/lists/* && sudo apt update` |
| `GPG error: ... NO_PUBKEY` (apt) | Missing signing key | Download key to `/etc/apt/keyrings/` and add `signed-by=` to source |
| `Error: GPG check FAILED` (dnf) | Missing or expired GPG key | `rpm --import <key-url>` or `dnf install <key-package>` |
| `error: failed to commit transaction (conflicting files)` (pacman) | File owned by another package | `pacman -S --overwrite <glob> <pkg>` (only if you know it's safe) |
| `failed to init transaction (unable to lock database)` (pacman) | Stale lock file from crashed pacman | `sudo rm /var/lib/pacman/db.lck` (only if no pacman process is running) |
| Broken packages after partial upgrade (apt) | Mixed release sources or interrupted upgrade | `sudo dpkg --configure -a && sudo apt install -f` |
| `nothing provides <dep>` (dnf) | Missing repo or package renamed | `dnf provides <dep>` to find which repo carries it |

## Pain Points

- **apt vs apt-get**: `apt` is for interactive use (progress bars, color output). `apt-get` is for scripts (stable output format, no interactive prompts). Both call the same backend. Use `apt-get` in automation; `apt` at the terminal.
- **dnf vs yum**: `dnf` replaced `yum` starting with Fedora 22 and RHEL 8. On modern Fedora (41+), `dnf5` is the default with improved performance. The `yum` command is a symlink to `dnf` on these systems.
- **Unattended upgrades (apt)**: Install `unattended-upgrades` package. Config lives in `/etc/apt/apt.conf.d/50unattended-upgrades` (allowed origins, blacklist) and `/etc/apt/apt.conf.d/20auto-upgrades` (enable/interval). Custom overrides go in a file that sorts after `50`, such as `52unattended-upgrades-local`.
- **Automatic updates (dnf)**: Install `dnf-automatic`. Config at `/etc/dnf/automatic.conf`. Enable via `systemctl enable --now dnf-automatic-install.timer` (to auto-install) or `dnf-automatic-download.timer` (download only).
- **autoremove gotchas**: On apt, `apt autoremove` can remove packages you still want if they were installed as dependencies. Use `apt-mark manual <pkg>` to protect them. On dnf, `clean_requirements_on_remove=True` (default in Fedora) removes deps on every `dnf remove`.
- **Proxy configuration**: apt uses `/etc/apt/apt.conf.d/99proxy` with `Acquire::http::Proxy "http://proxy:port";`. dnf uses `proxy=http://proxy:port` in `/etc/dnf/dnf.conf` `[main]` section. pacman has no native proxy setting; set `http_proxy`/`https_proxy` env vars and use `sudo -E pacman`. apk respects `http_proxy`/`https_proxy` environment variables.
- **pacman partial upgrades**: Never install packages after `pacman -Sy` without also upgrading (`-u`). This is the single most common cause of broken Arch systems. Always `pacman -Syu`.

## See Also

- `python-runtime` — Python version management and pip/uv package installation
- `docker` — Container image builds that depend on package managers
- `ansible` — Automated package installation across fleets

## References
See `references/` for:
- `docs.md` -- official documentation links for all four package managers
- `cheatsheet.md` -- side-by-side command comparison table
- `common-patterns.md` -- practical recipes: unattended upgrades, downgrading, orphan cleanup, proxy setup, lock file recovery
