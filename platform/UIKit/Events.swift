// Swiftboard UIKit (MIT): touches, events, gesture recognizers, and delivery of host pointer input.
import Foundation

open class UITouch: NSObject {
    public enum Phase: Int { case began, moved, stationary, ended, cancelled, regionEntered, regionMoved, regionExited }
    public enum TouchType: Int { case direct, indirect, pencil, indirectPointer; public static let stylus = TouchType.pencil }
    public internal(set) var phase: Phase = .began
    public internal(set) var tapCount = 1
    public internal(set) var timestamp: TimeInterval = CACurrentMediaTime()
    public internal(set) weak var view: UIView?
    public internal(set) weak var window: UIWindow?
    public internal(set) var type: TouchType = .direct
    public internal(set) var force: CGFloat = 0
    public internal(set) var maximumPossibleForce: CGFloat = 0
    public internal(set) var majorRadius: CGFloat = 20
    public internal(set) var majorRadiusTolerance: CGFloat = 5
    public internal(set) var gestureRecognizers: [UIGestureRecognizer]?
    var windowLocation: CGPoint = .zero
    var cancelledForView = false
    var previousWindowLocation: CGPoint = .zero
    public override init() {}
    public func location(in view: UIView?) -> CGPoint {
        guard let view else { return windowLocation }
        return view.convert(windowLocation, from: window)
    }
    public func previousLocation(in view: UIView?) -> CGPoint {
        guard let view else { return previousWindowLocation }
        return view.convert(previousWindowLocation, from: window)
    }
    public func preciseLocation(in view: UIView?) -> CGPoint { location(in: view) }
    public func precisePreviousLocation(in view: UIView?) -> CGPoint { previousLocation(in: view) }
}

open class UIEvent: NSObject {
    public enum EventType: Int { case touches, motion, remoteControl, presses, scroll = 10, hover, transform }
    public enum EventSubtype: Int { case none = 0, motionShake = 1, remoteControlPlay = 100, remoteControlPause, remoteControlStop, remoteControlTogglePlayPause, remoteControlNextTrack, remoteControlPreviousTrack }
    public internal(set) var type: EventType = .touches
    public internal(set) var subtype: EventSubtype = .none
    public internal(set) var timestamp: TimeInterval = CACurrentMediaTime()
    public internal(set) var allTouches: Set<UITouch>?
    public struct ButtonMask: OptionSet, Hashable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }
        public static let primary = ButtonMask(rawValue: 1)
        public static let secondary = ButtonMask(rawValue: 2)
        public static func button(_ n: Int) -> ButtonMask { ButtonMask(rawValue: 1 << (n - 1)) }
    }
    public internal(set) var buttonMask: ButtonMask = .primary
    public var modifierFlags: UIKeyModifierFlags { [] }
    public override init() {}
    public func touches(for view: UIView) -> Set<UITouch>? { allTouches?.filter { $0.view.map { $0.isDescendant(of: view) } ?? false } }
    public func touches(for window: UIWindow) -> Set<UITouch>? { allTouches }
    public func touches(for g: UIGestureRecognizer) -> Set<UITouch>? { allTouches }
    public func coalescedTouches(for t: UITouch) -> [UITouch]? { [t] }
    public func predictedTouches(for t: UITouch) -> [UITouch]? { [] }
}

open class UIPress: NSObject {
    public enum PressType: Int { case upArrow, downArrow, leftArrow, rightArrow, select, menu, playPause, pageUp = 30, pageDown = 31 }
    public enum Phase: Int { case began, changed, stationary, ended, cancelled }
    public internal(set) var type: PressType = .select
    public internal(set) var phase: Phase = .began
    public internal(set) var key: UIKey?
    public override init() {}
}
open class UIKey: NSObject {
    public internal(set) var characters = ""
    public internal(set) var charactersIgnoringModifiers = ""
    public internal(set) var modifierFlags: UIKeyModifierFlags = []
    public internal(set) var keyCode: Int = 0
}
open class UIPressesEvent: UIEvent {
    public internal(set) var allPresses: Set<UIPress> = []
}

// MARK: gesture recognizers

