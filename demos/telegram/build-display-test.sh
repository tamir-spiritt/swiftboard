#!/usr/bin/env bash
# Links the Display test (tests/DisplayMain.swift) against every module object into display.wasm.
set -e
. "$(dirname "$0")/env.sh"
HERE=$(cd "$(dirname "$0")" && pwd)
OUT=${OUT:-$TG_BUILD/disp}
OBJS=()
for m in WebCompat CoreGraphics QuartzCore CoreText UIKit AsyncDisplayKit Darwin ObjectiveC Accelerate AudioToolbox CoreHaptics CoreMedia AVFoundation \
         ObjCRuntimeUtils UIKitRuntimeUtils AppBundle SwiftSignalKit Markdown Display; do OBJS+=("$OUT/$m.o"); done
swasm -I "$OUT" ${OPT:--Onone} "$HERE/tests/DisplayMain.swift" "${OBJS[@]}" -o "$OUT/display.wasm" \
  -Xlinker --export=webRunLoopTick -Xlinker --allow-undefined
ls -la "$OUT/display.wasm"
