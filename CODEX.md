# Grove CODEX

## Mandate & Ownership
- Grove is the Tree-sitter wrapper and syntax engine for the Zig ecosystem, stewarded by the Grove Core Team. As lead engineer, I am responsible for defining technical direction, driving delivery, and keeping the integrations with Grim (editor) and Ghostlang (scripting engine) first-class.
- The CODEX captures the operating system of the project: shared vision, principles, execution model, and the immediate action plan required to ship the MVP and iterate toward launch.

## Product Vision
- **Purpose**: Deliver a safe, ergonomic, high-performance Tree-sitter interface in Zig that powers Grim and Ghostlang while remaining useful to the wider Zig community.
- **User Outcomes**:
  - Grim users experience instant, reliable syntax highlighting, selection, and structural editing for Zig and companion languages.
  - Ghostlang script authors gain structured syntax data for tooling, linting, and refactoring.
  - Third-party Zig applications embed Grove for parsing without dropping to C.
- **Differentiators**: Zig-native ergonomics, safety guarantees (no UB around moved trees), performance parity with C Tree-sitter, async-aware architecture via Zsync, and tight integration with rope-based buffers.

## Guiding Principles
1. **Safety first**: RAII wrappers and explicit lifetimes around Tree-sitter resources. Every public API must clearly communicate ownership and error semantics.
2. **Performance obsessed**: Achieve ±10% of the C runtime across throughput and incremental edits; benchmark regressions fail the build.
3. **Integration-led**: Any API decision is validated against Grim and Ghostlang workflows; we build for real consumers.
4. **Incremental delivery**: Ship thin vertical slices (MVP → Alpha → Beta → RC) with continuous feedback loops.
5. **Documentation parity**: Every feature ships with developer docs or examples. We treat docs and API shape as part of the deliverable.

## Status Log — 2025-10-05
- **Tree-sitter ABI 15 upgrade complete**: Core headers refreshed with new language metadata and compatibility fields; build now targets CLI/runtime 0.25.x with updated struct layout.
- **Rust grammar reinstated**: Vendored `tree-sitter-rust` sources restored to build graph, editor services, tooling, and docs; highlights and benchmarks include Rust coverage again.
- **Latency benchmark wired in**: Added `zig build bench-latency` executable with seed fixtures to enforce the <5 ms incremental target; baseline captured for release readiness.
- **Release docs refresh underway**: README, roadmap, and integration guides being polished ahead of RC1; changelog draft queued.

## Status Log — 2025-10-03
- **TypeScript grammar bundled**: Vendored parser/scanner compiled into Grove build; `Languages.typescript` exposed with highlight regression tests exercising vendored queries.
- **Highlight regression scaffolded**: TypeScript samples assert capture coverage to guard future query tweaks; Ghostlang utilities remain green.
- **Benchmark harness staged**: `zig build bench` now exercises Zig/JSON/TypeScript; throughput targets tracked in `grove-performance-baseline.json` ahead of Beta gates.
- **Markdown grammar pending**: Awaiting vendored parser drop before wiring highlight fixtures and registry hookup.

## Status Log — 2025-09-24
- **Ghostlang grammar ready for production**: Corpus expectations rewritten to match richer AST output, highlight and locals queries aligned with the new postfix-expression structure, and the `tree-sitter test` suite passes cleanly.
- **Vendored assets verified**: `vendor/grammars/ghostlang/` mirrors the latest generated parser and queries; diffs against `tree-sitter-ghostlang/` are empty.
- **Grove test suite green**: `zig build test` passes with Ghostlang registered in `languages.zig` and the highlight engine loading vendored queries.

### Next Focus When We Return
- Land Markdown grammar vendoring + highlight fixtures to complete Beta language scope.
- Coordinate with Grim to consume the vendored Ghostlang bundle and validate `.gza` file associations end-to-end (merge `feature/ghostlang-gza-adapter`).
- Publish a short integration note or changelog entry summarizing Ghostlang Phase 1 and TypeScript bundling (README + docs refresh where relevant).
- Stand up TypeScript/Markdown benchmark scenarios in Grim rope simulator to nail throughput + latency targets.

