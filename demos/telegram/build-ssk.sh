#!/usr/bin/env bash
# Compile Telegram's SwiftSignalKit to WebAssembly and link the signals test (tests/SignalsMain.swift).
# Uses build-display.sh's module flow (WebCompat is its own module; sources go through tools/objc-strip.py).
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
. "$(dirname "$0")/env.sh"
OUT=${OUT:-$TG_BUILD/disp}
"$HERE"/build-display.sh WebCompat SwiftSignalKit
swasm -I "$OUT" "$HERE/tests/SignalsMain.swift" "$OUT/WebCompat.o" "$OUT/SwiftSignalKit.o" -o "$OUT/signals.wasm" -Xlinker --export=webRunLoopTick -Xlinker --allow-undefined
ls -la "$OUT/signals.wasm"
