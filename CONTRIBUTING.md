# Contributing to Swiftboard

Thanks for helping. The fastest way to land a change:

1. Pick an item from **Help wanted** in the README (or open an issue describing what you want to add).
2. Add or extend an app in `examples/` that uses the feature. Examples double as test fixtures.
3. Implement it in `engine/` (Swift language: `parser.rs`, `interp.rs`, `methods.rs`; SwiftUI views and modifiers:
   `views.rs`; layout and drawing: `layout.rs`) or in `web/` for board features.
4. Run the checks:
   ```bash
   cd engine
   cargo test                                              # every example renders, interactions work
   cargo run --example render ../examples/<YourApp> <Preview name>
   cd .. && ./tools/build.sh && python3 -m http.server -d dist 8080
   ```
5. Open a PR with a screenshot of the frame before and after.

Guidelines:
- Keep the engine dependency-free (plain Rust, `wasm32-unknown-unknown`).
- Unsupported SwiftUI should fail loudly with the source position, never silently draw something wrong.
- Web runtime files must be loaded relative to the module (`new URL(path, import.meta.url)`), not the page.
- `platform/` is MIT and must never contain Telegram code; patched Telegram files belong in `demos/telegram/overlay/` (GPL).
