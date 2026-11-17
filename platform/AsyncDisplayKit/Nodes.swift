// Swiftboard AsyncDisplayKit (MIT): control, scroll and editable-text nodes, delegate protocols, helpers.
import Foundation

// MARK: control node

public struct ASControlNodeEvent: OptionSet, Hashable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let touchDown = ASControlNodeEvent(rawValue: 1 << 0)
    public static let touchDownRepeat = ASControlNodeEvent(rawValue: 1 << 1)
    public static let touchDragInside = ASControlNodeEvent(rawValue: 1 << 2)
    public static let touchDragOutside = ASControlNodeEvent(rawValue: 1 << 3)
    public static let touchUpInside = ASControlNodeEvent(rawValue: 1 << 4)
    public static let touchUpOutside = ASControlNodeEvent(rawValue: 1 << 5)
    public static let touchCancel = ASControlNodeEvent(rawValue: 1 << 6)
    public static let valueChanged = ASControlNodeEvent(rawValue: 1 << 12)
    public static let primaryActionTriggered = ASControlNodeEvent(rawValue: 1 << 13)
    public static let allEvents = ASControlNodeEvent(rawValue: 0xFFFF_FFFF)
}

open class ASControlNode: ASDisplayNode {
    struct Target { weak var target: AnyObject?; let action: Selector; let events: ASControlNodeEvent }
    private var targets: [Target] = []
    open var isEnabled = true
    open var isHighlighted = false
    open var isSelected = false
    public private(set) var isTracking = false
    public private(set) var isTouchInside = false
    public override init() { super.init() }
    open func addTarget(_ target: Any?, action: Selector, forControlEvents events: ASControlNodeEvent) {
        targets.append(Target(target: target as AnyObject?, action: action, events: events))
    }
    open func removeTarget(_ target: Any?, action: Selector?, forControlEvents events: ASControlNodeEvent) {
        targets.removeAll { t in (target == nil || t.target === (target as AnyObject?)) && (action == nil || t.action == action!) && !t.events.isDisjoint(with: events) }
    }
    open func actions(forTarget target: Any, forControlEvent e: ASControlNodeEvent) -> [String]? {
        let r = targets.filter { $0.target === (target as AnyObject) && $0.events.contains(e) }.map { $0.action.name }
        return r.isEmpty ? nil : r
    }
    open func allTargets() -> Set<AnyHashable> { Set(targets.compactMap { $0.target.map { ObjectIdentifier($0) } }) }
    open func sendActions(forControlEvents events: ASControlNodeEvent, with event: UIEvent?) {
        for t in targets where !t.events.isDisjoint(with: events) {
            if let tg = t.target { t.action.perform(on: tg, with: self, with: event) }
        }
    }
    open func beginTracking(with touch: UITouch, with event: UIEvent?) -> Bool { true }
    open func continueTracking(with touch: UITouch, with event: UIEvent?) -> Bool { true }
    open func endTracking(with touch: UITouch?, with event: UIEvent?) {}
    open func cancelTracking(with event: UIEvent?) {}
    open override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isEnabled, let t = touches.first else { return }
        isTracking = beginTracking(with: t, with: event)
        isTouchInside = true
        isHighlighted = true
        sendActions(forControlEvents: .touchDown, with: event)
    }
    open override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isEnabled, isTracking, let t = touches.first else { return }
        let inside = point(inside: t.location(in: view), with: event) || bounds.insetBy(dx: -70, dy: -70).contains(t.location(in: view))
        isTouchInside = inside
        isHighlighted = inside
        isTracking = continueTracking(with: t, with: event)
        sendActions(forControlEvents: inside ? .touchDragInside : .touchDragOutside, with: event)
    }
    open override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isEnabled else { return }
        endTracking(with: touches.first, with: event)
        isTracking = false
        isHighlighted = false
        sendActions(forControlEvents: isTouchInside ? [.touchUpInside, .primaryActionTriggered] : .touchUpOutside, with: event)
    }
    open override func touchesCancelled(_ touches: Set<UITouch>?, with event: UIEvent?) {
        cancelTracking(with: event)
        isTracking = false
        isHighlighted = false
        sendActions(forControlEvents: .touchCancel, with: event)
    }
}

// MARK: scroll node

public struct ASScrollDirection: OptionSet, Hashable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let right = ASScrollDirection(rawValue: 1 << 0)
    public static let left = ASScrollDirection(rawValue: 1 << 1)
    public static let up = ASScrollDirection(rawValue: 1 << 2)
    public static let down = ASScrollDirection(rawValue: 1 << 3)
    public static let horizontalDirections: ASScrollDirection = [.left, .right]
    public static let verticalDirections: ASScrollDirection = [.up, .down]
}
public let ASScrollDirectionVerticalDirections = ASScrollDirection.verticalDirections
public let ASScrollDirectionHorizontalDirections = ASScrollDirection.horizontalDirections

