# Telegram web port: progress log

## Layer 2: Display (Telegram's UI framework) on wasm32

Build: `demos/telegram/build-display.sh` (modules in dependency order; `MODE=typecheck` for Display only).
Heavy steps run on dispatched compute (4 vCPU / 8 GiB).

| Iteration | Display errors (type-check) | What changed |
|---|---|---|
| 1 | 198 | First full platform: WebCompat, CoreGraphics, QuartzCore, CoreText, UIKit, AsyncDisplayKit, system stubs, Telegram ObjC-module shims, preprocessor |
| 2 | 5 | NotificationCenter/RunLoop -> WebCompat (Foundation's unavailable on WASI), numeric `as NSNumber` bridging, CFGetTypeID, pthread rwlocks, word enumeration, NSLinguisticTagger, iOS 17-27 API stubs, ASDK importer names, 2 overlays |
| 3 | 1 | UIButton(type:) convenience (subclasses inherit init()), ReservedRegionKind.division |
| 4 | 0 | `NSAttributedString()` -> `(string: "")` |

### Codegen + runtime

| Step | Result |
|---|---|
| Display -> wasm object (`-Onone -wmo`) | 0 errors, `Display.o` 9.3 MB, 50-80 s on 4 vCPU |
| Link `tests/DisplayMain.swift` + all modules | `display.wasm` 70 MB (debug, Foundation+ICU) |
| Run 1 | link imports `env.CFRunLoop*`: Foundation's Timer needs CF run loops WASI's CF lacks -> implemented the CF timer C symbols in WebCompat over the web event loop |
| Run 2 | `GenerateImage.swift:508` assertion: CG pads automatic row strides to 64 bytes, UIKit contexts are BGRA little-endian -> matched |
| Run 3 | PASS: real Display nodes laid out and displayed; JSON display list in `tests/display-output.json` |
| Run 4 | ASDK nodes default to screen-scale contents (text recordings now 3x); signals test still PASS |

Test (`tests/DisplayMain.swift`, run with `node tests/run-display.mjs display.wasm`): a UIWindow holding an ASDisplayNode
with an ASImageNode (circle drawn by Display's `generateImage` through `DrawingContext`), an `ImmediateTextNode` title, a
two-line `TextNode.asyncLayout` preview truncated with an ellipsis, and a layer-backed separator. Output: layer tree with
frames, colors and each layer's contents as a recording of drawing ops (paths as SVG, text runs with CSS fonts).

## Browser host (Part A)

`web/uikit-host.js` + `web/telegram.html`/`telegram.js` (site assembled by `build-web.sh` into build/telegram/web; page at
`/`, files under `/_releases/<id>/`, wasm fetched via `new URL(..., import.meta.url)`). Verified in Chromium (Playwright,
publishing-layout harness): Display demo renders (circle, title, 2-line truncated text, separator), taps on the avatar
and title fire Swift handlers that re-lay out the title with TextNode.

| Build (-Osize, wasm-ld --strip-all; wasm-opt not available) | size | gzip |
|---|---|---|
| telegram-display.wasm | 57.3 MB | 20.1 MB |
| telegram-chatlist.wasm | 58.0 MB | 20.3 MB |

Most of the size is Foundation + ICU data (the Display + chat list code is a few MB); next: FoundationEssentials-only
or ICU data trimming, wasm-opt.

Fixed on the way: `UIView.convert(_:from: UICoordinateSpace)` recursed (infinite hit-test loop); WASI stdout is block
buffered (line buffering in uikit_set_screen); CoreText leaves run colors as the context fill color; a pan that
begins cancels the view's touches; wheel finds sibling scrollers (ListView keeps its scroller beside the cells).

## Layer 3: chat list (Part B)

Built (`build-chatlist.sh`, module list in `chatlist-stubs/MODULES`):
- Real Telegram code compiled to wasm: Display (all), ComponentFlow (all 32 files), HierarchyTrackingLayer,
  PeerOnlineMarkerNode, TelegramPresentationData subset (PresentationTheme, DefaultDayPresentationTheme,
  PresentationsResourceCache, PresentationResourceKey, PresentationResourcesChatList, PresentationResourcesItemList),
  ItemListUI subset (ItemListRevealOptionsNode, ItemListRevealMotion, ItemListRevealTouchGestureRecognizer,
  ItemListSelectableControlNode, ItemListEditableReorderControlNode, ItemListEditableItem), ChatListUI's
  ChatListBadgeNode. PresentationStrings generated from the real en Localizable.strings (`tools/gen-strings.py`).
- Stubs (data shapes, no storage/network): Postbox, TelegramCore (ids, media, wallpaper), TelegramUIPreferences
  (theme references), CheckNode, ManagedAnimationNode (no Lottie), and empty modules for the rest of ChatListItem's imports.
- Demo: `app/ChatListDemo.swift` (row layout glue with ChatListItemNode's metrics) + `app/ChatListApp.swift`: 10 chats in
  Display's real ListView, real theme colors, real unread badges (active/muted), read checks, pinned background, online
  markers. Browser: wheel and drag scroll the ListView, tap highlights and selects (Swift handler logs the chat).

ChatListItem.swift (6,257 lines, the real cell) type-checks with 328 errors against the current stubs: ~110 missing
symbols, mostly TelegramCore's engine types (EnginePeer, EngineMessage, EngineChatList, EngineRenderedPeer,
TelegramUser/media classes), AccountContext, AvatarNode, TextFormat/TelegramStringFormatting helpers and component
modules (EmojiStatusComponent, GlassBackgroundComponent, MultilineText*). Next step: write those stubs (or compile the
real UI ones: AvatarNode, ShimmerEffect, TextNodeWithEntities) and swap the demo row for ChatListItemNode.
