// Notification center and run loop for the browser. Foundation's are unavailable on WASI (no OperationQueue, no
// CFRunLoop), so tools/objc-strip.py maps `NotificationCenter` -> `WebNotificationCenter` and `RunLoop` -> `WebRunLoop`.
#if os(WASI)
import Foundation

public final class OperationQueue: NSObject {
    nonisolated(unsafe) public static let main = OperationQueue()
    public static var current: OperationQueue? { main }
    public var name: String?
    public var maxConcurrentOperationCount = 1
    public var isSuspended = false
    public var underlyingQueue: DispatchQueue?
    public override init() {}
    public func addOperation(_ block: @escaping () -> Void) { (underlyingQueue ?? .main).async(execute: block) }
    public func cancelAllOperations() {}
    public func waitUntilAllOperationsAreFinished() {}
}

public final class WebNotificationCenter: NSObject {
    nonisolated(unsafe) public static let `default` = WebNotificationCenter()
    final class Observer: NSObject {
        let name: Notification.Name?
        weak var object: AnyObject?
        let hasObject: Bool
        weak var target: AnyObject?
        let block: (Notification) -> Void
        init(name: Notification.Name?, object: Any?, target: AnyObject?, block: @escaping (Notification) -> Void) {
            self.name = name; self.object = object as AnyObject?; hasObject = object != nil; self.target = target; self.block = block
        }
    }
    private var observers: [Observer] = []
    public override init() {}
    @discardableResult
    public func addObserver(forName name: Notification.Name?, object: Any?, queue: OperationQueue?, using block: @escaping (Notification) -> Void) -> NSObjectProtocol {
        let o = Observer(name: name, object: object, target: nil, block: block)
        observers.append(o)
        return o
    }
    public func addObserver(_ observer: Any, selector: Selector, name: Notification.Name?, object: Any?) {
        let t = observer as AnyObject
        observers.append(Observer(name: name, object: object, target: t, block: { [weak t] n in if let t { selector.perform(on: t, with: n) } }))
    }
    public func removeObserver(_ observer: Any) {
        let t = observer as AnyObject
        observers.removeAll { $0 === t || $0.target === t }
    }
    public func removeObserver(_ observer: Any, name: Notification.Name?, object: Any?) {
        let t = observer as AnyObject
        observers.removeAll { ($0 === t || $0.target === t) && (name == nil || $0.name == name) }
    }
    public func post(_ n: Notification) {
        for o in observers where (o.name == nil || o.name == n.name) && (!o.hasObject || o.object === (n.object as AnyObject?)) {
            if o.block as AnyObject? != nil { o.block(n) }
        }
    }
    public func post(name: Notification.Name, object: Any?) { post(Notification(name: name, object: object)) }
    public func post(name: Notification.Name, object: Any?, userInfo: [AnyHashable: Any]?) { post(Notification(name: name, object: object, userInfo: userInfo)) }
}

public final class WebRunLoop: NSObject {
    public struct Mode: RawRepresentable, Hashable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public init(_ rawValue: String) { self.rawValue = rawValue }
        public static let `default` = Mode("kCFRunLoopDefaultMode")
        public static let common = Mode("kCFRunLoopCommonModes")
        public static let tracking = Mode("UITrackingRunLoopMode")
    }
    nonisolated(unsafe) public static let main = WebRunLoop()
    public static var current: WebRunLoop { main }
    public var currentMode: Mode? { .default }
    /// Timers made through `Timer(timeInterval:target:selector:...)` are already scheduled; others fire via `fire()`.
    public func add(_ timer: Timer, forMode mode: Mode) {
        if !WebTimers.entries.contains(where: { $0.timer === timer }) {
            WebTimers.track(timer, interval: max(0, timer.fireDate.timeIntervalSinceNow), repeats: timer.timeInterval > 0, action: { $0.fire() })
        }
    }
    public func perform(_ block: @escaping () -> Void) { DispatchQueue.main.async(execute: block) }
    public func perform(inModes modes: [Mode], block: @escaping () -> Void) { DispatchQueue.main.async(execute: block) }
    public func run(until date: Date) {
        while Date() < date { if webRunLoopTick() < 0 { break } }
    }
    @discardableResult public func run(mode: Mode, before date: Date) -> Bool { _ = webRunLoopTick(); return true }
}
#endif