### Quick Reminders
- Re-run `npx tree-sitter test` under `tree-sitter-ghostlang/` and `zig build test` after any grammar/query tweaks.
- Maintain query parity between source and `vendor/` before tagging releases.

## Stakeholder & Integration Map
| System | What Grove Provides | Key Interfaces | Notes |
|--------|---------------------|----------------|-------|
| **Grim** (Zig Vim alternative) | Syntax tree access, query-powered highlighting, edit translation | Rope adapter, incremental parse service, highlight pipeline | Must support live editing latency targets (<1 ms P50 per edit) |
| **Ghostlang** (Zig scripting engine) | Embeddable parsing services for tooling, linting, runtime helpers | Query API, traversal utilities | Grove shipped as dependency; needs sandbox-safe APIs |
| **Zsync** (async runtime) | Execution substrate for background parsing, query evaluation, benchmarking harness | Async executors, timers, channels | Required for multi-threaded parse and highlight jobs |
| **Tree-sitter** (C runtime) | Parsing engine; Grove wraps and extends it | Static library build, language grammars | Vendored under `archive/tree-sitter` |
| **nvim-treesitter** (reference) | Highlight queries and grammar reference | Grammar assets | Used for parity testing |

### Coordinated Delivery Strategy
- **Grim First-Class**: Ensure Grim reaches "functional editor" status in parallel with Grove’s MVP/Alpha so editor usability is never blocked on the parser roadmap. Grove exports stable APIs early to let Grim adopt features incrementally.
- **Reusable Grove Core**: Treat Grove as a general-purpose Zig parsing library, not just a Grim dependency. Benchmarks, docs, and packaging are maintained so other Zig projects can adopt it without Grim/Ghostlang context.
- **Plugin Safety from Day Zero**: Design Grove’s upcoming query/highlight APIs and planned plugin hooks with Ghostlang safety requirements (sandboxing, deterministic execution) in mind, even before Ghostlang integration lands.
- **Parallel Ghostlang Work**: Do not stall Grove or Grim awaiting Ghostlang milestones. Ghostlang can consume Grove later via the same stable APIs while Grove collects independent performance data.
- **Shared Timeline Management**: Align release cadence so Grove’s Beta (integration) coincides with Grim’s plugin subsystem branching point, enabling a clean handoff to Ghostlang once the plugin foundation is hardened.

## Architecture Blueprint
- **Core Layer** (`grove.core`): Zig wrappers over C API (`Parser`, `Tree`, `Node`, `Cursor`, `Query`). Handles allocator strategy, error sets, and lifetime guarantees.
- **Input Layer** (`grove.input`): Rope adapters, chunked readers, and edit translation utilities. Integrates with Grim's rope buffer and Ghostlang streams.
- **Query Layer** (`grove.query`): Compiles highlight/query DSL, iterates captures, caches patterns per language.
- **Highlight Service** (`grove.highlight`): Applies query results to Grim themes; exposes incremental diff updates.
- **Async/Runtime Layer** (`grove.runtime`): Thin adapters over Zsync for work scheduling, batching, and cancellation.
- **Tooling & Bench Harness** (`grove.tools`): CLI and bench utilities that surface performance metrics and regression guards.

## Delivery Phases
1. **MVP (Foundation)**
   - Ship Zig-safe wrappers for `Parser`, `Tree`, and `Node` with RAII management.
   - Provide `parseUtf8` API with edit application skeleton and diagnostics.
   - Integrate Tree-sitter static library into build system.
   - Include smoke tests (no grammar) plus fixture tests using vendored Zig grammar stub.
   - Publish developer docs explaining API usage.
2. **Alpha**
   - Rope delta translation, incremental parsing, and snapshot caching.
   - Query compilation and highlight prototype for Zig grammar.
   - CLI smoke tool (`zig build run -- zig.grove`) for manual verification.
3. **Beta**
   - Full highlight pipeline integrated with Grim; Ghostlang plugin scaffolding.
   - Async scheduling via Zsync, multi-file parse queue.
   - Benchmark harness with regression thresholds.