public protocol UIGestureRecognizerDelegate: AnyObject {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive press: UIPress) -> Bool
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive event: UIEvent) -> Bool
}
extension UIGestureRecognizerDelegate {
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool { true }
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool { false }
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool { false }
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool { false }
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool { true }
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive press: UIPress) -> Bool { true }
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive event: UIEvent) -> Bool { true }
}

open class UIGestureRecognizer: NSObject {
    public enum State: Int {
        case possible, began, changed, ended, cancelled, failed
        public static let recognized = State.ended
    }
    struct TargetAction { weak var target: AnyObject?; let action: Selector }
    private var targets: [TargetAction] = []
    open var state: State = .possible {
        didSet {
            switch state {
            case .began, .changed, .ended, .cancelled: sendActions()
            default: break
            }
        }
    }
    open weak var delegate: UIGestureRecognizerDelegate?
    open var isEnabled = true { didSet { if !isEnabled && (state == .began || state == .changed) { state = .cancelled } } }
    public internal(set) weak var view: UIView?
    open var cancelsTouchesInView = true
    open var delaysTouchesBegan = false
    open var delaysTouchesEnded = true
    open var requiresExclusiveTouchType = true
    open var allowedTouchTypes: [NSNumber] = []
    open var allowedPressTypes: [NSNumber] = []
    open var name: String?
    var failureRequirements: [UIGestureRecognizer] = []
    var activeTouches: [UITouch] = []

    public init(target: Any?, action: Selector?) {
        super.init()
        if let target, let action { addTarget(target, action: action) }
    }
    public override convenience init() { self.init(target: nil, action: nil) }
    open func addTarget(_ target: Any, action: Selector) { targets.append(TargetAction(target: target as AnyObject, action: action)) }
    open func removeTarget(_ target: Any?, action: Selector?) {
        targets.removeAll { t in (target == nil || t.target === (target as AnyObject)) && (action == nil || t.action == action!) }
    }
    func sendActions() { for t in targets { if let tg = t.target { t.action.perform(on: tg, with: self) } } }
    open func require(toFail other: UIGestureRecognizer) { failureRequirements.append(other) }
    open func location(in view: UIView?) -> CGPoint {
        guard !activeTouches.isEmpty else { return .zero }
        let pts = activeTouches.map { $0.location(in: view) }
        return CGPoint(x: pts.map { $0.x }.reduce(0, +) / CGFloat(pts.count), y: pts.map { $0.y }.reduce(0, +) / CGFloat(pts.count))
    }
    open func location(ofTouch index: Int, in view: UIView?) -> CGPoint { activeTouches.indices.contains(index) ? activeTouches[index].location(in: view) : .zero }
    open var numberOfTouches: Int { activeTouches.count }
    open func reset() {}
    open func ignore(_ touch: UITouch, for event: UIEvent) {}
    open func ignore(_ press: UIPress, for event: UIPressesEvent) {}
    open func canPrevent(_ g: UIGestureRecognizer) -> Bool { true }
    open func canBePrevented(by g: UIGestureRecognizer) -> Bool { true }
    open func shouldRequireFailure(of g: UIGestureRecognizer) -> Bool { false }
    open func shouldBeRequiredToFail(by g: UIGestureRecognizer) -> Bool { false }
    open func shouldReceive(_ event: UIEvent) -> Bool { true }
    open func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {}
    open func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {}
    open func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {}
    open func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {}
    open func touchesEstimatedPropertiesUpdated(_ touches: Set<UITouch>) {}
    open func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent) {}
    open func pressesChanged(_ presses: Set<UIPress>, with event: UIPressesEvent) {}
    open func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent) {}
    open func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent) {}
    open var modifierFlags: UIKeyModifierFlags { [] }
    open var buttonMask: UIEvent.ButtonMask { .primary }
}

open class UITapGestureRecognizer: UIGestureRecognizer {
    open var numberOfTapsRequired = 1
    open var numberOfTouchesRequired = 1
    open var buttonMaskRequired = 1
    private var start: CGPoint = .zero
    open override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) { start = location(in: view) }
    open override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        let p = location(in: view)
        if hypot(p.x - start.x, p.y - start.y) > 10 { state = .failed }
    }
    open override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        if state == .possible, (touches.first?.tapCount ?? 1) >= numberOfTapsRequired { state = .ended }
    }
    open override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) { state = .failed }
}

