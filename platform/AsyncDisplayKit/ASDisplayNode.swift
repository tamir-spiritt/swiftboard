// Swiftboard AsyncDisplayKit (MIT): a Swift rewrite of the node API Telegram uses, with synchronous display.
// A node keeps its properties on a detached "pending" layer until its view/layer loads, then mirrors them.
@_exported import UIKit
import Foundation

public typealias ASDisplayNodeViewBlock = () -> UIView
public typealias ASDisplayNodeLayerBlock = () -> CALayer
public typealias ASDisplayNodeDidLoadBlock = (ASDisplayNode) -> Void
public typealias ASDisplayNodeContextModifier = (CGContext, Any?) -> Void
public typealias asdisplaynode_iscancelled_block_t = () -> Bool

public enum ASCornerRoundingType: Int { case defaultSlowCALayer, precomposited, clipping }
public struct ASInterfaceState: OptionSet, Hashable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let none = ASInterfaceState([])
    public static let measureLayout = ASInterfaceState(rawValue: 1 << 0)
    public static let preload = ASInterfaceState(rawValue: 1 << 1)
    public static let display = ASInterfaceState(rawValue: 1 << 2)
    public static let visible = ASInterfaceState(rawValue: 1 << 3)
    public static let inHierarchy: ASInterfaceState = [.measureLayout, .preload, .display, .visible]
}
public struct ASSizeRange: Equatable {
    public var min: CGSize
    public var max: CGSize
    public init(min: CGSize, max: CGSize) { self.min = min; self.max = max }
}
public func ASSizeRangeMake(_ min: CGSize, _ max: CGSize) -> ASSizeRange { ASSizeRange(min: min, max: max) }
public func ASSizeRangeMake(_ exact: CGSize) -> ASSizeRange { ASSizeRange(min: exact, max: exact) }
open class ASLayout: NSObject {
    public let size: CGSize
    public weak var layoutElement: ASDisplayNode?
    public var position: CGPoint = .zero
    public init(size: CGSize, element: ASDisplayNode?) { self.size = size; layoutElement = element }
    public var frame: CGRect { CGRect(origin: position, size: size) }
}

public protocol ASInterfaceStateDelegate: AnyObject {
    func interfaceStateDidChange(_ newState: ASInterfaceState, from oldState: ASInterfaceState)
    func didEnterVisibleState()
    func didExitVisibleState()
    func didEnterDisplayState()
    func didExitDisplayState()
    func didEnterPreloadState()
    func didExitPreloadState()
    func nodeDidLayout()
    func nodeDidLoad()
    func hierarchyDisplayDidFinish()
}
extension ASInterfaceStateDelegate {
    public func interfaceStateDidChange(_ newState: ASInterfaceState, from oldState: ASInterfaceState) {}
    public func didEnterVisibleState() {}
    public func didExitVisibleState() {}
    public func didEnterDisplayState() {}
    public func didExitDisplayState() {}
    public func didEnterPreloadState() {}
    public func didExitPreloadState() {}
    public func nodeDidLayout() {}
    public func nodeDidLoad() {}
    public func hierarchyDisplayDidFinish() {}
}

open class ASDisplayNode: NSObject {
    private var _view: UIView?
    private var _layer: CALayer?
    private let pending = CALayer()
    private var viewBlock: ASDisplayNodeViewBlock?
    private var layerBlock: ASDisplayNodeLayerBlock?
    private var didLoadBlocks: [ASDisplayNodeDidLoadBlock] = []
    private var _subnodes: [ASDisplayNode] = []
    private var interfaceDelegates: [WeakInterfaceDelegate] = []
    public private(set) weak var supernode: ASDisplayNode?
    public private(set) var interfaceState: ASInterfaceState = []
    public private(set) var calculatedSize: CGSize = .zero
    public private(set) var constrainedSizeForCalculatedLayout = ASSizeRange(min: .zero, max: .zero)

    // view-level pending state
    private var _userInteractionEnabled = true
    private var _exclusiveTouch = false
    private var _autoresizingMask: UIView.AutoresizingMask = []
    private var _autoresizesSubviews = true
    private var _tintColor: UIColor?
    private var _contentMode: UIView.ContentMode = .scaleToFill
    private var _semanticContentAttribute: UISemanticContentAttribute = .unspecified
    private var _layoutMargins = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

