#!/usr/bin/env bash
# Optimized browser build of a Telegram-on-wasm demo app + the web host page.
#   build-web.sh [display]      -> $WEB/telegram-display.wasm (app/DisplayDemo.swift)
# Env: OUT (object dir, default build/telegram/opt), WEB (site dir, default build/telegram/web),
#      SKIP_MODULES=1 to relink only.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
. "$(dirname "$0")/env.sh"
export OUT=${OUT:-$TG_BUILD/opt}
export OPT=${OPT:--Osize}
WEB=${WEB:-$TG_BUILD/web}
APP=${1:-display}
MODS="WebCompat CoreGraphics QuartzCore CoreText UIKit AsyncDisplayKit Darwin ObjectiveC Accelerate AudioToolbox CoreHaptics CoreMedia AVFoundation Contacts CoreTelephony ImageIO CoreLocation MapKit CoreImage ObjCRuntimeUtils UIKitRuntimeUtils AppBundle SwiftSignalKit Markdown Display"
if [ -z "$SKIP_MODULES" ]; then
  # stop on a failed base module: linking would mix in stale objects (wasm traps with a signature mismatch)
  "$HERE"/build-display.sh WebCompat CoreGraphics QuartzCore CoreText UIKit AsyncDisplayKit Stubs ObjCRuntimeUtils UIKitRuntimeUtils AppBundle SwiftSignalKit Markdown Display > "$OUT/base-modules.log" 2>&1 ||
    { grep -E 'error:' -A3 "$OUT/base-modules.log" | head -20; exit 1; }
fi
CHATLIST_MODS="$(grep -v '^#' "$HERE/shims/chatlist/MODULES" | cut -d: -f1 | tr '\n' ' ')"
case $APP in
  display) SRC="$HERE/app/DisplayDemo.swift"; NAME=telegram-display; EXTRA_MODS="" ;;
  chatlist) SRC="$HERE/app/ChatListApp.swift"; NAME=telegram-chatlist; EXTRA_MODS="$CHATLIST_MODS"
    if [ -z "$SKIP_MODULES" ]; then
      OPT=$OPT "$HERE"/build-chatlist.sh modules || exit 1
    fi ;;
esac
OBJS=(); for m in $MODS $EXTRA_MODS; do OBJS+=("$OUT/$m.o"); done
# trimmed ICU data (platform/tools/icu-trim.py) replaces lib_FoundationICU.a's 34 MB data object; ICU_FULL=1 keeps it
if [ -z "$ICU_FULL" ]; then
  ICU=$TG_BUILD/icu
  if [ ! -f "$ICU/icu_trim.o" ]; then
    mkdir -p "$ICU"; (cd "$ICU" && ar x "$WASM_SDK/swift.xctoolchain/usr/lib/swift_static/wasi/lib_FoundationICU.a" icu_packaged_data.cpp.obj &&
      python3 "$ROOT/platform/tools/icu-trim.py" icu_packaged_data.cpp.obj icu_trim.c && "$CLANG" --target=wasm32-unknown-wasip1 -c icu_trim.c -o icu_trim.o)
  fi
  OBJS+=("$ICU/icu_trim.o")
fi
swasm -I "$OUT" $OPT -parse-as-library "$SRC" "${OBJS[@]}" -o "$OUT/$NAME.wasm" \
  -Xclang-linker -mexec-model=reactor \
  -Xlinker --export=app_start -Xlinker --export=webRunLoopTick -Xlinker --export=uikit_frame -Xlinker --export=uikit_frame_len \
  -Xlinker --export=uikit_pointer -Xlinker --export=uikit_wheel -Xlinker --export=uikit_set_screen -Xlinker --export=uikit_generation -Xlinker --export=uikit_debug \
  -Xlinker --allow-undefined -Xlinker --strip-all
mkdir -p "$WEB"
SIZE=$(stat -c %s "$OUT/$NAME.wasm")
WASM_OPT=${WASM_OPT:-$(command -v wasm-opt)}
if [ -z "$NO_WASM_OPT" ] && [ -x "$WASM_OPT" ]; then
  "$WASM_OPT" -Oz --all-features --strip-debug --strip-producers "$OUT/$NAME.wasm" -o "$WEB/$NAME.wasm"
else
  cp "$OUT/$NAME.wasm" "$WEB/$NAME.wasm"
fi
cp "$ROOT"/web/telegram.html "$WEB/index.html"
# bundle images referenced by the compiled Telegram sources and the demo app
python3 "$HERE/tools/gen-assets.py" "$WEB/assets" $(find "$OUT/src" -name '*.swift') "$HERE"/app/*.swift
cp "$ROOT"/web/telegram.js "$ROOT"/web/uikit-host.js "$ROOT"/web/engine.js "$ROOT"/web/icons.js "$WEB/"
gzip -9 -c "$WEB/$NAME.wasm" > "$OUT/$NAME.wasm.gz"
echo "linked $NAME.wasm: $SIZE bytes; shipped $(stat -c %s "$WEB/$NAME.wasm") bytes; gzip $(stat -c %s "$OUT/$NAME.wasm.gz") bytes"
