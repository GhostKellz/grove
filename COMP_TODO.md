# Grove Comprehensive Polishing TODO

**Last Updated:** 2025-10-29
**Status:** Phase 2 - Production Editor Integration

This document synthesizes insights from the entire Ghost ecosystem (GhostLang, GhostLS, Grim, and Grove) to identify the highest-impact next steps for making Grove the best tree-sitter wrapper for Zig.

---

## Executive Summary

Grove is a high-performance tree-sitter wrapper currently used by:
- **Grim** (v0.6.3) - Neovim-like editor with 15 language support
- **GhostLS** (v0.4.0) - Native LSP server for Ghostlang
- **GhostLang** (v0.2.1) - Production-ready scripting runtime

**Current State:**
- ✅ 15 bundled grammars (JSON, Zig, Rust, Ghostlang, TypeScript, TSX, Bash, JS, Python, Markdown, CMake, TOML, YAML, C, GShell)
- ✅ Tree-sitter 0.25.10 (ABI 15) support
- ✅ Core wrapper APIs complete
- ✅ Editor utilities (Query, Highlight, Editor)
- ✅ REPL/Shell APIs for GShell
- 🔄 Performance benchmarks baseline established
- ⚠️ **Critical Gap**: Grim has stub TODOs for Grove integration (`syntax/grove.zig:254,260`)

**Mission:** Eliminate all blockers preventing Grove from being the premier tree-sitter experience for Zig editors, with specific focus on completing Grim integration and performance optimization.

---

## Priority 1: Critical Blockers (Week 1-2)

### 1.1 Complete Grim Integration [CRITICAL]

**Problem:** Grim has fallback lexical highlighting because Grove integration is incomplete.

**Files Affected:**
- `/data/projects/grim/syntax/grove.zig:254` - "TODO: Implement Grove parsing when dependency is available"
- `/data/projects/grim/syntax/grove.zig:260` - "TODO: Implement full Grove tree-sitter highlighting when dependency is available"