    open var isLayerBacked = false
    open var displaysAsynchronously = true
    open var displaySuspended = false
    open var shouldAnimateSizeChanges = true
    open var placeholderEnabled = false
    open var placeholderFadeDuration: TimeInterval = 0
    open var drawingPriority = 0
    open var hitTestSlop: UIEdgeInsets = .zero
    open var automaticallyRelayoutOnSafeAreaChanges = false
    open var automaticallyRelayoutOnLayoutMarginsChanges = false
    open var disableClearContentsOnHide = false
    open var automaticallyManagesSubnodes = false
    open var cornerRoundingType: ASCornerRoundingType = .defaultSlowCALayer
    open var insetsLayoutMarginsFromSafeArea = true
    open var preservesSuperviewLayoutMargins = false
    open var defaultLayoutTransitionDuration: TimeInterval = 0.2
    open var defaultLayoutTransitionDelay: TimeInterval = 0
    open var defaultLayoutTransitionOptions: UIView.AnimationOptions = []
    open var willDisplayNodeContentWithRenderingContext: ASDisplayNodeContextModifier?
    open var didDisplayNodeContentWithRenderingContext: ASDisplayNodeContextModifier?
    open var isAccessibilityContainer = false
    open var accessibilityUsesViewElements = false
    open var debugName: String?
    public var isSynchronous: Bool { viewBlock != nil || layerBlock != nil }
    public var supportsLayerBacking: Bool { !isSynchronous || layerBlock != nil }

    public override init() { super.init(); baseInit() }
    /// ASDK defaults: contents at screen scale, opaque.
    private func baseInit() { pending.contentsScale = UIScreen.main.scale; pending.rasterizationScale = UIScreen.main.scale; pending.isOpaque = true }
    public convenience init(viewBlock: @escaping ASDisplayNodeViewBlock) { self.init(viewBlock: viewBlock, didLoad: nil) }
    public init(viewBlock: @escaping ASDisplayNodeViewBlock, didLoad: ASDisplayNodeDidLoadBlock?) {
        super.init(); baseInit(); self.viewBlock = viewBlock; if let d = didLoad { didLoadBlocks.append(d) }
    }
    public convenience init(layerBlock: @escaping ASDisplayNodeLayerBlock) { self.init(layerBlock: layerBlock, didLoad: nil) }
    public init(layerBlock: @escaping ASDisplayNodeLayerBlock, didLoad: ASDisplayNodeDidLoadBlock?) {
        super.init(); baseInit(); self.layerBlock = layerBlock; isLayerBacked = true; if let d = didLoad { didLoadBlocks.append(d) }
    }
    open func setViewBlock(_ block: @escaping ASDisplayNodeViewBlock) { viewBlock = block; isLayerBacked = false }
    open func setLayerBlock(_ block: @escaping ASDisplayNodeLayerBlock) { layerBlock = block; isLayerBacked = true }
    open func onDidLoad(_ body: @escaping ASDisplayNodeDidLoadBlock) {
        if isNodeLoaded { body(self) } else { didLoadBlocks.append(body) }
    }

    open class var viewClass: AnyClass { _ASDisplayView.self }
    open class var layerClass: AnyClass { _ASDisplayLayer.self }

    // MARK: loading
    public var isNodeLoaded: Bool { _layer != nil }
    open var view: UIView {
        if _layer == nil { load() }
        if _view == nil {
            // layer-backed node asked for a view: wrap its layer (ASDK asserts; we degrade gracefully)
            let v = _ASDisplayView(frame: .zero)
            v.asyncdisplaykit_node = self
            _view = v
        }
        return _view!
    }
    open var layer: CALayer {
        if _layer == nil { load() }
        return _layer!
    }
    private func load() {
        if isLayerBacked {
            let l: CALayer
            if let b = layerBlock { l = b() } else { l = ASDisplayNode.makeLayer(type(of: self).layerClass) }
            _layer = l
        } else {
            let v: UIView
            if let b = viewBlock { v = b() } else if let vc = type(of: self).viewClass as? _ASDisplayView.Type { v = vc.init(frame: .zero) } else { v = _ASDisplayView(frame: .zero) }
            _view = v
            _layer = v.layer
            v.asyncdisplaykit_node = self
            v.isUserInteractionEnabled = _userInteractionEnabled
            v.isExclusiveTouch = _exclusiveTouch
            v.autoresizingMask = _autoresizingMask
            v.autoresizesSubviews = _autoresizesSubviews
            if let t = _tintColor { v.tintColor = t }
            v.contentMode = _contentMode
            v.semanticContentAttribute = _semanticContentAttribute
            v.layoutMargins = _layoutMargins
            v.accessibilityLabel = accessibilityLabel
            v.isAccessibilityElement = isAccessibilityElement
            v.accessibilityTraits = accessibilityTraits
            v.accessibilityIdentifier = accessibilityIdentifier
        }
        let l = _layer!
        let wasContentsGravity = l.contentsGravity
        l.webCopyState(from: pending)
        if _view != nil && pending.contentsGravity == .resize { l.contentsGravity = wasContentsGravity == .resize ? UIView.gravityFor(_contentMode) : wasContentsGravity }
        l.asyncdisplaykit_node = self
        if let dl = l as? _ASDisplayLayer { dl.asyncdisplaykit_node = self; dl.needsDisplayOnBoundsChange = true }
        // attach already-added subnodes
        for s in _subnodes { attachSubnodeBacking(s, at: nil) }
        l.setNeedsDisplay()
        didLoad()
        let blocks = didLoadBlocks
        didLoadBlocks = []
        for b in blocks { b(self) }
        interfaceDelegates.forEach { $0.d?.nodeDidLoad() }
        if supernode?.isInHierarchy == true { setInHierarchy(true) }
    }
    static func makeLayer(_ cls: AnyClass) -> CALayer {
        if let t = cls as? CALayer.Type { return t.webMakeLayer() }
        return _ASDisplayLayer()
    }
    /// Layer for this node class (subclasses of _ASDisplayLayer make one; other CALayer classes use their own factory).
    open func didLoad() {}
    /// ASInterfaceStateDelegate hook (Telegram's Texture fork declares it on ASDisplayNode); subclasses may override.
    open func nodeDidLoad() {}
    open func baseDidInit() {}

