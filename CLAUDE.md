# Claude Code Grammar Integration Plan
## Session Date: 2025-10-03

### Mission
Integrate the following grammars into Grove to achieve comprehensive language coverage:
- **Bash/Zsh** (shell scripting)
- **Markdown** (documentation)
- **JavaScript** (web development)
- **Python** (scripting/data science)

### Integration Checklist per Grammar

For each grammar, we need to:

1. **Vendor the Grammar**
   - Clone/download the tree-sitter grammar repository
   - Extract `parser.c` (and `scanner.c`/`scanner.cc` if present)
   - Copy query files (highlights.scm, locals.scm, etc.)
   - Place in `vendor/grammars/<language>/`

2. **Build System Integration**
   - Add grammar sources to `build.zig`
   - Add C compilation flags
   - Link scanner if present

3. **Language Registry**
   - Add extern function declaration in `src/languages.zig`
   - Add enum variant to `Bundled`
   - Wire up in `raw()` and `get()` methods
   - Add to `ensureBundled()`
   - Add test case

4. **Editor Utilities**
   - Create `src/editor/<language>_lang.zig` or similar
   - Implement document symbols extraction
   - Implement folding ranges
   - Add to `src/editor/all_languages.zig`

5. **Testing**
   - Add basic parse test
   - Add editor utilities test
   - Verify `zig build test` passes

6. **Documentation**
   - Update `vendor/grammars/README.md`
   - Update main `README.md`
   - Update `TODO.md`

### Grammar Sources

| Language | Repository | Notes |
|----------|-----------|-------|
| Bash | https://github.com/tree-sitter/tree-sitter-bash | Official tree-sitter grammar |
| Markdown | https://github.com/tree-sitter-grammars/tree-sitter-markdown | Community maintained, 2-parser setup (markdown + inline) |
| JavaScript | https://github.com/tree-sitter/tree-sitter-javascript | Official, widely used |
| Python | https://github.com/tree-sitter/tree-sitter-python | Official, stable |

### Execution Order

1. **Bash** - Simplest, single parser.c
2. **JavaScript** - Similar to TypeScript already integrated
3. **Python** - Well-established grammar
4. **Markdown** - Most complex (dual parser setup)

### Progress Tracking

- [ ] Bash integration complete
- [ ] JavaScript integration complete
- [ ] Python integration complete
- [ ] Markdown integration complete
- [ ] All tests passing
- [ ] Documentation updated
- [ ] Performance benchmarks updated

### Post-Integration

- Run `zig build test` to verify all grammars
- Run `zig build bench` to capture performance baseline
- Update CHANGELOG.md
- Commit with message: "feat: Add Bash, JavaScript, Python, Markdown grammar support"

---

## Session Notes

Starting integration session...
