// Swiftboard UIKit (MIT): UIResponder, UIView, UIWindow, view animations.
import Foundation

public struct UIAccessibilityTraits: OptionSet, Hashable {
    public let rawValue: UInt64
    public init(rawValue: UInt64) { self.rawValue = rawValue }
    public static let none = UIAccessibilityTraits([])
    public static let button = UIAccessibilityTraits(rawValue: 1 << 0)
    public static let link = UIAccessibilityTraits(rawValue: 1 << 1)
    public static let image = UIAccessibilityTraits(rawValue: 1 << 2)
    public static let selected = UIAccessibilityTraits(rawValue: 1 << 3)
    public static let playsSound = UIAccessibilityTraits(rawValue: 1 << 4)
    public static let keyboardKey = UIAccessibilityTraits(rawValue: 1 << 5)
    public static let staticText = UIAccessibilityTraits(rawValue: 1 << 6)
    public static let summaryElement = UIAccessibilityTraits(rawValue: 1 << 7)
    public static let notEnabled = UIAccessibilityTraits(rawValue: 1 << 8)
    public static let updatesFrequently = UIAccessibilityTraits(rawValue: 1 << 9)
    public static let searchField = UIAccessibilityTraits(rawValue: 1 << 10)
    public static let startsMediaSession = UIAccessibilityTraits(rawValue: 1 << 11)
    public static let adjustable = UIAccessibilityTraits(rawValue: 1 << 12)
    public static let allowsDirectInteraction = UIAccessibilityTraits(rawValue: 1 << 13)
    public static let causesPageTurn = UIAccessibilityTraits(rawValue: 1 << 14)
    public static let header = UIAccessibilityTraits(rawValue: 1 << 16)
    public static let tabBar = UIAccessibilityTraits(rawValue: 1 << 28)
    public static let toggleButton = UIAccessibilityTraits(rawValue: 1 << 53)
    public static let supportsZoom = UIAccessibilityTraits(rawValue: 1 << 54)
}
extension UIView: WebAccessibilityFrameProviding {
    public var webDefaultAccessibilityFrame: CGRect { convert(bounds, to: nil) }
}
public enum UIAccessibilityScrollDirection: Int { case right = 1, left, up, down, next, previous }
public enum UIAccessibilityNavigationStyle: Int { case automatic, separate, combined }
public enum UIAccessibilityContainerType: Int { case none, dataTable, list, landmark, semanticGroup }

open class UIAccessibilityCustomAction: NSObject {
    public var name: String
    public var attributedName: NSAttributedString?
    public var image: UIImage?
    public weak var target: AnyObject?
    public var selector: Selector?
    public var actionHandler: ((UIAccessibilityCustomAction) -> Bool)?
    public init(name: String, target: Any?, selector: Selector) { self.name = name; self.target = target as AnyObject?; self.selector = selector }
    public init(name: String, actionHandler: ((UIAccessibilityCustomAction) -> Bool)?) { self.name = name; self.actionHandler = actionHandler }
    public init(attributedName: NSAttributedString, actionHandler: ((UIAccessibilityCustomAction) -> Bool)?) { name = attributedName.string; self.attributedName = attributedName; self.actionHandler = actionHandler }
    public init(name: String, image: UIImage?, actionHandler: ((UIAccessibilityCustomAction) -> Bool)?) { self.name = name; self.image = image; self.actionHandler = actionHandler }
}
open class UIAccessibilityCustomRotor: NSObject {
    public var name: String
    public init(name: String, itemSearch: @escaping (AnyObject) -> AnyObject?) { self.name = name }
}

// MARK: responder