    private var model: CALayer { _layer ?? pending }

    // MARK: hierarchy
    public var subnodes: [ASDisplayNode]? { _subnodes }
    open func addSubnode(_ subnode: ASDisplayNode) { insertSubnode(subnode, at: _subnodes.count) }
    open func insertSubnode(_ subnode: ASDisplayNode, at idx: Int) {
        if subnode === self { return }
        let wasMine = subnode.supernode === self
        if wasMine, let cur = _subnodes.firstIndex(where: { $0 === subnode }) { _subnodes.remove(at: cur) }
        else { subnode.removeFromSupernode() }
        let i = max(0, min(idx, _subnodes.count))
        _subnodes.insert(subnode, at: i)
        subnode.supernode = self
        if isNodeLoaded { attachSubnodeBacking(subnode, at: i) }
        if !wasMine && isInHierarchy && subnode.isNodeLoaded && subnode.isLayerBacked { subnode.setInHierarchy(true) }
    }
    open func insertSubnode(_ subnode: ASDisplayNode, belowSubnode below: ASDisplayNode) {
        guard let i = _subnodes.firstIndex(where: { $0 === below }) else { addSubnode(subnode); return }
        let adj = (subnode.supernode === self && (_subnodes.firstIndex { $0 === subnode } ?? Int.max) < i) ? i - 1 : i
        insertSubnode(subnode, at: adj)
    }
    open func insertSubnode(_ subnode: ASDisplayNode, aboveSubnode above: ASDisplayNode) {
        guard let i = _subnodes.firstIndex(where: { $0 === above }) else { addSubnode(subnode); return }
        let adj = (subnode.supernode === self && (_subnodes.firstIndex { $0 === subnode } ?? Int.max) < i) ? i : i + 1
        insertSubnode(subnode, at: adj)
    }
    open func replaceSubnode(_ subnode: ASDisplayNode, withSubnode replacement: ASDisplayNode) {
        guard let i = _subnodes.firstIndex(where: { $0 === subnode }) else { return }
        subnode.removeFromSupernode()
        insertSubnode(replacement, at: i)
    }
    open func removeFromSupernode() {
        guard let s = supernode else { return }
        s._subnodes.removeAll { $0 === self }
        supernode = nil
        if isNodeLoaded {
            if let v = _view, v.superview != nil { v.removeFromSuperview() } else { _layer?.removeFromSuperlayer() }
            if isLayerBacked && isInHierarchy { setInHierarchy(false) }
        }
    }
    /// Puts the subnode's view/layer into ours, ordered before the backing of the next loaded sibling.
    private func attachSubnodeBacking(_ sub: ASDisplayNode, at index: Int?) {
        let idx = index ?? (_subnodes.firstIndex { $0 === sub } ?? _subnodes.count)
        let next = _subnodes[(idx + 1)...].first { $0.isNodeLoaded && ($0._layer?.superlayer === _layer) }
        if let myView = _view, !sub.isLayerBacked {
            let sv = sub.view
            if let nv = next?._view, nv.superview === myView { myView.insertSubview(sv, belowSubview: nv) }
            else if let nl = next?._layer { myView.addSubview(sv); myView.layer.insertSublayer(sv.layer, below: nl) }
            else { myView.addSubview(sv) }
        } else {
            let sl = sub.isLayerBacked ? sub.layer : sub.view.layer
            if let nl = next?._layer { layer.insertSublayer(sl, below: nl) } else { layer.addSublayer(sl) }
        }
    }
    open func supernodes() -> [ASDisplayNode] {
        var r: [ASDisplayNode] = []; var s = supernode
        while let c = s { r.append(c); s = c.supernode }
        return r
    }
    public func supernode(of cls: AnyClass, includingSelf: Bool) -> ASDisplayNode? {
        var s: ASDisplayNode? = includingSelf ? self : supernode
        while let c = s { if type(of: c) == cls || c.isKind(of: cls) { return c }; s = c.supernode }
        return nil
    }

