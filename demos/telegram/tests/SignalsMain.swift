import SwiftSignalKit
import WebCompat

// Exercises Telegram's real SwiftSignalKit on WebAssembly: map, combineLatest, Promise, delays, Queue.after
var log: [String] = []

let a = ValuePromise<Int>(1, ignoreRepeated: true)
let b = Promise<String>()
b.set(.single("chats"))

let disposable = combineLatest(a.get(), b.get() |> map { $0.uppercased() })
    .start(next: { n, s in log.append("combine \(n) \(s)") })

a.set(2)
a.set(2) // ignored repeat
a.set(3)

let delayed = Signal<String, NoError>.single("delayed")
    |> delay(0.05, queue: Queue.mainQueue())
let _ = delayed.start(next: { v in log.append(v) })

Queue.mainQueue().after(0.01) { log.append("after 10ms") }

// drive the event loop like the browser does every frame
let start = CFAbsoluteTimeGetCurrent()
while CFAbsoluteTimeGetCurrent() - start < 2 {
    if webRunLoopTick() < 0 { break }
}
disposable.dispose()
for l in log { print(l) }
print(log == ["combine 1 CHATS", "combine 2 CHATS", "combine 3 CHATS", "after 10ms", "delayed"] ? "PASS" : "FAIL")
