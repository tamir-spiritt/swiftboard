#!/usr/bin/env bash
# Telegram chat list (layer 3): stub modules (chatlist-stubs/, one file per Telegram module, in ORDER) + a ChatListUI
# module made of the real upstream cell files. Needs the layer-2 modules in $OUT (build-display.sh).
#   build-chatlist.sh [stubs] [chatlist] ; MODE=typecheck for ChatListUI only
set -o pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
. "$(dirname "$0")/env.sh"
export OUT=${OUT:-$TG_BUILD/disp}
OPT=${OPT:--Onone}
STRIP="python3 $HERE/../../platform/tools/objc-strip.py"
CHATLIST_FILES=${CHATLIST_FILES:-"ChatListBadgeNode ChatListStatusNode ChatListTypingNode ChatListItemStrings ChatListPresentationData ChatListItem"}
mod() { local name=$1; shift
  swasm -module-name "$name" -parse-as-library -wmo $OPT -I "$OUT" -emit-module -emit-module-path "$OUT/$name.swiftmodule" \
    -c -swift-version 5 -suppress-warnings "$@" -o "$OUT/$name.o" > "$OUT/$name.log" 2>&1
  local rc=$?; [ $rc -ne 0 ] && { echo "== $name FAILED"; grep 'error:' "$OUT/$name.log" | head -20; }; return $rc; }
# build_modules [only]: every module in chatlist-stubs/MODULES (or just `only`)
build_modules() {
  grep -v '^#' "$HERE/chatlist-stubs/MODULES" | while IFS=: read -r name files; do
    [ -z "$name" ] && continue
    [ -n "$1" ] && [ "$1" != "$name" ] && continue
    rm -rf "$OUT/src/$name"; mkdir -p "$OUT/src/$name"
    for rel in $files; do
      src=$TG/submodules/$rel; [ -f "$HERE/overlay/submodules/$rel" ] && src=$HERE/overlay/submodules/$rel
      $STRIP "$src" "$OUT/src/$name/$(basename "$rel")"
    done
    if [ "$name" = PresentationStrings ]; then
      python3 "$HERE/tools/gen-strings.py" "$TG/Telegram/Telegram-iOS/en.lproj/Localizable.strings" "$OUT/src/$name/Generated.swift" "$TG/submodules/ChatListUI/Sources/**/*.swift" "$TG/submodules/TelegramPresentationData/Sources/**/*.swift" "$TG/submodules/ItemListUI/Sources/**/*.swift" "$TG/submodules/Display/Source/**/*.swift" "$HERE/chatlist-stubs/*.swift" "$HERE/app/*.swift" >/dev/null
    fi
    [ -f "$HERE/chatlist-stubs/$name.swift" ] && cp "$HERE/chatlist-stubs/$name.swift" "$OUT/src/$name/WebStub_$name.swift"
    mod "$name" $(ls "$OUT"/src/$name/*.swift 2>/dev/null) || return 1
  done
}
for step in ${*:-stubs chatlist}; do case $step in
  stubs|modules) build_modules "" || exit 1 ;;
  module:*) build_modules "${step#module:}" || exit 1 ;;
  chatlist)
    rm -rf "$OUT/src/ChatListUI"; mkdir -p "$OUT/src/ChatListUI"
    for f in $CHATLIST_FILES; do
      rel=submodules/ChatListUI/Sources/Node/$f.swift; src=$TG/$rel; [ -f "$HERE/overlay/$rel" ] && src=$HERE/overlay/$rel
      $STRIP "$src" "$OUT/src/ChatListUI/$f.swift"
    done
    for f in ${CHATLIST_EXTRA:-}; do $STRIP "$f" "$OUT/src/ChatListUI/$(basename "$f")"; done
    if [ "$MODE" = typecheck ]; then
      swiftc -target wasm32-unknown-wasip1 -sdk "$WASM_SDK/WASI.sdk" -resource-dir "$WASM_SDK/swift.xctoolchain/usr/lib/swift_static" \
        -module-name ChatListUI -parse-as-library -wmo -I "$OUT" -typecheck -swift-version 5 -suppress-warnings "$OUT"/src/ChatListUI/*.swift > "$OUT/ChatListUI.log" 2>&1
      echo "ChatListUI errors: $(grep -c ': error:' "$OUT/ChatListUI.log")"
    else mod ChatListUI "$OUT"/src/ChatListUI/*.swift; fi ;;
esac; done