    // MARK: interface state
    public private(set) var isInHierarchy = false
    public var isVisible: Bool { interfaceState.contains(.visible) }
    public var isInDisplayState: Bool { interfaceState.contains(.display) }
    public var isInPreloadState: Bool { interfaceState.contains(.preload) }
    func setInHierarchy(_ v: Bool) {
        guard v != isInHierarchy else { return }
        if v {
            willEnterHierarchy()
            isInHierarchy = true
            didEnterHierarchy()
            setInterfaceState(.inHierarchy)
        } else {
            isInHierarchy = false
            didExitHierarchy()
            setInterfaceState([])
        }
        for s in _subnodes where s.isNodeLoaded && (s.isLayerBacked || s._view?.superview == nil || v == false) {
            if s.isLayerBacked || !v { s.setInHierarchy(v) }
        }
    }
    func setInterfaceState(_ new: ASInterfaceState) {
        let old = interfaceState
        guard new != old else { return }
        interfaceState = new
        interfaceStateDidChange(new, from: old)
        let entered = new.subtracting(old), exited = old.subtracting(new)
        if entered.contains(.preload) { didEnterPreloadState() }
        if entered.contains(.display) { didEnterDisplayState() }
        if entered.contains(.visible) { didEnterVisibleState() }
        if exited.contains(.visible) { didExitVisibleState() }
        if exited.contains(.display) { didExitDisplayState() }
        if exited.contains(.preload) { didExitPreloadState() }
        for d in interfaceDelegates { d.d?.interfaceStateDidChange(new, from: old) }
    }
    open func willEnterHierarchy() {}
    open func didEnterHierarchy() {}
    open func didExitHierarchy() {}
    open func interfaceStateDidChange(_ newState: ASInterfaceState, from oldState: ASInterfaceState) {}
    open func didEnterVisibleState() { interfaceDelegates.forEach { $0.d?.didEnterVisibleState() } }
    open func didExitVisibleState() { interfaceDelegates.forEach { $0.d?.didExitVisibleState() } }
    open func didEnterDisplayState() { interfaceDelegates.forEach { $0.d?.didEnterDisplayState() } }
    open func didExitDisplayState() { interfaceDelegates.forEach { $0.d?.didExitDisplayState() } }
    open func didEnterPreloadState() { interfaceDelegates.forEach { $0.d?.didEnterPreloadState() } }
    open func didExitPreloadState() { interfaceDelegates.forEach { $0.d?.didExitPreloadState() } }
    final class WeakInterfaceDelegate { weak var d: ASInterfaceStateDelegate?; init(_ d: ASInterfaceStateDelegate) { self.d = d } }
    open func addInterfaceStateDelegate(_ d: ASInterfaceStateDelegate) { interfaceDelegates.append(WeakInterfaceDelegate(d)) }
    open func removeInterfaceStateDelegate(_ d: ASInterfaceStateDelegate) { interfaceDelegates.removeAll { $0.d === d || $0.d == nil } }
    open func recursivelySetInterfaceState(_ s: ASInterfaceState) { setInterfaceState(s); _subnodes.forEach { $0.recursivelySetInterfaceState(s) } }

    // MARK: layout
    open func setNeedsLayout() { if isNodeLoaded { layer.setNeedsLayout() } }
    open func layoutIfNeeded() { if isNodeLoaded { layer.layoutIfNeeded() } }
    open func layout() {}
    open func layoutDidFinish() {}
    open func calculatedLayoutDidChange() {}
    open func invalidateCalculatedLayout() { calculatedSize = .zero }
    open func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize { constrainedSize }
    open func calculateLayoutThatFits(_ constrainedSize: ASSizeRange) -> ASLayout {
        ASLayout(size: calculateSizeThatFits(constrainedSize.max), element: self)
    }
    @discardableResult open func measure(_ constrainedSize: CGSize) -> CGSize {
        let s = calculateSizeThatFits(constrainedSize)
        calculatedSize = s
        constrainedSizeForCalculatedLayout = ASSizeRange(min: .zero, max: constrainedSize)
        return s
    }
    open func layoutThatFits(_ constrainedSize: ASSizeRange) -> ASLayout {
        let l = calculateLayoutThatFits(constrainedSize)
        calculatedSize = l.size
        constrainedSizeForCalculatedLayout = constrainedSize
        return l
    }
    public var calculatedLayout: ASLayout? { ASLayout(size: calculatedSize, element: self) }
    open func transitionLayout(withAnimation animated: Bool, shouldMeasureAsync: Bool, measurementCompletion: (() -> Void)? = nil) { setNeedsLayout(); measurementCompletion?() }
    open func cancelLayoutTransition() {}
    /// Called by the backing view/layer during layout.
    func webLayout() {
        layout()
        layoutDidFinish()
        interfaceDelegates.forEach { $0.d?.nodeDidLayout() }
    }

