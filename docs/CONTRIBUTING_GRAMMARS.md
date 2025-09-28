# Contributing New Grammars to Grove

This guide walks you through adding support for a new programming language to Grove using Tree-sitter grammars.

## Overview

Grove uses Tree-sitter parsers to provide syntax highlighting, semantic analysis, and editor features for multiple programming languages. Adding a new language involves:

1. Obtaining or creating a Tree-sitter grammar
2. Integrating the grammar into Grove's build system
3. Creating language-specific queries for features like highlighting and folding
4. Adding editor integration and semantic analysis support
5. Testing and documentation

## Prerequisites

- Basic understanding of Tree-sitter and its query syntax
- Familiarity with Zig build system
- The programming language you want to add support for

## Step 1: Obtain a Tree-sitter Grammar

### Option A: Use an Existing Grammar

Most popular languages already have Tree-sitter grammars available:

```bash
# Find grammars at: https://github.com/tree-sitter
# Common ones include:
# - tree-sitter-python
# - tree-sitter-go
# - tree-sitter-c
# - tree-sitter-cpp
# - tree-sitter-java
# - tree-sitter-ruby
# - tree-sitter-kotlin
# - tree-sitter-swift
```

Add the grammar as a git submodule:

```bash
# Example for Python
git submodule add https://github.com/tree-sitter/tree-sitter-python archive/tree-sitter-python
cd archive/tree-sitter-python
npm install  # Generate parser.c if needed
```

### Option B: Create a New Grammar

If no grammar exists, you'll need to create one. Follow the [Tree-sitter documentation](https://tree-sitter.github.io/tree-sitter/creating-parsers).

## Step 2: Integrate into Build System

### 2.1 Add Grammar Files

Copy the generated parser files to the vendor directory:

```bash
# Create language directory
mkdir -p vendor/grammars/your_language

# Copy essential files
cp archive/tree-sitter-your-language/src/parser.c vendor/grammars/your_language/
# Copy scanner.c if it exists (for languages with external scanners)
cp archive/tree-sitter-your-language/src/scanner.c vendor/grammars/your_language/
```

### 2.2 Update build.zig

Add your language to the build configuration in `build.zig`:

```zig
// Add source file variables (around line 35)
const your_language_grammar_source = b.path("vendor/grammars/your_language/parser.c");
const your_language_scanner_source = b.path("vendor/grammars/your_language/scanner.c"); // if exists

// Add to module (around line 67)
mod.addCSourceFile(.{ .file = your_language_grammar_source, .flags = &.{"-std=c99"} });
// Add scanner if it exists
mod.addCSourceFile(.{ .file = your_language_scanner_source, .flags = &.{"-std=c99"} });
```

### 2.3 Update src/languages.zig

Add your language to the bundled languages:

```zig
// In the Bundled struct, add:
pub const your_language = LanguageDefinition{
    .name = "your_language",
    .source = c.tree_sitter_your_language,
};

// Update the allLanguages array:
pub const allLanguages = [_]LanguageDefinition{
    // ... existing languages
    .your_language,
};
```

### 2.4 Add C Binding

Add the external declaration in `src/c/tree_sitter.zig`:

```zig
// Add to extern block
pub extern fn tree_sitter_your_language() *const TSLanguage;
```

## Step 3: Create Language Queries

Tree-sitter queries define how to extract semantic information from the parse tree. Create query files in your grammar directory:

### 3.1 Highlights Query (`vendor/grammars/your_language/queries/highlights.scm`)

This defines syntax highlighting rules:

```scheme
; Example highlights.scm for a C-like language
(identifier) @variable
(function_definition name: (identifier) @function)
(call_expression function: (identifier) @function.call)

(string_literal) @string
(number_literal) @number
(comment) @comment

["class" "struct" "enum"] @keyword.type
["if" "else" "while" "for" "return"] @keyword.control
["public" "private" "static"] @keyword.modifier

(type_identifier) @type
(primitive_type) @type.builtin

["(" ")" "[" "]" "{" "}"] @punctuation.bracket
[";" "," "."] @punctuation.delimiter
```

### 3.2 Locals Query (`vendor/grammars/your_language/queries/locals.scm`)

This defines scope and variable binding information:

```scheme
; Function definitions create scopes
(function_definition) @local.scope

; Parameter definitions
(parameter_declaration name: (identifier) @local.definition.parameter)

; Variable definitions
(variable_declaration declarator: (identifier) @local.definition.variable)

; References to variables
(identifier) @local.reference
```

