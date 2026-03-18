---
name: rust-runtime
description: >
  Rust runtime management on Linux: rustup installation, toolchain management
  (stable/beta/nightly), cargo commands (build, run, test, clippy, fmt),
  cross-compilation targets, cargo-install for CLI tools, and rust-analyzer.
  MUST consult when installing, configuring, or troubleshooting Rust.
triggerPhrases:
  - "rust"
  - "rustup"
  - "cargo"
  - "rustc"
  - "rust toolchain"
  - "rust install"
  - "cargo build"
  - "cargo test"
  - "cargo clippy"
  - "cargo fmt"
  - "rust nightly"
  - "rust cross compile"
  - "rust-analyzer"
  - "Cargo.toml"
  - "crate"
  - "rustfmt"
  - "clippy"
  - "rust target"
  - "cargo publish"
globs:
  - "**/Cargo.toml"
  - "**/Cargo.lock"
  - "**/rust-toolchain.toml"
  - "**/rust-toolchain"
  - "**/.cargo/config.toml"
  - "**/clippy.toml"
  - "**/rustfmt.toml"
last_verified: "2026-03"
---

## Identity

| Field | Value |
|-------|-------|
| rustup binary | `~/.cargo/bin/rustup` |
| Compiler | `~/.cargo/bin/rustc` |
| Package manager / build tool | `~/.cargo/bin/cargo` |
| Toolchain root | `~/.rustup/toolchains/` (each channel has its own directory) |
| Cargo home | `~/.cargo/` (registry cache, installed binaries, config) |
| Installed binaries | `~/.cargo/bin/` (must be on `$PATH`) |
| Registry cache | `~/.cargo/registry/` (crates.io index + downloaded crates) |
| Build artifacts | `./target/` (per-project; `target/debug/`, `target/release/`) |
| Project config | `Cargo.toml` (manifest), `Cargo.lock` (lockfile) |
| Toolchain override | `rust-toolchain.toml` or `rust-toolchain` (per-directory) |
| Cargo config | `.cargo/config.toml` (per-project or `~/.cargo/config.toml` global) |
| Key env vars | `RUSTUP_HOME`, `CARGO_HOME`, `RUST_BACKTRACE`, `RUSTFLAGS`, `CARGO_TARGET_DIR` |

## Quick Start

```bash
# Install rustup (official installer)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Reload PATH
source "$HOME/.cargo/env"

# Verify
rustc --version
cargo --version

# Create a new project
cargo new myproject
cd myproject
cargo run
```

## Key Operations

| Task | Command |
|------|---------|
| **Rustup** | |
| Install Rust | `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \| sh` |
| Update all toolchains | `rustup update` |
| Show installed toolchains | `rustup toolchain list` |
| Install specific toolchain | `rustup toolchain install nightly` |
| Set default toolchain | `rustup default stable` |
| Use toolchain for one command | `cargo +nightly build` |
| Set project-local toolchain | Create `rust-toolchain.toml` (see below) |
| Uninstall a toolchain | `rustup toolchain uninstall nightly` |
| Show active toolchain | `rustup show` |
| List installed components | `rustup component list --installed` |
| Add component | `rustup component add rust-analyzer` |
| Remove component | `rustup component remove rust-docs` |
| List available targets | `rustup target list` |
| Add cross-compilation target | `rustup target add aarch64-unknown-linux-gnu` |
| Remove target | `rustup target remove aarch64-unknown-linux-gnu` |
| Self-update rustup | `rustup self update` |
| Uninstall Rust entirely | `rustup self uninstall` |
| **Cargo** | |
| Create new project (binary) | `cargo new myproject` |
| Create new project (library) | `cargo new --lib mylib` |
| Build (debug) | `cargo build` |
| Build (release, optimized) | `cargo build --release` |
| Run the project | `cargo run` |
| Run with arguments | `cargo run -- --flag value` |
| Run tests | `cargo test` |
| Run a specific test | `cargo test test_name` |
| Run tests with output | `cargo test -- --nocapture` |
| Run benchmarks | `cargo bench` |
| Check compilation (no codegen) | `cargo check` |
| Run linter (clippy) | `cargo clippy` |
| Clippy with warnings as errors | `cargo clippy -- -D warnings` |
| Format code | `cargo fmt` |
| Check formatting | `cargo fmt --check` |
| Generate docs | `cargo doc` |
| Generate and open docs | `cargo doc --open` |
| Add a dependency | `cargo add serde` |
| Add with features | `cargo add serde --features derive` |
| Add dev dependency | `cargo add --dev tokio-test` |
| Remove dependency | `cargo remove serde` |
| Update dependencies | `cargo update` |
| Update a single crate | `cargo update -p serde` |
| Clean build artifacts | `cargo clean` |
| Install binary crate | `cargo install ripgrep` |
| List installed binaries | `cargo install --list` |
| Publish to crates.io | `cargo publish` |
| Package (dry run) | `cargo package --list` |
| Show dependency tree | `cargo tree` |
| Show reverse dependencies | `cargo tree -i serde` |
| Audit dependencies | `cargo audit` (install: `cargo install cargo-audit`) |
| Cross-compile | `cargo build --target aarch64-unknown-linux-gnu` |

## Toolchain Channels

| Channel | Purpose | Update Frequency |
|---------|---------|-----------------|
| **stable** | Production use; all features stabilized | Every 6 weeks |
| **beta** | Preview of the next stable release | Every 6 weeks (tracks next stable) |
| **nightly** | Bleeding edge; unstable features behind `#![feature(...)]` | Daily |

Specific versions can be pinned: `rustup toolchain install 1.82.0`.

