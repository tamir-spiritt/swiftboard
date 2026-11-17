// A single-threaded Dispatch for WebAssembly in the browser.
// Every queue feeds one run loop; the host page drains it (`webRunLoopTick`) each frame.
// `sync` on another queue runs inline: with one thread there is nothing to wait for.
#if os(WASI)
@_exported import WASILibc
@_exported import Foundation

// MARK: time

@inline(__always) func webNowNanos() -> UInt64 {
    UInt64(ProcessInfo.processInfo.systemUptime * 1e9)
}

public typealias CFAbsoluteTime = Double
public func CFAbsoluteTimeGetCurrent() -> CFAbsoluteTime {
    Date().timeIntervalSinceReferenceDate
}

public enum DispatchTimeInterval: Equatable {
    case seconds(Int), milliseconds(Int), microseconds(Int), nanoseconds(Int), never
    var nanos: UInt64 {
        switch self {
        case .seconds(let s): return UInt64(max(0, s)) * 1_000_000_000
        case .milliseconds(let s): return UInt64(max(0, s)) * 1_000_000
        case .microseconds(let s): return UInt64(max(0, s)) * 1_000
        case .nanoseconds(let s): return UInt64(max(0, s))
        case .never: return UInt64.max
        }
    }
}

public struct DispatchTime: Comparable {
    public let uptimeNanoseconds: UInt64
    public init(uptimeNanoseconds: UInt64) { self.uptimeNanoseconds = uptimeNanoseconds }
    public static func now() -> DispatchTime { DispatchTime(uptimeNanoseconds: webNowNanos()) }
    public static let distantFuture = DispatchTime(uptimeNanoseconds: UInt64.max)
    public static func < (a: DispatchTime, b: DispatchTime) -> Bool { a.uptimeNanoseconds < b.uptimeNanoseconds }
    public static func + (t: DispatchTime, s: Double) -> DispatchTime {
        if s.isInfinite || s > 1e9 { return .distantFuture }
        return DispatchTime(uptimeNanoseconds: t.uptimeNanoseconds &+ UInt64(max(0, s) * 1e9))
    }
    public static func + (t: DispatchTime, i: DispatchTimeInterval) -> DispatchTime {
        let n = i.nanos
        return n == UInt64.max ? .distantFuture : DispatchTime(uptimeNanoseconds: t.uptimeNanoseconds &+ n)
    }
    public static func - (t: DispatchTime, s: Double) -> DispatchTime {
        DispatchTime(uptimeNanoseconds: t.uptimeNanoseconds &- UInt64(max(0, s) * 1e9))
    }
}
public typealias DispatchWallTime = DispatchTime

public struct DispatchQoS: Equatable {
    public enum QoSClass { case background, utility, `default`, userInitiated, userInteractive, unspecified }
    public let qosClass: QoSClass
    public let relativePriority: Int
    public init(qosClass: QoSClass, relativePriority: Int) { self.qosClass = qosClass; self.relativePriority = relativePriority }
    public static let background = DispatchQoS(qosClass: .background, relativePriority: 0)
    public static let utility = DispatchQoS(qosClass: .utility, relativePriority: 0)
    public static let `default` = DispatchQoS(qosClass: .default, relativePriority: 0)
    public static let userInitiated = DispatchQoS(qosClass: .userInitiated, relativePriority: 0)
    public static let userInteractive = DispatchQoS(qosClass: .userInteractive, relativePriority: 0)
    public static let unspecified = DispatchQoS(qosClass: .unspecified, relativePriority: 0)
    public static func == (a: DispatchQoS, b: DispatchQoS) -> Bool { a.qosClass == b.qosClass && a.relativePriority == b.relativePriority }
}

public struct DispatchWorkItemFlags: OptionSet {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let barrier = DispatchWorkItemFlags(rawValue: 1)
    public static let enforceQoS = DispatchWorkItemFlags(rawValue: 2)
    public static let inheritQoS = DispatchWorkItemFlags(rawValue: 4)
    public static let detached = DispatchWorkItemFlags(rawValue: 8)
    public static let assignCurrentContext = DispatchWorkItemFlags(rawValue: 16)
}

public final class DispatchWorkItem {
    let block: () -> Void
    public private(set) var isCancelled = false
    public init(qos: DispatchQoS = .unspecified, flags: DispatchWorkItemFlags = [], block: @escaping () -> Void) { self.block = block }
    public func perform() { if !isCancelled { block() } }
    public func cancel() { isCancelled = true }
}

public final class DispatchGroup {
    private var count = 0
    private var notifies: [(DispatchQueue, () -> Void)] = []
    public init() {}
    public func enter() { count += 1 }
    public func leave() {
        count -= 1
        if count <= 0 { let n = notifies; notifies = []; for (q, f) in n { q.async(execute: f) } }
    }
    public func notify(queue: DispatchQueue, execute: @escaping () -> Void) {
        if count <= 0 { queue.async(execute: execute) } else { notifies.append((queue, execute)) }
    }
}