**Required Actions:**
- [ ] **Implement `grove.zig` parsing functions** - Wire Grove's `Parser.parseUtf8()` into Grim's syntax system
- [ ] **Connect Grove highlight queries** - Integrate `grove.Highlight.collectHighlights()` with Grim's rendering pipeline
- [ ] **Test with all 15 grammars** - Ensure Zig, Rust, Ghostlang, TypeScript, Python, etc. highlight correctly
- [ ] **Verify Phantom TUI integration** - Confirm highlights render correctly in double-buffered terminal
- [ ] **Measure performance** - Ensure <5ms incremental parse latency (Grim's target)

**Success Criteria:**
- Grim removes lexical fallback and uses Grove exclusively
- All 15 languages render with proper syntax highlighting
- No flickering or rendering artifacts
- Performance meets Grim's <5ms latency requirement

**Blocking:** This prevents Grim from achieving full production quality.

---

### 1.2 Incremental Parsing Optimization

**Problem:** GhostLS and Grim both have TODOs for incremental parsing optimization.

**Affected Systems:**
- `/data/projects/grim/ui-tui/syntax_highlights.zig:105` - "TODO: Implement incremental parsing with Grove"
- GhostLS uses full document sync (`TextDocumentSyncKind.Full = 1`) but has incremental infrastructure

**Required Actions:**
- [ ] **Add benchmark for incremental edits** - Extend `bench-latency` to test edit scenarios
- [ ] **Optimize `grove.InputEdit` usage** - Reduce allocations in edit path
- [ ] **Cache AST nodes across edits** - Implement tree node reuse strategy
- [ ] **Document incremental best practices** - Provide examples for editor integrators

**Target Metrics:**
- **<5ms** incremental parse latency (insert/delete single line)
- **<10ms** for complex edits (paste multi-line code)
- **<100ms** for large file operations (1000+ line diffs)

**Success Criteria:**
- Grim implements incremental parsing using Grove APIs
- GhostLS switches to incremental sync (`TextDocumentSyncKind.Incremental = 2`)
- Benchmark results meet or exceed targets

---

### 1.3 Query System Enhancements

**Problem:** Grim and GhostLS rely heavily on queries, but some advanced features are missing.

**Current Gaps:**
- No query caching/validation at build time
- No support for custom predicates (`#is?`, `#match?`)
- Limited error messages for malformed queries

**Required Actions:**
- [ ] **Add query compilation/validation API** - `grove.Query.compile(source, language)` with detailed errors
- [ ] **Implement predicate support** - Handle `#is?`, `#match?`, `#eq?`, `#any-of?` in `QueryCursor`
- [ ] **Add query caching** - Memoize compiled queries by hash for reuse
- [ ] **Expose query metadata** - Provide capture names, pattern count, etc. for tooling

**Success Criteria:**
- GhostLS can validate `.scm` files at startup
- Grim can use complex highlight queries with predicates
- Clear error messages for bad queries (line/column, context)

---

## Priority 2: Performance Optimization (Week 3-4)

### 2.1 Parsing Throughput

**Target:** ≥10 MB/s (meet or exceed C tree-sitter baseline)

**Current Status:** Baseline benchmark established (`zig build bench`)

**Required Actions:**
- [ ] **Profile hot paths** - Use `perf` to identify allocator/tree-walking bottlenecks
- [ ] **Optimize allocator strategy** - Test arena vs GPA for parsing workloads
- [ ] **Reduce allocations** - Move to stack allocations where possible
- [ ] **Benchmark against C tree-sitter** - Head-to-head comparison with same inputs
- [ ] **Test with real codebases** - Parse Zig stdlib, Rust coreutils, TypeScript compiler

**Target Benchmarks:**
- Zig stdlib (120k lines): <2s cold parse
- Large TypeScript file (10k lines): <100ms cold parse
- Incremental edits: <5ms average

**Success Criteria:**
- Match or exceed C tree-sitter throughput
- 50% lower memory footprint than C implementation
- Zero allocations on incremental edits (using arena)

---

### 2.2 Memory Optimization

**Target:** <100 MB while indexing 10k-file projects

**Current Issues:**
- Tree nodes not pooled
- Query cursors allocate on every use
- No tree serialization/caching

**Required Actions:**
- [ ] **Implement tree pooling** - Reuse tree allocations across parses
- [ ] **Add query cursor pooling** - `grove.QueryCursorPool` for LSP servers
- [ ] **Reduce tree memory footprint** - Compact node storage
- [ ] **Add tree serialization** - Cache parsed trees to disk for large projects
- [ ] **Implement weak references** - Allow GC of unused trees

**Target Metrics:**
- Tree overhead: <5 KB per 1k LOC
- Query cursor: <1 KB per cursor
- Total memory: <100 MB for 10k files (1M LOC)

---

### 2.3 Multi-threading Support

**Problem:** GhostLS and Grim are single-threaded for parsing.

**Required Actions:**
- [ ] **Make `Parser` thread-safe** - Document threading model
- [ ] **Implement `ParserPool`** - Thread-local parser instances (already sketched in README)
- [ ] **Add parallel parsing API** - `grove.parseFiles([]Path, allocator)` with work stealing
- [ ] **Test with GhostLS workspace symbols** - Parallel indexing of project files

**Success Criteria:**
- GhostLS can index workspace in parallel
- Grim can pre-parse open buffers on background thread
- Linear speedup with CPU cores (up to 8 cores)

---

## Priority 3: Editor Features (Week 5-6)

### 3.1 Advanced Tree-sitter Features

**Missing Features from Upstream:**
- Injection layers (embedded languages)
- Local variable tracking
- Conceal syntax (markdown links, LaTeX)
- Spellcheck regions

**Required Actions:**
- [ ] **Implement injection support** - `grove.parseWithInjections(tree, source, injections_query)`
- [ ] **Add locals.scm support** - Track variable scopes for LSP
- [ ] **Expose conceal ranges** - For markdown/LaTeX rendering
- [ ] **Add spellcheck regions** - Mark comments/strings for external spellchecker

**Use Cases:**
- Grim: Highlight markdown code blocks with nested languages
- GhostLS: Track local variable scopes for go-to-definition
- Grim: Render markdown links as concealed text

---

### 3.2 LSP-Specific Helpers

**Problem:** GhostLS duplicates logic that should be in Grove.

**Required Actions:**
- [ ] **Add `grove.getSymbols(tree, source)`** - Extract function/class/variable symbols
- [ ] **Add `grove.getFolds(tree)`** - Calculate folding ranges
- [ ] **Add `grove.getHighlightSpans(tree, source, query)`** - Return LSP SemanticTokens format
- [ ] **Add `grove.getReferences(tree, source, position)`** - Find symbol references

**Success Criteria:**
- GhostLS removes custom symbol extraction logic
- 50% reduction in GhostLS codebase by using Grove helpers
- Other LSP servers can easily adopt Grove

---

### 3.3 Error Recovery & Diagnostics

**Problem:** Limited error recovery support.

**Current State:**
- `grove.getSyntaxErrors()` exists but returns minimal info
- No suggestions for error recovery

**Required Actions:**
- [ ] **Enhance error messages** - Include context, expected tokens
- [ ] **Add error recovery hints** - Suggest fixes (missing semicolon, etc.)
- [ ] **Expose parse state** - Allow LSP servers to inspect incomplete parses
- [ ] **Add incremental error tracking** - Only re-report changed errors

**Success Criteria:**
- GhostLS provides actionable error messages
- Grim shows inline suggestions for syntax errors
- Errors update incrementally without full re-parse

---

## Priority 4: Ecosystem & Polish (Week 7-8)

### 4.1 Documentation & Examples

**Current Gaps:**
- No comprehensive API documentation
- Limited examples beyond JSON parsing
- No editor integration guide

**Required Actions:**
- [ ] **Write API reference** - Document every public function with examples
- [ ] **Create editor integration guide** - Step-by-step for building a syntax highlighter
- [ ] **Add advanced examples** - Injection, incremental parsing, multi-threading
- [ ] **Document performance tips** - Allocator choice, caching strategies
- [ ] **Write grammar porting guide** - How to add new languages to Grove

**Deliverables:**
- `docs/API.md` - Complete API reference
- `docs/EDITOR_INTEGRATION.md` - Tutorial for editor authors
- `docs/GRAMMAR_GUIDE.md` - Adding new grammars
- `examples/` directory with 5+ examples

---

### 4.2 Testing & Quality Assurance

**Current State:**
- Basic tests for JSON parsing
- No fuzz testing
- No corpus tests for all 15 grammars

**Required Actions:**
- [ ] **Add corpus tests** - Test all 15 grammars against upstream test cases
- [ ] **Implement fuzz testing** - AFL/libFuzzer for parser robustness
- [ ] **Add memory leak detection** - Valgrind/ASAN in CI
- [ ] **Benchmark regression tests** - Alert on performance degradation
- [ ] **Add integration tests** - Full editor workflows (open, edit, save)

**Target Coverage:**
- 90% code coverage
- All grammars pass upstream corpus tests
- Zero memory leaks/UB under fuzz testing

---

### 4.3 Packaging & Distribution

**Current Gaps:**
- Grove v0.1.1 is hardcoded in Grim's `build.zig.zon`
- No semantic versioning policy
- No prebuilt binaries

**Required Actions:**
- [ ] **Establish versioning policy** - SemVer with compatibility guarantees
- [ ] **Create release automation** - Tag, build, publish to Zig package registry
- [ ] **Add prebuilt binaries** - GitHub releases for common platforms
- [ ] **Document upgrade path** - Migration guides between versions
- [ ] **Add CLI tool** - `grove` binary for grammar testing/validation

**Success Criteria:**
- Users can `zig fetch` latest Grove release
- Automated CI/CD for releases
- Breaking changes are clearly documented

---

## Priority 5: Future Innovations (Post-8 Weeks)

### 5.1 Native Zig Parser Runtime

**Vision:** Replace C tree-sitter with native Zig implementation.

**Benefits:**
- 2-3x performance improvement
- Better Zig integration (no FFI overhead)
- Compile-time grammar validation

**Research Areas:**
- [ ] Study tree-sitter LR parser generator
- [ ] Prototype Zig PEG parser
- [ ] Benchmark GLR vs LR(1) for editor use cases
- [ ] Design Zig-native grammar format

**Timeline:** Phase 3 (post-Phase 2 completion)

---

### 5.2 GPU-Accelerated Highlighting

**Vision:** Offload syntax highlighting to GPU for massive files.

**Use Case:** Grim rendering 100k+ line files

**Research Areas:**
- [ ] Prototype WebGPU/Vulkan compute shader for tree-sitter
- [ ] Benchmark vs CPU for different file sizes
- [ ] Design shader-friendly query format

**Timeline:** Phase 3 (speculative)

---

### 5.3 LSP Server Generator

**Vision:** Auto-generate LSP servers from tree-sitter grammars.

**Example:** `grove lsp-generate typescript` → full TypeScript LSP

**Required:**
- [ ] Define LSP feature templates
- [ ] Generate boilerplate from grammar rules
- [ ] Provide extension points for custom logic

**Timeline:** Phase 3 (ecosystem expansion)

---

## Dependency Matrix

This matrix shows which Grove improvements unblock other projects:

| Grove Feature | Grim | GhostLS | GhostLang | Priority |
|---------------|------|---------|-----------|----------|
| Complete `grove.zig` integration | 🔴 BLOCKED | ✅ | ✅ | P1 |
| Incremental parsing optimization | 🟡 Needed | 🟡 Needed | ✅ | P1 |
| Query predicate support | 🟡 Needed | ✅ | N/A | P1 |
| Multi-threading (ParserPool) | ✅ | 🟡 Needed | N/A | P2 |
| Injection support (embedded langs) | 🟡 Needed | N/A | N/A | P3 |
| LSP helper APIs | ✅ | 🟡 Needed | N/A | P3 |
| Enhanced error recovery | 🟡 Needed | 🟡 Needed | 🟡 Needed | P3 |

**Legend:**
- 🔴 BLOCKED: Cannot proceed without this
- 🟡 Needed: High value, not blocking
- ✅ Satisfied: No immediate need
- N/A: Not applicable

---

## Recommended 8-Week Sprint Plan

### Week 1-2: Unblock Grim
- [ ] Implement full Grove parsing in Grim's `syntax/grove.zig`
- [ ] Test all 15 grammars in Grim
- [ ] Document integration in `docs/EDITOR_INTEGRATION.md`

### Week 3-4: Performance Optimization
- [ ] Profile and optimize parsing throughput (target: ≥10 MB/s)
- [ ] Reduce memory footprint (target: <100 MB for 10k files)
- [ ] Implement incremental parsing optimizations

### Week 5-6: Editor Features
- [ ] Add injection support for embedded languages
- [ ] Implement LSP helper APIs (`getSymbols`, `getFolds`, etc.)
- [ ] Add query predicate support

### Week 7-8: Polish & Release
- [ ] Complete API documentation
- [ ] Add comprehensive test suite (corpus, fuzz, integration)
- [ ] Set up release automation and versioning
- [ ] Publish Grove v0.2.0 with all Phase 2 features

---

## Success Metrics (8-Week Goal)

**Performance:**
- ✅ Parsing throughput: ≥10 MB/s (match C tree-sitter)
- ✅ Incremental latency: <5 ms average
- ✅ Memory footprint: <100 MB for 10k files
- ✅ 50% lower memory than C tree-sitter

**Integration:**
- ✅ Grim uses Grove exclusively (no lexical fallback)
- ✅ GhostLS switches to incremental sync
- ✅ All 15 grammars render correctly in Grim
- ✅ Zero rendering artifacts/flicker

**Quality:**
- ✅ 90% test coverage
- ✅ All grammars pass upstream corpus tests
- ✅ Zero memory leaks/UB under fuzz testing
- ✅ Complete API documentation

**Ecosystem:**
- ✅ Automated release pipeline
- ✅ Published to Zig package registry
- ✅ 3+ example integrations (Grim, GhostLS, standalone tool)
- ✅ External contributors using Grove

---

## Action Items (This Week)

**Immediate (Next 3 Days):**
1. [ ] Open issue in Grim repo: "Complete Grove integration (remove lexical fallback)"
2. [ ] Create branch: `grove/grim-integration`
3. [ ] Implement parsing functions in `/data/projects/grim/syntax/grove.zig`
4. [ ] Write test case for Ghostlang highlighting in Grim

**This Week:**
5. [ ] Extend Grove benchmark suite with incremental edit tests
6. [ ] Profile Grove with `perf` to identify hot paths
7. [ ] Document current Grove API in `docs/API.md` (draft)
8. [ ] Add corpus tests for all 15 grammars

**Next Week:**
9. [ ] Complete Grim integration PR and merge
10. [ ] Release Grove v0.1.2 with performance fixes
11. [ ] Start work on query predicate support
12. [ ] Collaborate with Grim team on incremental parsing

---

## Community Engagement

**Forums:**
- Announce Grove Phase 2 progress on Zig forum
- Share benchmarks comparing Grove vs rust-analyzer tree-sitter
- Write blog post: "Building the fastest tree-sitter wrapper in Zig"

**Collaboration:**
- Invite Helix/Zed/Lapce maintainers to try Grove
- Contribute upstream to tree-sitter project (bug fixes, docs)
- Mentor contributors adding new grammars

---

## Conclusion

Grove is on the cusp of becoming the premier tree-sitter experience for Zig. The highest-impact work is:

1. **Complete Grim integration** - Unblocks production use
2. **Optimize performance** - Match/exceed C tree-sitter
3. **Add missing features** - Injections, predicates, LSP helpers
4. **Polish & release** - Documentation, tests, packaging

With focused effort over the next 8 weeks, Grove can achieve all Phase 2 goals and position itself as the best tree-sitter wrapper across any language ecosystem.

---

**Next Review:** 2025-11-05 (1 week from now)
**Maintainer:** GhostKellz
**Stakeholders:** Grim, GhostLS, Ghostlang, Zig community
