// Objective-C runtime stand-ins for a Swift-only (WASI) build: selectors that carry a typed invoker,
// associated objects, and the target/action conveniences Apple frameworks build on them.
#if os(WASI)
import Foundation

/// Unapplied method reference through a value's static type: objc-strip turns `#selector(node.tapped)` into
/// `Selector("tapped", webMethodOf(node) { $0.tapped })`.
public func webMethodOf<T: AnyObject, F>(_ value: T, _ f: @escaping (T) -> F) -> (T) -> F { f }

/// A selector: its ObjC-style name plus, when made from `#selector(...)` (see tools/objc-strip.py), a type-checked
/// invoker that calls the method on a target of the right class.
public struct Selector: Hashable, CustomStringConvertible {
    public let name: String
    private let invoker: ((AnyObject, Any?, Any?) -> Any?)?

    public init(_ name: String) { self.name = name; self.invoker = nil }
    public init(stringLiteral name: String) { self.init(name) }
    public init<T: AnyObject, R>(_ name: String, _ f: @escaping (T) -> () -> R) {
        self.name = name
        invoker = { t, _, _ in (t as? T).map { f($0)() } }
    }
    public init<T: AnyObject, A, R>(_ name: String, _ f: @escaping (T) -> (A) -> R) {
        self.name = name
        invoker = { t, a, _ in
            guard let t = t as? T else { return nil }
            if let a = a as? A { return f(t)(a) }
            if let a = Optional<Any>.none as? A { return f(t)(a) } // optional parameter, nil argument
            return nil
        }
    }
    public init<T: AnyObject, A, B, R>(_ name: String, _ f: @escaping (T) -> (A, B) -> R) {
        self.name = name
        invoker = { t, a, b in
            guard let t = t as? T, let a = a as? A, let b = b as? B else { return nil }
            return f(t)(a, b)
        }
    }

    /// Whether this selector can be performed on `target`.
    public func canPerform(on target: AnyObject) -> Bool { invoker != nil }
    /// Calls the method on `target` (arguments are cast to the declared types). Returns the method's result.
    @discardableResult
    public func perform(on target: AnyObject, with a: Any? = nil, with b: Any? = nil) -> Any? {
        guard let invoker else { return nil }
        return invoker(target, a, b)
    }

    public var description: String { name }
    public static func == (l: Selector, r: Selector) -> Bool { l.name == r.name }
    public func hash(into h: inout Hasher) { h.combine(name) }
}

public func NSSelectorFromString(_ s: String) -> Selector { Selector(s) }
public func NSStringFromSelector(_ s: Selector) -> String { s.name }
public func sel_getName(_ s: Selector) -> String { s.name }

// MARK: associated objects

public struct objc_AssociationPolicy: Equatable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let OBJC_ASSOCIATION_ASSIGN = objc_AssociationPolicy(rawValue: 0)
    public static let OBJC_ASSOCIATION_RETAIN_NONATOMIC = objc_AssociationPolicy(rawValue: 1)
    public static let OBJC_ASSOCIATION_COPY_NONATOMIC = objc_AssociationPolicy(rawValue: 3)
    public static let OBJC_ASSOCIATION_RETAIN = objc_AssociationPolicy(rawValue: 769)
    public static let OBJC_ASSOCIATION_COPY = objc_AssociationPolicy(rawValue: 771)
}

private final class AssociationBox { var values: [UnsafeRawPointer: Any] = [:] }
private final class WeakKey: Hashable {
    weak var object: AnyObject?
    let id: ObjectIdentifier
    init(_ o: AnyObject) { object = o; id = ObjectIdentifier(o) }
    static func == (a: WeakKey, b: WeakKey) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }
}
nonisolated(unsafe) private var associations: [ObjectIdentifier: (WeakKey, AssociationBox)] = [:]

private func pruneAssociations() {
    if associations.count % 256 == 0 {
        associations = associations.filter { $0.value.0.object != nil }
    }
}

