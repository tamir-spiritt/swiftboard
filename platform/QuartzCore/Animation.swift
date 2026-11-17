// Swiftboard QuartzCore (MIT): animations, timing functions, transactions, display link.
// Animations do not interpolate frames yet: a layer keeps them for their duration (so completion delegates and
// CATransaction completion blocks fire at the right time) and the model values are what gets painted.
import Foundation

public struct CAMediaTimingFunctionName: RawRepresentable, Hashable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public static let linear = CAMediaTimingFunctionName("linear")
    public static let easeIn = CAMediaTimingFunctionName("easeIn")
    public static let easeOut = CAMediaTimingFunctionName("easeOut")
    public static let easeInEaseOut = CAMediaTimingFunctionName("easeInEaseOut")
    public static let `default` = CAMediaTimingFunctionName("default")
}
public let kCAMediaTimingFunctionLinear = CAMediaTimingFunctionName.linear.rawValue
public let kCAMediaTimingFunctionEaseIn = CAMediaTimingFunctionName.easeIn.rawValue
public let kCAMediaTimingFunctionEaseOut = CAMediaTimingFunctionName.easeOut.rawValue
public let kCAMediaTimingFunctionEaseInEaseOut = CAMediaTimingFunctionName.easeInEaseOut.rawValue
public let kCAMediaTimingFunctionDefault = CAMediaTimingFunctionName.default.rawValue

open class CAMediaTimingFunction: NSObject {
    public let controlPoints: [Float]
    public let name: CAMediaTimingFunctionName?
    public init(controlPoints c1x: Float, _ c1y: Float, _ c2x: Float, _ c2y: Float) {
        controlPoints = [c1x, c1y, c2x, c2y]; name = nil
    }
    public init(name: CAMediaTimingFunctionName) {
        self.name = name
        switch name {
        case .linear: controlPoints = [0, 0, 1, 1]
        case .easeIn: controlPoints = [0.42, 0, 1, 1]
        case .easeOut: controlPoints = [0, 0, 0.58, 1]
        case .easeInEaseOut: controlPoints = [0.42, 0, 0.58, 1]
        default: controlPoints = [0.25, 0.1, 0.25, 1]
        }
    }
    public func getControlPoint(at idx: Int, values ptr: UnsafeMutablePointer<Float>) {
        switch idx {
        case 0: ptr[0] = 0; ptr[1] = 0
        case 1: ptr[0] = controlPoints[0]; ptr[1] = controlPoints[1]
        case 2: ptr[0] = controlPoints[2]; ptr[1] = controlPoints[3]
        default: ptr[0] = 1; ptr[1] = 1
        }
    }
    open override func isEqual(_ object: Any?) -> Bool {
        guard let o = object as? CAMediaTimingFunction else { return false }
        return o.controlPoints == controlPoints && o.name == name
    }
    /// Progress along the curve for linear time t in [0, 1].
    public func solve(_ t: Double) -> Double {
        let x1 = Double(controlPoints[0]), y1 = Double(controlPoints[1]), x2 = Double(controlPoints[2]), y2 = Double(controlPoints[3])
        func bez(_ a: Double, _ b: Double, _ s: Double) -> Double { 3 * a * (1 - s) * (1 - s) * s + 3 * b * (1 - s) * s * s + s * s * s }
        var lo = 0.0, hi = 1.0
        for _ in 0..<30 { let mid = (lo + hi) / 2; if bez(x1, x2, mid) < t { lo = mid } else { hi = mid } }
        return bez(y1, y2, (lo + hi) / 2)
    }
}

public struct CAMediaTimingFillMode: RawRepresentable, Hashable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let forwards = CAMediaTimingFillMode(rawValue: "forwards")
    public static let backwards = CAMediaTimingFillMode(rawValue: "backwards")
    public static let both = CAMediaTimingFillMode(rawValue: "both")
    public static let removed = CAMediaTimingFillMode(rawValue: "removed")
}
public let kCAFillModeForwards = CAMediaTimingFillMode.forwards.rawValue
public let kCAFillModeBoth = CAMediaTimingFillMode.both.rawValue
public let kCAFillModeRemoved = CAMediaTimingFillMode.removed.rawValue

public protocol CAMediaTiming: AnyObject {
    var beginTime: CFTimeInterval { get set }
    var duration: CFTimeInterval { get set }
    var speed: Float { get set }
    var timeOffset: CFTimeInterval { get set }
    var repeatCount: Float { get set }
    var autoreverses: Bool { get set }
    var fillMode: CAMediaTimingFillMode { get set }
}