open class UIResponder: NSObject {
    public override init() { super.init() }
    open var next: UIResponder? { nil }
    open var canBecomeFirstResponder: Bool { false }
    open var canResignFirstResponder: Bool { true }
    open var isFirstResponder: Bool { UIResponder.webFirstResponder === self }
    nonisolated(unsafe) static weak var webFirstResponder: UIResponder?
    @discardableResult open func becomeFirstResponder() -> Bool {
        guard canBecomeFirstResponder else { return false }
        UIResponder.webFirstResponder?.resignFirstResponder()
        UIResponder.webFirstResponder = self
        return true
    }
    @discardableResult open func resignFirstResponder() -> Bool {
        if UIResponder.webFirstResponder === self { UIResponder.webFirstResponder = nil }
        return true
    }
    open func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) { next?.touchesBegan(touches, with: event) }
    open func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) { next?.touchesMoved(touches, with: event) }
    open func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { next?.touchesEnded(touches, with: event) }
    open func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { next?.touchesCancelled(touches, with: event) }
    open func touchesEstimatedPropertiesUpdated(_ touches: Set<UITouch>) {}
    open func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) { next?.pressesBegan(presses, with: event) }
    open func pressesChanged(_ presses: Set<UIPress>, with event: UIPressesEvent?) {}
    open func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) { next?.pressesEnded(presses, with: event) }
    open func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {}
    open func motionBegan(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {}
    open func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {}
    open func motionCancelled(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {}
    open func remoteControlReceived(with event: UIEvent?) {}
    open func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool { false }
    open func target(forAction action: Selector, withSender sender: Any?) -> Any? {
        canPerformAction(action, withSender: sender) ? self : next?.target(forAction: action, withSender: sender)
    }
    open var keyCommands: [UIKeyCommand]? { nil }
    open var inputView: UIView? { nil }
    open var inputAccessoryView: UIView? { nil }
    open var inputViewController: UIViewController? { nil }
    open var inputAccessoryViewController: UIViewController? { nil }
    open var textInputMode: UITextInputMode? { nil }
    open var textInputContextIdentifier: String? { nil }
    open var undoManager: AnyObject? { nil }
    open func reloadInputViews() {}
    open var editingInteractionConfiguration: Int { 0 }
    open func buildMenu(with builder: AnyObject) {}
    open func validate(_ command: AnyObject) {}
    open func _trap() {}

    // accessibility (UIAccessibility informal protocol)
    open var isAccessibilityElement = false
    open var accessibilityLabel: String?
    open var accessibilityAttributedLabel: NSAttributedString?
    open var accessibilityHint: String?
    open var accessibilityAttributedHint: NSAttributedString?
    open var accessibilityValue: String?
    open var accessibilityAttributedValue: NSAttributedString?
    open var accessibilityTraits: UIAccessibilityTraits = []
    open var accessibilityPath: UIBezierPath?
    open var accessibilityActivationPoint: CGPoint = .zero
    open var accessibilityLanguage: String?
    open var accessibilityElementsHidden = false
    open var accessibilityViewIsModal = false
    open var shouldGroupAccessibilityChildren = false
    open var accessibilityNavigationStyle: UIAccessibilityNavigationStyle = .automatic
    open var accessibilityRespondsToUserInteraction = true
    open var accessibilityUserInputLabels: [String]?
    open var accessibilityIdentifier: String?
    open var accessibilityElements: [Any]?
    open var accessibilityCustomActions: [UIAccessibilityCustomAction]?
    open var accessibilityCustomRotors: [UIAccessibilityCustomRotor]?
    open var accessibilityContainerType: UIAccessibilityContainerType = .none
    open weak var accessibilityContainer: AnyObject?
    open var accessibilityHeaderElements: [Any]?
    open func accessibilityActivate() -> Bool { false }
    open func accessibilityIncrement() {}
    open func accessibilityDecrement() {}
    open func accessibilityScroll(_ direction: UIAccessibilityScrollDirection) -> Bool { false }
    open func accessibilityPerformEscape() -> Bool { false }
    open func accessibilityPerformMagicTap() -> Bool { false }
    open func accessibilityElementDidBecomeFocused() {}
    open func accessibilityElementDidLoseFocus() {}
    open func accessibilityElementIsFocused() -> Bool { false }
    open func accessibilityElementCount() -> Int { accessibilityElements?.count ?? 0 }
    open func accessibilityElement(at index: Int) -> Any? { accessibilityElements?[index] }
    open func index(ofAccessibilityElement element: Any) -> Int { accessibilityElements?.firstIndex { ($0 as AnyObject) === (element as AnyObject) } ?? NSNotFound }

    public static let keyboardWillShowNotification = Notification.Name("UIKeyboardWillShowNotification")
    public static let keyboardDidShowNotification = Notification.Name("UIKeyboardDidShowNotification")
    public static let keyboardWillHideNotification = Notification.Name("UIKeyboardWillHideNotification")
    public static let keyboardDidHideNotification = Notification.Name("UIKeyboardDidHideNotification")
    public static let keyboardWillChangeFrameNotification = Notification.Name("UIKeyboardWillChangeFrameNotification")
    public static let keyboardDidChangeFrameNotification = Notification.Name("UIKeyboardDidChangeFrameNotification")
    public static let keyboardFrameBeginUserInfoKey = "UIKeyboardFrameBeginUserInfoKey"
    public static let keyboardFrameEndUserInfoKey = "UIKeyboardFrameEndUserInfoKey"
    public static let keyboardAnimationDurationUserInfoKey = "UIKeyboardAnimationDurationUserInfoKey"
    public static let keyboardAnimationCurveUserInfoKey = "UIKeyboardAnimationCurveUserInfoKey"
    public static let keyboardIsLocalUserInfoKey = "UIKeyboardIsLocalUserInfoKey"
}

// MARK: view

open class UIView: UIResponder, CALayerDelegate, UITraitEnvironment, UICoordinateSpace {
    public enum ContentMode: Int { case scaleToFill, scaleAspectFit, scaleAspectFill, redraw, center, top, bottom, left, right, topLeft, topRight, bottomLeft, bottomRight }
    public enum TintAdjustmentMode: Int { case automatic, normal, dimmed }
    public enum AnimationCurve: Int { case easeInOut, easeIn, easeOut, linear }
    public enum AnimationTransition: Int { case none, flipFromLeft, flipFromRight, curlUp, curlDown }
    public struct AutoresizingMask: OptionSet, Hashable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let flexibleLeftMargin = AutoresizingMask(rawValue: 1)
        public static let flexibleWidth = AutoresizingMask(rawValue: 2)
        public static let flexibleRightMargin = AutoresizingMask(rawValue: 4)
        public static let flexibleTopMargin = AutoresizingMask(rawValue: 8)
        public static let flexibleHeight = AutoresizingMask(rawValue: 16)
        public static let flexibleBottomMargin = AutoresizingMask(rawValue: 32)
    }
    public struct AnimationOptions: OptionSet, Hashable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let layoutSubviews = AnimationOptions(rawValue: 1 << 0)
        public static let allowUserInteraction = AnimationOptions(rawValue: 1 << 1)
        public static let beginFromCurrentState = AnimationOptions(rawValue: 1 << 2)
        public static let `repeat` = AnimationOptions(rawValue: 1 << 3)
        public static let autoreverse = AnimationOptions(rawValue: 1 << 4)
        public static let overrideInheritedDuration = AnimationOptions(rawValue: 1 << 5)
        public static let overrideInheritedCurve = AnimationOptions(rawValue: 1 << 6)
        public static let allowAnimatedContent = AnimationOptions(rawValue: 1 << 7)
        public static let showHideTransitionViews = AnimationOptions(rawValue: 1 << 8)
        public static let overrideInheritedOptions = AnimationOptions(rawValue: 1 << 9)
        public static let curveEaseInOut = AnimationOptions(rawValue: 0 << 16)
        public static let curveEaseIn = AnimationOptions(rawValue: 1 << 16)
        public static let curveEaseOut = AnimationOptions(rawValue: 2 << 16)
        public static let curveLinear = AnimationOptions(rawValue: 3 << 16)
        public static let transitionNone = AnimationOptions(rawValue: 0 << 20)
        public static let transitionFlipFromLeft = AnimationOptions(rawValue: 1 << 20)
        public static let transitionFlipFromRight = AnimationOptions(rawValue: 2 << 20)
        public static let transitionCurlUp = AnimationOptions(rawValue: 3 << 20)
        public static let transitionCurlDown = AnimationOptions(rawValue: 4 << 20)
        public static let transitionCrossDissolve = AnimationOptions(rawValue: 5 << 20)
        public static let transitionFlipFromTop = AnimationOptions(rawValue: 6 << 20)
        public static let transitionFlipFromBottom = AnimationOptions(rawValue: 7 << 20)
        public static let preferredFramesPerSecond60 = AnimationOptions(rawValue: 3 << 24)
    }
    public struct KeyframeAnimationOptions: OptionSet, Hashable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let layoutSubviews = KeyframeAnimationOptions(rawValue: 1 << 0)
        public static let allowUserInteraction = KeyframeAnimationOptions(rawValue: 1 << 1)
        public static let beginFromCurrentState = KeyframeAnimationOptions(rawValue: 1 << 2)
        public static let calculationModeLinear = KeyframeAnimationOptions(rawValue: 0 << 10)
        public static let calculationModeCubic = KeyframeAnimationOptions(rawValue: 3 << 10)
    }
    public enum SystemAnimation: UInt { case delete }

    open class var layerClass: AnyClass { CALayer.self }
    public let layer: CALayer
    public private(set) var subviews: [UIView] = []
    public private(set) weak var superview: UIView?
    open var tag = 0
    open var isUserInteractionEnabled = true
    open var isMultipleTouchEnabled = false
    open var isExclusiveTouch = false
    open var autoresizesSubviews = true
    open var autoresizingMask: AutoresizingMask = []
    open var contentMode: ContentMode = .scaleToFill { didSet { layer.contentsGravity = UIView.gravity(for: contentMode) } }
    open var clearsContextBeforeDrawing = true
    open var tintAdjustmentMode: TintAdjustmentMode = .automatic
    open var semanticContentAttribute: UISemanticContentAttribute = .unspecified
    open var translatesAutoresizingMaskIntoConstraints = true
    open var insetsLayoutMarginsFromSafeArea = true
    open var preservesSuperviewLayoutMargins = false
    open var layoutMargins = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
    open var directionalLayoutMargins = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
    open var overrideUserInterfaceStyle: UIUserInterfaceStyle = .unspecified
    open var focusGroupIdentifier: String?
    open var accessibilityIgnoresInvertColors = false
    open var interactions: [UIInteraction] = []
    open var gestureRecognizers: [UIGestureRecognizer]? {
        get { recognizers.isEmpty ? nil : recognizers }
        set { recognizers.forEach { $0.view = nil }; recognizers = []; newValue?.forEach { addGestureRecognizer($0) } }
    }
    var recognizers: [UIGestureRecognizer] = []
    private var _tintColor: UIColor?
    private var _mask: UIView?
    var webSafeAreaInsets: UIEdgeInsets = .zero

    static func gravity(for m: ContentMode) -> CALayerContentsGravity {
        switch m {
        case .scaleToFill, .redraw: return .resize
        case .scaleAspectFit: return .resizeAspect
        case .scaleAspectFill: return .resizeAspectFill
        case .center: return .center
        case .top: return .top
        case .bottom: return .bottom
        case .left: return .left
        case .right: return .right
        case .topLeft: return .bottomLeft
        case .topRight: return .bottomRight
        case .bottomLeft: return .topLeft
        case .bottomRight: return .topRight
        }
    }

    public init(frame: CGRect) {
        layer = UIView.makeLayer(type(of: self).layerClass)
        super.init()
        layer.delegate = self
        layer.contentsScale = UIScreen.main.scale
        self.frame = frame
        layer.setNeedsDisplay()
    }
    public required init?(coder: NSCoder) {
        layer = UIView.makeLayer(type(of: self).layerClass)
        super.init()
        layer.delegate = self
    }
    public override convenience init() { self.init(frame: .zero) }

    static func makeLayer(_ cls: AnyClass) -> CALayer {
        if let t = cls as? CALayer.Type { return t.webMakeLayer() }
        return CALayer()
    }

    // MARK: geometry
    open var frame: CGRect {
        get { layer.frame }
        set {
            let old = layer.bounds.size
            layer.frame = newValue
            if old != newValue.size { boundsSizeChanged(from: old) }
        }
    }
    open var bounds: CGRect {
        get { layer.bounds }
        set {
            let old = layer.bounds.size
            layer.bounds = newValue
            if old != newValue.size { boundsSizeChanged(from: old) }
        }
    }
    open var center: CGPoint {
        get { layer.position }
        set { layer.position = newValue }
    }
    open var transform: CGAffineTransform {
        get { CATransform3DGetAffineTransform(layer.transform) }
        set { layer.transform = CATransform3DMakeAffineTransform(newValue) }
    }
    open var transform3D: CATransform3D {
        get { layer.transform }
        set { layer.transform = newValue }
    }
    open var anchorPoint: CGPoint {
        get { layer.anchorPoint }
        set { layer.anchorPoint = newValue }
    }
    open var alpha: CGFloat {
        get { CGFloat(layer.opacity) }
        set { layer.opacity = Float(newValue) }
    }
    open var isHidden: Bool {
        get { layer.isHidden }
        set { layer.isHidden = newValue }
    }
    open var isOpaque: Bool {
        get { layer.isOpaque }
        set { layer.isOpaque = newValue }
    }
    open var clipsToBounds: Bool {
        get { layer.masksToBounds }
        set { layer.masksToBounds = newValue }
    }
    open var backgroundColor: UIColor? {
        get { layer.backgroundColor.map { UIColor(cgColor: $0) } }
        set { layer.backgroundColor = newValue?.cgColor }
    }
    open var contentScaleFactor: CGFloat {
        get { layer.contentsScale }
        set { layer.contentsScale = newValue }
    }
    open var tintColor: UIColor! {
        get { _tintColor ?? superview?.tintColor ?? UIColor.systemBlue }
        set { _tintColor = newValue; tintColorDidChange() }
    }
    open func tintColorDidChange() {}
    open var mask: UIView? {
        get { _mask }
        set { _mask = newValue; layer.mask = newValue?.layer }
    }
    open var safeAreaInsets: UIEdgeInsets { webSafeAreaInsets }
    open var safeAreaLayoutGuide: UILayoutGuide { UILayoutGuide(owner: self) }
    open var layoutMarginsGuide: UILayoutGuide { UILayoutGuide(owner: self) }
    open func safeAreaInsetsDidChange() {}
    open func layoutMarginsDidChange() {}
    open var intrinsicContentSize: CGSize { CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric) }
    public static let noIntrinsicMetric: CGFloat = -1
    public static let layoutFittingCompressedSize = CGSize.zero
    public static let layoutFittingExpandedSize = CGSize(width: 10000, height: 10000)
    open func invalidateIntrinsicContentSize() {}
    open func sizeThatFits(_ size: CGSize) -> CGSize { bounds.size }
    open func sizeToFit() { frame.size = sizeThatFits(bounds.size) }
    open func systemLayoutSizeFitting(_ s: CGSize) -> CGSize { sizeThatFits(s) }

    private func boundsSizeChanged(from old: CGSize) {
        setNeedsLayout()
        if contentMode == .redraw { setNeedsDisplay() }
        guard autoresizesSubviews else { return }
        let dw = bounds.width - old.width, dh = bounds.height - old.height
        for v in subviews where !v.autoresizingMask.isEmpty {
            var f = v.frame
            let m = v.autoresizingMask
            if m.contains(.flexibleWidth) { f.size.width += dw } else if m.contains(.flexibleLeftMargin) && !m.contains(.flexibleRightMargin) { f.origin.x += dw }
            else if m.contains(.flexibleLeftMargin) && m.contains(.flexibleRightMargin) { f.origin.x += dw / 2 }
            if m.contains(.flexibleHeight) { f.size.height += dh } else if m.contains(.flexibleTopMargin) && !m.contains(.flexibleBottomMargin) { f.origin.y += dh }
            else if m.contains(.flexibleTopMargin) && m.contains(.flexibleBottomMargin) { f.origin.y += dh / 2 }
            v.frame = f
        }
    }

    // MARK: hierarchy
    open var window: UIWindow? {
        var v: UIView? = self
        while let c = v { if let w = c as? UIWindow { return w }; v = c.superview }
        return nil
    }
    open override var next: UIResponder? { webViewController ?? superview }
    weak var webViewController: UIViewController?

    open func addSubview(_ view: UIView) { insertSubview(view, at: subviews.count) }
    open func insertSubview(_ view: UIView, at index: Int) {
        if view === self { return }
        let oldWindow = view.window
        let newWindow = window
        if view.superview !== self {
            view.willMove(toSuperview: self)
            if oldWindow !== newWindow { view.webWillMove(toWindow: newWindow) }
            view.removeFromSuperviewSilently()
        } else if let cur = subviews.firstIndex(where: { $0 === view }) {
            subviews.remove(at: cur)
        }
        let i = max(0, min(index, subviews.count))
        // place the layer before the layer of the view that will follow it (other sublayers keep their order)
        if i < subviews.count {
            layer.insertSublayer(view.layer, below: subviews[i].layer)
        } else if let last = subviews.last, last.layer.superlayer === layer {
            layer.insertSublayer(view.layer, above: last.layer)
        } else {
            layer.addSublayer(view.layer)
        }
        subviews.insert(view, at: i)
        let moved = view.superview !== self
        view.superview = self
        if moved {
            didAddSubview(view)
            view.didMoveToSuperview()
            if oldWindow !== newWindow { view.webDidMove(toWindow: newWindow) }
        }
        setNeedsLayout()
    }
    open func insertSubview(_ view: UIView, belowSubview sibling: UIView) {
        guard let i = subviews.firstIndex(where: { $0 === sibling }) else { addSubview(view); return }
        let adj = (view.superview === self && (subviews.firstIndex { $0 === view } ?? Int.max) < i) ? i - 1 : i
        insertSubview(view, at: adj)
    }
    open func insertSubview(_ view: UIView, aboveSubview sibling: UIView) {
        guard let i = subviews.firstIndex(where: { $0 === sibling }) else { addSubview(view); return }
        let adj = (view.superview === self && (subviews.firstIndex { $0 === view } ?? Int.max) < i) ? i : i + 1
        insertSubview(view, at: adj)
    }
    open func bringSubviewToFront(_ view: UIView) { if view.superview === self { insertSubview(view, at: subviews.count) } }
    open func sendSubviewToBack(_ view: UIView) { if view.superview === self { insertSubview(view, at: 0) } }
    open func exchangeSubview(at a: Int, withSubviewAt b: Int) {
        guard a != b, subviews.indices.contains(a), subviews.indices.contains(b) else { return }
        let va = subviews[a], vb = subviews[b]
        insertSubview(va, at: b); insertSubview(vb, at: a)
    }
    func removeFromSuperviewSilently() {
        guard let s = superview else { return }
        s.willRemoveSubview(self)
        s.subviews.removeAll { $0 === self }
        layer.removeFromSuperlayer()
        superview = nil
    }
    open func removeFromSuperview() {
        guard superview != nil else { return }
        let oldWindow = window
        willMove(toSuperview: nil)
        if oldWindow != nil { webWillMove(toWindow: nil) }
        removeFromSuperviewSilently()
        didMoveToSuperview()
        if oldWindow != nil { webDidMove(toWindow: nil) }
    }
    func webWillMove(toWindow w: UIWindow?) { willMove(toWindow: w); for s in subviews { s.webWillMove(toWindow: w) } }
    func webDidMove(toWindow w: UIWindow?) { didMoveToWindow(); for s in subviews { s.webDidMove(toWindow: w) } }
    open func isDescendant(of view: UIView) -> Bool {
        var v: UIView? = self
        while let c = v { if c === view { return true }; v = c.superview }
        return false
    }
    open func viewWithTag(_ tag: Int) -> UIView? {
        if self.tag == tag { return self }
        for s in subviews { if let v = s.viewWithTag(tag) { return v } }
        return nil
    }
    open func didAddSubview(_ subview: UIView) {}
    open func willRemoveSubview(_ subview: UIView) {}
    open func willMove(toSuperview newSuperview: UIView?) {}
    open func didMoveToSuperview() {}
    open func willMove(toWindow newWindow: UIWindow?) {}
    open func didMoveToWindow() {}

    // MARK: layout & display
    open func setNeedsLayout() { layer.setNeedsLayout() }
    open func layoutIfNeeded() { layer.layoutIfNeeded() }
    open func layoutSubviews() {}
    open func setNeedsDisplay() { layer.setNeedsDisplay() }
    open func setNeedsDisplay(_ r: CGRect) { layer.setNeedsDisplay() }
    open func draw(_ rect: CGRect) {}
    open func setNeedsUpdateConstraints() {}
    open func updateConstraintsIfNeeded() {}
    open func updateConstraints() {}

    // CALayerDelegate
    open func layoutSublayers(of layer: CALayer) { if layer === self.layer { layoutSubviews() } }
    open func draw(_ layer: CALayer, in ctx: CGContext) {
        UIGraphicsPushContext(ctx)
        draw(bounds)
        UIGraphicsPopContext()
    }
    open func display(_ layer: CALayer) {}
    open func layerWillDraw(_ layer: CALayer) {}
    open func action(for layer: CALayer, forKey event: String) -> CAAction? { NSNull() }
    public var webImplementsDisplay: Bool { false }

    // MARK: traits
    open var traitCollection: UITraitCollection {
        if overrideUserInterfaceStyle != .unspecified { return UITraitCollection(userInterfaceStyle: overrideUserInterfaceStyle) }
        return superview?.traitCollection ?? UITraitCollection.current
    }
    open func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {}
    open var effectiveUserInterfaceLayoutDirection: UIUserInterfaceLayoutDirection { .leftToRight }
    public class func userInterfaceLayoutDirection(for attribute: UISemanticContentAttribute) -> UIUserInterfaceLayoutDirection { attribute == .forceRightToLeft ? .rightToLeft : .leftToRight }

    // MARK: hit testing & conversion
    open func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard isUserInteractionEnabled, !isHidden, alpha > 0.01, self.point(inside: point, with: event) else { return nil }
        for s in subviews.reversed() {
            if let h = s.hitTest(s.convert(point, from: self), with: event) { return h }
        }
        return self
    }
    open func point(inside point: CGPoint, with event: UIEvent?) -> Bool { bounds.contains(point) }
    open func convert(_ point: CGPoint, to view: UIView?) -> CGPoint { layer.convert(point, to: (view ?? window)?.layer) }
    open func convert(_ point: CGPoint, from view: UIView?) -> CGPoint { layer.convert(point, from: (view ?? window)?.layer) }
    open func convert(_ rect: CGRect, to view: UIView?) -> CGRect { layer.convert(rect, to: (view ?? window)?.layer) }
    open func convert(_ rect: CGRect, from view: UIView?) -> CGRect { layer.convert(rect, from: (view ?? window)?.layer) }
    // Non-optional views pick these overloads; forward to the UIView? versions explicitly (else they call themselves).
    public func convert(_ point: CGPoint, to space: UICoordinateSpace) -> CGPoint {
        if let v = space as? UIView { return convert(point, to: Optional(v)) }
        return convert(point, to: nil as UIView?)
    }
    public func convert(_ point: CGPoint, from space: UICoordinateSpace) -> CGPoint {
        if let v = space as? UIView { return convert(point, from: Optional(v)) }
        return convert(point, from: nil as UIView?)
    }
    public func convert(_ rect: CGRect, to space: UICoordinateSpace) -> CGRect {
        if let v = space as? UIView { return convert(rect, to: Optional(v)) }
        return convert(rect, to: nil as UIView?)
    }
    public func convert(_ rect: CGRect, from space: UICoordinateSpace) -> CGRect {
        if let v = space as? UIView { return convert(rect, from: Optional(v)) }
        return convert(rect, from: nil as UIView?)
    }

    // MARK: gestures & interactions
    open func addGestureRecognizer(_ g: UIGestureRecognizer) {
        g.view?.removeGestureRecognizer(g)
        recognizers.append(g); g.view = self
    }
    open func removeGestureRecognizer(_ g: UIGestureRecognizer) {
        recognizers.removeAll { $0 === g }
        if g.view === self { g.view = nil }
    }
    open func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool { true }
    open func addInteraction(_ i: UIInteraction) { interactions.append(i); i.willMove(to: self); i.didMove(to: self) }
    open func removeInteraction(_ i: UIInteraction) { interactions.removeAll { $0 === i }; i.willMove(to: nil); i.didMove(to: nil) }
    @discardableResult open func endEditing(_ force: Bool) -> Bool {
        if let r = UIResponder.webFirstResponder as? UIView, r.isDescendant(of: self) { return r.resignFirstResponder() }
        return true
    }

    // MARK: snapshots
    open func snapshotView(afterScreenUpdates: Bool) -> UIView? {
        let v = UIView(frame: frame)
        v.layer.contents = layer.contents
        return v
    }
    open func resizableSnapshotView(from rect: CGRect, afterScreenUpdates: Bool, withCapInsets: UIEdgeInsets) -> UIView? { snapshotView(afterScreenUpdates: afterScreenUpdates) }
    @discardableResult open func drawHierarchy(in rect: CGRect, afterScreenUpdates: Bool) -> Bool { false }

    // MARK: animations (applied immediately; completion fires after the duration)
    nonisolated(unsafe) static var animationsEnabled = true
    nonisolated(unsafe) static var animationDepth = 0
    nonisolated(unsafe) static var currentDuration: TimeInterval = 0
    public class var areAnimationsEnabled: Bool { animationsEnabled }
    public class func setAnimationsEnabled(_ e: Bool) { animationsEnabled = e }
    public class func performWithoutAnimation(_ actions: () -> Void) {
        let e = animationsEnabled; animationsEnabled = false; actions(); animationsEnabled = e
    }
    public class var inheritedAnimationDuration: TimeInterval { animationDepth > 0 ? currentDuration : 0 }
    static func runAnimation(duration: TimeInterval, delay: TimeInterval, animations: () -> Void, completion: ((Bool) -> Void)?) {
        animationDepth += 1
        let old = currentDuration; currentDuration = duration
        CATransaction.begin()
        CATransaction.setAnimationDuration(duration)
        animations()
        CATransaction.commit()
        currentDuration = old
        animationDepth -= 1
        if let completion {
            let t = animationsEnabled ? duration + delay : 0
            DispatchQueue.main.asyncAfter(deadline: .now() + t) { completion(true) }
        }
    }
    public class func animate(withDuration duration: TimeInterval, delay: TimeInterval, options: AnimationOptions = [], animations: @escaping () -> Void, completion: ((Bool) -> Void)? = nil) {
        runAnimation(duration: duration, delay: delay, animations: animations, completion: completion)
    }
    public class func animate(withDuration duration: TimeInterval, animations: @escaping () -> Void, completion: ((Bool) -> Void)? = nil) {
        runAnimation(duration: duration, delay: 0, animations: animations, completion: completion)
    }
    public class func animate(withDuration duration: TimeInterval, animations: @escaping () -> Void) {
        runAnimation(duration: duration, delay: 0, animations: animations, completion: nil)
    }
    public class func animate(withDuration duration: TimeInterval, delay: TimeInterval, usingSpringWithDamping damping: CGFloat, initialSpringVelocity velocity: CGFloat,
                              options: AnimationOptions = [], animations: @escaping () -> Void, completion: ((Bool) -> Void)? = nil) {
        runAnimation(duration: duration, delay: delay, animations: animations, completion: completion)
    }
    public class func animate(springDuration duration: TimeInterval = 0.5, bounce: CGFloat = 0, initialSpringVelocity: CGFloat = 0, delay: TimeInterval = 0,
                              options: AnimationOptions = [], animations: () -> Void, completion: ((Bool) -> Void)? = nil) {
        runAnimation(duration: duration, delay: delay, animations: animations, completion: completion)
    }
    public class func transition(with view: UIView, duration: TimeInterval, options: AnimationOptions = [], animations: (() -> Void)?, completion: ((Bool) -> Void)? = nil) {
        runAnimation(duration: duration, delay: 0, animations: { animations?() }, completion: completion)
    }
    public class func transition(from: UIView, to: UIView, duration: TimeInterval, options: AnimationOptions = [], completion: ((Bool) -> Void)? = nil) {
        if let s = from.superview { s.insertSubview(to, aboveSubview: from); from.removeFromSuperview() }
        runAnimation(duration: duration, delay: 0, animations: {}, completion: completion)
    }
    public class func animateKeyframes(withDuration duration: TimeInterval, delay: TimeInterval, options: KeyframeAnimationOptions = [], animations: @escaping () -> Void, completion: ((Bool) -> Void)? = nil) {
        runAnimation(duration: duration, delay: delay, animations: animations, completion: completion)
    }
    public class func addKeyframe(withRelativeStartTime: Double, relativeDuration: Double, animations: @escaping () -> Void) { animations() }
    public class func perform(_ animation: SystemAnimation, on views: [UIView], options: AnimationOptions = [], animations: (() -> Void)?, completion: ((Bool) -> Void)? = nil) {
        runAnimation(duration: 0.25, delay: 0, animations: { animations?() }, completion: completion)
    }
    nonisolated(unsafe) static var legacyDuration: TimeInterval = 0.2
    public class func beginAnimations(_ id: String?, context: UnsafeMutableRawPointer?) { CATransaction.begin() }
    public class func commitAnimations() { CATransaction.commit() }
    public class func setAnimationDuration(_ d: TimeInterval) { CATransaction.setAnimationDuration(d) }
    public class func setAnimationCurve(_ c: AnimationCurve) {}
    public class func setAnimationDelay(_ d: TimeInterval) {}
    public class func setAnimationBeginsFromCurrentState(_ b: Bool) {}
    public class func setAnimationRepeatCount(_ c: Float) {}
    public class func setAnimationDelegate(_ d: Any?) {}

    open override var description: String { "<\(type(of: self)) frame=\(frame)>" }
}

