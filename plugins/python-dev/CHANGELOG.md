# Changelog

All notable changes to the python-dev plugin are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.1] - 2026-03-04

### Changed
- update org references from L3Digital-Net to L3DigitalNet

### Fixed
- apply /hygiene sweep fixes — em dashes, root README python-dev entry
- apply audit findings — factual errors, docs, UX


## [Unreleased]

## [1.0.0] - 2026-03-02

### Added

- 11 Python development skills with automatic context-triggered loading:
  - `python-anti-patterns`: checklist of common Python bugs and structural mistakes
  - `python-type-safety`: type hints, generics, Protocol, TypeVar, mypy/pyright
  - `python-design-patterns`: KISS, SRP, composition over inheritance, dependency injection
  - `python-code-style`: ruff, naming conventions, docstrings, import organization
  - `python-resource-management`: context managers, ExitStack, streaming, cleanup
  - `python-resilience`: tenacity retries, exponential backoff, timeouts, circuit breakers
  - `python-configuration`: pydantic-settings, environment variables, secrets
  - `python-observability`: structlog, Prometheus, OpenTelemetry, correlation IDs
  - `python-testing-patterns`: pytest fixtures, parametrize, mocking, async tests
  - `async-python-patterns`: asyncio, gather, semaphores, event loop patterns
  - `python-background-jobs`: Celery, RQ, Dramatiq, idempotency, job state
- `/python-code-review` command: systematic audit across all 11 domains with 🔴/🟡/🟢 prioritized findings and top 3 action items