    // MARK: display
    open func setNeedsDisplay() { if isNodeLoaded { layer.setNeedsDisplay() } }
    open func setNeedsDisplay(atScale contentsScale: CGFloat) { if isNodeLoaded { layer.contentsScale = contentsScale; layer.setNeedsDisplay() } }
    open func recursivelySetNeedsDisplay(atScale contentsScale: CGFloat) { setNeedsDisplay(atScale: contentsScale); _subnodes.forEach { $0.recursivelySetNeedsDisplay(atScale: contentsScale) } }
    open func displayImmediately() { if isNodeLoaded { layer.setNeedsDisplay(); layer.displayIfNeeded() } }
    open func recursivelyEnsureDisplaySynchronously(_ sync: Bool) { displayImmediately(); _subnodes.forEach { $0.recursivelyEnsureDisplaySynchronously(sync) } }
    open func recursivelySetDisplaySuspended(_ flag: Bool) { displaySuspended = flag; _subnodes.forEach { $0.recursivelySetDisplaySuspended(flag) } }
    open func recursivelyClearContents() { clearContents(); _subnodes.forEach { $0.recursivelyClearContents() } }
    open func clearContents() {}
    open func displayWillStartAsynchronously(_ asynchronously: Bool) {}
    open func displayDidFinish() {}
    open func hierarchyDisplayDidFinish() {}
    open func subnodeDisplayWillStart(_ subnode: ASDisplayNode) {}
    open func subnodeDisplayDidFinish(_ subnode: ASDisplayNode) {}
    open var contentsScaleForDisplay: CGFloat { model.contentsScale }
    open func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? { nil }
    nonisolated(unsafe) static var baseDrawCalled = false
    nonisolated(unsafe) static var baseDisplayCalled = false
    open class func draw(_ bounds: CGRect, withParameters parameters: Any?, isCancelled: () -> Bool, isRasterizing: Bool) { baseDrawCalled = true }
    open class func display(withParameters parameters: Any?, isCancelled: () -> Bool) -> UIImage? { baseDisplayCalled = true; return nil }
    open func placeholderImage() -> UIImage? { nil }

    /// Synchronous display: image from display(withParameters:) or drawing from draw(_:withParameters:...).
    func webDisplay(_ l: _ASDisplayLayer) {
        guard !displaySuspended else { return }
        let bounds = l.bounds
        guard bounds.width > 0, bounds.height > 0 else { return }
        displayWillStartAsynchronously(false)
        let params = drawParameters(forAsyncLayer: l)
        ASDisplayNode.baseDisplayCalled = false
        if let image = type(of: self).display(withParameters: params, isCancelled: { false }) {
            l.contents = image.cgImage
            displayDidFinish()
            return
        }
        guard ASDisplayNode.baseDisplayCalled else { displayDidFinish(); return }
        let scale = l.contentsScale
        guard let ctx = CGContext(data: nil, width: max(1, Int((bounds.width * scale).rounded(.up))), height: max(1, Int((bounds.height * scale).rounded(.up))),
                                  bitsPerComponent: 8, bytesPerRow: 0, space: .deviceRGB, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue) else { return }
        ctx.translateBy(x: 0, y: CGFloat(ctx.height))
        ctx.scaleBy(x: scale, y: -scale)
        let setup = ctx.ops.count
        UIGraphicsPushContext(ctx)
        if isOpaque, let bg = l.backgroundColor { ctx.setFillColor(bg); ctx.fill(CGRect(origin: .zero, size: bounds.size)) }
        willDisplayNodeContentWithRenderingContext?(ctx, params)
        ASDisplayNode.baseDrawCalled = false
        type(of: self).draw(CGRect(origin: .zero, size: bounds.size), withParameters: params, isCancelled: { false }, isRasterizing: false)
        let drew = !ASDisplayNode.baseDrawCalled
        didDisplayNodeContentWithRenderingContext?(ctx, params)
        UIGraphicsPopContext()
        if drew || ctx.ops.count > setup + (isOpaque ? 2 : 0) { l.contents = ctx.makeImage() }
        displayDidFinish()
    }