open class UILayoutGuide: NSObject {
    public weak var owningView: UIView?
    public var identifier = ""
    init(owner: UIView) { owningView = owner }
    public override init() {}
    public var layoutFrame: CGRect { (owningView?.bounds ?? .zero).inset(by: owningView?.safeAreaInsets ?? .zero) }
}

public protocol UIInteraction: AnyObject {
    var view: UIView? { get }
    func willMove(to view: UIView?)
    func didMove(to view: UIView?)
}

// MARK: window

open class UIWindow: UIView {
    public struct Level: RawRepresentable, Hashable, Comparable {
        public let rawValue: CGFloat
        public init(rawValue: CGFloat) { self.rawValue = rawValue }
        public init(_ rawValue: CGFloat) { self.rawValue = rawValue }
        public static let normal = Level(rawValue: 0)
        public static let alert = Level(rawValue: 2000)
        public static let statusBar = Level(rawValue: 1000)
        public static func < (a: Level, b: Level) -> Bool { a.rawValue < b.rawValue }
        public static func + (a: Level, b: CGFloat) -> Level { Level(rawValue: a.rawValue + b) }
    }
    open var rootViewController: UIViewController? {
        didSet {
            oldValue?.view.removeFromSuperview()
            if let vc = rootViewController {
                vc.view.frame = bounds
                vc.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                addSubview(vc.view)
            }
        }
    }
    open var windowLevel: Level = .normal
    open var screen: UIScreen = .main
    open weak var windowScene: UIWindowScene?
    open var canResizeToFitContent = false
    public private(set) var isKeyWindow = false
    open override var window: UIWindow? { self }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        UIWindow.register(self)
    }
    public required init?(coder: NSCoder) { super.init(coder: coder); UIWindow.register(self) }
    public init(windowScene: UIWindowScene) {
        super.init(frame: windowScene.screen.bounds)
        self.windowScene = windowScene
        UIWindow.register(self)
    }
    static func register(_ w: UIWindow) {
        CALayer.webRootLayers.append({ [weak w] in w?.layer })
        UIApplication.shared.webWindows.append(WeakWindow(w))
    }
    open func makeKeyAndVisible() { makeKey(); isHidden = false }
    open func makeKey() {
        for w in UIApplication.shared.windows { w.isKeyWindow = false }
        isKeyWindow = true
        becomeKey()
    }
    open func becomeKey() {}
    open func resignKey() {}
    open func sendEvent(_ event: UIEvent) { WebEventDispatch.dispatch(event, in: self) }
    open func _update(toInterfaceOrientation arg1: Int32, duration arg2: Double, force arg3: Bool) {}
    open override var next: UIResponder? { UIApplication.shared }
    public static let didBecomeVisibleNotification = Notification.Name("UIWindowDidBecomeVisibleNotification")
    public static let didBecomeHiddenNotification = Notification.Name("UIWindowDidBecomeHiddenNotification")
    public static let didBecomeKeyNotification = Notification.Name("UIWindowDidBecomeKeyNotification")
    public static let didResignKeyNotification = Notification.Name("UIWindowDidResignKeyNotification")
}
final class WeakWindow { weak var window: UIWindow?; init(_ w: UIWindow) { window = w } }