public func objc_setAssociatedObject(_ object: Any, _ key: UnsafeRawPointer, _ value: Any?, _ policy: objc_AssociationPolicy) {
    let o = object as AnyObject
    let id = ObjectIdentifier(o)
    var entry = associations[id]
    if entry == nil || entry!.0.object !== o {
        pruneAssociations()
        entry = (WeakKey(o), AssociationBox())
        associations[id] = entry
    }
    entry!.1.values[key] = value
}

public func objc_getAssociatedObject(_ object: Any, _ key: UnsafeRawPointer) -> Any? {
    let o = object as AnyObject
    guard let entry = associations[ObjectIdentifier(o)], entry.0.object === o else { return nil }
    return entry.1.values[key]
}

public func objc_removeAssociatedObjects(_ object: Any) {
    associations[ObjectIdentifier(object as AnyObject)] = nil
}

// MARK: Timer target/action (fired by the web run loop: the browser has no CFRunLoop to run)

extension Timer {
    public convenience init(timeInterval ti: TimeInterval, target: Any, selector: Selector, userInfo: Any?, repeats: Bool) {
        let t = target as AnyObject
        let action: (Timer) -> Void = { timer in selector.perform(on: t, with: timer) }
        self.init(timeInterval: ti, repeats: repeats, block: { _ in })
        WebTimers.track(self, interval: ti, repeats: repeats, action: action)
    }
    public class func scheduledTimer(timeInterval ti: TimeInterval, target: Any, selector: Selector, userInfo: Any?, repeats: Bool) -> Timer {
        Timer(timeInterval: ti, target: target, selector: selector, userInfo: userInfo, repeats: repeats)
    }
    public class func webScheduledTimer(withTimeInterval ti: TimeInterval, repeats: Bool, block: @escaping (Timer) -> Void) -> Timer {
        let timer = Timer(timeInterval: ti, repeats: repeats, block: { _ in })
        WebTimers.track(timer, interval: ti, repeats: repeats, action: block)
        return timer
    }
}

public enum WebTimers {
    final class Entry { let timer: Timer; var at: Date; let interval: TimeInterval; let repeats: Bool; let action: (Timer) -> Void
        init(_ t: Timer, _ at: Date, _ i: TimeInterval, _ r: Bool, _ a: @escaping (Timer) -> Void) { timer = t; self.at = at; interval = i; repeats = r; action = a } }
    nonisolated(unsafe) static var entries: [Entry] = []
    public static func track(_ t: Timer, interval: TimeInterval, repeats: Bool, action: @escaping (Timer) -> Void) {
        let e = Entry(t, Date().addingTimeInterval(interval), interval, repeats, action)
        entries.append(e)
        arm(e)
    }
    static func arm(_ e: Entry) {
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0, e.at.timeIntervalSinceNow)) {
            guard e.timer.isValid else { entries.removeAll { $0 === e }; return }
            e.action(e.timer)
            if e.repeats && e.timer.isValid {
                e.at = Date().addingTimeInterval(max(e.interval, 0.001))
                arm(e)
            } else {
                e.timer.invalidate()
                entries.removeAll { $0 === e }
            }
        }
    }
}
#endif

#if os(WASI)
// MARK: key-value coding (classes that know their keys adopt WebKeyValueCoding; everything else keeps a bag)

public protocol WebKeyValueCoding: AnyObject {
    /// `.some(value)` when the key is a known property, `nil` to fall back to the generic bag.
    func webValue(forKey key: String) -> Any??
    /// true when the key was a known property.
    func webSetValue(_ value: Any?, forKey key: String) -> Bool
}

nonisolated(unsafe) private var kvcBagKey: UInt8 = 0
private final class KVCBag { var values: [String: Any] = [:] }