## Default Components by Profile

| Component | minimal | default | complete |
|-----------|---------|---------|----------|
| rustc | yes | yes | yes |
| rust-std | yes | yes | yes |
| cargo | yes | yes | yes |
| rust-docs | no | yes | yes |
| rustfmt | no | yes | yes |
| clippy | no | yes | yes |
| rust-analyzer | no | no | yes |
| miri | no | no | yes |
| rust-src | no | no | yes |
| llvm-tools | no | no | yes |

Install individually: `rustup component add rust-analyzer`

## Common Cross-Compilation Targets

| Target Triple | Platform |
|---------------|----------|
| `x86_64-unknown-linux-gnu` | Linux x86_64 (glibc, default on most distros) |
| `x86_64-unknown-linux-musl` | Linux x86_64 (musl, fully static binaries) |
| `aarch64-unknown-linux-gnu` | Linux ARM64 (Raspberry Pi 4/5, AWS Graviton) |
| `aarch64-unknown-linux-musl` | Linux ARM64 (static) |
| `armv7-unknown-linux-gnueabihf` | Linux ARMv7 hard-float (Raspberry Pi 2/3) |
| `x86_64-pc-windows-gnu` | Windows x86_64 (MinGW) |
| `x86_64-pc-windows-msvc` | Windows x86_64 (MSVC) |
| `x86_64-apple-darwin` | macOS x86_64 |
| `aarch64-apple-darwin` | macOS ARM64 (Apple Silicon) |
| `wasm32-unknown-unknown` | WebAssembly (no WASI) |
| `wasm32-wasip1` | WebAssembly with WASI preview 1 |

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `rustc: command not found` | `~/.cargo/bin` not on PATH | `source "$HOME/.cargo/env"` or add to `~/.bashrc`: `export PATH="$HOME/.cargo/bin:$PATH"` |
| `error[E0658]: ... is experimental` | Feature requires nightly | Switch to nightly: `cargo +nightly build`; or add `#![feature(...)]` to `lib.rs`/`main.rs` |
| `linker 'cc' not found` | No C compiler/linker installed | `sudo apt install build-essential` (Ubuntu/Debian) or `sudo dnf groupinstall 'Development Tools'` (Fedora) |
| `error: linking with ... failed` during cross-compile | Missing cross-compilation linker | Install cross toolchain: `sudo apt install gcc-aarch64-linux-gnu`; set linker in `.cargo/config.toml` |
| `Blocking waiting for file lock on package cache` | Another cargo process running | Wait for it to finish; or delete `~/.cargo/.package-cache` if stale |
| `cargo clippy` not found | Component not installed | `rustup component add clippy` |
| `cargo fmt` not found | Component not installed | `rustup component add rustfmt` |
| Build uses excessive disk space | `target/` grows with every build | `cargo clean` to remove; set `CARGO_TARGET_DIR` to share across projects |
| `GLIBC_x.xx not found` | Binary built on newer system, ran on older | Build with musl target for static binaries: `cargo build --target x86_64-unknown-linux-musl` |
| `rust-analyzer` not working in editor | Component not installed or wrong toolchain | `rustup component add rust-analyzer`; ensure editor uses the rustup-managed binary |
| Slow builds | Debug builds are unoptimized; large dependency tree | Use `cargo check` for type-checking only; set `opt-level = 1` in `[profile.dev]` for faster dev builds; use `sccache` |

## Pain Points

- **`target/` directory grows large**: Debug builds include full debug info and are unoptimized, easily reaching gigabytes. Use `cargo clean` periodically. Set `CARGO_TARGET_DIR` to a shared location to avoid per-project target dirs. For CI, cache only `~/.cargo/registry/` and `~/.cargo/git/`, not `target/`.

- **Static binaries with musl**: The `x86_64-unknown-linux-musl` target produces fully static binaries that work on any Linux distro. Install the musl toolchain first: `sudo apt install musl-tools`. For cross-architecture static builds (e.g., ARM64), use the `cross` tool: `cargo install cross && cross build --target aarch64-unknown-linux-musl --release`.

- **Cross-compilation linker config**: `rustup target add` installs the Rust standard library but not the platform linker. You must install a cross linker separately and configure it in `.cargo/config.toml`. See the common-patterns reference for the full setup.

- **nightly features are unstable**: Features behind `#![feature(...)]` can change or be removed between nightly releases. Pin a specific nightly date in `rust-toolchain.toml` if you depend on unstable features: `channel = "nightly-2026-03-01"`.

- **`Cargo.lock` in version control**: For binary projects, commit `Cargo.lock` (reproducible builds). For library crates, do not commit it (let downstream consumers resolve their own versions). This is a strong convention, not enforced by tooling.

- **Build scripts (`build.rs`) need system deps**: Some crates (e.g., `openssl-sys`, `libz-sys`) build C code via `build.rs` and need system headers. Install with `sudo apt install pkg-config libssl-dev` or use vendored features: `cargo add openssl --features vendored`.

- **Editions (2015, 2018, 2021, 2024)**: Each Rust edition introduces syntax and behavior changes. New projects default to the latest edition. Existing code migrates with `cargo fix --edition`. Crates of different editions interoperate in the same binary without issues.

## See Also
- **python-runtime** — Python version and environment management (similar multi-version patterns)
- **node-runtime** — Node.js runtime management with nvm
- **package-managers** — System package managers (apt, dnf, pacman) for installing build dependencies

## References
See `references/` for:
- `docs.md` — official documentation links (Rust book, Cargo book, rustup, crates.io)
- `cheatsheet.md` — side-by-side cargo commands, rustup workflows, cross-compilation setup