public protocol CAAction {
    func run(forKey event: String, object anObject: Any, arguments dict: [AnyHashable: Any]?)
}
extension NSNull: CAAction {
    public func run(forKey event: String, object anObject: Any, arguments dict: [AnyHashable: Any]?) {}
}

public protocol CAAnimationDelegate: AnyObject {
    func animationDidStart(_ anim: CAAnimation)
    func animationDidStop(_ anim: CAAnimation, finished flag: Bool)
}
extension CAAnimationDelegate {
    public func animationDidStart(_ anim: CAAnimation) {}
    public func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {}
}

public struct CAValueFunctionName: RawRepresentable, Hashable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let rotateX = CAValueFunctionName(rawValue: "rotateX")
    public static let rotateY = CAValueFunctionName(rawValue: "rotateY")
    public static let rotateZ = CAValueFunctionName(rawValue: "rotateZ")
    public static let scale = CAValueFunctionName(rawValue: "scale")
    public static let scaleX = CAValueFunctionName(rawValue: "scaleX")
    public static let scaleY = CAValueFunctionName(rawValue: "scaleY")
    public static let scaleZ = CAValueFunctionName(rawValue: "scaleZ")
    public static let translate = CAValueFunctionName(rawValue: "translate")
    public static let translateX = CAValueFunctionName(rawValue: "translateX")
    public static let translateY = CAValueFunctionName(rawValue: "translateY")
    public static let translateZ = CAValueFunctionName(rawValue: "translateZ")
}
open class CAValueFunction: NSObject {
    public let name: CAValueFunctionName
    public init?(name: CAValueFunctionName) { self.name = name }
}

open class CAAnimation: NSObject, CAMediaTiming, CAAction, NSCopying {
    open var beginTime: CFTimeInterval = 0
    open var duration: CFTimeInterval = 0
    open var speed: Float = 1
    open var timeOffset: CFTimeInterval = 0
    open var repeatCount: Float = 0
    open var repeatDuration: CFTimeInterval = 0
    open var autoreverses = false
    open var fillMode: CAMediaTimingFillMode = .removed
    open var timingFunction: CAMediaTimingFunction?
    /// Strong, as in CoreAnimation.
    open var delegate: CAAnimationDelegate?
    open var isRemovedOnCompletion = true
    open var preferredFrameRateRange: CAFrameRateRange = .default
    var kvcValues: [String: Any] = [:]

    public override init() {}
    public class func defaultValue(forKey key: String) -> Any? { nil }
    open func shouldArchiveValue(forKey key: String) -> Bool { true }
    open func copy(with zone: NSZone? = nil) -> Any {
        let a = makeCopy()
        a.beginTime = beginTime; a.duration = duration; a.speed = speed; a.timeOffset = timeOffset; a.repeatCount = repeatCount
        a.repeatDuration = repeatDuration; a.autoreverses = autoreverses; a.fillMode = fillMode; a.timingFunction = timingFunction
        a.delegate = delegate; a.isRemovedOnCompletion = isRemovedOnCompletion; a.preferredFrameRateRange = preferredFrameRateRange; a.kvcValues = kvcValues
        copyProperties(to: a)
        return a
    }
    open func makeCopy() -> CAAnimation { CAAnimation() }
    open func copyProperties(to a: CAAnimation) {}
    public func run(forKey event: String, object anObject: Any, arguments dict: [AnyHashable: Any]?) {
        (anObject as? CALayer)?.add(self, forKey: event)
    }
    /// Seconds from start to finish (one cycle times repeats, autoreverse, speed).
    public var webActiveDuration: CFTimeInterval {
        var d = duration == 0 ? CATransaction.animationDuration() : duration
        if repeatDuration > 0 { d = repeatDuration } else if repeatCount > 0 { d *= Double(repeatCount == .infinity ? 1e9 : repeatCount) }
        if autoreverses { d *= 2 }
        return speed == 0 ? .infinity : d / Double(abs(speed))
    }
}
extension CAAnimation: WebKeyValueCoding {
    public func webValue(forKey key: String) -> Any?? { .some(kvcValues[key]) }
    public func webSetValue(_ value: Any?, forKey key: String) -> Bool { kvcValues[key] = value; return true }
}

