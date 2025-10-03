# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Reinstated the vendored **tree-sitter-rust** grammar (v0.25.3) with scanner support, editor utilities, CLI hooks, and benchmark coverage.
- Introduced a dedicated incremental latency benchmark (`zig build bench-latency`) seeded with TypeScript fixtures to enforce the <5 ms P50 goal.
- Documented release workflow updates across README, CODEX, and TODO to guide RC1 preparation.

### Changed
- Upgraded the vendored Tree-sitter runtime headers to ABI version 15, aligning Grove with CLI/runtime 0.25.x expectations.
- Refreshed tooling, language registry, and tests to use the restored Rust grammar alongside JSON, Zig, Ghostlang, and TypeScript.
- Enhanced performance documentation to highlight both throughput (`zig build bench`) and latency guardrails.

### Pending
- Markdown grammar vendoring and fixtures (tracked for Week 4 deliverable).
- Python and JavaScript grammar onboarding for the Beta milestone.
