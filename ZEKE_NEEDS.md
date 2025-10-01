# Grove Requirements for Zeke Integration

**Project:** github.com/ghostkellz/grove
**Issue:** Missing tree-sitter vendor files blocking Zeke integration
**Status:** ⚠️ **BLOCKED** - Cannot build with Grove dependency
**Priority:** 🔥 **HIGH** - Required for AST-based code editing features

---

## 🚨 **Current Blocker**

### Build Error:
```
error: failed to check cache:
'/home/chris/.cache/zig/p/grove-0.0.0-rGFsN0MDNABGL_w5s6NKnWYwDHMcKtSiFo2bi5oC6lzk/vendor/tree-sitter/lib/src/lib.c'
file_hash FileNotFound
```

### Root Cause:
The Grove repository archive from GitHub is missing the vendored tree-sitter library files that are declared in `build.zig`:

```zig
// From Grove's build.zig
exe.addCSourceFile(.{
    .file = b.path("vendor/tree-sitter/lib/src/lib.c"),  // ← Missing!
    .flags = &.{ "-std=c99", "-DTREE_SITTER_STATIC=1", "-D_DEFAULT_SOURCE", "-D_GNU_SOURCE" },
});

exe.addCSourceFile(.{ .file = b.path("vendor/grammars/json/parser.c"), .flags = &.{"-std=c99"} });
exe.addCSourceFile(.{ .file = b.path("vendor/grammars/zig/parser.c"), .flags = &.{"-std=c99"} });
exe.addCSourceFile(.{ .file = b.path("vendor/grammars/ghostlang/parser.c"), .flags = &.{"-std=c99"} });
```

### Why This Happens:
- Tree-sitter is likely a **git submodule** that isn't included in GitHub's archive downloads
- When Zig fetches the tarball, submodule contents are not included
- The `vendor/` directory structure exists but without the actual C source files

---

## ✅ **Required Fixes for Grove**

### Option 1: Git Submodules (Recommended)

**In Grove Repository:**

1. **Initialize Git Submodules**
   ```bash
   cd ~/projects/grove

   # Add tree-sitter as submodule
   git submodule add https://github.com/tree-sitter/tree-sitter.git vendor/tree-sitter

   # Add grammar submodules
   git submodule add https://github.com/tree-sitter/tree-sitter-json.git vendor/grammars/json
   git submodule add https://github.com/maxxnino/tree-sitter-zig.git vendor/grammars/zig
   git submodule add https://github.com/ghostkellz/tree-sitter-ghostlang.git vendor/grammars/ghostlang

   # Initialize and update
   git submodule update --init --recursive
   ```

2. **Commit Submodule Configuration**
   ```bash
   git add .gitmodules vendor/
   git commit -m "Add tree-sitter and grammar submodules"
   git push
   ```

3. **Add Submodule Instructions to README**
   ```markdown
   ## Building Grove

   Grove uses git submodules for tree-sitter. Clone with:

   \`\`\`bash
   git clone --recurse-submodules https://github.com/ghostkellz/grove.git
   # OR after cloning:
   git submodule update --init --recursive
   \`\`\`
   ```