open class CAPropertyAnimation: CAAnimation {
    open var keyPath: String?
    open var isAdditive = false
    open var isCumulative = false
    open var valueFunction: CAValueFunction?
    public convenience init(keyPath: String?) { self.init(); self.keyPath = keyPath }
    open override func makeCopy() -> CAAnimation { CAPropertyAnimation() }
    open override func copyProperties(to a: CAAnimation) {
        guard let a = a as? CAPropertyAnimation else { return }
        a.keyPath = keyPath; a.isAdditive = isAdditive; a.isCumulative = isCumulative; a.valueFunction = valueFunction
    }
}

open class CABasicAnimation: CAPropertyAnimation {
    open var fromValue: Any?
    open var toValue: Any?
    open var byValue: Any?
    open override func makeCopy() -> CAAnimation { CABasicAnimation() }
    open override func copyProperties(to a: CAAnimation) {
        super.copyProperties(to: a)
        guard let a = a as? CABasicAnimation else { return }
        a.fromValue = fromValue; a.toValue = toValue; a.byValue = byValue
    }
}

public struct CAAnimationCalculationMode: RawRepresentable, Hashable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let linear = CAAnimationCalculationMode(rawValue: "linear")
    public static let discrete = CAAnimationCalculationMode(rawValue: "discrete")
    public static let paced = CAAnimationCalculationMode(rawValue: "paced")
    public static let cubic = CAAnimationCalculationMode(rawValue: "cubic")
    public static let cubicPaced = CAAnimationCalculationMode(rawValue: "cubicPaced")
}
public struct CAAnimationRotationMode: RawRepresentable, Hashable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let rotateAuto = CAAnimationRotationMode(rawValue: "auto")
    public static let rotateAutoReverse = CAAnimationRotationMode(rawValue: "autoReverse")
}

open class CAKeyframeAnimation: CAPropertyAnimation {
    open var values: [Any]?
    open var path: CGPath?
    open var keyTimes: [NSNumber]?
    open var timingFunctions: [CAMediaTimingFunction]?
    open var calculationMode: CAAnimationCalculationMode = .linear
    open var tensionValues: [NSNumber]?
    open var continuityValues: [NSNumber]?
    open var biasValues: [NSNumber]?
    open var rotationMode: CAAnimationRotationMode?
    open override func makeCopy() -> CAAnimation { CAKeyframeAnimation() }
    open override func copyProperties(to a: CAAnimation) {
        super.copyProperties(to: a)
        guard let a = a as? CAKeyframeAnimation else { return }
        a.values = values; a.path = path; a.keyTimes = keyTimes; a.timingFunctions = timingFunctions; a.calculationMode = calculationMode
        a.rotationMode = rotationMode
    }
}

open class CASpringAnimation: CABasicAnimation {
    open var mass: CGFloat = 1
    open var stiffness: CGFloat = 100
    open var damping: CGFloat = 10
    open var initialVelocity: CGFloat = 0
    open var allowsOverdamping = false
    public override init() { super.init() }
    public convenience init(perceptualDuration: TimeInterval, bounce: CGFloat) {
        self.init()
        stiffness = pow(2 * .pi / CGFloat(perceptualDuration), 2)
        damping = 4 * .pi * (1 - bounce) / CGFloat(perceptualDuration)
    }
    open var perceptualDuration: TimeInterval { 2 * .pi / sqrt(Double(stiffness / mass)) }
    open var bounce: CGFloat { 1 - damping * CGFloat(perceptualDuration) / (4 * .pi) }
    /// Time until the oscillation decays below ~0.1%.
    open var settlingDuration: CFTimeInterval {
        let zeta = Double(damping) / (2 * sqrt(Double(stiffness * mass)))
        let w0 = sqrt(Double(stiffness / mass))
        if zeta <= 0 { return 10 }
        return min(10, max(0.1, -log(0.001) / (zeta * w0)))
    }
    open override func makeCopy() -> CAAnimation { CASpringAnimation() }
    open override func copyProperties(to a: CAAnimation) {
        super.copyProperties(to: a)
        guard let a = a as? CASpringAnimation else { return }
        a.mass = mass; a.stiffness = stiffness; a.damping = damping; a.initialVelocity = initialVelocity; a.allowsOverdamping = allowsOverdamping
    }
}

open class CAAnimationGroup: CAAnimation {
    open var animations: [CAAnimation]?
    open override func makeCopy() -> CAAnimation { CAAnimationGroup() }
    open override func copyProperties(to a: CAAnimation) { (a as? CAAnimationGroup)?.animations = animations }
}