open class UIPanGestureRecognizer: UIGestureRecognizer {
    open var minimumNumberOfTouches = 1
    open var maximumNumberOfTouches = Int.max
    open var allowedScrollTypesMask: UIScrollTypeMask = []
    private var origin: CGPoint = .zero
    private var offset: CGPoint = .zero
    private var lastPoint: CGPoint = .zero
    private var lastTime: TimeInterval = 0
    private var currentVelocity: CGPoint = .zero
    open func translation(in view: UIView?) -> CGPoint {
        let p = location(in: nil)
        return CGPoint(x: p.x - origin.x + offset.x, y: p.y - origin.y + offset.y)
    }
    open func setTranslation(_ t: CGPoint, in view: UIView?) { origin = location(in: nil); offset = t }
    open func velocity(in view: UIView?) -> CGPoint { currentVelocity }
    open override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        origin = location(in: nil); offset = .zero; lastPoint = origin; lastTime = CACurrentMediaTime(); currentVelocity = .zero
    }
    open override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        let p = location(in: nil), now = CACurrentMediaTime()
        if now > lastTime { currentVelocity = CGPoint(x: (p.x - lastPoint.x) / CGFloat(now - lastTime), y: (p.y - lastPoint.y) / CGFloat(now - lastTime)) }
        lastPoint = p; lastTime = now
        if state == .possible {
            if hypot(p.x - origin.x, p.y - origin.y) > 10 { origin = p; state = .began }
        } else if state == .began || state == .changed { state = .changed }
    }
    open override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        if state == .began || state == .changed { state = .ended } else { state = .failed }
    }
    open override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        if state == .began || state == .changed { state = .cancelled } else { state = .failed }
    }
}
public struct UIScrollTypeMask: OptionSet { public let rawValue: Int; public init(rawValue: Int) { self.rawValue = rawValue }
    public static let discrete = UIScrollTypeMask(rawValue: 1); public static let continuous = UIScrollTypeMask(rawValue: 2); public static let all: UIScrollTypeMask = [.discrete, .continuous] }

open class UIScreenEdgePanGestureRecognizer: UIPanGestureRecognizer {
    open var edges: UIRectEdge = []
}

open class UILongPressGestureRecognizer: UIGestureRecognizer {
    open var minimumPressDuration: TimeInterval = 0.5
    open var allowableMovement: CGFloat = 10
    open var numberOfTapsRequired = 0
    open var numberOfTouchesRequired = 1
    private var start: CGPoint = .zero
    private var generation = 0
    open override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        start = location(in: nil)
        generation += 1
        let g = generation
        DispatchQueue.main.asyncAfter(deadline: .now() + minimumPressDuration) { [weak self] in
            guard let self, self.generation == g, self.state == .possible, !self.activeTouches.isEmpty else { return }
            self.state = .began
        }
    }
    open override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        let p = location(in: nil)
        if state == .possible { if hypot(p.x - start.x, p.y - start.y) > allowableMovement { state = .failed } }
        else if state == .began || state == .changed { state = .changed }
    }
    open override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        generation += 1
        if state == .began || state == .changed { state = .ended } else { state = .failed }
    }
    open override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        generation += 1
        if state == .began || state == .changed { state = .cancelled } else { state = .failed }
    }
}

open class UIPinchGestureRecognizer: UIGestureRecognizer {
    open var scale: CGFloat = 1
    open var velocity: CGFloat { 0 }
}
open class UIRotationGestureRecognizer: UIGestureRecognizer {
    open var rotation: CGFloat = 0
    open var velocity: CGFloat { 0 }
}
open class UISwipeGestureRecognizer: UIGestureRecognizer {
    public struct Direction: OptionSet { public let rawValue: UInt; public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let right = Direction(rawValue: 1); public static let left = Direction(rawValue: 2); public static let up = Direction(rawValue: 4); public static let down = Direction(rawValue: 8) }
    open var direction: Direction = .right
    open var numberOfTouchesRequired = 1
}
open class UIHoverGestureRecognizer: UIGestureRecognizer {}

