// Swiftboard web port: Swift stand-in for Telegram's UIKitRuntimeUtils (an ObjC module of UIKit categories and
// private-API helpers). Same API surface, implemented on the Swiftboard UIKit; category properties live in
// associated objects and setter "swizzles" become WebObservers on the UIKit side.
import Foundation
import UIKit
import AsyncDisplayKit

// MARK: NSBag, NSWeakReference, NotificationCenterUtils

public final class NSBag: NSObject {
    private var next = 0
    private var items: [(Int, Any)] = []
    public override init() {}
    public func addItem(_ item: Any) -> Int { next += 1; items.append((next, item)); return next }
    public func enumerateItems(_ block: (Any) -> Void) { for (_, i) in items { block(i) } }
    public func removeItem(_ key: Int) { items.removeAll { $0.0 == key } }
}
public final class NSWeakReference: NSObject {
    public weak var value: AnyObject?
    public init(value: Any?) { self.value = value as AnyObject? }
}
public typealias NotificationHandlerBlock = (String?, Any?, [AnyHashable: Any]?, (() -> Void)?) -> Bool
public final class NotificationCenterUtils: NSObject {
    nonisolated(unsafe) static var handlers: [NotificationHandlerBlock] = []
    public static func addNotificationHandler(_ handler: @escaping NotificationHandlerBlock) { handlers.append(handler) }
}

// MARK: associated-object helpers

