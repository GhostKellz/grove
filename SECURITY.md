# Security Policy

## Supported Versions

Security fixes are targeted at the latest development line in this repository.

| Version | Supported |
| --- | --- |
| `main` / latest unreleased | Yes |
| older tags and archived snapshots | No |

## Reporting A Vulnerability

Please do not open a public issue for suspected security vulnerabilities.

Report privately with:

- a clear description of the issue
- affected files, grammars, or subsystems
- reproduction steps or a minimal source sample
- impact assessment if known

If a private security contact is not yet published for this repository, use the maintainer's private contact channel or GitHub security advisories if enabled.

## Scope

Grove wraps Tree-sitter parsers and exposes editor-facing helpers. Security reports are most useful when they demonstrate a concrete risk in parser lifecycle management, bundled grammar handling, query execution, or host/editor integration.

Areas most likely to matter for security reports:

- crashes, memory corruption, or undefined behavior triggered by untrusted source text
- parser, tree, node, query, or edit APIs that violate documented ownership guarantees
- unbounded resource consumption from crafted input, queries, or incremental edit sequences
- unsafe dynamic grammar loading or language registry behavior
- editor integration behavior that can cross trust boundaries unexpectedly

## Current Security Model

The project aims to provide:

- deterministic parser and tree lifetimes
- allocator-aware APIs with explicit ownership
- error propagation instead of panics in public APIs
- bounded input handling where Tree-sitter or Grove has size limits
- query validation before runtime use

These controls should be validated with tests before being relied on in security-sensitive editor or tooling environments.

## Response Expectations

When a report is reproducible and in scope, the expected response is:

1. confirm impact and affected versions
2. prepare a fix with regression coverage when possible
3. coordinate disclosure timing if the issue is significant

## Hardening Guidance

If you embed Grove in a security-sensitive system:

- run only the latest patched revision you have verified
- validate query files before loading them
- treat dynamic grammars and externally supplied queries as untrusted input
- set practical size and timeout limits around parsing workflows
- fuzz grammar and incremental-edit paths used with untrusted documents
