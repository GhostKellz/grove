# Grove Cross-Platform Compatibility

## Overview

Grove is designed to work across Linux, macOS, and Windows platforms. This document outlines the current status and requirements for each platform.

## Platform Support Status

| Platform | Native Build | Cross-Compilation | Validation Status |
|----------|--------------|-------------------|-------------------|
| Linux    | ✅ Tested     | N/A               | ✅ Validated       |
| macOS    | ⚠️ Expected   | ❌ Tree-sitter deps | 🔄 Pending        |
| Windows  | ⚠️ Expected   | ❌ Tree-sitter deps | 🔄 Pending        |

## Validated Components (Linux x86_64)

✅ **Language Loading**: All 6 bundled languages (Ghostlang, TypeScript, TSX, Zig, JSON, Rust)
✅ **Path Handling**: Platform-specific path separators and line endings
✅ **Build Target Support**: Architecture and OS detection
✅ **Editor Services**: Initialization and basic functionality
✅ **Grim Bridge**: Configuration export and integration
✅ **Memory Management**: Allocation/deallocation patterns

## Cross-Compilation Limitations

### Tree-sitter Unicode Dependencies

The Tree-sitter C library includes Unicode dependencies (`unicode/umachine.h`) that are not available during cross-compilation with Zig. This affects:

- Windows cross-compilation from Linux
- macOS cross-compilation from Linux

### Workarounds

1. **Native Builds**: Build Grove natively on each target platform
2. **CI/CD**: Use platform-specific runners for testing
3. **Alternative Unicode**: Consider Tree-sitter configuration without Unicode support

## Platform-Specific Considerations

### Linux
- **Status**: Fully supported and tested
- **Dependencies**: Standard GNU toolchain
- **Package Managers**: Ready for distribution via package managers

### macOS
- **Status**: Expected to work (API compatibility)
- **Dependencies**: Xcode command line tools
- **Considerations**: Apple Silicon (ARM64) vs Intel (x86_64)

### Windows
- **Status**: Expected to work (API compatibility)
- **Dependencies**: MSVC or MinGW toolchain
- **Considerations**: Windows-specific path handling implemented

## Validation Strategy

### Current Approach
1. **Runtime Validation**: Test on native Linux platform
2. **API Compatibility**: Verify platform abstractions
3. **Path Handling**: Test platform-specific file system operations

### Recommended CI/CD Setup
```yaml
strategy:
  matrix:
    os: [ubuntu-latest, macos-latest, windows-latest]
    include:
      - os: ubuntu-latest
        target: x86_64-linux
      - os: macos-latest
        target: x86_64-macos
      - os: windows-latest
        target: x86_64-windows
```

## Grove Module Compatibility

### Core Modules
- ✅ **Parser**: Platform-agnostic Tree-sitter bindings
- ✅ **Language**: Static language definitions
- ✅ **Query**: Tree-sitter query execution
- ✅ **Tree/Node**: AST manipulation

### Editor Services
- ✅ **Highlights**: Syntax highlighting engine
- ✅ **Features**: Document symbols, folding ranges
- ✅ **All Languages**: Multi-language utilities

### Platform Bridge
- ✅ **Grim Bridge**: Cross-platform editor integration
- ✅ **Query Registry**: Pre-configured queries and themes

## Future Work

1. **Native Platform Testing**: Set up CI/CD with native runners
2. **Tree-sitter Optimization**: Investigate Unicode-free builds
3. **Package Distribution**: Create platform-specific packages
4. **Performance Benchmarking**: Compare performance across platforms

## RC1 Status

Grove has achieved RC1 status for Linux platforms with comprehensive validation. macOS and Windows support is architecturally ready but requires native testing for final validation.