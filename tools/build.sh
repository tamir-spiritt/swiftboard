#!/usr/bin/env bash
# Build the Rust engine to wasm and assemble the static site in dist/
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH=$HOME/.cargo/bin:$PATH CARGO_INCREMENTAL=0
(cd engine && cargo build --release --target wasm32-unknown-unknown -q)
V=$(date +%s)
rm -rf dist && mkdir -p dist/assets
cp engine/target/wasm32-unknown-unknown/release/swiftboard.wasm dist/
cp web/*.css web/*.html web/icons.js web/engine.js web/keyboard.js web/uikit-host.js web/starter.swift dist/
sed "s/__V__/$V/" web/app.js > dist/app.js
sed -i "s#'./engine.js'#'./engine.js?v=$V'#; s#'./keyboard.js'#'./keyboard.js?v=$V'#; s#'./uikit-host.js'#'./uikit-host.js?v=$V'#" dist/app.js
sed -i "s#\"app.js\"#\"app.js?v=$V\"#; s#\"style.css\"#\"style.css?v=$V\"#" dist/index.html
cp web/assets/* dist/assets/
rm -f dist/telegram.html
cp -r examples dist/examples
python3 tools/examples_manifest.py examples > dist/examples/examples.json
echo "built dist v$V ($(du -sh dist | cut -f1))"
