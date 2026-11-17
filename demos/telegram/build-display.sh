#!/usr/bin/env bash
# Compile Telegram's Display module (and everything under it) to WebAssembly.
#   build-display.sh [module ...]   (default: all, in dependency order)
# Env: OUT (build dir), MODE=typecheck (only type-check Display, for error-driven work), OPT (-Onone default)
set -o pipefail
. "$(dirname "$0")/env.sh"
HERE=$(cd "$(dirname "$0")" && pwd)
PLAT=$(cd "$HERE/../../platform" && pwd)
OUT=${OUT:-$TG_BUILD/disp}
OPT=${OPT:--Onone}
mkdir -p "$OUT/src"
STRIP="python3 $PLAT/tools/objc-strip.py"

# upstream sources with overlay files substituted, run through the ObjC-interop preprocessor
prep() { # name dir-glob...
  local name=$1; shift
  rm -rf "$OUT/src/$name"; mkdir -p "$OUT/src/$name"
  local f rel src i=0
  for f in "$@"; do
    rel=${f#$TG/}
    src=$f; [ -f "$HERE/overlay/$rel" ] && src=$HERE/overlay/$rel
    i=$((i+1))
    $STRIP "$src" "$OUT/src/$name/$(basename "$f")"
  done
}

mod() { # name sources... (platform/shim modules, compiled as-is)
  local name=$1; shift
  echo "== $name"
  swasm -module-name "$name" -parse-as-library -wmo $OPT -I "$OUT" -emit-module -emit-module-path "$OUT/$name.swiftmodule" \
    -enable-experimental-feature Extern -c -swift-version 5 "$@" -o "$OUT/$name.o" 2>&1 | grep -v '^\s*$' | tee "$OUT/$name.log" | grep -E 'error' | head -40
  return ${PIPESTATUS[0]}
}

ALL="WebCompat CoreGraphics QuartzCore CoreText UIKit AsyncDisplayKit Stubs ObjCRuntimeUtils UIKitRuntimeUtils AppBundle SwiftSignalKit Markdown Display"
MODS=${*:-$ALL}
for m in $MODS; do
  case $m in
    WebCompat|CoreGraphics|QuartzCore|CoreText|UIKit|AsyncDisplayKit) mod $m "$PLAT"/$m/*.swift || exit 1 ;;
    Stubs) for s in Darwin ObjectiveC Accelerate AudioToolbox CoreHaptics CoreMedia AVFoundation Contacts CoreTelephony ImageIO CoreLocation MapKit CoreImage; do mod $s "$PLAT"/Stubs/$s.swift || exit 1; done ;;
    ObjCRuntimeUtils|UIKitRuntimeUtils|AppBundle) mod $m "$HERE"/shims/$m/*.swift || exit 1 ;;
    SwiftSignalKit) prep SwiftSignalKit "$TG"/submodules/SSignalKit/SwiftSignalKit/Source/*.swift
      mod SwiftSignalKit "$OUT"/src/SwiftSignalKit/*.swift || exit 1 ;;
    Markdown) prep Markdown "$TG"/submodules/Markdown/Source/*.swift
      mod Markdown "$OUT"/src/Markdown/*.swift || exit 1 ;;
    Display) prep Display $(find "$TG"/submodules/Display/Source -name '*.swift' | sort)
      if [ "$MODE" = typecheck ]; then
        echo "== Display (typecheck)"
        swiftc -target wasm32-unknown-wasip1 -sdk "$WASM_SDK/WASI.sdk" -resource-dir "$WASM_SDK/swift.xctoolchain/usr/lib/swift_static" \
          -module-name Display -parse-as-library -wmo -I "$OUT" -typecheck -swift-version 5 "$OUT"/src/Display/*.swift > "$OUT/Display.log" 2>&1
        echo "Display errors: $(grep -c ': error:' "$OUT/Display.log")"
      else
        mod Display "$OUT"/src/Display/*.swift || exit 1
      fi ;;
  esac
done
