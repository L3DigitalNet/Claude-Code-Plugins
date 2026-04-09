# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [0.6.0] - 2026-04-09

### Added
- `scripts/detect-project.sh` for project type detection with marker file scanning and sub-classification
- `scripts/inventory-sources.sh` for source file discovery with approximate function counting
- `scripts/inventory-tests.sh` for test file discovery with category classification and test counting
- `scripts/git-function-changes.sh` for extracting changed function signatures from git history
- `scripts/test-status-update.sh` for atomic read-merge-write of TEST_STATUS.json

### Changed
- `commands/analyze.md` Steps 1-3 and 5 now reference scripts for detection, inventory, and status updates
- `commands/status.md` Step 1 now reads status via script

## [0.5.0] - 2026-04-08

### Added
- Step 5 Phase 3: test quality assessment — flags weak assertions, missing boundary coverage, and over-mocked tests
- Step 6: git diff integration for recently-changed function priority boost
- Step 3: conftest.py complexity check — flags complex fixtures as candidates for their own tests
- Convergence loop: batch size now scales with gap count (3-5 for ≤15 gaps, 5-8 for 16-30, 8-12 for 31+)
- All 5 stack profiles: "Commonly Undertested Patterns" section with framework-specific testing blind spots
- python-fastapi profile: middleware, scheduler, Jinja2/HTMX, webhooks, external API clients, module-level singletons
- python-fastapi profile: UI testing now applicable for server-rendered HTML projects (Jinja2/HTMX)
- Status command: staleness check now estimates function-level change scope

### Changed
- Gap analysis now operates at function/behavior level instead of file level
- Step 4 reads source files to enumerate functions, behaviors, and branches
- Step 5 Phase 2 maps test functions → source functions instead of test files → source files
- Step 6 creates one gap per untested function/behavior, not per source file
- Convergence loop: category ordering is now a phase gate (complete one category before starting next)
- Analyze command updated to reflect behavioral (not structural) coverage mapping

### Fixed
- File-level mapping drastically under-reported gaps: a source file with 15 functions where only 3 were tested reported zero gaps

## [0.3.0] - 2026-03-27

### Changed
- Converted 9 skills to on-demand references; testing-mindset kept as sole always-on skill
- Stack profiles moved to `references/profiles/`
- Commands updated to read references instead of consulting skills

### Removed
- Deleted 9 skill directories (4 core + 5 profiles); content preserved in `references/`

## [0.2.0] - 2026-03-16

### Added
- add non-unit test design principles
- add category-specific test generation guidance

### Fixed
- make gap analysis category-aware in Step 5


## [0.1.0] - 2026-03-16

### Added
- add /test-driver:status command
- add /test-driver:analyze command
- add swift-swiftui stack profile
- add home-assistant stack profile
- add python-django stack profile
- add python-pyside6 stack profile
- add python-fastapi stack profile
- add test-design universal principles skill
- add test-status persistent state skill
- add convergence-loop iteration engine skill
- add gap-analysis methodology skill
- add testing-mindset always-on behavioral skill
- scaffold plugin with plugin.json

### Changed
- add README.md
- add CHANGELOG.md
