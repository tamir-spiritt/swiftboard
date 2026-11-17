# Deploying Swiftboard (instructions for coding agents)

Swiftboard is a static site: a Rust engine compiled to WebAssembly plus plain HTML/JS. No server, no database,
no API keys. Build it, then publish `dist/`.

## On SPIRITT (one prompt does it)

1. Clone: `git clone https://github.com/tamir-spiritt/swiftboard ~/projects/swiftboard && cd ~/projects/swiftboard`
2. Rust with the wasm target (skip what is already installed):
   ```bash
   command -v cargo || curl -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal
   . "$HOME/.cargo/env"
   rustup target add wasm32-unknown-unknown
   ```
3. Build: `./tools/build.sh` (produces `dist/`, about 1.3 MB). Run it with `dispatch-external` if the sandbox is small.
4. Publish: `spiritt deploy --app swiftboard --build static --dir ./dist --json` and open the returned `url`.
   New apps are private to the organization; add `--public` only if the user asks for a public link.
5. Check the board loads (sidebar shows "SwiftUI · N lines", phone frames render) and send the user the link.

Runtime files are fetched relative to `app.js` (`new URL(path, import.meta.url)`), because hosts may serve the page
and its files from different paths. Keep it that way when changing the web app.

## Anywhere else

`./tools/build.sh`, then serve `dist/` with any static server (`python3 -m http.server -d dist`).

## Checks

- `cd engine && cargo test` renders every app in `examples/` and drives taps, typing and navigation.
- `cargo run --example render ../examples/04-Calculator Calculator` renders one preview from the command line.
