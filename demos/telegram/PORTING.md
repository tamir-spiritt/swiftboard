# Porting Telegram-iOS to the browser (Swiftboard demo)

Goal: Telegram's real iOS source (github.com/TelegramMessenger/Telegram-iOS, GPL) compiled with the real Swift
compiler to WebAssembly and rendered in a Swiftboard frame. Swiftboard (MIT) only loads Telegram as a test app.

## Licensing layout (keep it this way)
- `platform/` (MIT, ours): browser implementations of Apple frameworks (WebCompat, UIKit, QuartzCore, CoreGraphics,
  CoreText, AsyncDisplayKit-in-Swift). Never copy Telegram code here.
- `demos/telegram/` (GPL, derived): build scripts, `overlay/` = patched copies of upstream files at the same relative
  path (keep them minimal, comment `Swiftboard web port:` at each change), tests.
- Telegram source itself is NOT committed. Checkout: `./demos/telegram/fetch-telegram.sh` (into `build/telegram-ios`).

## Toolchain
- `demos/telegram/env.sh`: Swift 6.4+ and the official Swift SDK for WebAssembly (install commands inside), plus a
  `swasm` helper (swiftc for wasm32-unknown-wasip1). SwiftPM is not required: the scripts call the compiler directly.
- `demos/telegram/fetch-telegram.sh` downloads Telegram-iOS into `build/telegram-ios` (GPL, never committed).
- Run Node tests with `node --no-warnings demos/telegram/tests/run-display.mjs <file>.wasm` (WASI preview1).
- Full builds are heavy: use a machine with 8+ cores and 16 GB of RAM.
- Foundation on WASI links ICU, which dominates binary size; see Help wanted in the README.

## Status
1. DONE SwiftSignalKit -> wasm: `demos/telegram/build-ssk.sh`; `tests/SignalsMain.swift` PASSES in Node
   (combineLatest, map, ValuePromise, delay, Queue.after through the run loop).
   - `platform/WebCompat/Dispatch.swift`: single-threaded DispatchQueue/Time/QoS/Group/WorkItem/SpecificKey/
     SourceTimer + `WebRunLoop`; host calls exported `webRunLoopTick()` (returns ns to next timer, 0 more work, -1 idle).
   - `platform/WebCompat/Pthread.swift`: no-op mutexes. os_unfair_lock, pthread_cond, autoreleasepool, CFAbsoluteTime in Dispatch.swift.
   - overlay `SSignalKit/SwiftSignalKit/Source/ThreadPool.swift`: runs tasks on the event loop.
2. DONE Display compiles to wasm (0 errors) and runs in Node (`tests/DisplayMain.swift`, see PROGRESS.md).
   - Build: `build-display.sh` (all modules in order; `MODE=typecheck` for Display only), `build-display-test.sh` links
     the test; run `node --no-warnings tests/run-display.mjs display.wasm` (provides `swiftboard.measure_text`).
     Use dispatched compute for Display (needs ~4 GB; 1-2 min).
   - Platform modules (MIT, `platform/`): WebCompat (Dispatch, pthread, Selector, associated objects, KVC, NSValue
     boxing, WebNotificationCenter, WebRunLoop, OperationQueue, Timer target/action, CF run-loop timer symbols),
     CoreGraphics (recording CGContext; CGImage = pixels | recording | host asset), QuartzCore (CALayer tree,
     transforms, animations keep real timing for completions, CATransaction, CADisplayLink, `WebDisplayList` JSON),
     CoreText (runs/lines/typesetter/framesetter on host text measurement), UIKit, AsyncDisplayKit (Swift,
     synchronous display), Stubs (Darwin, ObjectiveC, Accelerate, AudioToolbox, CoreHaptics, CoreMedia,
     AVFoundation).
   - Preprocessor `platform/tools/objc-strip.py`: strips @objc & co; `#selector(T.m(_:))` -> `Selector("m(_:)",
     T.m(_:))` (the Selector carries a typed invoker, no dispatch tables needed); `x.m?(...)` -> `x.m(...)` for ObjC
     optional protocol methods (list in objc-optional-methods.txt); `NotificationCenter`/`RunLoop` -> WebCompat's;
     `x as NSNumber` -> dynamic bridging cast; `NSAttributedString()` etc -> `(string: "")`; appends `import WebCompat`.
   - Telegram ObjC modules re-implemented in Swift: `demos/telegram/shims/` (ObjCRuntimeUtils, UIKitRuntimeUtils,
     AppBundle). Overlays: `NavigationKeyframes.swift`, `UIKitUtils.swift` (one-line changes each).
   - Known gaps: animations are not interpolated (model values paint; completions fire on time); `presentation()` is
     the model layer; UIView.layerClass subclasses defined outside the platform get their nearest platform ancestor's
     layer class (no `required init()`); text metrics in Node are approximations (browser uses canvas measureText);
     bitmap pixel reads (DrawingContext.bytes, colorAt) see blank memory; `#available(iOS N, *)` is true on WASI, so the
     newest-OS branches run.
3. Then ChatListUI and its ~130 deps (TelegramCore/Postbox/AccountContext...): stub data layer with fake chats.
4. Board integration: load the Telegram wasm in a frame, forward taps/scroll/keyboard, paint its display list.