    // MARK: geometry & appearance (mirrored onto the backing layer/view)
    open var frame: CGRect {
        get { model.frame }
        set { model.frame = newValue }
    }
    open var bounds: CGRect {
        get { model.bounds }
        set { model.bounds = newValue }
    }
    open var position: CGPoint {
        get { model.position }
        set { model.position = newValue }
    }
    open var anchorPoint: CGPoint {
        get { model.anchorPoint }
        set { model.anchorPoint = newValue }
    }
    open var zPosition: CGFloat {
        get { model.zPosition }
        set { model.zPosition = newValue }
    }
    open var transform: CATransform3D {
        get { model.transform }
        set { model.transform = newValue }
    }
    open var subnodeTransform: CATransform3D {
        get { model.sublayerTransform }
        set { model.sublayerTransform = newValue }
    }
    open var alpha: CGFloat {
        get { CGFloat(model.opacity) }
        set { model.opacity = Float(newValue) }
    }
    open var isHidden: Bool {
        get { model.isHidden }
        set { model.isHidden = newValue }
    }
    open var isOpaque: Bool {
        get { model.isOpaque }
        set { model.isOpaque = newValue }
    }
    open var clipsToBounds: Bool {
        get { model.masksToBounds }
        set { model.masksToBounds = newValue }
    }
    open var cornerRadius: CGFloat {
        get { model.cornerRadius }
        set { model.cornerRadius = newValue }
    }
    open var contents: Any? {
        get { model.contents }
        set { model.contents = newValue }
    }
    open var contentsRect: CGRect {
        get { model.contentsRect }
        set { model.contentsRect = newValue }
    }
    open var contentsCenter: CGRect {
        get { model.contentsCenter }
        set { model.contentsCenter = newValue }
    }
    open var contentsScale: CGFloat {
        get { model.contentsScale }
        set { model.contentsScale = newValue }
    }
    open var rasterizationScale: CGFloat {
        get { model.rasterizationScale }
        set { model.rasterizationScale = newValue }
    }
    open var contentsGravity: String {
        get { model.contentsGravity.rawValue }
        set { model.contentsGravity = CALayerContentsGravity(rawValue: newValue) }
    }
    open var backgroundColor: UIColor? {
        get { model.backgroundColor.map { UIColor(cgColor: $0) } }
        set { model.backgroundColor = newValue?.cgColor }
    }
    open var shadowColor: CGColor? {
        get { model.shadowColor }
        set { model.shadowColor = newValue }
    }
    open var shadowOpacity: CGFloat {
        get { CGFloat(model.shadowOpacity) }
        set { model.shadowOpacity = Float(newValue) }
    }
    open var shadowOffset: CGSize {
        get { model.shadowOffset }
        set { model.shadowOffset = newValue }
    }
    open var shadowRadius: CGFloat {
        get { model.shadowRadius }
        set { model.shadowRadius = newValue }
    }
    open var borderWidth: CGFloat {
        get { model.borderWidth }
        set { model.borderWidth = newValue }
    }
    open var borderColor: CGColor? {
        get { model.borderColor }
        set { model.borderColor = newValue }
    }
    open var allowsGroupOpacity: Bool {
        get { model.allowsGroupOpacity }
        set { model.allowsGroupOpacity = newValue }
    }
    open var allowsEdgeAntialiasing: Bool {
        get { model.allowsEdgeAntialiasing }
        set { model.allowsEdgeAntialiasing = newValue }
    }
    open var edgeAntialiasingMask: UInt32 {
        get { model.edgeAntialiasingMask.rawValue }
        set { model.edgeAntialiasingMask = CAEdgeAntialiasingMask(rawValue: newValue) }
    }
    open var needsDisplayOnBoundsChange: Bool {
        get { model.needsDisplayOnBoundsChange }
        set { model.needsDisplayOnBoundsChange = newValue }
    }
    open var isUserInteractionEnabled: Bool {
        get { _view?.isUserInteractionEnabled ?? _userInteractionEnabled }
        set { _userInteractionEnabled = newValue; _view?.isUserInteractionEnabled = newValue }
    }
    open var isExclusiveTouch: Bool {
        get { _view?.isExclusiveTouch ?? _exclusiveTouch }
        set { _exclusiveTouch = newValue; _view?.isExclusiveTouch = newValue }
    }
    open var autoresizingMask: UIView.AutoresizingMask {
        get { _view?.autoresizingMask ?? _autoresizingMask }
        set { _autoresizingMask = newValue; _view?.autoresizingMask = newValue }
    }
    open var autoresizesSubviews: Bool {
        get { _view?.autoresizesSubviews ?? _autoresizesSubviews }
        set { _autoresizesSubviews = newValue; _view?.autoresizesSubviews = newValue }
    }
    open var tintColor: UIColor! {
        get { _view?.tintColor ?? _tintColor ?? supernode?.tintColor ?? UIColor.systemBlue }
        set { _tintColor = newValue; _view?.tintColor = newValue; tintColorDidChange() }
    }
    open func tintColorDidChange() {}
    open var contentMode: UIView.ContentMode {
        get { _view?.contentMode ?? _contentMode }
        set { _contentMode = newValue; if let v = _view { v.contentMode = newValue } else { model.contentsGravity = UIView.gravityFor(newValue) } }
    }
    open var semanticContentAttribute: UISemanticContentAttribute {
        get { _view?.semanticContentAttribute ?? _semanticContentAttribute }
        set { _semanticContentAttribute = newValue; _view?.semanticContentAttribute = newValue }
    }
    open var layoutMargins: UIEdgeInsets {
        get { _view?.layoutMargins ?? _layoutMargins }
        set { _layoutMargins = newValue; _view?.layoutMargins = newValue }
    }
    open func layoutMarginsDidChange() {}
    open var safeAreaInsets: UIEdgeInsets { _view?.safeAreaInsets ?? .zero }
    open func safeAreaInsetsDidChange() {}

