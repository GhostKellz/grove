# 🌳 Grove Wishlist for GShell Integration

<div align="center">
  <strong>What GShell needs from Grove for next-gen syntax highlighting</strong>
</div>

---

## 📋 Current Status

✅ **Already Have:**
- 14 production grammars (JSON, Zig, Rust, **Ghostlang**, TypeScript, Bash, Python, etc.)
- Tree-sitter 0.25.10 (ABI 15) wrapper
- Safe parser lifecycle with pooling
- Query, Highlight, and Editor APIs
- Incremental parsing support
- Benchmark harness

⏳ **In Progress:**
- Phase 2: Production editor integration (Weeks 1-8)
- Performance optimization (≥10 MB/s, <5ms incremental latency)
- Editor features (folding, symbols, navigation)

---

## 🎯 What GShell Needs

### **P0: Critical Path** (Needed for GShell v0.2.0 - Next 4 weeks)

#### 1. **GShell Grammar** (`tree-sitter-gshell`)

GShell syntax is a superset of Bash + Ghostlang. We need a dedicated grammar:

**Key Syntax Elements:**
```bash
# 1. Standard shell commands
ls -la /tmp
echo "hello world"
cat file.txt | grep "pattern" | sort

# 2. Pipes and redirections
command > file.txt
command >> file.txt
command 2>&1 | tee output.log

# 3. Built-in commands (GShell-specific)
cd /tmp
pwd
alias ll='ls -la'
setenv PATH /usr/bin
jobs
fg %1
bg %2

# 4. Ghostlang scripting blocks
$(
  local function hello(name)
    print("Hello, " .. name)
  end
  hello("world")
)

# 5. Variable expansion
echo $PATH
echo ${HOME}/documents
echo $(pwd)

# 6. Control flow (if we add it)
if [ -f file.txt ]; then
  echo "File exists"
fi

# 7. Comments
# This is a comment

# 8. Ghostshell protocol markers (OSC 133)
\e]133;A\e\\  # Prompt start
\e]133;B\e\\  # Prompt end
```

**Grammar Structure:**
```
gshell
├── command_line
│   ├── pipeline
│   │   ├── command
│   │   │   ├── command_name (external or builtin)
│   │   │   ├── argument
│   │   │   └── flag
│   │   └── pipe_operator
│   ├── redirection
│   │   ├── redirect_out (>)
│   │   ├── redirect_append (>>)
│   │   └── redirect_in (<)
│   └── background_operator (&)
├── variable_expansion
│   ├── simple_expansion ($VAR)
│   └── braced_expansion (${VAR})
├── ghostlang_block ($(...))
├── string
│   ├── double_quoted
│   └── single_quoted
└── comment
```

**Highlight Queries:**
```scheme
; highlights.scm for GShell

; Built-in commands
(command_name
  (identifier) @builtin
  (#match? @builtin "^(cd|pwd|echo|exit|alias|setenv|jobs|fg|bg)$"))

; External commands
(command_name) @function

; Flags
(flag) @parameter

; Strings
(string) @string

; Variables
(variable_expansion) @variable

; Operators
(pipe_operator) @operator
(redirect_operator) @operator

; Comments
(comment) @comment

; Ghostlang blocks
(ghostlang_block) @embedded
```

**Use Case:**
```bash
$ gshell
gsh> ls -la /tmp | grep "test" > output.txt
     ^^                  ^^^^         ^^^^^^^^^^
   command            command       redirection
     ^^^                                  ^
    flag                              operator

gsh> echo $PATH
     ^^^^ ^^^^^^
  builtin variable
```

#### 2. **Real-time REPL Highlighting API** (`realtime.zig`)

GShell REPL needs to highlight as the user types:

```zig
pub const RealtimeHighlighter = struct {
    parser: grove.Parser,
    language: *grove.Language,
    arena: std.heap.ArenaAllocator,

    pub fn init(allocator: std.mem.Allocator) !RealtimeHighlighter {
        var parser = try grove.Parser.init(allocator);
        const language = try grove.Languages.gshell.get();  // NEW!
        try parser.setLanguage(language);

        return .{
            .parser = parser,
            .language = language,
            .arena = std.heap.ArenaAllocator.init(allocator),
        };
    }

    pub fn highlightLine(self: *RealtimeHighlighter, line: []const u8) ![]HighlightSpan {
        // Parse single line of input
        var tree = try self.parser.parseUtf8(null, line);
        defer tree.deinit();

        // Extract highlights
        const highlights = try grove.Highlight.collectHighlights(
            self.arena.allocator(),
            tree,
            self.language,
            line,
        );

        return highlights;
    }

    pub fn updateLine(self: *RealtimeHighlighter, old_line: []const u8, new_line: []const u8) ![]HighlightSpan {
        // Incremental update - only re-parse changed region
        // This is critical for fast typing in REPL
        // Target: <5ms for typical single-line edits
    }
};

pub const HighlightSpan = struct {
    start: usize,
    end: usize,
    kind: HighlightKind,
};

pub const HighlightKind = enum {
    command,
    builtin,
    flag,
    string,
    variable,
    operator,
    comment,
    error_node,
};
```