final class Box<T> { var value: T; init(_ v: T) { value = v } }
private func assoc<T>(_ o: AnyObject, _ key: UnsafeRawPointer, _ def: T) -> T { (objc_getAssociatedObject(o, key) as? Box<T>)?.value ?? def }
private func setAssoc<T>(_ o: AnyObject, _ key: UnsafeRawPointer, _ v: T) { objc_setAssociatedObject(o, key, Box(v), .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
nonisolated(unsafe) private var keys = [UInt8](repeating: 0, count: 64)
private func key(_ i: Int) -> UnsafeRawPointer { keys.withUnsafeBufferPointer { UnsafeRawPointer($0.baseAddress! + i) } }

// MARK: UIBarButtonItem (Proxy)

public typealias UIBarButtonItemSetTitleListener = (String?) -> Void
public typealias UIBarButtonItemSetEnabledListener = (Bool) -> Void
extension UIBarButtonItem {
    public var customDisplayNode: ASDisplayNode? { assoc(self, key(0), nil as ASDisplayNode?) }
    public var backButtonAppearance: Bool { assoc(self, key(1), false) }
    public var requiresOwnSection: Bool { get { assoc(self, key(2), false) } set { setAssoc(self, key(2), newValue) } }
    public var staysInRow: Bool { get { assoc(self, key(3), false) } set { setAssoc(self, key(3), newValue) } }
    public convenience init(customDisplayNode: ASDisplayNode) {
        self.init()
        setAssoc(self, key(0), Optional(customDisplayNode))
    }
    public convenience init(backButtonAppearanceWithTitle title: String, target: Any?, action: Selector?) {
        self.init(title: title, style: .plain, target: target, action: action)
        setAssoc(self, key(1), true)
    }
    public func performActionOnTarget() {
        if let custom = assoc(self, key(4), nil as (() -> Void)?) { custom(); return }
        if let a = action, let t = target { a.perform(on: t, with: self) }
    }
    public func setCustomAction(_ action: (() -> Void)?) { setAssoc(self, key(4), action) }
    public func addSetTitleListener(_ l: @escaping UIBarButtonItemSetTitleListener) -> Int {
        webObservers.add { [weak self] p in if p == "title" { l(self?.title) } }
    }
    public func removeSetTitleListener(_ key: Int) { webObservers.remove(key) }
    public func addSetEnabledListener(_ l: @escaping UIBarButtonItemSetEnabledListener) -> Int {
        webObservers.add { [weak self] p in if p == "enabled" { l(self?.isEnabled ?? true) } }
    }
    public func removeSetEnabledListener(_ key: Int) { webObservers.remove(key) }
}

// MARK: UIButton (LegacyAppearance)

extension UIButton {
    public var legacyAdjustsImageWhenHighlighted: Bool { get { adjustsImageWhenHighlighted } set { adjustsImageWhenHighlighted = newValue } }
    public var legacyAdjustsImageWhenDisabled: Bool { get { adjustsImageWhenDisabled } set { adjustsImageWhenDisabled = newValue } }
    public var legacyContentEdgeInsets: UIEdgeInsets { get { contentEdgeInsets } set { contentEdgeInsets = newValue } }
    public var legacyImageEdgeInsets: UIEdgeInsets { get { imageEdgeInsets } set { imageEdgeInsets = newValue } }
}

// MARK: UIKitUtils

public func animationDurationFactorImpl() -> Double { 1 }
public func makeSpringAnimationImpl(_ keyPath: String, _ duration: Double) -> CABasicAnimation {
    let a = CASpringAnimation(keyPath: keyPath)
    a.mass = 3; a.stiffness = 1000; a.damping = 500; a.duration = 0.5
    a.timingFunction = CAMediaTimingFunction(name: .linear)
    return a
}
public func make26SpringAnimationImpl(_ keyPath: String, _ duration: Double) -> CABasicAnimation { makeSpringAnimationImpl(keyPath, duration) }
public func makeSpringBounceAnimationImpl(_ keyPath: String, _ initialVelocity: CGFloat, _ damping: CGFloat) -> CASpringAnimation {
    let a = CASpringAnimation(keyPath: keyPath)
    a.mass = 5; a.stiffness = 900; a.damping = damping; a.initialVelocity = initialVelocity
    a.duration = a.settlingDuration
    return a
}
/// Value of a critically damped spring (CoreAnimation's keyboard curve) at normalized time t.
public func springAnimationValueAtImpl(_ animation: CABasicAnimation, _ t: CGFloat) -> CGFloat {
    let x = Double(t)
    return CGFloat(1 - (1 + 10 * x) * exp(-10 * x))
}
public func makeCustomZoomBlurEffectImpl(_ isLight: Bool) -> UIBlurEffect { UIBlurEffect(style: isLight ? .light : .dark) }
public func applySmoothRoundedCornersImpl(_ layer: CALayer) { layer.cornerCurve = .continuous }

public protocol UIKitPortalViewProtocol: AnyObject {
    var sourceView: UIView? { get set }
    var forwardsClientHitTestingToSourceView: Bool { get set }
    var allowsHitTesting: Bool { get set }
    var allowsBackdropGroups: Bool { get set }
    var matchesPosition: Bool { get set }
    var matchesTransform: Bool { get set }
    var matchesAlpha: Bool { get set }
    var hidesSourceView: Bool { get set }
}
/// Portal views mirror another view's rendering; the painter shows the source layer at the portal's place.
public final class WebPortalView: UIView, UIKitPortalViewProtocol {
    public weak var sourceView: UIView? { didSet { layer.setValue(sourceView?.layer, forKey: "webPortalSource") } }
    public var forwardsClientHitTestingToSourceView = false
    public var allowsHitTesting = false
    public var allowsBackdropGroups = false
    public var matchesPosition = false
    public var matchesTransform = false
    public var matchesAlpha = false
    public var hidesSourceView = false
}
public func makePortalView(_ matchPosition: Bool) -> (UIView & UIKitPortalViewProtocol)? {
    let v = WebPortalView(frame: .zero)
    v.matchesPosition = matchPosition
    return v
}
public func isViewPortalView(_ view: UIView) -> Bool { view is WebPortalView }
public func getPortalViewSourceView(_ portalView: UIView) -> UIView? { (portalView as? WebPortalView)?.sourceView }

/// CAFilter stand-in: a name and KVC inputs (the painter maps known filters onto CSS filters).
public final class WebLayerFilter: NSObject {
    public let name: String
    public init(name: String) { self.name = name }
}
public func makeBlurFilter() -> NSObject? { WebLayerFilter(name: "gaussianBlur") }
public func makeVariableBlurFilter() -> NSObject? { WebLayerFilter(name: "variableBlur") }
public func makeLuminanceToAlphaFilter() -> NSObject? { WebLayerFilter(name: "luminanceToAlpha") }
public func makeColorInvertFilter() -> NSObject? { WebLayerFilter(name: "colorInvert") }
public func makeMonochromeFilter() -> NSObject? { WebLayerFilter(name: "colorMonochrome") }
public func makeDisplacementMapFilter() -> NSObject? { WebLayerFilter(name: "displacementMap") }
public func makeColorMatrixFilter() -> NSObject? { WebLayerFilter(name: "colorMatrix") }
public func setLayerDisableScreenshots(_ layer: CALayer, _ disableScreenshots: Bool) { setAssoc(layer, key(5), disableScreenshots) }
public func getLayerDisableScreenshots(_ layer: CALayer) -> Bool { assoc(layer, key(5), false) }
public func setLayerContentsMaskMode(_ layer: CALayer, _ maskMode: Bool) { layer.setValue(maskMode, forKey: "webContentsMaskMode") }
public func setMonochromaticEffectImpl(_ view: UIView, _ isEnabled: Bool) {}

// MARK: UIMenuItem / UILabel

extension UIMenuItem {
    public convenience init(title: String, icon: UIImage?, action: Selector) { self.init(title: title, action: action) }
}
extension UILabel {
    public static func setDateLabelColor(_ color: UIColor) {}
}

// MARK: UINavigationItem / UITabBarItem (Proxy)

public typealias UINavigationItemSetTitleListener = (String?, Bool) -> Void
public typealias UINavigationItemSetTitleViewListener = (UIView?) -> Void
public typealias UINavigationItemSetImageListener = (UIImage?) -> Void
public typealias UINavigationItemSetBarButtonItemListener = (UIBarButtonItem?, UIBarButtonItem?, Bool) -> Void
public typealias UINavigationItemSetMutipleBarButtonItemsListener = ([UIBarButtonItem]?, Bool) -> Void
public typealias UITabBarItemSetBadgeListener = (String?) -> Void

extension UINavigationItem {
    private var targetItem: UINavigationItem? { assoc(self, key(6), nil as UINavigationItem?) }
    public func setTargetItem(_ item: UINavigationItem?) { setAssoc(self, key(6), item) }
    public func hasTargetItem() -> Bool { targetItem != nil }
    public func setTitle(_ title: String?, animated: Bool) {
        setAssoc(self, key(7), animated)
        self.title = title
        setAssoc(self, key(7), false)
    }
    private var lastAnimated: Bool { assoc(self, key(7), false) }
    public func addSetTitleListener(_ l: @escaping UINavigationItemSetTitleListener) -> Int {
        webObservers.add { [weak self] p in if p == "title", let s = self { l(s.title, s.lastAnimated) } }
    }
    public func removeSetTitleListener(_ key: Int) { webObservers.remove(key) }
    public func addSetTitleViewListener(_ l: @escaping UINavigationItemSetTitleViewListener) -> Int {
        webObservers.add { [weak self] p in if p == "titleView" { l(self?.titleView) } }
    }
    public func removeSetTitleViewListener(_ key: Int) { webObservers.remove(key) }
    public func addSetLeftBarButtonItemListener(_ l: @escaping UINavigationItemSetBarButtonItemListener) -> Int {
        var previous = leftBarButtonItem
        return webObservers.add { [weak self] p in if p == "leftBarButtonItems" { let cur = self?.leftBarButtonItem; l(previous, cur, false); previous = cur } }
    }
    public func removeSetLeftBarButtonItemListener(_ key: Int) { webObservers.remove(key) }
    public func addSetRightBarButtonItemListener(_ l: @escaping UINavigationItemSetBarButtonItemListener) -> Int {
        var previous = rightBarButtonItem
        return webObservers.add { [weak self] p in if p == "rightBarButtonItems" { let cur = self?.rightBarButtonItem; l(previous, cur, false); previous = cur } }
    }
    public func removeSetRightBarButtonItemListener(_ key: Int) { webObservers.remove(key) }
    public func addSetMultipleRightBarButtonItemsListener(_ l: @escaping UINavigationItemSetMutipleBarButtonItemsListener) -> Int {
        webObservers.add { [weak self] p in if p == "rightBarButtonItems" { l(self?.rightBarButtonItems, false) } }
    }
    public func removeSetMultipleRightBarButtonItemsListener(_ key: Int) { webObservers.remove(key) }
    public func addSetBackBarButtonItemListener(_ l: @escaping UINavigationItemSetBarButtonItemListener) -> Int {
        var previous = backBarButtonItem
        return webObservers.add { [weak self] p in if p == "backBarButtonItem" { let cur = self?.backBarButtonItem; l(previous, cur, false); previous = cur } }
    }
    public func removeSetBackBarButtonItemListener(_ key: Int) { webObservers.remove(key) }
    public func addSetBadgeListener(_ l: @escaping UITabBarItemSetBadgeListener) -> Int {
        webObservers.add { [weak self] p in if p == "badge" { l(self?.badge) } }
    }
    public func removeSetBadgeListener(_ key: Int) { webObservers.remove(key) }
    public var badge: String? {
        get { assoc(self, key(8), nil as String?) }
        set { setAssoc(self, key(8), newValue); webObservers.notify("badge") }
    }
}

public func UITabBarItem_addSetBadgeListener(_ item: UITabBarItem, _ listener: @escaping UITabBarItemSetBadgeListener) -> Int {
    item.webObservers.add { [weak item] p in if p == "badgeValue" { listener(item?.badgeValue) } }
}
extension UITabBarItem {
    public func removeSetBadgeListener(_ key: Int) { webObservers.remove(key) }
    public func addSetTitleListener(_ l: @escaping UINavigationItemSetTitleListener) -> Int {
        webObservers.add { [weak self] p in if p == "title" { l(self?.title, false) } }
    }
    public func removeSetTitleListener(_ key: Int) { webObservers.remove(key) }
    public func addSetImageListener(_ l: @escaping UINavigationItemSetImageListener) -> Int {
        webObservers.add { [weak self] p in if p == "image" { l(self?.image) } }
    }
    public func removeSetImageListener(_ key: Int) { webObservers.remove(key) }
    public func addSetSelectedImageListener(_ l: @escaping UINavigationItemSetImageListener) -> Int {
        webObservers.add { [weak self] p in if p == "selectedImage" { l(self?.selectedImage) } }
    }
    public func removeSetSelectedImageListener(_ key: Int) { webObservers.remove(key) }
    public var animationName: String? { get { assoc(self, key(9), nil as String?) } set { setAssoc(self, key(9), newValue) } }
    public var animationOffset: CGPoint { get { assoc(self, key(10), CGPoint.zero) } set { setAssoc(self, key(10), newValue) } }
    public var animationScale: CGFloat { get { assoc(self, key(11), 1 as CGFloat) } set { setAssoc(self, key(11), newValue) } }
    public var ringSelection: Bool { get { assoc(self, key(12), false) } set { setAssoc(self, key(12), newValue) } }
}

// MARK: UIViewController / UIApplication (Navigation)

public struct UIResponderDisableAutomaticKeyboardHandling: OptionSet {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let forward = UIResponderDisableAutomaticKeyboardHandling(rawValue: 1 << 0)
    public static let backward = UIResponderDisableAutomaticKeyboardHandling(rawValue: 1 << 1)
}
extension UIViewController {
    public func setHintWillBePresentedInPreviewingContext(_ value: Bool) { setAssoc(self, key(13), value) }
    public func isPresentedInPreviewingContext() -> Bool { assoc(self, key(13), false) }
    public func setIgnoreAppearanceMethodInvocations(_ v: Bool) { setAssoc(self, key(14), v) }
    public func ignoreAppearanceMethodInvocations() -> Bool { assoc(self, key(14), false) }
    public func navigation_setNavigationController(_ c: UINavigationController?) { setAssoc(self, key(15), c) }
    public func navigation_setPresentingViewController(_ c: UIViewController?) { webSetPresenting(c) }
    public func navigation_setDismiss(_ dismiss: (() -> Void)?, rootController: UIViewController?) { setAssoc(self, key(16), dismiss) }
    public func state_setNeedsStatusBarAppearanceUpdate(_ block: (() -> Void)?) { setAssoc(self, key(17), block) }
}
extension UIApplication {
    public func internalSetStatusBarStyle(_ style: UIStatusBarStyle, animated: Bool) { statusBarStyle = style }
    public func internalSetStatusBarHidden(_ hidden: Bool, animation: UIStatusBarAnimation) { isStatusBarHidden = hidden }
    public func internalGetKeyboard() -> UIWindow? { nil }
    public func internalGetKeyboard(forScene scene: UIWindowScene?) -> UIWindow? { nil }
}

// MARK: spring overrides

open class CALayerSpringParametersOverrideParameters: NSObject {
    public override init() {}
}
public final class CALayerSpringParametersOverrideParametersSpring: CALayerSpringParametersOverrideParameters {
    public let stiffness: CGFloat, damping: CGFloat, duration: Double
    public init(stiffness: CGFloat, damping: CGFloat, duration: Double) { self.stiffness = stiffness; self.damping = damping; self.duration = duration }
}
public final class CALayerSpringParametersOverrideParametersCustomCurve: CALayerSpringParametersOverrideParameters {
    public let cp1: CGPoint, cp2: CGPoint
    public init(cp1: CGPoint, cp2: CGPoint) { self.cp1 = cp1; self.cp2 = cp2 }
}
public final class CALayerSpringParametersOverride: NSObject {
    public let parameters: CALayerSpringParametersOverrideParameters?
    public init(parameters: CALayerSpringParametersOverrideParameters?) { self.parameters = parameters }
}
nonisolated(unsafe) private var springOverrides: [CALayerSpringParametersOverride] = []
extension CALayer {
    public static func push(_ o: CALayerSpringParametersOverride) { springOverrides.append(o) }
    public static func pushSpringParametersOverride(_ o: CALayerSpringParametersOverride) { springOverrides.append(o) }
    public static func popSpringParametersOverride() { _ = springOverrides.popLast() }
}

// MARK: UIView (Navigation)

extension UIView {
    public var disablesInteractiveTransitionGestureRecognizer: Bool { get { assoc(self, key(18), false) } set { setAssoc(self, key(18), newValue) } }
    public var disablesInteractiveKeyboardGestureRecognizer: Bool { get { assoc(self, key(19), false) } set { setAssoc(self, key(19), newValue) } }
    public var disablesInteractiveModalDismiss: Bool { get { assoc(self, key(20), false) } set { setAssoc(self, key(20), newValue) } }
    public var disablesInteractiveTransitionGestureRecognizerNow: (() -> Bool)? { get { assoc(self, key(21), nil as (() -> Bool)?) } set { setAssoc(self, key(21), newValue) } }
    public var disableAutomaticKeyboardHandling: UIResponderDisableAutomaticKeyboardHandling { get { assoc(self, key(22), []) } set { setAssoc(self, key(22), newValue) } }
    public var interactiveTransitionGestureRecognizerTest: ((CGPoint) -> Bool)? { get { assoc(self, key(23), nil as ((CGPoint) -> Bool)?) } set { setAssoc(self, key(23), newValue) } }
    public func input_setInputAccessoryHeightProvider(_ block: (() -> CGFloat)?) { setAssoc(self, key(24), block) }
    public func input_getInputAccessoryHeight() -> CGFloat { assoc(self, key(24), nil as (() -> CGFloat)?)?() ?? 0 }
}

public func applyKeyboardAutocorrection(_ textView: UITextView) {}

open class AboveStatusBarWindow: UIWindow {
    open var supportedOrientations: (() -> UIInterfaceOrientationMask)?
}
extension UIScrollView {
    public func fixScrollDisplayLink() {}
}
public func snapshotViewByDrawingInContext(_ view: UIView) {}

open class EffectSettingsContainerView: UIView {
    open var lumaMin: Double = 0
    open var lumaMax: Double = 0
    open var glassBlurRadius: Double = 0
    public static func applyGlassBlurRadius(_ radius: Double, toLayerTree layer: CALayer, depth: Int32) {}
    nonisolated(unsafe) public static var morphGlassBlurRadius: Double = 0
}
public final class WebHelpers: NSObject {
    public static func addTrustedDomain(_ domain: String) -> () -> Void { {} }
}

// MARK: UIWindow (OrientationChange)

extension UIWindow {
    public func isRotating() -> Bool { false }
    public static func addPostDeviceOrientationDidChange(_ block: @escaping () -> Void) {}
    public static func isDeviceRotating() -> Bool { false }
}
