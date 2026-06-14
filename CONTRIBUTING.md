# Contributing to Grove

Grove is a Zig library around Tree-sitter. Contributions should keep the public API safe, allocator-aware, and practical for editor integrations.

## Development Setup

Required tools:

- Zig 0.17.0-dev or later
- a C toolchain supported by Zig
- Tree-sitter knowledge for grammar or query changes

Common checks:

```bash
zig build
zig build test
zig build bench
zig build bench-latency
```

Run the smallest relevant check while iterating, then run `zig build test` before opening a pull request.

## Contribution Workflow

1. Create a focused branch for the change.
2. Keep code, docs, and tests scoped to the behavior being changed.
3. Add regression coverage for bug fixes and public API behavior.
4. Update documentation when changing public APIs, editor helpers, bundled grammars, or build requirements.
5. Open a pull request with a concise summary, validation commands, and any compatibility notes.

## Code Guidelines

- Prefer existing module boundaries and naming conventions.
- Use explicit ownership and `deinit` patterns for allocated or Tree-sitter-owned resources.
- Return typed errors from public APIs instead of panicking.
- Keep wrappers thin unless a stronger Zig abstraction removes real caller complexity.
- Avoid introducing dependencies unless they are necessary for core parsing, testing, or editor integration.

## Documentation Guidelines

The docs layout mirrors the sibling Ghostlang project:

- `docs/README.md` is the documentation index.
- Other documentation files use lowercase names.
- Related documents are grouped into folders such as `api/`, `guides/`, `architecture/`, `integration/`, `roadmap/`, and `rfcs/`.

When adding docs, update [docs/README.md](docs/README.md) and use relative links that continue to work after publishing.

## Grammar Contributions

Use [docs/guides/contributing-grammars.md](docs/guides/contributing-grammars.md) for new bundled grammar work. Grammar changes should include:

- build integration
- query assets where relevant
- parser smoke tests
- documentation updates
- upstream license notes

## RFCs

Use the RFC process for breaking API changes, major modules, new dependencies, or architecture decisions that need broader review. See [docs/rfcs/index.md](docs/rfcs/index.md).

## Security

Do not disclose vulnerabilities in public issues. See [SECURITY.md](SECURITY.md) for reporting guidance.