open class ASScrollView: UIScrollView {
    open override func layoutSubviews() { super.layoutSubviews(); asyncdisplaykit_node?.webLayout() }
    open override func didMoveToWindow() { super.didMoveToWindow(); asyncdisplaykit_node?.setInHierarchy(window != nil) }
}
open class ASScrollNode: ASDisplayNode {
    open var automaticallyManagesContentSize = false
    open var scrollableDirections: ASScrollDirection = .verticalDirections
    open var canCancelAllTouchesInViews = false
    public override init() {
        super.init()
        setViewBlock { ASScrollView(frame: .zero) }
    }
    open override var view: UIScrollView { super.view as! UIScrollView }
}

// MARK: editable text node

public protocol ASEditableTextNodeDelegate: AnyObject {
    func editableTextNodeShouldBeginEditing(_ editableTextNode: ASEditableTextNode) -> Bool
    func editableTextNodeDidBeginEditing(_ editableTextNode: ASEditableTextNode)
    func editableTextNode(_ editableTextNode: ASEditableTextNode, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool
    func editableTextNodeDidChangeSelection(_ editableTextNode: ASEditableTextNode, fromSelectedRange: NSRange, toSelectedRange: NSRange, dueToEditing: Bool)
    func editableTextNodeDidUpdateText(_ editableTextNode: ASEditableTextNode)
    func editableTextNodeDidFinishEditing(_ editableTextNode: ASEditableTextNode)
    func editableTextNodeShouldCopy(_ editableTextNode: ASEditableTextNode) -> Bool
    func editableTextNodeShouldPaste(_ editableTextNode: ASEditableTextNode) -> Bool
    func editableTextNodeTarget(forAction action: Selector) -> ASEditableTextNodeTargetForAction?
    func editableTextNodeShouldReturn(_ editableTextNode: ASEditableTextNode) -> Bool
    func editableTextNodeBackspaceWhileEmpty(_ editableTextNode: ASEditableTextNode)
    func editableTextNodeMenu(_ editableTextNode: ASEditableTextNode, forTextRange textRange: NSRange, suggestedActions: [UIMenuElement]) -> UIMenu
}
extension ASEditableTextNodeDelegate {
    public func editableTextNodeShouldBeginEditing(_ editableTextNode: ASEditableTextNode) -> Bool { true }
    public func editableTextNodeDidBeginEditing(_ editableTextNode: ASEditableTextNode) {}
    public func editableTextNode(_ editableTextNode: ASEditableTextNode, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool { true }
    public func editableTextNodeDidChangeSelection(_ editableTextNode: ASEditableTextNode, fromSelectedRange: NSRange, toSelectedRange: NSRange, dueToEditing: Bool) {}
    public func editableTextNodeDidUpdateText(_ editableTextNode: ASEditableTextNode) {}
    public func editableTextNodeDidFinishEditing(_ editableTextNode: ASEditableTextNode) {}
    public func editableTextNodeShouldCopy(_ editableTextNode: ASEditableTextNode) -> Bool { true }
    public func editableTextNodeShouldPaste(_ editableTextNode: ASEditableTextNode) -> Bool { true }
    public func editableTextNodeTarget(forAction action: Selector) -> ASEditableTextNodeTargetForAction? { nil }
    public func editableTextNodeShouldReturn(_ editableTextNode: ASEditableTextNode) -> Bool { true }
    public func editableTextNodeBackspaceWhileEmpty(_ editableTextNode: ASEditableTextNode) {}
    public func editableTextNodeMenu(_ editableTextNode: ASEditableTextNode, forTextRange textRange: NSRange, suggestedActions: [UIMenuElement]) -> UIMenu { UIMenu(children: suggestedActions) }
}
open class ASEditableTextNodeTargetForAction: NSObject {
    public let target: Any?
    public init(target: Any?) { self.target = target }
}
open class ASEditableTextNode: ASDisplayNode {
    open weak var delegate: ASEditableTextNodeDelegate?
    open var scrollEnabled = true { didSet { if isNodeLoaded { textView.isScrollEnabled = scrollEnabled } } }
    open var baseFont: UIFont? = UIFont.systemFont(ofSize: 17)
    open var typingAttributes: [String: Any]? {
        didSet {
            var a: [NSAttributedString.Key: Any] = [:]
            for (k, v) in typingAttributes ?? [:] { a[NSAttributedString.Key(k)] = v }
            if isNodeLoaded { textView.typingAttributes = a }
        }
    }
    open var selectedRange = NSRange(location: 0, length: 0)
    open var selectionRect: CGRect { .zero }
    open var attributedPlaceholderText: NSAttributedString?
    open var attributedText: NSAttributedString? {
        didSet {
            if isNodeLoaded { textView.attributedText = attributedText ?? NSAttributedString(string: "") }
            delegate?.editableTextNodeDidUpdateText(self)
        }
    }
    open var textContainerInset: UIEdgeInsets = .zero { didSet { if isNodeLoaded { textView.textContainerInset = textContainerInset } } }
    open var maximumLinesToDisplay = 0
    open var autocapitalizationType: UITextAutocapitalizationType = .sentences
    open var autocorrectionType: UITextAutocorrectionType = .default
    open var spellCheckingType: UITextSpellCheckingType = .default
    open var keyboardType: UIKeyboardType = .default
    open var keyboardAppearance: UIKeyboardAppearance = .default
    open var returnKeyType: UIReturnKeyType = .default
    open var enablesReturnKeyAutomatically = false
    open var isSecureTextEntry = false
    open var initialPrimaryLanguage: String?
    open var textInputMode: UITextInputMode { UITextInputMode() }
    public private(set) lazy var textView: UITextView = {
        let v = UITextView(frame: .zero, textContainer: nil)
        v.backgroundColor = .clear
        v.textContainerInset = textContainerInset
        v.attributedText = attributedText ?? NSAttributedString(string: "")
        return v
    }()
    public override init() { super.init() }
    open override func didLoad() {
        super.didLoad()
        textView.frame = bounds
        textView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(textView)
    }
    open func isDisplayingPlaceholder() -> Bool { (attributedText?.length ?? 0) == 0 }
    open override func isFirstResponder() -> Bool { isNodeLoaded && textView.isFirstResponder }
    @discardableResult open override func becomeFirstResponder() -> Bool { textView.becomeFirstResponder() }
    @discardableResult open override func resignFirstResponder() -> Bool { textView.resignFirstResponder() }
    open func frame(forTextRange r: NSRange) -> CGRect { .zero }
    open func resetInitialPrimaryLanguage() {}
    open func dropAutocorrection() {}
    open func isCurrentlyEmoji() -> Bool { false }
}

// MARK: delegate protocols (ObjC optional requirements become defaulted requirements)

public protocol ASGestureRecognizerDelegate: AnyObject {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive press: UIPress) -> Bool
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive event: UIEvent) -> Bool
}
extension ASGestureRecognizerDelegate {
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool { true }
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool { false }
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool { false }
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool { false }
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool { true }
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive press: UIPress) -> Bool { true }
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive event: UIEvent) -> Bool { true }
}
public protocol ASScrollViewDelegate: AnyObject {
    func scrollViewDidScroll(_ scrollView: UIScrollView)
    func scrollViewDidZoom(_ scrollView: UIScrollView)
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView)
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>)
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool)
    func scrollViewWillBeginDecelerating(_ scrollView: UIScrollView)
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView)
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView)
    func viewForZooming(in scrollView: UIScrollView) -> UIView?
    func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?)
    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat)
    func scrollViewShouldScroll(toTop scrollView: UIScrollView) -> Bool
    func scrollViewDidScroll(toTop scrollView: UIScrollView)
    func scrollViewDidChangeAdjustedContentInset(_ scrollView: UIScrollView)
    func accessibilityScrollStatus(for scrollView: UIScrollView) -> String?
    func accessibilityAttributedScrollStatus(for scrollView: UIScrollView) -> NSAttributedString?
}
extension ASScrollViewDelegate {
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {}
    public func scrollViewDidZoom(_ scrollView: UIScrollView) {}
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {}
    public func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {}
    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {}
    public func scrollViewWillBeginDecelerating(_ scrollView: UIScrollView) {}
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {}
    public func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {}
    public func viewForZooming(in scrollView: UIScrollView) -> UIView? { nil }
    public func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {}
    public func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {}
    public func scrollViewShouldScroll(toTop scrollView: UIScrollView) -> Bool { true }
    public func scrollViewDidScroll(toTop scrollView: UIScrollView) {}
    public func scrollViewDidChangeAdjustedContentInset(_ scrollView: UIScrollView) {}
    public func accessibilityScrollStatus(for scrollView: UIScrollView) -> String? { nil }
    public func accessibilityAttributedScrollStatus(for scrollView: UIScrollView) -> NSAttributedString? { nil }
}

