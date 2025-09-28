# HOWTO: Grove ↔ Grim Ghostlang Adapter Branch

This guide describes the exact steps to create, validate, and CI-test the Ghostlang integration between **Grove** and **Grim**.

---

## 📂 Branch Naming

Use the following branch name for clarity and consistency:

```
feature/ghostlang-gza-adapter
```

---

## 🛠️ Setup Instructions

1. **Clone Grim and create branch**
   ```sh
   git clone git@github.com:ghostkellz/grim.git
   cd grim
   git checkout -b feature/ghostlang-gza-adapter
   ```

2. **Link Grove as dependency**
   - Edit `build.zig` in Grim to point to Grove (relative path or local checkout).
   - Import `grove/src/editor/ghostlang.zig` for `GhostlangUtilities`.

3. **Vendor queries temporarily**
   ```sh
   mkdir -p third_party/grove-queries/ghostlang/queries
   cp -r ../grove/vendor/grammars/ghostlang/queries/* third_party/grove-queries/ghostlang/queries/
   ```

4. **Wire editor services**
   - `documentSymbols()` → symbols/outline
   - `foldingRanges()` → folding provider
   - `highlight()` → syntax colors
   - `textobjectAt()` → motions

5. **Run Grove tests locally**
   ```sh
   cd ../grove
   zig build test --filter "ghostlang utilities"
   ```

6. **Smoke test Grim headless**
   ```sh
   ./tools/smoke_gza.sh examples/host/config/init.gza
   ```

---

## 🧪 CI Integration (Self-hosted Runner)

Create `.github/workflows/grim-grove.yml` in Grim:

```yaml
name: Grim ↔ Grove (Ghostlang)

on:
  push:
    branches: [ "feature/ghostlang-gza-adapter" ]
  pull_request:
    branches: [ "feature/ghostlang-gza-adapter" ]

jobs:
  smoke:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v4
        with: { path: grim }

      - uses: actions/checkout@v4
        with: { repository: ghostkellz/grove, path: grove, ref: main }

      - name: Vendor Ghostlang queries
        run: |
          rm -rf grim/third_party/grove-queries/ghostlang/queries
          mkdir -p grim/third_party/grove-queries/ghostlang/queries
          cp -r grove/vendor/grammars/ghostlang/queries/* grim/third_party/grove-queries/ghostlang/queries/

      - name: Build Grim
        working-directory: grim
        run: zig build -Dghostlang=true -Doptimize=ReleaseSafe

      - name: Run Grove tests
        working-directory: grove
        run: zig build test --filter "ghostlang utilities"

      - name: Smoke test Grim
        working-directory: grim
        run: ./tools/smoke_gza.sh examples/host/config/init.gza
```

---

## ✅ Acceptance Gates

- Highlight parity with Grove grammar
- Document symbols load in <30ms/1k LOC
- Folding works for functions/blocks
- Textobjects select reliably
- No crashes; fallback tokenizer works if queries missing

---

## 📦 Next Steps

- [ ] Convert vendored queries → Git submodule or build-time fetch
- [ ] Add `docs/ghostlang.md` with user instructions
- [ ] Pin Grove commit for reproducibility
- [ ] Add `examples/ghostlang/*.gza` for demos