    // MARK: geometry conversion
    open func convert(_ point: CGPoint, to node: ASDisplayNode?) -> CGPoint { layer.convert(point, to: node?.layer) }
    open func convert(_ point: CGPoint, from node: ASDisplayNode?) -> CGPoint { layer.convert(point, from: node?.layer) }
    open func convert(_ rect: CGRect, to node: ASDisplayNode?) -> CGRect { layer.convert(rect, to: node?.layer) }
    open func convert(_ rect: CGRect, from node: ASDisplayNode?) -> CGRect { layer.convert(rect, from: node?.layer) }

    // MARK: touches & responders (forwarded from _ASDisplayView)
    open func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        bounds.inset(by: UIEdgeInsets(top: hitTestSlop.top, left: hitTestSlop.left, bottom: hitTestSlop.bottom, right: hitTestSlop.right)).contains(point)
    }
    open func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? { (_view as? _ASDisplayView)?.webSuperHitTest(point, with: event) }
    open func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) { (_view as? _ASDisplayView)?.webSuperTouchesBegan(touches, with: event) }
    open func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) { (_view as? _ASDisplayView)?.webSuperTouchesMoved(touches, with: event) }
    open func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { (_view as? _ASDisplayView)?.webSuperTouchesEnded(touches, with: event) }
    open func touchesCancelled(_ touches: Set<UITouch>?, with event: UIEvent?) { (_view as? _ASDisplayView)?.webSuperTouchesCancelled(touches ?? [], with: event) }
    open func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool { true }
    open func canBecomeFirstResponder() -> Bool { false }
    @discardableResult open func becomeFirstResponder() -> Bool { false }
    open func canResignFirstResponder() -> Bool { true }
    @discardableResult open func resignFirstResponder() -> Bool { _view?.resignFirstResponder() ?? false }
    open func isFirstResponder() -> Bool { _view?.isFirstResponder ?? false }
    open func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool { false }

    // MARK: accessibility
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
    open var accessibilityHeaderElements: [Any]?
    open var accessibilityIdentifier: String?
    open var accessibilityElements: [Any]?
    open var accessibilityCustomActions: [UIAccessibilityCustomAction]?
    open var accessibilityCustomRotors: [UIAccessibilityCustomRotor]?
    open var accessibilityRespondsToUserInteraction = true
    open var accessibilityUserInputLabels: [String]?
    open var accessibilityContainerType: UIAccessibilityContainerType = .none
    open func accessibilityActivate() -> Bool { false }
    open func accessibilityIncrement() {}
    open func accessibilityDecrement() {}
    open func accessibilityScroll(_ direction: UIAccessibilityScrollDirection) -> Bool { false }
    open func accessibilityPerformEscape() -> Bool { false }
    open func accessibilityPerformMagicTap() -> Bool { false }
    open func accessibilityElementDidBecomeFocused() {}
    open func accessibilityElementDidLoseFocus() {}
    open func performAccessibilityCustomAction(_ action: UIAccessibilityCustomAction) -> Bool { action.actionHandler?(action) ?? false }
    open var defaultAccessibilityLabel: String? { nil }
    open var defaultAccessibilityTraits: UIAccessibilityTraits { [] }

    // MARK: description
    open func displayNodeRecursiveDescription() -> String { recursiveDescription(0) }
    func recursiveDescription(_ depth: Int) -> String {
        String(repeating: "  ", count: depth) + "<\(type(of: self)) frame=\(frame)>\n" + _subnodes.map { $0.recursiveDescription(depth + 1) }.joined()
    }
    open var detailedLayoutDescription: String { "" }
    open override var description: String { "<\(type(of: self)) frame=\(frame)>" }
    public class var nonFatalErrorBlock: ((Error) -> Void)? { get { nil } set {} }
    public class var shouldStoreUnflattenedLayouts: Bool { get { false } set {} }
}