public struct CATransitionType: RawRepresentable, Hashable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let fade = CATransitionType(rawValue: "fade")
    public static let moveIn = CATransitionType(rawValue: "moveIn")
    public static let push = CATransitionType(rawValue: "push")
    public static let reveal = CATransitionType(rawValue: "reveal")
}
public struct CATransitionSubtype: RawRepresentable, Hashable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let fromRight = CATransitionSubtype(rawValue: "fromRight")
    public static let fromLeft = CATransitionSubtype(rawValue: "fromLeft")
    public static let fromTop = CATransitionSubtype(rawValue: "fromTop")
    public static let fromBottom = CATransitionSubtype(rawValue: "fromBottom")
}
open class CATransition: CAAnimation {
    open var type: CATransitionType = .fade
    open var subtype: CATransitionSubtype?
    open var startProgress: Float = 0
    open var endProgress: Float = 1
    open override func makeCopy() -> CAAnimation { CATransition() }
    open override func copyProperties(to a: CAAnimation) { (a as? CATransition)?.type = type; (a as? CATransition)?.subtype = subtype }
}

// MARK: transactions

public enum CATransaction {
    final class Frame {
        var disableActions = false
        var duration: CFTimeInterval = 0.25
        var timing: CAMediaTimingFunction?
        var completion: (() -> Void)?
        var latestEnd: CFTimeInterval = 0
        var values: [String: Any] = [:]
    }
    nonisolated(unsafe) static var stack: [Frame] = []
    static var top: Frame? { stack.last }

    public static func begin() { stack.append(Frame()) }
    public static func commit() {
        guard let f = stack.popLast() else { return }
        if let parent = stack.last { parent.latestEnd = max(parent.latestEnd, f.latestEnd) }
        if let c = f.completion {
            let delay = max(0, f.latestEnd - CACurrentMediaTime())
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: c)
        }
    }
    public static func flush() {}
    public static func lock() {}
    public static func unlock() {}
    public static func disableActions() -> Bool { stack.last?.disableActions ?? false }
    public static func setDisableActions(_ v: Bool) { stack.last?.disableActions = v }
    public static func animationDuration() -> CFTimeInterval { stack.last?.duration ?? 0.25 }
    public static func setAnimationDuration(_ d: CFTimeInterval) { stack.last?.duration = d }
    public static func animationTimingFunction() -> CAMediaTimingFunction? { stack.last?.timing }
    public static func setAnimationTimingFunction(_ f: CAMediaTimingFunction?) { stack.last?.timing = f }
    public static func completionBlock() -> (() -> Void)? { stack.last?.completion }
    public static func setCompletionBlock(_ b: (() -> Void)?) {
        if stack.isEmpty { // implicit transaction: complete on the next turn of the run loop
            if let b { DispatchQueue.main.async(execute: b) }
            return
        }
        stack.last?.completion = b
    }
    public static func value(forKey key: String) -> Any? { stack.last?.values[key] }
    public static func setValue(_ v: Any?, forKey key: String) { stack.last?.values[key] = v }
    static func noteAnimation(endingAt t: CFTimeInterval) { for f in stack { f.latestEnd = max(f.latestEnd, t) } }
}

// MARK: display link

open class CADisplayLink: NSObject {
    private let target: AnyObject
    private let selector: Selector
    private var running = false
    open var isPaused = false { didSet { if !isPaused { schedule() } } }
    open var preferredFramesPerSecond = 0
    open var preferredFrameRateRange: CAFrameRateRange = .default
    open var frameInterval = 1
    public private(set) var timestamp: CFTimeInterval = CACurrentMediaTime()
    public private(set) var targetTimestamp: CFTimeInterval = CACurrentMediaTime() + 1.0 / 60.0
    public let duration: CFTimeInterval = 1.0 / 60.0
    private var invalidated = false
    private var added = false

    public init(target: Any, selector sel: Selector) {
        self.target = target as AnyObject
        self.selector = sel
    }
    open func add(to runloop: WebRunLoop, forMode mode: WebRunLoop.Mode) { added = true; schedule() }
    open func remove(from runloop: WebRunLoop, forMode mode: WebRunLoop.Mode) { added = false }
    open func invalidate() { invalidated = true }
    private func schedule() {
        guard added, !invalidated, !isPaused, !running else { return }
        running = true
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            guard let self else { return }
            self.running = false
            guard self.added, !self.invalidated, !self.isPaused else { return }
            self.timestamp = CACurrentMediaTime()
            self.targetTimestamp = self.timestamp + self.duration
            self.selector.perform(on: self.target, with: self)
            self.schedule()
        }
    }
}
