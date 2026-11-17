#!/usr/bin/env bash
# Telegram chat list (layer 3): the modules in shims/chatlist/MODULES, in order, up to ChatListUI (the real
# ChatListItem cell). Each module is real upstream files and/or a closure (<Module>.closure.json, assembled by
# tools/assemble.py) plus its shim shims/chatlist/<Module>.swift. Needs the layer-2 modules in $OUT (build-display.sh).
#   build-chatlist.sh [modules] [module:Name ...] [chatlist] [typecheck-chatlist]
set -o pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
. "$(dirname "$0")/env.sh"
export OUT=${OUT:-$TG_BUILD/disp}
OPT=${OPT:--Onone}
STRIP="python3 $HERE/../../platform/tools/objc-strip.py"
mod() { local name=$1; shift
  swasm -module-name "$name" -parse-as-library -wmo $OPT -I "$OUT" -emit-module -emit-module-path "$OUT/$name.swiftmodule" \
    -c -swift-version 5 -suppress-warnings "$@" -o "$OUT/$name.o" > "$OUT/$name.log" 2>&1
  local rc=$?; [ $rc -ne 0 ] && { echo "== $name FAILED"; grep 'error:' "$OUT/$name.log" | head -20; }; return $rc; }
# build_modules [only]: every module in shims/chatlist/MODULES (or just `only`)
build_modules() {
  grep -v '^#' "$HERE/shims/chatlist/MODULES" | while IFS=: read -r name files; do
    [ -z "$name" ] && continue
    [ -n "$1" ] && [ "$1" != "$name" ] && continue
    rm -rf "$OUT/src/$name"; mkdir -p "$OUT/src/$name"
    if [ -f "$HERE/shims/chatlist/$name.closure.json" ]; then
      python3 "$HERE/tools/assemble.py" "$name" "$HERE/shims/chatlist/$name.closure.json" "$OUT"
      mod "$name" "$OUT"/src/$name/*.swift || return 1
      continue
    fi
    for rel in $files; do
      src=$TG/submodules/$rel; [ -f "$HERE/overlay/submodules/$rel" ] && src=$HERE/overlay/submodules/$rel
      $STRIP "$src" "$OUT/src/$name/$(basename "$rel")"
    done
    # FlatBuffers runtime and Telegram's generated FlatSerialization models (flatc 24.12.23, as upstream's build)
    # (its Data/ContiguousBytes APIs are off on WASI, but this WASI SDK has Foundation: turn them on)
    if [ "$name" = FlatBuffers ]; then cp "$FLATBUFFERS_DIR"/swift/Sources/FlatBuffers/*.swift "$OUT/src/$name/"; sed -i 's/!os(WASI)/true/' "$OUT"/src/$name/*.swift; fi
    if [ "$name" = FlatSerialization ]; then
      "$FLATC" --require-explicit-ids --swift -o "$OUT/src/$name" "$TG"/submodules/TelegramCore/FlatSerialization/Models/*.fbs >/dev/null 2>&1
    fi
    if [ "$name" = PresentationStrings ]; then
      python3 "$HERE/tools/gen-strings.py" "$TG/Telegram/Telegram-iOS/en.lproj/Localizable.strings" "$OUT/src/$name/Generated.swift" "$TG/submodules/ChatListUI/Sources/**/*.swift" "$TG/submodules/TelegramPresentationData/Sources/**/*.swift" "$TG/submodules/ItemListUI/Sources/**/*.swift" "$TG/submodules/Display/Source/**/*.swift" "$TG/submodules/TextFormat/Sources/**/*.swift" "$TG/submodules/TelegramStringFormatting/Sources/**/*.swift" "$TG/submodules/LocalizedPeerData/Sources/**/*.swift" "$TG/submodules/AvatarNode/Sources/**/*.swift" "$TG/submodules/TelegramUI/Components/EmojiStatusComponent/Sources/**/*.swift" "$TG/submodules/TelegramUI/Components/EmojiTextAttachmentView/Sources/**/*.swift" "$TG/submodules/AccountContext/Sources/**/*.swift" "$HERE/shims/chatlist/*.swift" "$HERE/app/*.swift" >/dev/null
    fi
    [ -f "$HERE/shims/chatlist/$name.swift" ] && cp "$HERE/shims/chatlist/$name.swift" "$OUT/src/$name/WebStub_$name.swift"
    mod "$name" $(ls "$OUT"/src/$name/*.swift 2>/dev/null) || return 1
  done
}
for step in ${*:-stubs chatlist}; do case $step in
  stubs|modules) build_modules "" || exit 1 ;;
  module:*) build_modules "${step#module:}" || exit 1 ;;
  chatlist) build_modules ChatListUI || exit 1 ;;
  typecheck-chatlist)
    python3 "$HERE/tools/assemble.py" ChatListUI "$HERE/shims/chatlist/ChatListUI.closure.json" "$OUT"
    swiftc -target wasm32-unknown-wasip1 -sdk "$WASM_SDK/WASI.sdk" -resource-dir "$WASM_SDK/swift.xctoolchain/usr/lib/swift_static" \
      -module-name ChatListUI -parse-as-library -wmo -I "$OUT" -typecheck -swift-version 5 -suppress-warnings "$OUT"/src/ChatListUI/*.swift > "$OUT/ChatListUI.log" 2>&1
    echo "ChatListUI errors: $(grep -c ': error:' "$OUT/ChatListUI.log")" ;;
esac; done