// MARK: image buffers & helpers

open class ASCGImageBuffer: NSObject {
    public let mutableBytes: UnsafeMutableRawPointer
    public let length: UInt
    private var handedOff = false
    public init?(length: UInt) {
        self.length = length
        mutableBytes = UnsafeMutableRawPointer.allocate(byteCount: Int(max(1, length)), alignment: 16)
        mutableBytes.initializeMemory(as: UInt8.self, repeating: 0, count: Int(max(1, length)))
    }
    deinit { if !handedOff { mutableBytes.deallocate() } }
    /// The provider owns the bytes from now on (freed when the provider goes away).
    public func createDataProviderAndInvalidate() -> CGDataProvider {
        handedOff = true
        return CGDataProvider(dataInfo: nil, data: mutableBytes, size: Int(length), releaseData: { _, p, _ in UnsafeMutableRawPointer(mutating: p).deallocate() })!
    }
}

public func ASDisplayNodeSetResizableContents(_ obj: AnyObject, _ image: UIImage) {
    let apply: (CALayer) -> Void = { l in
        l.contents = image.cgImage
        l.contentsScale = image.scale
        let s = image.size, i = image.capInsets
        if s.width > 0 && s.height > 0 {
            l.contentsCenter = CGRect(x: i.left / s.width, y: i.top / s.height,
                                      width: max(0, s.width - i.left - i.right) / s.width, height: max(0, s.height - i.top - i.bottom) / s.height)
        }
    }
    if let n = obj as? ASDisplayNode {
        n.contents = image.cgImage; n.contentsScale = image.scale
        if n.isNodeLoaded { apply(n.layer) } else {
            let s = image.size, i = image.capInsets
            if s.width > 0 && s.height > 0 {
                n.contentsCenter = CGRect(x: i.left / s.width, y: i.top / s.height, width: max(0, s.width - i.left - i.right) / s.width, height: max(0, s.height - i.top - i.bottom) / s.height)
            }
        }
    } else if let l = obj as? CALayer { apply(l) }
}
public func ASPerformMainThreadDeallocation<T>(_ object: inout T?) { object = nil }
public func ASPerformBlockOnMainThread(_ block: @escaping () -> Void) { block() }
public func ASPerformBlockOnBackgroundThread(_ block: @escaping () -> Void) { DispatchQueue.main.async(execute: block) }
public func ASIsCGRectValidForLayout(_ r: CGRect) -> Bool { !r.isNull && !r.isInfinite && r.minX.isFinite && r.minY.isFinite && r.width.isFinite && r.height.isFinite && r.width >= 0 && r.height >= 0 }
public func ASIsCGPositionValidForLayout(_ p: CGPoint) -> Bool { p.x.isFinite && p.y.isFinite }
public func ASIsCGSizeValidForLayout(_ s: CGSize) -> Bool { s.width.isFinite && s.height.isFinite && s.width >= 0 && s.height >= 0 }
public func ASDisplayNodeCachedAccessibilityElements(_ node: ASDisplayNode?) -> [Any]? { node?.accessibilityElements }
public func ASScreenScale() -> CGFloat { UIScreen.main.scale }
public func ASFloorPixelValue(_ f: CGFloat) -> CGFloat { let s = ASScreenScale(); return floor(f * s) / s }
public func ASCeilPixelValue(_ f: CGFloat) -> CGFloat { let s = ASScreenScale(); return ceil(f * s) / s }
public func ASRoundPixelValue(_ f: CGFloat) -> CGFloat { let s = ASScreenScale(); return (f * s).rounded() / s }
public func ASDisplayNodeFindFirstSubnode(_ start: ASDisplayNode, _ block: (ASDisplayNode) -> Bool) -> ASDisplayNode? {
    for s in start.subnodes ?? [] { if block(s) { return s }; if let f = ASDisplayNodeFindFirstSubnode(s, block) { return f } }
    return nil
}
public func ASDisplayNodeFindAllSubnodes(_ start: ASDisplayNode, _ block: (ASDisplayNode) -> Bool) -> [ASDisplayNode] {
    var r: [ASDisplayNode] = []
    for s in start.subnodes ?? [] { if block(s) { r.append(s) }; r += ASDisplayNodeFindAllSubnodes(s, block) }
    return r
}
public func ASDisplayNodeUltimateParentOfNode(_ n: ASDisplayNode) -> ASDisplayNode { var c = n; while let s = c.supernode { c = s }; return c }
public func ASFindWindowOfLayer(_ l: CALayer) -> UIWindow? {
    var c: CALayer? = l
    while let x = c { if let w = x.delegate as? UIWindow { return w }; c = x.superlayer }
    return nil
}
public enum ASHorizontalAlignment: Int { case none, left, middle, right, leading, trailing }
public enum ASVerticalAlignment: Int { case none, top, center, bottom }
public let ASDefaultDrawingPriority = 0