**Use Case:**
```zig
// In GShell REPL (src/repl.zig)
const grove = @import("grove");

var highlighter = try grove.RealtimeHighlighter.init(allocator);
defer highlighter.deinit();

while (true) {
    // User types: "ls -la"
    const line = try readline.read();

    // Highlight in real-time
    const highlights = try highlighter.highlightLine(line);

    // Render with colors
    for (highlights) |span| {
        const text = line[span.start..span.end];
        const color = switch (span.kind) {
            .command => "\x1b[32m",  // Green
            .builtin => "\x1b[36m",  // Cyan
            .flag => "\x1b[34m",     // Blue
            .string => "\x1b[33m",   // Yellow
            .variable => "\x1b[35m", // Magenta
            .operator => "\x1b[37m", // White
            .error_node => "\x1b[31m", // Red
            else => "\x1b[0m",
        };
        print("{s}{s}\x1b[0m", .{color, text});
    }
}
```

#### 3. **Error Detection for REPL**

Highlight syntax errors as user types:

```zig
pub fn getSyntaxErrors(tree: *grove.Tree) ![]SyntaxError {
    const root = tree.rootNode() orelse return &[_]SyntaxError{};

    var errors = std.ArrayList(SyntaxError).init(allocator);
    var cursor = try grove.TreeCursor.init(root);
    defer cursor.deinit();

    while (cursor.next()) |node| {
        if (std.mem.eql(u8, node.kind(), "ERROR") or
            std.mem.eql(u8, node.kind(), "MISSING")) {
            try errors.append(.{
                .start = node.startByte(),
                .end = node.endByte(),
                .message = try errorMessage(node),
            });
        }
    }

    return errors.toOwnedSlice();
}

pub const SyntaxError = struct {
    start: usize,
    end: usize,
    message: []const u8,
};
```

**Use Case:**
```bash
gsh> echo "unterminated string
     ^^^^^^^^^^^^^^^^^^^^^^
     ❌ Unterminated string literal (red underline)

gsh> ls |  # Incomplete pipe
        ^
     ❌ Expected command after pipe (red indicator)

gsh> echo "hello"
     ✅ Valid syntax (green command)
```

---

### **P1: Important** (Needed for GShell v0.3.0 - 4-8 weeks)

#### 4. **Command Validation**

Highlight invalid commands differently from valid ones:

```zig
pub fn validateCommand(command_name: []const u8) bool {
    // Check if command exists in PATH
    // This requires system integration, might be GShell's job
    // Grove can provide the API, GShell provides the validator
}

pub const CommandValidator = fn(command: []const u8) bool;

pub fn highlightWithValidator(
    tree: *grove.Tree,
    validator: CommandValidator
) ![]HighlightSpan {
    // Highlight commands green if valid, red if not found
}
```

**Use Case:**
```bash
gsh> ls -la        # Green (command exists)
gsh> lss -la       # Red (command not found)
gsh> cd /tmp       # Cyan (built-in, always valid)
gsh> nonexist      # Red (not in PATH)
```

#### 5. **Completion Context Detection**

Help GShell know what kind of completion to offer:

```zig
pub const CompletionContext = enum {
    command,       // Start of command
    flag,          // After command, expects flag
    file_path,     // After command/flag, expects file
    variable,      // Inside $VAR expansion
    ghostlang,     // Inside $(...) block
};

pub fn getCompletionContext(line: []const u8, cursor_pos: usize) !CompletionContext {
    // Parse line and determine what should be completed at cursor
}
```

**Use Case:**
```bash
gsh> ls |   # cursor here
          ^ CompletionContext.command (suggest commands)

gsh> ls -   # cursor here
          ^ CompletionContext.flag (suggest -la, -lh, etc.)

gsh> cat    # cursor here (space after cat)
          ^ CompletionContext.file_path (suggest files)

gsh> echo $  # cursor here
           ^ CompletionContext.variable (suggest $PATH, $HOME, etc.)
```

#### 6. **Embedded Ghostlang Highlighting**