extension NSObject {
    private var webKVCBag: KVCBag {
        if let b = objc_getAssociatedObject(self, &kvcBagKey) as? KVCBag { return b }
        let b = KVCBag()
        objc_setAssociatedObject(self, &kvcBagKey, b, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return b
    }
    public func value(forKey key: String) -> Any? {
        if let k = self as? WebKeyValueCoding, let v = k.webValue(forKey: key) { return v }
        if let d = self as? NSDictionary { return d.object(forKey: key) }
        return webKVCBag.values[key]
    }
    public func setValue(_ value: Any?, forKey key: String) {
        if let k = self as? WebKeyValueCoding, k.webSetValue(value, forKey: key) { return }
        if let d = self as? NSMutableDictionary { d.setObject(value as Any, forKey: key as NSString); return }
        webKVCBag.values[key] = value
    }
    public func value(forKeyPath keyPath: String) -> Any? {
        if let k = self as? WebKeyValueCoding, let v = k.webValue(forKey: keyPath) { return v }
        var parts = keyPath.split(separator: ".").map(String.init)
        guard !parts.isEmpty else { return nil }
        let first = parts.removeFirst()
        let v = value(forKey: first)
        if parts.isEmpty { return v }
        return (v as? NSObject)?.value(forKeyPath: parts.joined(separator: "."))
    }
    public func setValue(_ value: Any?, forKeyPath keyPath: String) {
        if let k = self as? WebKeyValueCoding, k.webSetValue(value, forKey: keyPath) { return }
        var parts = keyPath.split(separator: ".").map(String.init)
        if parts.count <= 1 { setValue(value, forKey: keyPath); return }
        let last = parts.removeLast()
        (self.value(forKeyPath: parts.joined(separator: ".")) as? NSObject)?.setValue(value, forKey: last)
    }
}

/// NSValue boxing for any Swift value (CATransform3D, UIEdgeInsets, ...): corelibs NSValue cannot encode structs,
/// so the value lives in a box tied to the NSValue (associated object) and the NSValue holds its address.
final class WebValueBox: CustomStringConvertible { let value: Any; init(_ v: Any) { value = v }; var description: String { "\(value)" } }
nonisolated(unsafe) private var webBoxKey: UInt8 = 0

extension NSValue {
    public convenience init(webBoxing value: Any) {
        let box = WebValueBox(value)
        var address = Int64(Int(bitPattern: Unmanaged.passUnretained(box).toOpaque()))
        self.init(bytes: &address, objCType: "q")
        objc_setAssociatedObject(self, &webBoxKey, box, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
    /// The value stored with `init(webBoxing:)`.
    public var webBoxed: Any? { (objc_getAssociatedObject(self, &webBoxKey) as? WebValueBox)?.value }
}
#endif

#if os(WASI)
// MARK: Foundation gaps (corelibs lacks some Darwin conveniences)
extension NSMutableAttributedString {
    public convenience init() { self.init(string: "") }
}
#endif

#if os(WASI)
// MARK: informal UIAccessibility on NSObject (read on arbitrary accessibility elements)
public protocol WebAccessibilityFrameProviding: AnyObject { var webDefaultAccessibilityFrame: CGRect { get } }
nonisolated(unsafe) private var axFrameKey: UInt8 = 0
extension NSObject {
    public var accessibilityFrame: CGRect {
        get {
            if let v = objc_getAssociatedObject(self, &axFrameKey) as? CGRect { return v }
            return (self as? WebAccessibilityFrameProviding)?.webDefaultAccessibilityFrame ?? .zero
        }
        set { objc_setAssociatedObject(self, &axFrameKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}

// MARK: word enumeration (corelibs marks the Foundation one unavailable; available overloads win)
public struct WebSubstringEnumerationOptions: OptionSet {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let byWords = WebSubstringEnumerationOptions(rawValue: 3)
    public static let byComposedCharacterSequences = WebSubstringEnumerationOptions(rawValue: 2)
}
extension StringProtocol {
    public func enumerateSubstrings(in range: Range<String.Index>, options: WebSubstringEnumerationOptions, _ body: (String?, Range<String.Index>, Range<String.Index>, inout Bool) -> Void) {
        let s = String(self)
        var stop = false
        if options.contains(.byWords) {
            var i = range.lowerBound
            while i < range.upperBound && !stop {
                while i < range.upperBound && !(s[i].isLetter || s[i].isNumber || s[i] == "'") { i = s.index(after: i) }
                if i >= range.upperBound { break }
                var j = i
                while j < range.upperBound && (s[j].isLetter || s[j].isNumber || s[j] == "'") { j = s.index(after: j) }
                body(String(s[i..<j]), i..<j, i..<j, &stop)
                i = j
            }
        } else {
            var i = range.lowerBound
            while i < range.upperBound && !stop {
                let j = s.index(after: i)
                body(String(s[i..<j]), i..<j, i..<j, &stop)
                i = j
            }
        }
    }
}

// MARK: NSLinguisticTagger (script-based language guess)
public struct NSLinguisticTagScheme: RawRepresentable, Hashable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let language = NSLinguisticTagScheme(rawValue: "Language")
    public static let script = NSLinguisticTagScheme(rawValue: "Script")
    public static let tokenType = NSLinguisticTagScheme(rawValue: "TokenType")
}
public struct NSLinguisticTag: RawRepresentable, Hashable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
}
public final class NSLinguisticTagger: NSObject {
    public var string: String?
    public init(tagSchemes: [NSLinguisticTagScheme], options: Int) {}
    public static func dominantLanguage(for s: String) -> String? { guess(s) }
    public var dominantLanguage: String? { string.flatMap(NSLinguisticTagger.guess) }
    public func tag(at index: Int, scheme: NSLinguisticTagScheme, tokenRange: UnsafeMutablePointer<NSRange>?, sentenceRange: UnsafeMutablePointer<NSRange>?) -> NSLinguisticTag? {
        string.flatMap(NSLinguisticTagger.guess).map { NSLinguisticTag(rawValue: $0) }
    }
    static func guess(_ s: String) -> String? {
        for u in s.unicodeScalars {
            switch u.value {
            case 0x0590...0x05FF: return "he"
            case 0x0600...0x06FF: return "ar"
            case 0x0400...0x04FF: return "ru"
            case 0x4E00...0x9FFF: return "zh"
            case 0x3040...0x30FF: return "ja"
            case 0x41...0x5A, 0x61...0x7A: return "en"
            default: continue
            }
        }
        return nil
    }
}

extension NSValue {
    /// Darwin's sized variant.
    public func getValue(_ value: UnsafeMutableRawPointer, size: Int) { getValue(value) }
}
#endif

#if os(WASI)
// MARK: CFRunLoopTimer for Foundation's Timer (CoreFoundation on WASI ships without run loops).
// CF objects on non-Darwin share Swift's object header, so a Swift object can stand in for the CF timer:
// Foundation retains/releases it like any CF object.
public typealias WebCFTimerCallout = @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> Void
final class WebCFTimer {
    var valid = true
    var fireDate: Double
    var interval: Double
    var tolerance: Double = 0
    let callout: WebCFTimerCallout?
    let info: UnsafeMutableRawPointer?
    var scheduled = false
    init(fireDate: Double, interval: Double, callout: WebCFTimerCallout?, info: UnsafeMutableRawPointer?) {
        self.fireDate = fireDate; self.interval = interval; self.callout = callout; self.info = info
    }
    func schedule() {
        guard valid, !scheduled else { return }
        scheduled = true
        let delay = max(0, fireDate - Date().timeIntervalSinceReferenceDate)
        let me = Unmanaged.passRetained(self)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            let t = me.takeRetainedValue()
            t.scheduled = false
            guard t.valid else { return }
            t.callout?(Unmanaged.passUnretained(t).toOpaque(), t.info)
            if t.interval > 0 && t.valid {
                t.fireDate = Date().timeIntervalSinceReferenceDate + t.interval
                t.schedule()
            } else {
                t.valid = false
            }
        }
    }
}
final class WebCFRunLoop { static let main = WebCFRunLoop() }
@inline(__always) private func cfTimer(_ p: UnsafeMutableRawPointer?) -> WebCFTimer? {
    p.map { Unmanaged<WebCFTimer>.fromOpaque($0).takeUnretainedValue() }
}
@_cdecl("CFRunLoopTimerCreate")
public func _webCFRunLoopTimerCreate(_ allocator: UnsafeRawPointer?, _ fireDate: Double, _ interval: Double, _ flags: UInt, _ order: Int,
                                     _ callout: WebCFTimerCallout?, _ context: UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer? {
    let info = context?.load(fromByteOffset: MemoryLayout<Int>.size, as: UnsafeMutableRawPointer?.self)
    return Unmanaged.passRetained(WebCFTimer(fireDate: fireDate, interval: interval, callout: callout, info: info)).toOpaque()
}
@_cdecl("CFRunLoopGetCurrent")
public func _webCFRunLoopGetCurrent() -> UnsafeMutableRawPointer? { Unmanaged.passUnretained(WebCFRunLoop.main).toOpaque() }
@_cdecl("CFRunLoopAddTimer")
public func _webCFRunLoopAddTimer(_ rl: UnsafeMutableRawPointer?, _ timer: UnsafeMutableRawPointer?, _ mode: UnsafeRawPointer?) { cfTimer(timer)?.schedule() }
@_cdecl("CFRunLoopTimerGetNextFireDate")
public func _webCFRunLoopTimerGetNextFireDate(_ t: UnsafeMutableRawPointer?) -> Double { cfTimer(t)?.fireDate ?? 0 }
@_cdecl("CFRunLoopTimerSetNextFireDate")
public func _webCFRunLoopTimerSetNextFireDate(_ t: UnsafeMutableRawPointer?, _ d: Double) { cfTimer(t)?.fireDate = d }
@_cdecl("CFRunLoopTimerGetInterval")
public func _webCFRunLoopTimerGetInterval(_ t: UnsafeMutableRawPointer?) -> Double { cfTimer(t)?.interval ?? 0 }
@_cdecl("CFRunLoopTimerGetTolerance")
public func _webCFRunLoopTimerGetTolerance(_ t: UnsafeMutableRawPointer?) -> Double { cfTimer(t)?.tolerance ?? 0 }
@_cdecl("CFRunLoopTimerSetTolerance")
public func _webCFRunLoopTimerSetTolerance(_ t: UnsafeMutableRawPointer?, _ v: Double) { cfTimer(t)?.tolerance = v }
@_cdecl("CFRunLoopTimerInvalidate")
public func _webCFRunLoopTimerInvalidate(_ t: UnsafeMutableRawPointer?) { cfTimer(t)?.valid = false }
@_cdecl("CFRunLoopTimerIsValid")
public func _webCFRunLoopTimerIsValid(_ t: UnsafeMutableRawPointer?) -> UInt8 { (cfTimer(t)?.valid ?? false) ? 1 : 0 }
#endif

#if os(WASI)
extension NSMutableString {
    /// Darwin's variadic appendFormat; corelibs has none.
    public func appendFormat(_ format: String, _ args: CVarArg...) { append(String(format: format, arguments: args)) }
}
#endif

#if os(WASI)
// MARK: CFStringTokenizer (word units) for search tokens
public final class CFStringTokenizer {
    let string: NSString
    var tokens: [NSRange] = []
    var index = -1
    init(_ s: NSString, _ range: NSRange) {
        string = s
        var i = range.location, start = -1
        let end = range.location + range.length
        func isWord(_ c: unichar) -> Bool { Character(Unicode.Scalar(c) ?? " ").isLetter || Character(Unicode.Scalar(c) ?? " ").isNumber }
        while i <= end {
            let w = i < end && isWord(s.character(at: i))
            if w && start < 0 { start = i } else if !w && start >= 0 { tokens.append(NSRange(location: start, length: i - start)); start = -1 }
            i += 1
        }
    }
}
public struct CFStringTokenizerTokenType: OptionSet {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let normal = CFStringTokenizerTokenType(rawValue: 1)
}
public typealias CFIndex = Int
public typealias CFAllocator = AnyObject
public let kCFAllocatorDefault: CFAllocator? = nil
public struct CFRange: Equatable {
    public var location: CFIndex
    public var length: CFIndex
    public init() { location = 0; length = 0 }
    public init(location: CFIndex, length: CFIndex) { self.location = location; self.length = length }
}
public func CFRangeMake(_ loc: CFIndex, _ len: CFIndex) -> CFRange { CFRange(location: loc, length: len) }
public let kCFStringTokenizerUnitWord: UInt = 0
public func CFLocaleCopyCurrent() -> AnyObject? { nil }
public func CFStringTokenizerCreate(_ alloc: CFAllocator?, _ string: NSString, _ range: CFRange, _ options: UInt, _ locale: AnyObject?) -> CFStringTokenizer { CFStringTokenizer(string, NSRange(location: range.location, length: range.length)) }
public func CFStringTokenizerAdvanceToNextToken(_ t: CFStringTokenizer) -> CFStringTokenizerTokenType {
    t.index += 1
    return t.index < t.tokens.count ? .normal : []
}
public func CFStringTokenizerGetCurrentTokenRange(_ t: CFStringTokenizer) -> CFRange {
    t.index >= 0 && t.index < t.tokens.count ? CFRange(location: t.tokens[t.index].location, length: t.tokens[t.index].length) : CFRange(location: -1, length: 0)
}
#endif

#if os(WASI)
/// Seconds between 1970 and 2001 (CoreFoundation's reference date).
public let kCFAbsoluteTimeIntervalSince1970: Double = 978307200.0
#endif

#if os(WASI)
extension Data.ReadingOptions {
    /// Darwin's old name for .alwaysMapped.
    public static var mappedRead: Data.ReadingOptions { .alwaysMapped }
}
#endif

#if os(WASI)
extension NSDictionary {
    /// Darwin's NSDictionary(contentsOf:): property lists, and old-style `"key" = "value";` .strings files.
    public convenience init?(contentsOf url: URL) {
        guard let data = try? Data(contentsOf: url) else { return nil }
        if let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
            self.init(dictionary: plist); return
        }
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf16) else { return nil }
        var result: [String: String] = [:]
        let pattern = try! NSRegularExpression(pattern: #""((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;"#)
        let ns = text as NSString
        func unescape(_ s: String) -> String {
            s.replacingOccurrences(of: "\\n", with: "\n").replacingOccurrences(of: "\\\"", with: "\"").replacingOccurrences(of: "\\\\", with: "\\")
        }
        for m in pattern.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            result[unescape(ns.substring(with: m.range(at: 1)))] = unescape(ns.substring(with: m.range(at: 2)))
        }
        self.init(dictionary: result)
    }
}
#endif

#if os(WASI)
// MARK: NSDataDetector (links)
/// Darwin's NSDataDetector, links only, via a URL regex (corelibs Foundation has none and cannot construct link
/// results). Phone numbers are not detected.
public final class NSDataDetector {
    public final class Result {
        public let resultType: NSTextCheckingResult.CheckingType
        public let range: NSRange
        public let url: URL?
        init(range: NSRange, url: URL?) { resultType = .link; self.range = range; self.url = url }
    }
    let types: NSTextCheckingResult.CheckingType
    static let pattern = try! NSRegularExpression(pattern:
        #"(?i)\b(?:(?:https?|tg|ftp)://[^\s<>"]+|www\.[^\s<>"]+|[a-z0-9][a-z0-9-]*(?:\.[a-z0-9-]+)*\.(?:com|org|net|io|me|ai|app|dev|co|ru|de|uk|info|tv|xyz|gg|so|sh|ly|to|t\.me)(?:/[^\s<>"]*)?)"#)
    public init(types: UInt64) throws { self.types = NSTextCheckingResult.CheckingType(rawValue: types) }
    public func enumerateMatches(in string: String, options: NSRegularExpression.MatchingOptions = [], range: NSRange,
                                 using block: (Result?, NSRegularExpression.MatchingFlags, UnsafeMutablePointer<ObjCBool>) -> Void) {
        guard types.contains(.link) else { return }
        var stop = ObjCBool(false)
        let ns = string as NSString
        for m in NSDataDetector.pattern.matches(in: string, options: [], range: range) {
            var r = m.range
            while r.length > 0, let last = ns.substring(with: NSRange(location: r.location + r.length - 1, length: 1)).unicodeScalars.first,
                  ".,;:!?)]}'".unicodeScalars.contains(last) { r.length -= 1 }
            var s = ns.substring(with: r)
            if !s.contains("://") { s = "http://" + s }
            block(Result(range: r, url: URL(string: s)), [], &stop)
            if stop.boolValue { return }
        }
    }
    public func matches(in string: String, options: NSRegularExpression.MatchingOptions = [], range: NSRange) -> [Result] {
        var out: [Result] = []
        enumerateMatches(in: string, options: options, range: range) { r, _, _ in if let r { out.append(r) } }
        return out
    }
}
#endif

#if os(WASI)
// time_t is Int on Darwin (Int64 here): Darwin code passes `&someInt`.
@discardableResult public func localtime_r(_ t: UnsafePointer<Int>, _ result: UnsafeMutablePointer<tm>) -> UnsafeMutablePointer<tm>? {
    var v = time_t(t.pointee); return WASILibc.localtime_r(&v, result)
}
@discardableResult public func gmtime_r(_ t: UnsafePointer<Int>, _ result: UnsafeMutablePointer<tm>) -> UnsafeMutablePointer<tm>? {
    var v = time_t(t.pointee); return WASILibc.gmtime_r(&v, result)
}
#endif

#if os(WASI)
// MARK: word enumeration
// corelibs Foundation marks NSString.EnumerationOptions.byWords unavailable. objc-strip rewrites Darwin's
// `enumerateSubstrings(in:options: [.byWords ...])` to these; other options forward to corelibs.
extension NSString.EnumerationOptions {
    public static let webByWords = NSString.EnumerationOptions(rawValue: 3)
}
extension NSString {
    public func webEnumerateSubstrings(in range: NSRange, options opts: NSString.EnumerationOptions = [],
                                       using block: (String?, NSRange, NSRange, UnsafeMutablePointer<ObjCBool>) -> Void) {
        guard opts.rawValue & 0xff == 3 else { return enumerateSubstrings(in: range, options: opts, using: block) }
        // words: maximal runs of letters, digits, marks and apostrophes (UTF-16 ranges)
        var words: [NSRange] = []
        var start = -1
        let isWordUnit: (unichar) -> Bool = { c in
            guard let s = Unicode.Scalar(c) else { return true } // surrogate halves belong to the word
            return CharacterSet.alphanumerics.contains(s) || CharacterSet.nonBaseCharacters.contains(s) || c == 0x27 || c == 0x2019 || c == 0x5F
        }
        for i in range.location ..< range.location + range.length {
            if isWordUnit(character(at: i)) { if start < 0 { start = i } }
            else if start >= 0 { words.append(NSRange(location: start, length: i - start)); start = -1 }
        }
        if start >= 0 { words.append(NSRange(location: start, length: range.location + range.length - start)) }
        if opts.contains(.reverse) { words.reverse() }
        var stop = ObjCBool(false)
        for w in words {
            block(opts.contains(.substringNotRequired) ? nil : substring(with: w), w, w, &stop)
            if stop.boolValue { return }
        }
    }
}
#endif
