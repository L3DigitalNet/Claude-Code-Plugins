---
name: node-runtime
description: >
  Node.js runtime management on Linux — version installation via nvm and
  NodeSource, npm and pnpm package management, global vs local packages,
  corepack, process management with pm2, and troubleshooting.
  MUST consult when installing, configuring, or troubleshooting Node.js.
triggerPhrases:
  - "node"
  - "nodejs"
  - "node.js"
  - "npm"
  - "npx"
  - "pnpm"
  - "yarn"
  - "nvm"
  - "node version"
  - "node install"
  - "package.json"
  - "node_modules"
  - "pm2"
  - "corepack"
globs:
  - "**/package.json"
  - "**/package-lock.json"
  - "**/pnpm-lock.yaml"
  - "**/yarn.lock"
  - "**/.nvmrc"
  - "**/.node-version"
  - "**/.npmrc"
last_verified: "2026-03"
---

## Identity

| Item | Value |
|------|-------|
| Binary | `node`, `npm`, `npx` (bundled with Node.js) |
| Config | `~/.npmrc` (user), `.npmrc` (project), `package.json` |
| NVM root | `~/.nvm` (versions in `~/.nvm/versions/node/`, default set via alias) |
| npm cache | `~/.npm/_cacache` |
| npm global prefix | `/usr/local` (system install) or `~/.nvm/versions/node/v<x>/` (nvm) |
| pnpm global store | `~/.local/share/pnpm/store/v3` |
| Install methods | nvm (recommended), NodeSource PPA, distro repos, binary tarball, source |

## Quick Start

```bash
# 1. Install nvm (v0.40.4)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash

# 2. Reload shell (or open a new terminal)
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# 3. Install latest LTS
nvm install --lts

# 4. Verify
node --version
npm --version

# 5. Start a project
mkdir myapp && cd myapp
npm init -y
```

## Key Operations

| Task | Command |
|------|---------|
| Check Node version | `node --version` |
| Check npm version | `npm --version` |
| Find Node binary | `which node` / `type -a node` |
| **nvm** | |
| Install latest LTS | `nvm install --lts` |
| Install specific version | `nvm install 24` |
| Switch version (session) | `nvm use 24` |
| Set default | `nvm alias default 24` |
| List installed versions | `nvm ls` |
| List remote versions | `nvm ls-remote --lts` |
| Use project .nvmrc | `nvm use` (reads `.nvmrc` in cwd) |
| Uninstall a version | `nvm uninstall 20` |
| **npm** | |
| Init project | `npm init -y` |
| Install all deps | `npm install` (or `npm i`) |
| Add dependency | `npm install express` |
| Add dev dependency | `npm install --save-dev jest` |
| Install globally | `npm install -g pm2` |
| Update all | `npm update` |
| Audit vulnerabilities | `npm audit` |
| Audit fix | `npm audit fix` |
| Run script | `npm run build` |
| Run binary (npx) | `npx eslint .` |
| List outdated | `npm outdated` |
| Clean cache | `npm cache clean --force` |
| **pnpm** | |
| Install pnpm | `npm install -g pnpm` (or `corepack enable pnpm`) |
| Install all deps | `pnpm install` (or `pnpm i`) |
| Add dependency | `pnpm add express` |
| Add dev dependency | `pnpm add -D jest` |
| Remove dependency | `pnpm remove express` |
| Update all | `pnpm update` |
| Run script | `pnpm run build` (or `pnpm build`) |
| Execute binary | `pnpm dlx create-react-app myapp` |
| **pm2** | |
| Start app | `pm2 start app.js --name myapp` |
| Start in cluster mode | `pm2 start app.js -i max` |
| List processes | `pm2 list` |
| Stop / restart / delete | `pm2 stop myapp` / `pm2 restart myapp` / `pm2 delete myapp` |
| Zero-downtime reload | `pm2 reload myapp` |
| View logs | `pm2 logs` |
| Monitor | `pm2 monit` |
| Save process list | `pm2 save` |
| Generate startup script | `pm2 startup` |
| Scale | `pm2 scale myapp +2` |

## Current LTS Schedule (as of March 2026)

| Version | Codename | Status | EOL |
|---------|----------|--------|-----|
| 25.x | — | Current | ~May 2026 |
| 24.x | Krypton | Active LTS | Apr 2027 (maintenance), Apr 2028 (EOL) |
| 22.x | Jod | Maintenance LTS | Apr 2027 (EOL) |
| 20.x | Iron | Maintenance LTS | Apr 2026 (EOL) |

Node.js 26.x ships April 2026 under the old model (last even/odd cycle). Starting with Node.js 27 (April 2027), every release becomes LTS under the new one-release-per-year cadence with 36-month total support.

