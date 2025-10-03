# Grim Adapter Branch Playbook

This document coordinates the Grove ↔ Grim touchpoints required to validate `.gza` workflows using the new Ghostlang editor utilities.

## Overview

- **Goal:** Stand up a temporary Grim branch that consumes Grove's Ghostlang services (highlights, document symbols, folding).
- **Why now:** Grove Alpha phase focuses on downstream adoption. Completing this branch closes the loop with Grim's `.gza` editing story.
- **Artifacts:**
  - Branch spec at `archive/grim/branches/ghostlang-adapter/README.md`
  - Grove utility module `src/editor/ghostlang.zig`
  - Ghostlang locals/textobjects queries (`vendor/grammars/ghostlang/queries/*.scm`)

## Branch Setup Checklist

1. **Create adapter branch on upstream Grim**

   ```sh
   git clone git@github.com:ghostkellz/grim.git
   cd grim
   git checkout -b feature/ghostlang-gza-adapter
   ```

   The `archive/grim` snapshot in this repo remains a historical reference—use it for quick file lookups, but treat the GitHub repository as the source of truth.

2. **Link Grove as a dependency**
   - Point Grim's `build.zig` (in the upstream repo) to the Grove workspace (a relative path works for iterative development).
   - Import `grove/src/editor/ghostlang.zig` to access `GhostlangUtilities`.

3. **Wire editor services**
   - Use `GhostlangUtilities.documentSymbols` for palette + definition features.
   - Use `GhostlangUtilities.foldingRanges` for fold discovery.
   - Reuse Grove highlight engine (already validated) for syntax colors.

4. **Manual validation loop**
   - Open `host/config/init.gza` (or example plugins) from the upstream Grim repo inside Grim.
   - Cross-check against the archived fixtures under `archive/grim` if you need historical context.
   - Verify: syntax highlighting, document symbols, folding toggles, textobject motions.
   - Capture findings in `archive/grim/branches/ghostlang-adapter/SMOKE.md`.

5. **Report back**
   - Update `CODEX.md` Status Log with results.
   - Mark Grove Alpha checklist items complete (see `TODO.md`).
   - Mirror follow-up actions in `GRIM_TODO.md` before requesting merge into Grim `main`.

## Quick Test Harness

To sanity-check Grove utilities before integrating, run from the Grove root:

```sh
zig build test --filter "ghostlang utilities"
```

This covers:

- Ghostlang locals query (document symbols)
- Ghostlang textobject query (folding ranges)

## Pending Follow-ups

- Automate Grim ↔ Grove integration (CI job fetching latest vendored grammar).
- Add telemetry hooks once Grim exposes performance counters.
- Document user-facing Grim instructions ahead of Beta.
