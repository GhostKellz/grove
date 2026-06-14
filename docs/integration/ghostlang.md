# Ghostlang Integration

Grove bundles the production Ghostlang Tree-sitter grammar with **full hybrid Lua/brace syntax support** so editors can light up Grim plugin scripts out of the box. This note captures the essentials for downstream consumers.

**Status**: ✅ Fully synchronized with Ghostlang Phase A/B/C runtime (Oct 2025)

## Language Handle

- Call `grove.Languages.ghostlang.get()` to obtain the vendored `TSLanguage` wrapper.
- File extension: `.gla` maps to Ghostlang sources in Grim.
- The parser is built directly from `vendor/tree-sitter-ghostlang/src/parser.c`.

## Query Assets

`vendor/tree-sitter-ghostlang/queries/` ships the full query suite:

- `highlights.scm` – syntax highlighting with dedicated captures for **44+ editor API calls** (`@function.builtin`), including:
  - New helpers: `arraySet`, `arrayPop`, `objectKeys`
  - Iterator functions: `pairs`, `ipairs`
  - All Lua-style keywords: `local`, `then`, `elseif`, `do`, `end`, `repeat`, `until`, `in`, `and`, `or`, `not`
- `locals.scm` – scope and definition tracking for navigation and renaming, including:
  - Local variable and function scopes
  - Generic and numeric for loop control variables
  - Repeat-until block scopes
  - Closure capture tracking
- `textobjects.scm` – smart selections for functions, calls, blocks, strings, and comments.
- `injections.scm` – embedded language detection for JSON, CSS, SQL, and regex payloads inside Ghostlang strings.

Each file is ready to load through `grove.Query` helpers or custom pipelines. Grove does not hardcode queries so consumers may supply theme-specific rule tables.

## Upstream Source

- Repository: [`GhostKellz/tree-sitter-ghostlang`](https://github.com/GhostKellz/tree-sitter-ghostlang)
- Ghostlang Source Extension: `.gla`
- Grammar Version: Phase A/B/C complete (Oct 2025)
- Tree-sitter: 0.25+ (ABI 15)
- Features:
  - ✅ Hybrid Lua/brace syntax
  - ✅ Generic and numeric for loops
  - ✅ Local functions and closures
  - ✅ Multi-return values
  - ✅ Repeat-until loops
  - ✅ Method call syntax (`:`)
  - ✅ Varargs (`...`)
  - ✅ Break/continue statements
  - ✅ 44+ built-in editor helpers

## Testing Tips

- Regenerate the grammar in the standalone `tree-sitter-ghostlang` repository and vendor its tracked files into `vendor/tree-sitter-ghostlang/`:

  ```bash
  npm install
  npx tree-sitter generate
  npx tree-sitter test
  ```

- Grove’s unit tests cover `grove.Languages.ghostlang.get()`; add integration tests by parsing sample `.gla` fixtures and loading highlight queries through `grove.HighlightEngine`.

For deeper context, see `vendor/tree-sitter-ghostlang/docs/integration/grove.md` in this repository.

---

## Ghostlang Runtime API (Phase A/B/C)

Grove's grammar supports all Ghostlang runtime features. Key API highlights:

### New Helper Functions (Phase C)

```javascript
// Array manipulation
var arr = createArray();
arrayPush(arr, "item");
arraySet(arr, 0, "new value");  // ✨ NEW: Set by index
var last = arrayPop(arr);        // ✨ NEW: Remove and return last element
var len = arrayLength(arr);
var item = arrayGet(arr, 0);

// Object manipulation
var obj = createObject();
objectSet(obj, "key", "value");
var value = objectGet(obj, "key");
var keys = objectKeys(obj);      // ✨ NEW: Get all object keys as array

// Iterator functions
for k, v in pairs(obj) do        // ✨ Iterate over object key-value pairs
  log(k, v);
end

for i, val in ipairs(arr) do     // ✨ Iterate over array with 1-based indexing
  log(i, val);
end
```

### Multi-Return Values (Phase B)

```javascript
// Functions can return multiple values
function divmod(a, b) {
  return a / b, a % b;           // ✨ Return multiple values
}

// Destructure multiple returns
var quotient, remainder = divmod(10, 3);

// Forward multiple returns
function wrapper() {
  return divmod(20, 6);          // ✨ Pass through multiple returns
}
```

### Closures & Upvalues (Phase B)

```javascript
function makeCounter() {
  local count = 0;               // ✨ Local variable captured by closure
  return function() {
    count = count + 1;           // ✨ Upvalue access
    return count;
  };
}

var counter1 = makeCounter();
log(counter1());  // 1
log(counter1());  // 2
```

### Hybrid Syntax Examples

Ghostlang supports **both Lua-style and brace-style** syntax:

```javascript
// Lua-style
if x > 10 then
  log("big");
elseif x > 5 then
  log("medium");
else
  log("small");
end

// Brace-style
if (x > 10) {
  log("big");
} else if (x > 5) {
  log("medium");
} else {
  log("small");
}

// Both styles can be mixed
for i = 1, 10 do              // Lua-style for
  if (i % 2 == 0) {           // Brace-style if
    continue;
  }
  log(i);
end
```

For complete API reference, see [`archive/ghostlang/docs/api.md`](../../archive/ghostlang/docs/api.md).