**Recommendation:** Use Node.js 24.x (Active LTS) for production. Node.js 20.x reaches EOL April 2026; plan migration now.

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `nvm: command not found` after install | Shell config not sourced | Add nvm init lines to `~/.bashrc` or `~/.zshrc`, then `source ~/.bashrc` |
| `npm WARN EBADENGINE` | package.json `engines` field mismatch | `nvm install` the version the project requires, or update `engines` |
| `EACCES: permission denied` on global install | System Node.js + no nvm; npm tries `/usr/local/lib` | Switch to nvm (installs to `~/.nvm`, no sudo needed) or `npm config set prefix ~/.local` |
| `gyp ERR! build error` | Missing C++ toolchain or headers for native modules | `sudo apt install build-essential python3` (Ubuntu/Debian), `sudo dnf groupinstall 'Development Tools'` (Fedora) |
| `node: /lib/x86_64-linux-gnu/libc.so.6: version GLIBC_x.xx not found` | Node binary requires newer glibc than the OS ships | Use an older Node.js LTS or upgrade the OS |
| `Error: Cannot find module` | Module not installed, or installed for a different Node version | `npm install` in project root; if using nvm, reinstall global packages after switching versions |
| `npm ERR! ERESOLVE could not resolve` | Dependency tree conflict | `npm install --legacy-peer-deps` (workaround) or update conflicting packages |
| `ENOSPC: System limit for number of file watchers reached` | inotify watch limit too low for dev servers | `echo fs.inotify.max_user_watches=524288 \| sudo tee -a /etc/sysctl.conf && sudo sysctl -p` |
| Wrong Node version in new shell | nvm default alias not set | `nvm alias default 24` |
| pm2 processes gone after reboot | Startup hook not configured | `pm2 startup && pm2 save` |

## Pain Points

- **nvm shell integration**: nvm is a bash function, not a binary. It only works in shells that source the init script. Non-interactive shells (cron, systemd) do not load nvm automatically. For those contexts, use the absolute path: `~/.nvm/versions/node/v24.x.x/bin/node`.

- **npm vs pnpm vs yarn**: npm ships with Node.js and works everywhere. pnpm uses a content-addressable store with hard links, saving disk space and speeding up installs (especially in monorepos). Yarn (v4+) offers Plug'n'Play (PnP) mode that eliminates `node_modules` entirely. For new projects, pnpm is the strongest default; npm if you want zero setup.

- **Global packages and sudo**: Never `sudo npm install -g`. With nvm, global packages go to `~/.nvm/` (user-writable). Without nvm, either reconfigure npm's prefix (`npm config set prefix ~/.local`) or use `npx`/`pnpm dlx` to avoid global installs altogether.

- **LTS vs Current**: Current releases get new features first but only six months of support. LTS releases get 30 months. Stick with Active LTS for production; use Current only if you need bleeding-edge APIs.

- **Corepack for yarn/pnpm**: Corepack ships with Node.js 14.19 through 24.x. Run `corepack enable` to make `yarn` and `pnpm` available without global installs. Pin the version per-project via the `"packageManager"` field in `package.json` (e.g., `"packageManager": "pnpm@10.6.0"`). Corepack downloads the exact version on first use. Note: corepack is removed from Node.js 25+, install it separately via `npm install -g corepack`.

- **NODE_ENV effects**: Many frameworks behave differently based on `NODE_ENV`. Express disables verbose error pages in production. npm skips `devDependencies` when `NODE_ENV=production`. Always set it explicitly in production: `NODE_ENV=production node app.js` or in your systemd unit / pm2 ecosystem file.

- **nvm and global packages across versions**: Each nvm-managed Node.js version has its own global `node_modules`. After installing a new version, reinstall global packages: `nvm install 24 --reinstall-packages-from=22`. Alternatively, keep a `~/.nvm/default-packages` file listing packages to auto-install with each new version.

## See Also

- `python-runtime` — Python version and environment management
- `package-managers` — System package managers (apt, dnf, pacman)
- `docker` — Container runtime
- `systemd` — Service management (for deploying Node apps as services)
- **rust-runtime** — Rust toolchain for native addons and CLI tools alongside Node.js

## References

See `references/` for:
- `docs.md` — official documentation links (nodejs.org, npmjs.com, nvm-sh/nvm, pnpm.io, pm2)
- `cheatsheet.md` — side-by-side npm vs pnpm vs yarn commands, nvm workflow, pm2 commands
- `common-patterns.md` — nvm setup in .bashrc/.zshrc, .nvmrc project pinning, pm2 ecosystem file, systemd Node.js service, Docker patterns, npm vs pnpm lockfile differences
