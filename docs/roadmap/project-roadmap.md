# Grove Delivery Roadmap

> **Status:** Draft • Owner: Grove Core Team • Last Updated: 2025-09-24

The roadmap tracks Grove from MVP through Launch. Dates are relative (weeks) and will be refined at each milestone review.

## Milestone Overview
| Phase | Duration | Primary Goals |
|-------|----------|----------------|
| **MVP (v0.1.0)** | Weeks 1-4 | Tree-sitter core wrappers, build integration, basic parsing API, docs |
| **Alpha (v0.2.0)** | Weeks 5-8 | Rope integration, incremental parsing, highlight prototype, async prep |
| **Beta (v0.3.0)** | Weeks 9-12 | Grim integration, Ghostlang adapters, benchmark harness, query features |
| **RC1 (v0.4.0)** | Weeks 13-14 | API freeze, cross-platform validation, docs completeness |
| **RC2 (v0.5.0)** | Weeks 15-16 | Performance stabilization, bug triage, release tooling |
| **RC3 (v0.6.0)** | Weeks 17-18 | Final polish, compatibility sign-off, comms prep |
| **Launch (v1.0.0)** | Week 19 | Public release, documentation push, post-launch SLAs |

---

## MVP (v0.1.0)
**Objective:** Ship a production-usable foundation that exposes a safe Zig API over the Tree-sitter C runtime.

### Scope
- Compile vendor Tree-sitter static library via `build.zig`.
- Implement core modules: `parser.zig`, `tree.zig`, `node.zig`, `language.zig`.
- Provide `Parser.parseUtf8` returning `Tree` with RAII management.
- Deliver stub Zig grammar (minimal) and smoke tests around parser lifecycle.
- Author docs: `docs/roadmap/mvp-overview.md`, `docs/api/parser.md`.

### Engineering Checklist
- [ ] Build + test pass on Linux (CI hook).
- [ ] Fuzz harness for parser init vs. teardown.
- [ ] Memory leak detection via `zig test --fuzz` run locally.
- [ ] CODEX + ROADMAP updated with scope completion.

### Exit Criteria
- `grove` module importable in Grim sandbox.
- Documented example parsing string → syntax tree (even if mock language).
- Known issues logged with severity tags.

---

## Alpha (v0.2.0)
**Objective:** Connect Grove to editor buffers and unlock incremental parsing + highlight queries.

### Scope
- Rope adapter translating deltas → Tree-sitter edits.
- Incremental parse pipeline with snapshot caching.
- Query subsystem capable of compiling highlight queries and iterating captures.
- Highlight prototype for Zig grammar integrated into Grim feature branch.
- Begin integrating Zsync for background tasks (no hard dependency yet).

### Engineering Checklist
- [ ] Rope simulator tests covering inserts/deletes/moves.
- [ ] Query unit tests with fixture queries from `archive/nvim-treesitter`.
- [ ] Benchmark harness skeleton with throughput metrics.
- [ ] Docs: `docs/api/rope.md`, `docs/api/query.md`.

### Exit Criteria
- Grim branch renders Zig highlights via Grove.
- Ghostlang receives parse trees for script lint prototype.
- Beta backlog groomed and estimated.

---

## Beta (v0.3.0)
**Objective:** Harden Grove for real-world workloads and provide integration tooling.

### Scope
- Full Grim integration behind feature flag `-Duse_grove=true`.
- Ghostlang plugin helpers + sample scripts.
- Async scheduling with Zsync (parse queue, highlight updates, timers).
- Benchmark suite with regression gates (throughput, latency, memory).
- Expanded grammar support: JSON, Rust, TypeScript, Python.

### Engineering Checklist
- [ ] Performance baselines captured & versioned.
- [ ] Integration tests spanning Grim/Ghostlang workflows.
- [ ] Crash reproduction harness and telemetry hooks.
- [ ] Docs: `docs/integration/grim.md`, `docs/integration/ghostlang.md`.

### Exit Criteria
- Grim nightly builds default to Grove backend for Zig.
- Ghostlang scripts can request syntax trees asynchronously.
- No open P0/P1 issues without workarounds.

---

## RC1 (v0.4.0)
**Objective:** Freeze APIs and validate cross-platform compatibility.

### Scope
- API review + stabilization; publish RFC for any remaining changes.
- Windows/macOS build + test support.
- CI matrix + automated artifacts.
- Documentation audit for completeness.

### Engineering Checklist
- [ ] API docs generated, cross-linked, and versioned.
- [ ] RC1 release notes drafted.
- [ ] CI gating on docs and formatting.
- [ ] External dependency versions locked.

### Exit Criteria
- API surface labeled `stable`.
- All target platforms build & run tests.
- Unblocked path to RC2.

---

## RC2 (v0.5.0)
**Objective:** Optimize, burn down bugs, and finalize performance guarantees.

### Scope
- Focused performance tuning (profiling, allocation strategy, query caching).
- Bug triage and resolution for outstanding blockers.
- Polish developer ergonomics (errors, logging, CLI UX).

### Engineering Checklist
- [ ] Daily benchmark trend review.
- [ ] Crash/issue SLA of <24h response.
- [ ] Docs updated with troubleshooting & tuning guides.

### Exit Criteria
- Benchmarks meet or exceed targets (±10% of C runtime, <1ms edit P50).
- All P0/P1 issues closed or waived by triage board.
- RC3 release candidate builds green.

---

## RC3 (v0.6.0)
**Objective:** Final packaging, compatibility validation, and launch readiness.

### Scope
- Compatibility tests against Grim/ghostlang release branches.
- Migration guides, upgrade scripts, and release communication draft.
- Finalize installer/binary distribution strategy (if any).

### Engineering Checklist
- [ ] Compatibility matrix signed off by downstream teams.
- [ ] Release playbook rehearsed.
- [ ] Monitoring/logging hooks ready for launch.

### Exit Criteria
- Zero critical issues outstanding.
- Documentation site frozen for launch.
- Launch go/no-go meeting complete.

---

## Launch (v1.0.0)
**Objective:** Public release with support processes in place.

### Scope
- Tag v1.0.0, publish artifacts, update documentation and announcement posts.
- Enable issue templates, discussion boards, and contribution guidelines.
- Establish post-launch support SLAs (weekly patch cadence, security response).

### Engineering Checklist
- [ ] Release blog, docs landing page, tutorials live.
- [ ] Support rotation schedule published.
- [ ] Analytics/telemetry (if enabled) monitored.

### Exit Criteria
- Launch announcement delivered (blog + Grim/Ghostlang channels).
- First post-launch patch plan queued.
- Retrospective scheduled for Week 20.

---

## Governance & Review Cadence
- **Quarterly**: Review roadmap, adjust scope, consider community requests.
- **Monthly**: Performance and stability check-ins with Grim & Ghostlang teams.
- **Per-Release**: Milestone review to confirm exit criteria and update documentation.

---

*This roadmap evolves with feedback. Update alongside CODEX changes and ensure milestones remain realistic and measurable.*