### 3.3 Textobjects Query (`vendor/grammars/your_language/queries/textobjects.scm`)

This defines code objects for navigation:

```scheme
(function_definition) @function.outer
(function_definition body: (compound_statement) @function.inner)

(class_declaration) @class.outer
(class_declaration body: (declaration_list) @class.inner)

(if_statement) @conditional.outer
(while_statement) @loop.outer
(for_statement) @loop.outer

(comment) @comment.outer
```

### 3.4 Folding Query (`vendor/grammars/your_language/queries/folding.scm`)

This defines what code sections can be folded:

```scheme
[
  (function_definition)
  (class_declaration)
  (compound_statement)
  (array_initializer)
  (comment)
] @fold
```

## Step 4: Add Editor Integration

### 4.1 Create Language Utilities

Create a new file `src/editor/your_language.zig`:

```zig
const std = @import("std");
const grove = @import("../root.zig");

pub const YourLanguageUtilities = struct {
    allocator: std.mem.Allocator,
    language: grove.Language,

    pub fn init(allocator: std.mem.Allocator) !YourLanguageUtilities {
        return .{
            .allocator = allocator,
            .language = try grove.Languages.your_language.get(),
        };
    }

    pub fn documentSymbols(self: YourLanguageUtilities, root: grove.Node, source: []const u8) ![]grove.LSP.DocumentSymbol {
        // Implement document symbol extraction
        // This should use Tree-sitter queries to find functions, classes, etc.
        _ = self;
        _ = root;
        _ = source;
        return &.{};
    }

    pub fn foldingRanges(self: YourLanguageUtilities, root: grove.Node, source: []const u8) ![]grove.LSP.FoldingRange {
        // Implement folding range extraction
        _ = self;
        _ = root;
        _ = source;
        return &.{};
    }
};
```

### 4.2 Update Editor Services

Add your language to `src/editor/all_languages.zig`:

```zig
// Import your utilities
const YourLanguageUtilities = @import("your_language.zig").YourLanguageUtilities;

// Add to LanguageUtilities union
pub const LanguageUtilities = union(enum) {
    // ... existing languages
    your_language: YourLanguageUtilities,

    // Add to init method
    pub fn init(allocator: std.mem.Allocator, language: grove.Language) !LanguageUtilities {
        const name = language.name();
        // ... existing language checks
        if (std.mem.eql(u8, name, "your_language")) {
            return .{ .your_language = try YourLanguageUtilities.init(allocator) };
        }
        return error.UnsupportedLanguage;
    }
};
```

### 4.3 Update Query Registry

Add queries to `src/editor/query_registry.zig`:

```zig
// In registerAllQueries method, add:
try self.registerLanguageQueries("your_language", .{
    .highlights = @embedFile("../vendor/grammars/your_language/queries/highlights.scm"),
    .locals = @embedFile("../vendor/grammars/your_language/queries/locals.scm"),
    .textobjects = @embedFile("../vendor/grammars/your_language/queries/textobjects.scm"),
    .folding = @embedFile("../vendor/grammars/your_language/queries/folding.scm"),
});
```

## Step 5: Add Semantic Analysis Support

### 5.1 Create Language-Specific Analyzer

Add your language to `src/semantic/analyzers.zig`:

```zig
pub const YourLanguageAnalyzer = struct {
    allocator: std.mem.Allocator,
    base: SemanticAnalyzer,
    traversal: TreeTraversal,

    pub fn init(allocator: std.mem.Allocator) !YourLanguageAnalyzer {
        const language = try Languages.your_language.get();
        var base = SemanticAnalyzer.init(allocator, language);

        // Register language-specific queries
        try base.registerQuery("functions",
            \\(function_definition
            \\  name: (identifier) @function.name
            \\  parameters: (parameter_list) @function.params
            \\  body: (compound_statement) @function.body)
        );

        return .{
            .allocator = allocator,
            .base = base,
            .traversal = TreeTraversal.init(allocator),
        };
    }

    pub fn deinit(self: *YourLanguageAnalyzer) void {
        self.base.deinit();
    }

    pub fn findFunctions(self: *YourLanguageAnalyzer, cursor: *SemanticCursor) ![]FunctionInfo {
        // Implement function finding using your queries
        // Similar to TypeScript/Zig analyzers
        _ = self;
        _ = cursor;
        return &.{};
    }
};
```

