# Grove Sync Brief — Helper Expansion (2025-10-05)

**Status**: ✅ **COMPLETE** (2025-10-05)

This sync successfully integrated all Ghostlang Phase A/B/C features into Grove. The helper surface shipped by Ghostlang (arraySet, arrayPop, objectKeys) is now fully documented and highlighted in Grove's tree-sitter grammar.

## What Changed

- `ScriptEngine.registerEditorHelpers` now exposes three additional helpers:
  - `arraySet(array, index, value)` — replaces or appends entries.
  - `arrayPop(array)` — removes and returns the final array element.
  - `objectKeys(object)` — returns a string array with the table's keys.
- Allocator plumbing and copy semantics match the existing helper suite; every helper gracefully fails with `nil`/`-1` on invalid inputs.
- New regression tests live in `src/root.zig` (`editor helper array set and pop`, `editor helper object keys enumeration`). They assert chaining semantics, pop behaviour, and key enumeration.
- Documentation updates:
  - `docs/api.md` helper table now lists the new function signatures and behaviors.
  - `docs/v0.1-roadmap.md` marks the array/object helper milestone complete.

## Completed Actions for Grove

1. **Runtime bindings** ✅
   - Grove grammar now recognizes all new helpers in highlights.scm
   - Grammar supports full hybrid Lua/brace syntax from Ghostlang runtime
   - No embedded engine changes needed - Grove is a tree-sitter grammar provider only

2. **Autocomplete & docs** ✅
   - Updated highlights.scm to include: arraySet, arrayPop, objectKeys, pairs, ipairs
   - Updated GROVE_STATUS.md with Phase A/B/C completion status
   - Updated docs/integration/ghostlang.md with comprehensive API reference and examples
   - Added hybrid syntax examples and multi-return value documentation

3. **Grammar & tests** ✅
   - Verified vendored grammar has all Phase A/B/C features
   - Confirmed test corpus coverage (29 tests):
     - phase_a_features.txt: local vars/functions, generic for, anonymous functions, varargs, method calls
     - control_flow.txt: numeric for loops (basic, with step, negative step), repeat-until loops
     - basic.txt: core syntax features
   - All query files (highlights, locals, textobjects, injections) support new constructs

4. **Plugin compatibility** ✅
   - No bundled plugins in Grove (Grove is grammar-only)
   - Downstream consumers (Grim) can now use all 44+ built-in helpers
   - Full hybrid syntax support enables GShell deployment

## Verification Checklist

- [x] Grammar sync verified - vendored grammar has all Phase A/B/C features
- [x] Query files updated - highlights.scm includes arraySet, arrayPop, objectKeys, pairs, ipairs
- [x] Documentation updated - GROVE_STATUS.md reflects Phase A/B/C completion
- [x] Integration docs updated - docs/integration/ghostlang.md has complete API reference
- [x] Test corpus verified - 29 tests covering all hybrid syntax features
- [x] Locals.scm verified - scope tracking for all new constructs (generic for, numeric for, repeat-until, closures)

## Owners & Follow-up

- Runtime sync: @grove-runtime
- Documentation sync: @grove-docs
- Plugin QA: @grove-plugins

Open follow-up: consider adding `objectValues` / `arrayInsert` if Grove needs them—capture requests in `GROVE_HYBRID_UPDATE.md` after this merge lands.