When user writes Ghostlang in `$(...)` blocks, highlight using Ghostlang grammar:

```zig
pub fn highlightEmbedded(
    tree: *grove.Tree,
    source: []const u8
) ![]HighlightSpan {
    // Detect Ghostlang blocks
    // Switch to Ghostlang grammar for those regions
    // Merge highlights back into main highlight list
}
```

**Use Case:**
```bash
gsh> echo $(local x = 10; print(x * 2))
            ^^^^^ ^   ^^   ^^^^^  ^   ^
         keyword var num keyword var op num
     # Ghostlang syntax highlighted inside $()
```

---

### **P2: Nice to Have** (Needed for GShell v0.4.0+ - 8+ weeks)

#### 7. **Semantic Highlighting**

Go beyond syntax to semantic understanding:

```zig
pub fn semanticHighlight(
    tree: *grove.Tree,
    source: []const u8,
    symbol_table: *SymbolTable,
) ![]HighlightSpan {
    // Highlight based on semantic info:
    // - Variables defined vs undefined
    // - Functions called vs defined
    // - Aliases expanded
}
```

**Use Case:**
```bash
gsh> alias ll='ls -la'  # Define alias
gsh> ll                  # Highlight 'll' as alias (different color)
gsh> $UNDEFINED_VAR      # Highlight as undefined (warning color)
gsh> $PATH               # Highlight as defined (normal variable color)
```

#### 8. **Performance Profiling Integration**

Help identify slow commands in history:

```zig
pub const PerformanceAnnotation = struct {
    command: []const u8,
    duration_ms: u64,
};

pub fn highlightWithPerformance(
    highlights: []HighlightSpan,
    perf_data: []PerformanceAnnotation,
) ![]HighlightSpan {
    // Annotate slow commands with different colors
}
```

**Use Case:**
```bash
gsh> history
  1. ls -la              (2ms)   # Normal
  2. find / -name foo    (5432ms) # Red highlight (slow!)
  3. echo hello          (1ms)   # Normal
```

---

### **P3: Future Vision** (Nice to have, no timeline)

#### 9. **Multi-line Editing**

Support for complex multi-line scripts:

```zig
pub fn highlightMultiline(lines: []const []const u8) ![][]HighlightSpan {
    // Handle multi-line shell scripts
}
```

#### 10. **Diff Highlighting**

Show diffs in command output:

```zig
pub fn highlightDiff(diff_text: []const u8) ![]HighlightSpan {
    // Highlight git diff, etc.
}
```

---

## 🔧 API Design Preferences

### **What GShell Prefers:**

1. **Low Latency**: <5ms for single-line highlights (critical for REPL feel)
2. **Incremental Updates**: Don't re-parse entire line on single char insert
3. **Memory Efficient**: Use arena allocator, batch allocations
4. **Error Recovery**: Graceful degradation on parse errors
5. **Simple Types**: Return arrays, not complex iterators

### **Example Perfect API:**

```zig
// Simple, fast, allocator-based
var highlighter = try grove.RealtimeHighlighter.init(allocator);
defer highlighter.deinit();

const highlights = try highlighter.highlightLine("ls -la | grep test");
// Returns: []HighlightSpan (simple array)
// Latency: <5ms guaranteed
```

---

## 📊 Integration Success Metrics

When Grove integration is complete, GShell users should see:

- ✅ Commands highlighted green (valid) or red (invalid)
- ✅ Flags highlighted blue
- ✅ Strings highlighted yellow
- ✅ Variables highlighted magenta
- ✅ Syntax errors highlighted red in real-time
- ✅ Ghostlang blocks highlighted with Ghostlang syntax
- ✅ <5ms highlight latency (no typing lag)
- ✅ Incremental updates (only re-parse changed region)

---

## 🤝 Collaboration

GShell is happy to:
- Help design and test GShell grammar
- Provide real-world shell syntax examples
- Benchmark performance in REPL scenarios
- Contribute PRs for shell-specific APIs
- Write integration tests

Grove can prioritize:
- P0: GShell grammar + REPL API (next 4 weeks)
- P1: Command validation + completion context (4-8 weeks)
- P2: Semantic highlighting (8+ weeks)

**Let's build the most beautiful shell syntax highlighting ever!** 🎨

---

## 📞 Contact

For questions or coordination:
- Open an issue in GShell repo: [ghostkellz/gshell](https://github.com/ghostkellz/gshell)
- Reference this wishlist in Grove issues/PRs
- Coordinate timelines in DRAFT_DISCOVERY.md

**Thank you for building Grove!** 🌳