### 5.2 Update Semantic Module

Add factory function to `src/semantic.zig`:

```zig
pub fn createYourLanguageAnalyzer(allocator: std.mem.Allocator) !YourLanguageAnalyzer {
    return YourLanguageAnalyzer.init(allocator);
}
```

### 5.3 Update LSP Support

Add your language to the LSP factory in `src/lsp.zig`:

```zig
pub fn createYourLanguageServer(self: LanguageServerFactory) !LanguageServer {
    const language = try grove.Languages.your_language.get();
    return LanguageServer.init(self.allocator, language);
}

// Update createServer method
pub fn createServer(self: LanguageServerFactory, language_name: []const u8) !LanguageServer {
    // ... existing checks
    if (std.mem.eql(u8, language_name, "your_language")) return self.createYourLanguageServer();
    return error.UnsupportedLanguage;
}
```

## Step 6: Testing

### 6.1 Test Basic Parsing

Create a test file and verify parsing works:

```bash
# Test with a simple program in your language
echo 'your_language_code_here' > test.your_ext
zig build run -- test.your_ext
```

### 6.2 Test Highlighting

```bash
# Test syntax highlighting
zig build run -- --highlight test.your_ext
```

### 6.3 Test LSP Features

```bash
# Test LSP capabilities
zig build lsp-demo -- your_language
```

### 6.4 Add Integration Tests

Create tests in `src/tests/` directory:

```zig
const std = @import("std");
const testing = std.testing;
const grove = @import("grove");

test "your_language parsing" {
    const allocator = testing.allocator;

    const source = "your_test_code_here";
    const language = try grove.Languages.your_language.get();

    var parser = try grove.Parser.init(allocator);
    defer parser.deinit();

    try parser.setLanguage(language);
    const tree = try parser.parseUtf8(null, source);
    defer tree.deinit();

    const root = tree.rootNode().?;
    try testing.expect(!root.isNull());
}
```

## Step 7: Documentation

### 7.1 Update README

Add your language to the supported languages list in README.md.

### 7.2 Add Examples

Create example files in `examples/your_language/`:

```bash
mkdir -p examples/your_language
# Add sample files showing various language features
```

### 7.3 Update Documentation

Add language-specific documentation in `docs/languages/`:

```markdown
# Your Language Support

Grove provides comprehensive support for Your Language including:

- Syntax highlighting
- Code folding
- Document symbols
- Semantic analysis
- LSP features

## Features

- Function detection
- Class/struct detection
- Variable scoping
- Error detection

## Configuration

[Language-specific configuration options]
```

## Step 8: Submit Contribution

### 8.1 Commit Changes

```bash
git add .
git commit -m "Add support for Your Language

- Tree-sitter grammar integration
- Syntax highlighting queries
- Editor utilities and LSP support
- Documentation and examples"
```

### 8.2 Test Everything

```bash
# Run all tests
zig build test

# Test cross-platform
zig build cross-platform

# Test benchmarks
zig build bench
```

### 8.3 Create Pull Request

1. Push to your fork
2. Create pull request with detailed description
3. Include examples of the new language support working
4. Add any special build requirements or dependencies

## Common Issues and Solutions

### Build Errors

- **Missing scanner.c**: Not all grammars have external scanners. Only include if the file exists.
- **Compilation errors**: Check that the generated parser.c is compatible with your Tree-sitter version.
- **Linking issues**: Ensure all C source files are properly added to build.zig.

### Query Issues

- **Empty highlights**: Start with a minimal highlights.scm and gradually add more patterns.
- **Query compilation errors**: Use `tree-sitter query` tool to test queries against your grammar.
- **Missing captures**: Check the grammar's node types using `tree-sitter parse --tree`.

### Performance Issues

- **Slow parsing**: Large grammars can be slow. Consider adding incremental parsing optimizations.
- **Memory usage**: Monitor memory usage with complex queries, especially in semantic analysis.

## Resources

- [Tree-sitter Documentation](https://tree-sitter.github.io/tree-sitter/)
- [Tree-sitter Grammar Collection](https://github.com/tree-sitter)
- [Query Syntax Reference](https://tree-sitter.github.io/tree-sitter/using-parsers#query-syntax)
- [Grove Architecture Overview](docs/architecture.md)

## Getting Help

- Open an issue for questions about grammar integration
- Check existing language implementations for examples
- Join discussions in GitHub Discussions

Happy contributing! 🌳