4. **RC1-3**
   - Stabilize API surface, freeze error sets.
   - Cross-platform validation, CI hardening, documentation polish.
   - RC3 requires zero known P0 bugs, release notes, and migration guide.
5. **Launch**
   - Tag v1.0.0, publish docs & API guides, announce to Grim/Ghostlang communities.

## Engineering Operating Model
- **Branching**: `main` healthy and releasable; feature branches follow `<phase>/<feature>` naming (e.g. `mvp/parser-init`). PRs require tests and docs.
- **Testing Strategy**: Unit tests for wrappers, integration tests with rope simulators, fuzz harness for edit paths, benchmark gate on CI.
- **Tooling**: `zig build`, `zig build test`, `zig build bench`. CI to run lint + tests + benchmarks. Nightly run for long benchmarks.
- **Documentation Flow**: Every milestone updates `docs/` with architecture notes, API references, and integration guides.

## Dependency & Build Decisions
- Tree-sitter C runtime is vendored from `archive/tree-sitter`; we compile static library via Zig build.
- Grammars are vendored per language as generated C files (starting with Zig grammar, then JSON/Rust/TypeScript/Python).
- Zsync is leveraged for async tasks; add as dependency once we move into Alpha stage (MVP keeps synchronous path).
- Ghostlang integration is post-MVP; provide adapter crate for script plugins.

## Quality Gates
- Build succeeds with `zig build` and `zig build test` on Linux/macOS/Windows x64.
- No memory leaks (verified via `zig test --fuzz` and valgrind nightly).
- Performance regressions >10% fail CI.
- Documentation coverage: All public APIs have doc comments + docs landing page.

## Risk Register
| Risk | Impact | Mitigation |
|------|--------|------------|
| Tree-sitter C API divergence | Medium | Pin to specific commit, audit breaking changes quarterly |
| Lack of Zig grammar parity | High | Vendor grammar, maintain query test suite, collaborate with Zig grammar maintainers |
| Async complexity with Zsync | Medium | Stage integration post-MVP, maintain sync fallback |
| Rope edit translation bugs | Critical | Build property-based tests with fuzzed edit sequences |
| Resource leaks | Critical | Enforce RAII and allocate via arena/pool with deterministic teardown |

## Immediate Action Plan (Next 4 Weeks)
1. **Week 1**
   - Wire Tree-sitter static library in build.zig.
   - Implement `c_api.zig`, `parser.zig`, `tree.zig`, `node.zig` with RAII wrappers.
   - Ship MVP tests: parser initialization, null-language protection, and tree visit API using stub language fixture.
2. **Week 2**
   - Introduce `language.zig` registry with vendored Zig grammar stub.
   - Implement simple highlight query loader (no async).
   - Publish docs: `docs/mvp-overview.md`, `docs/api/parser.md`.
3. **Week 3**
   - Add edit translation skeleton and test harness.
   - Integrate with Grim rope buffer mock; ensure incremental parse call path works.
4. **Week 4**
   - Release v0.1.0 (MVP) tag, document usage, collect feedback from Grim maintainers.
   - Share Grove performance snapshot with broader Zig community to validate reusable-library positioning.

## Communication Cadence
- Weekly engineering status update (posted to CODEX section in repo).
- Milestone review at end of each phase; align Grim & Ghostlang maintainers.
- Issues labeled by phase (`mvp`, `alpha`, etc.) and component (parser, query, highlight).

## Contribution Guidelines (TL;DR)
- Tests and docs are mandatory for every change.
- Public API changes require an RFC in `docs/rfcs/`.
- Use Zig standard style; run `zig fmt` before committing.
- Benchmark or profiling data must accompany performance-affecting changes.

## Appendix: References
- Tree-sitter upstream: `archive/tree-sitter`
- Grim codebase: `archive/grim`
- Ghostlang runtime: `archive/ghostlang`
- Async runtime (Zsync): `archive/zsync`
- Highlight & query references: `archive/nvim-treesitter`

---
*Maintained by the Grove Core Team. This CODEX is the source of truth for operational direction—update it alongside roadmap and implementation changes.*