public final class DispatchSpecificKey<T> {
    public init() {}
}

// MARK: run loop

final class WebEventLoop {
    static let shared = WebEventLoop()
    struct Timed { let at: UInt64; let seq: Int; let queue: DispatchQueue; let f: () -> Void }
    var ready: [(DispatchQueue, () -> Void)] = []
    var timed: [Timed] = []
    var seq = 0
    var current: [DispatchQueue] = []

    func post(_ q: DispatchQueue, _ f: @escaping () -> Void) { ready.append((q, f)) }
    func post(_ q: DispatchQueue, at: UInt64, _ f: @escaping () -> Void) {
        seq += 1
        timed.append(Timed(at: at, seq: seq, queue: q, f: f))
    }
    func run(_ q: DispatchQueue, _ f: () -> Void) {
        current.append(q)
        f()
        current.removeLast()
    }
    /// Runs everything that is due. Returns nanoseconds until the next timer (0 = more work ready, -1 = idle).
    func tick(budget: Int = 100_000) -> Int64 {
        var n = 0
        while n < budget {
            let now = webNowNanos()
            if !timed.isEmpty {
                var due: [Timed] = []
                timed.removeAll(where: { t in if t.at <= now { due.append(t); return true }; return false })
                due.sort { ($0.at, $0.seq) < ($1.at, $1.seq) }
                for t in due { ready.append((t.queue, t.f)) }
            }
            if ready.isEmpty { break }
            let batch = ready
            ready = []
            for (q, f) in batch { run(q, f); n += 1 }
        }
        if !ready.isEmpty { return 0 }
        guard let next = timed.map({ $0.at }).min() else { return -1 }
        let now = webNowNanos()
        return next > now ? Int64(min(next - now, UInt64(Int64.max))) : 0
    }
}

@_cdecl("webRunLoopTick")
public func webRunLoopTick() -> Int64 { WebEventLoop.shared.tick() }

// MARK: queues

public final class DispatchQueue {
    public struct Attributes: OptionSet {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let concurrent = Attributes(rawValue: 1)
        public static let initiallyInactive = Attributes(rawValue: 2)
    }
    public enum AutoreleaseFrequency { case inherit, workItem, never }

    public let label: String
    private var specifics: [ObjectIdentifier: Any] = [:]

    public init(label: String, qos: DispatchQoS = .unspecified, attributes: Attributes = [], autoreleaseFrequency: AutoreleaseFrequency = .inherit, target: DispatchQueue? = nil) {
        self.label = label
    }

    public static let main = DispatchQueue(label: "com.apple.main-thread")
    private static let globals: [DispatchQoS.QoSClass: DispatchQueue] = [
        .background: DispatchQueue(label: "global.background"), .utility: DispatchQueue(label: "global.utility"),
        .default: DispatchQueue(label: "global.default"), .userInitiated: DispatchQueue(label: "global.userInitiated"),
        .userInteractive: DispatchQueue(label: "global.userInteractive"), .unspecified: DispatchQueue(label: "global.unspecified"),
    ]
    public static func global(qos: DispatchQoS.QoSClass = .default) -> DispatchQueue { globals[qos]! }

    public func async(execute: @escaping () -> Void) { WebEventLoop.shared.post(self, execute) }
    public func async(group: DispatchGroup? = nil, qos: DispatchQoS = .unspecified, flags: DispatchWorkItemFlags = [], execute: @escaping () -> Void) {
        group?.enter()
        WebEventLoop.shared.post(self) { execute(); group?.leave() }
    }
    public func async(execute item: DispatchWorkItem) { WebEventLoop.shared.post(self) { item.perform() } }
    public func asyncAfter(deadline: DispatchTime, qos: DispatchQoS = .unspecified, flags: DispatchWorkItemFlags = [], execute: @escaping () -> Void) {
        if deadline == .distantFuture { return }
        WebEventLoop.shared.post(self, at: deadline.uptimeNanoseconds, execute)
    }
    public func asyncAfter(deadline: DispatchTime, execute item: DispatchWorkItem) {
        asyncAfter(deadline: deadline) { item.perform() }
    }
    public func sync<T>(execute work: () throws -> T) rethrows -> T {
        WebEventLoop.shared.current.append(self)
        defer { WebEventLoop.shared.current.removeLast() }
        return try work()
    }
    public func sync<T>(flags: DispatchWorkItemFlags, execute work: () throws -> T) rethrows -> T { try sync(execute: work) }

    public func setSpecific<T>(key: DispatchSpecificKey<T>, value: T?) { specifics[ObjectIdentifier(key)] = value }
    public func getSpecific<T>(key: DispatchSpecificKey<T>) -> T? { specifics[ObjectIdentifier(key)] as? T }
    public static func getSpecific<T>(key: DispatchSpecificKey<T>) -> T? {
        let q = WebEventLoop.shared.current.last ?? DispatchQueue.main
        return q.getSpecific(key: key)
    }
    public func activate() {}
    public func suspend() {}
    public func resume() {}
}