**Limitations:**
- GitHub archive downloads still won't work
- Users must clone with `--recurse-submodules`
- Zig's `zig fetch` won't work (Zig doesn't handle git submodules)

---

### Option 2: Vendor Files Directly (Zig-Friendly) ✅ **RECOMMENDED**

**In Grove Repository:**

1. **Download and Vendor Tree-sitter**
   ```bash
   cd ~/projects/grove

   # Create vendor directories
   mkdir -p vendor/tree-sitter/lib
   mkdir -p vendor/grammars/{json,zig,ghostlang}

   # Download tree-sitter core
   curl -L https://github.com/tree-sitter/tree-sitter/archive/refs/tags/v0.22.6.tar.gz | tar xz
   cp -r tree-sitter-0.22.6/lib vendor/tree-sitter/
   rm -rf tree-sitter-0.22.6

   # Download grammars
   for grammar in json zig ghostlang; do
       # Download and extract grammar files
       # Copy parser.c and other needed files
   done
   ```

2. **Commit Vendored Files**
   ```bash
   git add vendor/
   git commit -m "Vendor tree-sitter and grammars for Zig compatibility"
   git push
   ```

3. **Update .gitignore**
   ```gitignore
   # Don't ignore vendor directory
   !vendor/
   !vendor/**
   ```

**Advantages:**
- ✅ Works with `zig fetch`
- ✅ Works with GitHub archive downloads
- ✅ No submodule complexity
- ✅ Self-contained repository
- ✅ Reproducible builds

**Disadvantages:**
- Larger repository size
- Manual updates for tree-sitter upgrades

---

### Option 3: Zig Package Manager Approach

**In Grove's build.zig.zon:**

1. **Fetch tree-sitter as Zig dependency**
   ```zig
   .dependencies = .{
       .tree_sitter = .{
           .url = "https://github.com/tree-sitter/tree-sitter/archive/refs/tags/v0.22.6.tar.gz",
           .hash = "...", // Run zig fetch to get hash
       },
       .tree_sitter_json = .{
           .url = "https://github.com/tree-sitter/tree-sitter-json/archive/refs/heads/master.tar.gz",
           .hash = "...",
       },
       // ... other grammars
   };
   ```

2. **Update build.zig to use dependencies**
   ```zig
   const tree_sitter = b.dependency("tree_sitter", .{
       .target = target,
       .optimize = optimize,
   });

   exe.addCSourceFile(.{
       .file = tree_sitter.path("lib/src/lib.c"),
       .flags = &.{ "-std=c99", "-DTREE_SITTER_STATIC=1" },
   });
   ```

**Advantages:**
- ✅ Zig-native approach
- ✅ Automatic dependency management
- ✅ Works with `zig fetch`

**Disadvantages:**
- Requires refactoring build.zig
- Grammar repos might not have build.zig

---

## 📋 **Required Files for Grove**

### Tree-sitter Core:
```
vendor/tree-sitter/
├── lib/
│   ├── include/
│   │   └── tree_sitter/
│   │       ├── api.h
│   │       └── parser.h
│   └── src/
│       ├── lib.c          ← PRIMARY MISSING FILE
│       ├── alloc.c
│       ├── get_changed_ranges.c
│       ├── language.c
│       ├── lexer.c
│       ├── node.c
│       ├── parser.c
│       ├── query.c
│       ├── stack.c
│       ├── subtree.c
│       └── tree_cursor.c
```

### Grammar Parsers:
```
vendor/grammars/
├── json/
│   ├── parser.c           ← MISSING
│   └── scanner.c (if needed)
├── zig/
│   ├── parser.c           ← MISSING
│   └── scanner.c
├── ghostlang/
│   ├── parser.c           ← MISSING
│   └── scanner.c
└── (other grammars...)
```

---

## 🔧 **Testing After Fix**

Once Grove is fixed, test with:

```bash
# Remove cached grove
rm -rf ~/.cache/zig/p/grove-*

# Re-fetch
zig fetch --save https://github.com/ghostkellz/grove/archive/refs/heads/main.tar.gz

# Should now include all files
ls -la ~/.cache/zig/p/grove-*/vendor/tree-sitter/lib/src/lib.c
# ✅ File exists!

# Re-enable in Zeke
cd /data/projects/zeke

# Uncomment in build.zig.zon
# .grove = .{
#     .url = "https://github.com/ghostkellz/grove/archive/refs/heads/main.tar.gz",
#     .hash = "grove-...",
# },

# Uncomment in build.zig
# const grove = b.dependency("grove", .{ ... });

# Test build
zig build

# Should compile successfully!
```

---

## 🎯 **Zeke Features Waiting on Grove**

Once Grove is fixed, these features can be activated:

### AST-Based Code Intelligence:
- ✅ **Smart file analysis** - Extract functions, types, symbols
- ✅ **Syntax-aware refactoring** - Rename, extract function, inline
- ✅ **Go to definition** - Jump to symbol definitions
- ✅ **Find references** - Find all uses of a symbol
- ✅ **Syntax validation** - Real-time error detection
- ✅ **Syntax highlighting** - Tree-sitter powered

### Commands Ready to Activate:
```bash
# These are implemented but disabled:
zeke analyze <file>                    # Code analysis
zeke refactor rename <old> <new>       # Rename symbol
zeke refactor extract <start> <end>    # Extract function
zeke symbols <file>                    # List all symbols
zeke definition <file> <line> <col>    # Go to definition
zeke references <symbol>               # Find references
```

---

## 📊 **Impact on Zeke**

| Feature | Status Without Grove | Status With Grove |
|---------|---------------------|-------------------|
| Smart Git (Zap) | ✅ Working | ✅ Working |
| Code Search | ✅ Working | ✅ Working |
| File Operations | ✅ Working | ✅ Working |
| **AST Analysis** | ❌ Disabled | ✅ **ENABLED** |
| **Refactoring** | ❌ Disabled | ✅ **ENABLED** |
| **Symbol Navigation** | ❌ Disabled | ✅ **ENABLED** |
| **Syntax Validation** | ❌ Disabled | ✅ **ENABLED** |

---

## 🚀 **Recommended Action Plan**

### For Grove Maintainer:

**Week 1:**
1. Download tree-sitter v0.22.6 and grammar sources
2. Vendor all C files directly into `vendor/` directory
3. Test build locally
4. Commit and push

**Week 2:**
5. Add documentation for building
6. Test with `zig fetch` from external project
7. Verify Zeke integration works
8. Tag stable release (v0.1.0)

### For Zeke (After Grove Fixed):

1. Re-enable Grove in `build.zig.zon`
2. Re-enable Grove integration code
3. Test AST features
4. Document Grove-powered features
5. Ship Zeke Alpha with full code intelligence

---

## 📝 **Quick Fix Commands (For Grove Maintainer)**

```bash
# Clone Grove
cd ~/projects
git clone https://github.com/ghostkellz/grove.git
cd grove

# Download tree-sitter
curl -L https://github.com/tree-sitter/tree-sitter/archive/refs/tags/v0.22.6.tar.gz -o ts.tar.gz
tar xzf ts.tar.gz
mkdir -p vendor/tree-sitter
cp -r tree-sitter-0.22.6/lib vendor/tree-sitter/
rm -rf tree-sitter-0.22.6 ts.tar.gz

# Download JSON grammar
curl -L https://github.com/tree-sitter/tree-sitter-json/archive/refs/heads/master.tar.gz -o json.tar.gz
tar xzf json.tar.gz
mkdir -p vendor/grammars/json
cp tree-sitter-json-master/src/parser.c vendor/grammars/json/
rm -rf tree-sitter-json-master json.tar.gz

# Download Zig grammar
curl -L https://github.com/maxxnino/tree-sitter-zig/archive/refs/heads/master.tar.gz -o zig.tar.gz
tar xzf zig.tar.gz
mkdir -p vendor/grammars/zig
cp tree-sitter-zig-master/src/parser.c vendor/grammars/zig/
rm -rf tree-sitter-zig-master zig.tar.gz

# (Repeat for ghostlang grammar)

# Verify files exist
ls -la vendor/tree-sitter/lib/src/lib.c
ls -la vendor/grammars/*/parser.c

# Commit
git add vendor/
git commit -m "feat: Vendor tree-sitter and grammars for Zig compatibility

Fixes build issues when using Grove as a Zig dependency.
Now works with zig fetch and GitHub archive downloads."

git push origin main

# Tag release
git tag -a v0.1.0 -m "First stable release with vendored dependencies"
git push origin v0.1.0
```

---

## ✅ **Success Criteria**

Grove is ready for Zeke when:

1. ✅ `zig fetch https://github.com/ghostkellz/grove/archive/refs/heads/main.tar.gz` succeeds
2. ✅ File `~/.cache/zig/p/grove-*/vendor/tree-sitter/lib/src/lib.c` exists
3. ✅ Zeke builds with Grove dependency enabled
4. ✅ Grove's example programs compile and run
5. ✅ Tree-sitter parsing works for all supported languages

---

**Status:** Waiting on Grove vendor files fix

**Blocker:** Missing tree-sitter C source files in repository

**ETA:** ~1-2 hours of work to vendor files + test

**Priority:** HIGH - Blocks 40% of Zeke's planned features

---

**Last Updated:** 2025-10-01
**Reported By:** Zeke Integration Team
**Affects:** AST-based code intelligence, refactoring, symbol navigation