// MARK: delivery

/// Routes touches to the hit-tested view and the gesture recognizers along its superview chain.
public enum WebEventDispatch {
    nonisolated(unsafe) static var tracked: [Int: (UITouch, [UIGestureRecognizer])] = [:]
    nonisolated(unsafe) public static var debug = false
    static func dispatch(_ event: UIEvent, in window: UIWindow) {
        guard let touches = event.allTouches else { return }
        for t in touches {
            if debug { print("[uikit] touch phase=\(t.phase.rawValue) at \(t.windowLocation) view=\(t.view.map { String(describing: type(of: $0)) } ?? "-") recognizers=\(t.gestureRecognizers?.map { "\(type(of: $0)):\($0.state.rawValue)" } ?? [])") }
            switch t.phase {
            case .began:
                let hit = window.hitTest(t.windowLocation, with: event)
                t.view = hit
                t.window = window
                var recognizers: [UIGestureRecognizer] = []
                var v = hit
                while let c = v {
                    for g in c.recognizers where g.isEnabled && (g.delegate?.gestureRecognizer(g, shouldReceive: t) ?? true) { recognizers.append(g) }
                    v = c.superview
                }
                t.gestureRecognizers = recognizers
                for g in recognizers {
                    if g.state == .failed || g.state == .ended || g.state == .cancelled { g.state = .possible; g.reset() }
                    g.activeTouches.append(t)
                    g.touchesBegan([t], with: event)
                }
                hit?.touchesBegan([t], with: event)
            case .moved:
                for g in t.gestureRecognizers ?? [] where g.state != .failed {
                    let before = g.state
                    g.touchesMoved([t], with: event)
                    if before == .possible && g.state == .began && !(g.delegate?.gestureRecognizerShouldBegin(g) ?? true) { g.state = .failed }
                }
                if (t.gestureRecognizers ?? []).contains(where: { ($0.state == .began || $0.state == .changed) && $0.cancelsTouchesInView }) {
                    // a recognizer took over: the view's touch is cancelled, as in UIKit
                    if !t.cancelledForView { t.cancelledForView = true; t.view?.touchesCancelled([t], with: event) }
                } else if !t.cancelledForView {
                    t.view?.touchesMoved([t], with: event)
                }
            case .ended, .cancelled:
                for g in t.gestureRecognizers ?? [] where g.state != .failed {
                    if t.phase == .ended { g.touchesEnded([t], with: event) } else { g.touchesCancelled([t], with: event) }
                    g.activeTouches.removeAll { $0 === t }
                }
                if t.cancelledForView {
                } else if t.phase == .ended && !(t.gestureRecognizers ?? []).contains(where: { $0.state == .ended && $0.cancelsTouchesInView && !($0 is UITapGestureRecognizer) }) {
                    t.view?.touchesEnded([t], with: event)
                } else { t.view?.touchesCancelled([t], with: event) }
                for g in t.gestureRecognizers ?? [] where g.activeTouches.isEmpty && g.state != .possible {
                    let g2 = g
                    DispatchQueue.main.async { if g2.activeTouches.isEmpty { g2.state = .possible; g2.reset() } }
                }
            default: break
            }
        }
    }

    nonisolated(unsafe) static var touchesById: [Int: UITouch] = [:]
    /// Host input: phase 0 began, 1 moved, 2 ended, 3 cancelled; point in window coordinates.
    public static func pointer(id: Int, phase: Int, x: Double, y: Double, window: UIWindow) {
        let t: UITouch
        if phase == 0 { t = UITouch(); touchesById[id] = t } else if let e = touchesById[id] { t = e } else { return }
        t.previousWindowLocation = phase == 0 ? CGPoint(x: x, y: y) : t.windowLocation
        t.windowLocation = CGPoint(x: x, y: y)
        t.phase = [UITouch.Phase.began, .moved, .ended, .cancelled][max(0, min(3, phase))]
        t.timestamp = CACurrentMediaTime()
        let e = UIEvent()
        e.allTouches = [t]
        window.sendEvent(e)
        if phase >= 2 { touchesById[id] = nil }
    }
}
