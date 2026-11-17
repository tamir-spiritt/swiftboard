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

Built (`build-chatlist.sh`, module list in `shims/chatlist/MODULES`):
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

## Layer 3b: toward the real ChatListItemNode (on-par round, 2026-11-17)

### Size (task 2), chat list wasm

| Step | raw | gzip |
|---|---|---|
| before (-Osize, --strip-all) | 58.0 MB | 20.3 MB |
| + ICU data trimmed to root/en (`platform/tools/icu-trim.py`, 34 MB -> 3.8 MB of data) | 27.8 MB | 8.2 MB |
| + wasm-opt -Oz (binaryen 123) | 19.6 MB | 6.9 MB |

Verified in node (reactor runner) and Chromium after each step: 10 chats, tap selects.

### Approach: real upstream code, closure-driven

`tools/closure.py` type-checks a module (shim + real files + extracted declarations), maps each missing name to the
upstream file declaring it (local) and adds the whole file (when the path matches the
module's allow pattern) or extracts just that declaration verbatim (`tools/assemble.py`). Names declared in another
module are routed into that module's `<Module>.closure.json`. `tools/drop-decls.py` removes members that need the
network/API layer (`Api.`, `account: Account`, `postbox: Postbox`, `transaction: Transaction`, `MTRpcError` ...).
`tools/rebuild-closures.sh` iterates in dependency order until stable.

### Error counts per round

| Round | Module | errors |
|---|---|---|
| 0 | ChatListItem.swift vs hand stubs (start) | 328 |
| 1 | Postbox (23 real files) | 21 -> 7 -> 9 -> 0 |
| 2 | TelegramCore SyncCore closure, FlatBuffers dropped | 411 -> 388 -> 0 (but serialization gutted) |
| 3 | TelegramCore with real FlatBuffers runtime + flatc-generated models | 265 -> 106 -> 56 -> 32 -> 16 -> 10 -> 0 |
| 4 | TelegramUIPreferences | 20 -> 1 -> 0 |
| 5 | TelegramPresentationData (16 real files) | 46 -> 18 -> 6 -> 1 -> 0 |
| 6 | TextFormat (first pass) | 33 |
| 7 | TextFormat (time_t, NSDataDetector, attachments, strings arg fix) | 33 -> 19 -> 14 -> 12 -> 0 |
| 8 | TelegramStringFormatting (MapKit/CoreLocation, PlatformRestrictionMatching) | 363 -> 339 -> 330 -> 0 |
| 9 | AccountContext (protocol shim + WebAccountContext, real value types) | 11 -> 0 |
| 10 | EmojiTextAttachmentView / TextNodeWithEntities / MultilineTextWithEntitiesComponent / EmojiStatusComponent | 8 / 2 / 14 / 2 -> 0 |
| 11 | AvatarNode (real: AvatarNode, PeerAvatar, AvatarBadgeView) | 20 -> 6 -> 0 |
| 12 | ChatListItem.swift (ChatListUI module) | 328 -> 81 -> 30 -> 19 -> 5 -> 3 -> 2 -> 1 |

Remaining: 1 error, a compiler "failed to produce diagnostic" at the start of ChatListItemNode.asyncLayout's
returned closure (2,000+ lines). The real error inside is hidden by multi-statement closure inference; diagnosis copies
the body into a typed local function so statements check one by one (local).

## Real ChatListItemNode in the browser (round 13)

- Run 1 trapped in `Bundle.main` (WASI has no executable path): upstream `defaultPresentationStrings` reads
  Localizable.strings through `getAppBundle()`. The web build compiles the same strings, so the shim defines the value
  and assemble.py drops the upstream line.
- Run 2: `[swift] chat list started with 10 chats: 10 rows are ChatListUI.ChatListItemNode (real Telegram cell), 0 other`.
- Read checks drew a single tick: ChatListStatusChecksNode draws both ticks with `setBlendMode(.copy)`, and canvas
  'copy' clears everything outside the painted shape. The host now emulates CG copy (punch shape, paint source-over).
- Tap: ChatListItem.selected calls `interaction.messageSelected` for a chat with a message; the shim had it as a no-op.
  Now: `[swift] chat selected (ChatListItem.selected -> messageSelected): Design Team, last message: ...`.
- Chromium (publishing-layout harness): (local)

## Release build of the real-cell chat list (round 14)

Same pipeline as round 10 (-Osize modules, ICU data trimmed to root/en, wasm-opt -Oz from binaryen 123):

| Step | raw | gzip |
|---|---|---|
| linked (-Osize, --strip-all, trimmed ICU) | 33.0 MB | 9.7 MB |
| + wasm-opt -Oz | 22.8 MB | 8.0 MB |

The real cell pulls in ~30 more real Telegram modules than the hand-written row did (round 10: 19.6 MB / 6.9 MB).
Assets: 87 of the 91 bundle images referenced by the compiled sources are exported (`tools/gen-assets.py`); the chat
list's muted, pinned, verified and badge icons render from them.

- Fix: the `.byWords` rewrite now matches only the NSString form (Display's `String.enumerateSubstrings` keeps the
  StringProtocol overload); build-web.sh stops when a base module fails instead of linking stale objects (that mix
  trapped with "null function or function signature mismatch").
- Chromium, publishing-layout harness: `[swift] chat list started with 10 chats: 10 rows are ChatListUI.ChatListItemNode
  (real Telegram cell), 0 other`; wheel + drag scroll; tap -> `ChatListItem.selected -> messageSelected: Design Team`.
  Shots: (local) (copied to (local).