extension UIView {
    static func gravityFor(_ m: ContentMode) -> CALayerContentsGravity {
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
}

// MARK: backing view & layer

open class _ASDisplayLayer: CALayer {
    open var displaysAsynchronously = false
    open var isDisplaySuspended = false
    public override init() { super.init(); needsDisplayOnBoundsChange = true }
    public override init(layer: Any) { super.init(layer: layer) }
    public required init?(coder: NSCoder) { super.init(coder: coder) }
    open override class func webMakeLayer() -> CALayer { _ASDisplayLayer() }
    open func cancelAsyncDisplay() {}
    open func displayImmediately() { setNeedsDisplay(); displayIfNeeded() }
    open override func display() {
        if let n = asyncdisplaykit_node { n.webDisplay(self) } else { super.display() }
    }
    open override func layoutSublayers() {
        super.layoutSublayers()
        if let n = asyncdisplaykit_node, n.isLayerBacked { n.webLayout() }
    }
}

open class _ASDisplayView: UIView {
    public required override init(frame: CGRect) { super.init(frame: frame) }
    public required init?(coder: NSCoder) { super.init(coder: coder) }
    open override class var layerClass: AnyClass { _ASDisplayLayer.self }
    var node: ASDisplayNode? { asyncdisplaykit_node }
    open override func layoutSubviews() { super.layoutSubviews(); node?.webLayout() }
    open override func didMoveToWindow() {
        super.didMoveToWindow()
        node?.setInHierarchy(window != nil)
    }
    open override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let n = node { return n.hitTest(point, with: event) }
        return super.hitTest(point, with: event)
    }
    open override func point(inside point: CGPoint, with event: UIEvent?) -> Bool { node?.point(inside: point, with: event) ?? super.point(inside: point, with: event) }
    func webSuperHitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? { super.hitTest(point, with: event) }
    open override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) { if let n = node { n.touchesBegan(touches, with: event) } else { super.touchesBegan(touches, with: event) } }
    open override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) { if let n = node { n.touchesMoved(touches, with: event) } else { super.touchesMoved(touches, with: event) } }
    open override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { if let n = node { n.touchesEnded(touches, with: event) } else { super.touchesEnded(touches, with: event) } }
    open override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { if let n = node { n.touchesCancelled(touches, with: event) } else { super.touchesCancelled(touches, with: event) } }
    func webSuperTouchesBegan(_ t: Set<UITouch>, with e: UIEvent?) { super.touchesBegan(t, with: e) }
    func webSuperTouchesMoved(_ t: Set<UITouch>, with e: UIEvent?) { super.touchesMoved(t, with: e) }
    func webSuperTouchesEnded(_ t: Set<UITouch>, with e: UIEvent?) { super.touchesEnded(t, with: e) }
    func webSuperTouchesCancelled(_ t: Set<UITouch>, with e: UIEvent?) { super.touchesCancelled(t, with: e) }
    open override func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool { node?.gestureRecognizerShouldBegin(g) ?? true }
    open override var canBecomeFirstResponder: Bool { node?.canBecomeFirstResponder() ?? false }
    open override func tintColorDidChange() { super.tintColorDidChange(); node?.tintColorDidChange() }
    open override func safeAreaInsetsDidChange() { super.safeAreaInsetsDidChange(); node?.safeAreaInsetsDidChange() }
    open override func layoutMarginsDidChange() { super.layoutMarginsDidChange(); node?.layoutMarginsDidChange() }
    // accessibility reads through to the node
    open override var accessibilityElements: [Any]? { get { node?.accessibilityElements ?? super.accessibilityElements } set { super.accessibilityElements = newValue } }
}

// MARK: node lookup from views and layers

final class WeakNodeBox { weak var node: ASDisplayNode?; init(_ n: ASDisplayNode?) { node = n } }
nonisolated(unsafe) private var nodeKey: UInt8 = 0
extension UIView {
    public var asyncdisplaykit_node: ASDisplayNode? {
        get { (objc_getAssociatedObject(self, &nodeKey) as? WeakNodeBox)?.node }
        set { objc_setAssociatedObject(self, &nodeKey, WeakNodeBox(newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    public func addSubnode(_ node: ASDisplayNode) {
        if let n = asyncdisplaykit_node { n.addSubnode(node) } else { addSubview(node.view) }
    }
}
extension CALayer {
    public var asyncdisplaykit_node: ASDisplayNode? {
        get { (objc_getAssociatedObject(self, &nodeKey) as? WeakNodeBox)?.node }
        set { objc_setAssociatedObject(self, &nodeKey, WeakNodeBox(newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    public func addSubnode(_ node: ASDisplayNode) {
        if let n = asyncdisplaykit_node { n.addSubnode(node) } else { addSublayer(node.layer) }
    }
}

public func ASViewToDisplayNode(_ view: UIView?) -> ASDisplayNode? { view?.asyncdisplaykit_node }
public func ASLayerToDisplayNode(_ layer: CALayer?) -> ASDisplayNode? { layer?.asyncdisplaykit_node }
