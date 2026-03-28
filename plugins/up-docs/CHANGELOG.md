# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Added

- `/up-docs:drift` command for comprehensive drift analysis: SSHes into live infrastructure, syncs Outline wiki across four convergence phases (infrastructure sync, wiki consistency, link integrity, Notion update)
- Server inspection reference with patterns for systemd, Docker, web servers, databases, DNS, VPN, monitoring, and backup services
- Convergence tracking reference with iteration mechanics, oscillation detection, and narrowing strategy

## [0.1.0] - 2026-03-28

### Added

- `/up-docs:repo` command to update repository documentation (README.md, docs/, CLAUDE.md)
- `/up-docs:wiki` command to update Outline wiki with implementation-level details
- `/up-docs:notion` command to update Notion with strategic and organizational context
- `/up-docs:all` command to update all three layers sequentially
- Summary report template for consistent output formatting across all commands
- Notion content guidelines reference document