// MARK: timers

public protocol DispatchSourceTimer: AnyObject {
    func schedule(deadline: DispatchTime, repeating: DispatchTimeInterval, leeway: DispatchTimeInterval)
    func schedule(deadline: DispatchTime, repeating: Double, leeway: DispatchTimeInterval)
    func setEventHandler(handler: (() -> Void)?)
    func setCancelHandler(handler: (() -> Void)?)
    func resume()
    func suspend()
    func cancel()
    func activate()
    var isCancelled: Bool { get }
}

extension DispatchSourceTimer {
    public func schedule(deadline: DispatchTime) { schedule(deadline: deadline, repeating: .never, leeway: .nanoseconds(0)) }
    public func schedule(deadline: DispatchTime, repeating: DispatchTimeInterval) { schedule(deadline: deadline, repeating: repeating, leeway: .nanoseconds(0)) }
    public func schedule(deadline: DispatchTime, repeating: Double) { schedule(deadline: deadline, repeating: repeating, leeway: .nanoseconds(0)) }
    public func setEventHandler(qos: DispatchQoS = .unspecified, flags: DispatchWorkItemFlags = [], handler: (() -> Void)?) { setEventHandler(handler: handler) }
}

final class WebTimer: DispatchSourceTimer {
    let queue: DispatchQueue
    var deadline = DispatchTime.distantFuture
    var interval: UInt64 = UInt64.max
    var handler: (() -> Void)?
    var cancelHandler: (() -> Void)?
    var running = false
    var generation = 0
    private(set) var isCancelled = false
    init(queue: DispatchQueue) { self.queue = queue }

    func schedule(deadline: DispatchTime, repeating: DispatchTimeInterval, leeway: DispatchTimeInterval) {
        self.deadline = deadline
        self.interval = repeating.nanos
        arm()
    }
    func schedule(deadline: DispatchTime, repeating: Double, leeway: DispatchTimeInterval) {
        self.deadline = deadline
        self.interval = repeating.isInfinite || repeating <= 0 ? UInt64.max : UInt64(repeating * 1e9)
        arm()
    }
    func setEventHandler(handler: (() -> Void)?) { self.handler = handler }
    func setCancelHandler(handler: (() -> Void)?) { self.cancelHandler = handler }
    func resume() { running = true; arm() }
    func activate() { resume() }
    func suspend() { running = false; generation += 1 }
    func cancel() {
        if isCancelled { return }
        isCancelled = true
        generation += 1
        if let c = cancelHandler { queue.async(execute: c) }
    }
    private func arm() {
        generation += 1
        guard running, !isCancelled, deadline != .distantFuture else { return }
        let g = generation
        WebEventLoop.shared.post(queue, at: deadline.uptimeNanoseconds) { [weak self] in
            guard let self, self.generation == g, !self.isCancelled else { return }
            self.handler?()
            if self.interval != UInt64.max, !self.isCancelled, self.generation == g {
                self.deadline = DispatchTime(uptimeNanoseconds: self.deadline.uptimeNanoseconds &+ self.interval)
                self.arm()
            }
        }
    }
}

public enum DispatchSource {
    public struct TimerFlags: OptionSet {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let strict = TimerFlags(rawValue: 1)
    }
    public static func makeTimerSource(flags: TimerFlags = [], queue: DispatchQueue? = nil) -> DispatchSourceTimer {
        WebTimer(queue: queue ?? .main)
    }
}

// MARK: Darwin locks

public struct os_unfair_lock { public init() {} }
public typealias os_unfair_lock_t = UnsafeMutablePointer<os_unfair_lock>
@inline(__always) public func os_unfair_lock_lock(_ l: UnsafeMutablePointer<os_unfair_lock>) {}
@inline(__always) public func os_unfair_lock_unlock(_ l: UnsafeMutablePointer<os_unfair_lock>) {}
@inline(__always) public func os_unfair_lock_trylock(_ l: UnsafeMutablePointer<os_unfair_lock>) -> Bool { true }

@inline(__always) public func autoreleasepool<T>(invoking body: () throws -> T) rethrows -> T { try body() }

@inline(__always) public func pthread_cond_init(_ c: UnsafeMutablePointer<pthread_cond_t>, _ a: UnsafePointer<pthread_condattr_t>?) -> Int32 { 0 }
@inline(__always) public func pthread_cond_destroy(_ c: UnsafeMutablePointer<pthread_cond_t>) -> Int32 { 0 }
@inline(__always) public func pthread_cond_broadcast(_ c: UnsafeMutablePointer<pthread_cond_t>) -> Int32 { 0 }
@inline(__always) public func pthread_cond_signal(_ c: UnsafeMutablePointer<pthread_cond_t>) -> Int32 { 0 }
#endif
