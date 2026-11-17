#!/usr/bin/env bash
# Runs closure.py for each listed module (plain modules without a closure file are just built) (dependency order) and compiles it. When a closure routes declarations into
# another module's closure file, that module (and everything after it) is rebuilt in the next pass.
#   rebuild-closures.sh Module...      (output also appended to "$TG_BUILD"/logs/closures.log)
cd "$(dirname "$0")"
. ../env.sh
mkdir -p "$TG_BUILD"/logs
exec > >(tee -a "$TG_BUILD"/logs/closures.log) 2>&1
declare -A ALLOW=([ChatListUI]='^ChatListUI/Sources/(Node/)?ChatList(BadgeNode|StatusNode|TypingNode|ItemStrings|PresentationData|Item|RichTextPreview|NeighborFacets)\.swift$' [Postbox]='^$' [TelegramCore]='^TelegramCore/Sources/SyncCore/' [TelegramUIPreferences]='^TelegramUIPreferences/Sources/' [TelegramPresentationData]='^TelegramPresentationData/Sources/' [TextFormat]='^TextFormat/Sources/' [AccountContext]='^$' [TelegramStringFormatting]='^TelegramStringFormatting/Sources/')
mods=("$@")
start=0
if [ -n "$FROM" ]; then for ((j=0; j<${#mods[@]}; j++)); do [ "${mods[$j]}" = "$FROM" ] && start=$j; done; fi
for pass in 1 2 3 4 5 6; do
  dirty_idx=-1
  for ((i=start; i<${#mods[@]}; i++)); do
    m=${mods[$i]}
    if [ ! -f ../shims/chatlist/$m.closure.json ]; then
      ../build-chatlist.sh module:$m > "$TG_BUILD"/logs/build.$m.log 2>&1 && echo "[$pass] $m: built" || echo "[$pass] $m: build failed: $(grep -c 'error:' "$TG_BUILD"/logs/build.$m.log) errors"
      continue
    fi
    out=$(python3 closure.py "$m" "$TG_BUILD"/decl-index.json ../shims/chatlist/$m.closure.json "${ALLOW[$m]:-^$}" 10)
    dirty=$(echo "$out" | grep '^DIRTY:' | cut -d: -f2)
    echo "[$pass] $m: $(echo "$out" | grep '^round' | tail -1) |left: $(echo "$out" | grep '^LEFT' | cut -c15-400) |dirty:$dirty"
    ../build-chatlist.sh module:$m > "$TG_BUILD"/logs/build.$m.log 2>&1 || echo "  build $m failed: $(grep -c 'error:' "$TG_BUILD"/logs/build.$m.log) errors"
    for d in $dirty; do
      for ((j=0; j<${#mods[@]}; j++)); do [ "${mods[$j]}" = "$d" ] && { [ $dirty_idx -lt 0 ] || [ $j -lt $dirty_idx ]; } && dirty_idx=$j; done
    done
  done
  [ $dirty_idx -lt 0 ] && break
  start=$dirty_idx
done
