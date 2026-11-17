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
MODS="WebCompat CoreGraphics QuartzCore CoreText UIKit AsyncDisplayKit Darwin ObjectiveC Accelerate AudioToolbox CoreHaptics CoreMedia AVFoundation ObjCRuntimeUtils UIKitRuntimeUtils AppBundle SwiftSignalKit Markdown Display"
if [ -z "$SKIP_MODULES" ]; then
  "$HERE"/build-display.sh WebCompat CoreGraphics QuartzCore CoreText UIKit AsyncDisplayKit Stubs ObjCRuntimeUtils UIKitRuntimeUtils AppBundle SwiftSignalKit Markdown Display 2>&1 | grep -E 'error:' -A3 | head -20
fi
CHATLIST_MODS="$(grep -v '^#' "$HERE/chatlist-stubs/MODULES" | cut -d: -f1 | tr '\n' ' ') ChatListUI"
case $APP in
  display) SRC="$HERE/app/DisplayDemo.swift"; NAME=telegram-display; EXTRA_MODS="" ;;
  chatlist) SRC="$HERE/app/ChatListApp.swift"; NAME=telegram-chatlist; EXTRA_MODS="$CHATLIST_MODS"
    if [ -z "$SKIP_MODULES" ]; then
      OPT=$OPT CHATLIST_FILES="ChatListBadgeNode" CHATLIST_EXTRA="$HERE/app/ChatListDemo.swift" "$HERE"/build-chatlist.sh modules chatlist || exit 1
    fi ;;
esac
OBJS=(); for m in $MODS $EXTRA_MODS; do OBJS+=("$OUT/$m.o"); done
swasm -I "$OUT" $OPT -parse-as-library "$SRC" "${OBJS[@]}" -o "$OUT/$NAME.wasm" \
  -Xclang-linker -mexec-model=reactor \
  -Xlinker --export=app_start -Xlinker --export=webRunLoopTick -Xlinker --export=uikit_frame -Xlinker --export=uikit_frame_len \
  -Xlinker --export=uikit_pointer -Xlinker --export=uikit_wheel -Xlinker --export=uikit_set_screen -Xlinker --export=uikit_generation -Xlinker --export=uikit_debug \
  -Xlinker --allow-undefined -Xlinker --strip-all
mkdir -p "$WEB"
SIZE=$(stat -c %s "$OUT/$NAME.wasm")
if command -v wasm-opt >/dev/null; then
  wasm-opt -Oz --enable-bulk-memory --enable-sign-ext --enable-mutable-globals --enable-nontrapping-float-to-int "$OUT/$NAME.wasm" -o "$WEB/$NAME.wasm"
else
  cp "$OUT/$NAME.wasm" "$WEB/$NAME.wasm"
fi
cp "$ROOT"/web/telegram.html "$WEB/index.html"
cp "$ROOT"/web/telegram.js "$ROOT"/web/uikit-host.js "$ROOT"/web/engine.js "$ROOT"/web/icons.js "$WEB/"
gzip -9 -c "$WEB/$NAME.wasm" > "$OUT/$NAME.wasm.gz"
echo "linked $NAME.wasm: $SIZE bytes; shipped $(stat -c %s "$WEB/$NAME.wasm") bytes; gzip $(stat -c %s "$OUT/$NAME.wasm.gz") bytes"
