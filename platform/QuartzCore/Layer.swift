// Swiftboard QuartzCore (MIT): the CALayer tree. Display is synchronous: setNeedsDisplay marks the layer and
// `CALayer.webFlush()` (called by the host before painting) runs layout and display passes.
import Foundation

public struct CALayerContentsGravity: RawRepresentable, Hashable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let center = CALayerContentsGravity(rawValue: "center")
    public static let top = CALayerContentsGravity(rawValue: "top")
    public static let bottom = CALayerContentsGravity(rawValue: "bottom")
    public static let left = CALayerContentsGravity(rawValue: "left")
    public static let right = CALayerContentsGravity(rawValue: "right")
    public static let topLeft = CALayerContentsGravity(rawValue: "topLeft")
    public static let topRight = CALayerContentsGravity(rawValue: "topRight")
    public static let bottomLeft = CALayerContentsGravity(rawValue: "bottomLeft")
    public static let bottomRight = CALayerContentsGravity(rawValue: "bottomRight")
    public static let resize = CALayerContentsGravity(rawValue: "resize")
    public static let resizeAspect = CALayerContentsGravity(rawValue: "resizeAspect")
    public static let resizeAspectFill = CALayerContentsGravity(rawValue: "resizeAspectFill")
}
public struct CALayerContentsFilter: RawRepresentable, Hashable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let nearest = CALayerContentsFilter(rawValue: "nearest")
    public static let linear = CALayerContentsFilter(rawValue: "linear")
    public static let trilinear = CALayerContentsFilter(rawValue: "trilinear")
}
public struct CALayerContentsFormat: RawRepresentable, Hashable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let RGBA8Uint = CALayerContentsFormat(rawValue: "RGBA8")
    public static let RGBA16Float = CALayerContentsFormat(rawValue: "RGBAh")
    public static let gray8Uint = CALayerContentsFormat(rawValue: "Gray8")
}
public struct CALayerCornerCurve: RawRepresentable, Hashable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let circular = CALayerCornerCurve(rawValue: "circular")
    public static let continuous = CALayerCornerCurve(rawValue: "continuous")
}
public struct CACornerMask: OptionSet, Hashable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let layerMinXMinYCorner = CACornerMask(rawValue: 1)
    public static let layerMaxXMinYCorner = CACornerMask(rawValue: 2)
    public static let layerMinXMaxYCorner = CACornerMask(rawValue: 4)
    public static let layerMaxXMaxYCorner = CACornerMask(rawValue: 8)
}
public struct CAEdgeAntialiasingMask: OptionSet {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }
    public static let layerLeftEdge = CAEdgeAntialiasingMask(rawValue: 1)
    public static let layerRightEdge = CAEdgeAntialiasingMask(rawValue: 2)
    public static let layerBottomEdge = CAEdgeAntialiasingMask(rawValue: 4)
    public static let layerTopEdge = CAEdgeAntialiasingMask(rawValue: 8)
}
public struct CAAutoresizingMask: OptionSet {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }
}
public let kCAOnOrderIn = "onOrderIn"
public let kCAOnOrderOut = "onOrderOut"
public let kCATransition = "transition"
public let kCAGravityResize = "resize"
public let kCAGravityResizeAspect = "resizeAspect"
public let kCAGravityResizeAspectFill = "resizeAspectFill"

public protocol CALayerDelegate: AnyObject {
    func display(_ layer: CALayer)
    func draw(_ layer: CALayer, in ctx: CGContext)
    func layerWillDraw(_ layer: CALayer)
    func layoutSublayers(of layer: CALayer)
    func action(for layer: CALayer, forKey event: String) -> CAAction?
    /// Whether `display(_:)` is implemented (ObjC respondsToSelector).
    var webImplementsDisplay: Bool { get }
}
extension CALayerDelegate {
    public func display(_ layer: CALayer) {}
    public func draw(_ layer: CALayer, in ctx: CGContext) {}
    public func layerWillDraw(_ layer: CALayer) {}
    public func layoutSublayers(of layer: CALayer) {}
    public func action(for layer: CALayer, forKey event: String) -> CAAction? { nil }
    public var webImplementsDisplay: Bool { false }
}

open class CALayer: NSObject, CAMediaTiming {
    // geometry
    open var bounds: CGRect = .zero { didSet { if bounds.size != oldValue.size { if needsDisplayOnBoundsChange { setNeedsDisplay() }; setNeedsLayout() } } }
    open var position: CGPoint = .zero
    open var zPosition: CGFloat = 0
    open var anchorPoint = CGPoint(x: 0.5, y: 0.5)
    open var anchorPointZ: CGFloat = 0
    open var transform: CATransform3D = .identity
    open var sublayerTransform: CATransform3D = .identity
    open var frame: CGRect {
        get {
            let r = CGRect(x: position.x - bounds.width * anchorPoint.x, y: position.y - bounds.height * anchorPoint.y, width: bounds.width, height: bounds.height)
            if transform == .identity { return r }
            let t = CATransform3DGetAffineTransform(transform)
            let ap = CGPoint(x: position.x, y: position.y)
            let moved = r.offsetBy(dx: -ap.x, dy: -ap.y).applying(t)
            return moved.offsetBy(dx: ap.x, dy: ap.y)
        }
        set {
            bounds.size = newValue.size
            position = CGPoint(x: newValue.minX + newValue.width * anchorPoint.x, y: newValue.minY + newValue.height * anchorPoint.y)
        }
    }
    open func setAffineTransform(_ t: CGAffineTransform) { transform = CATransform3DMakeAffineTransform(t) }
    open func affineTransform() -> CGAffineTransform { CATransform3DGetAffineTransform(transform) }

    // hierarchy
    public internal(set) weak var superlayer: CALayer?
    private var _sublayers: [CALayer] = []
    open var sublayers: [CALayer]? {
        get { _sublayers.isEmpty ? nil : _sublayers }
        set {
            for l in _sublayers { l.superlayer = nil }
            _sublayers = []
            for l in newValue ?? [] { addSublayer(l) }
        }
    }
    open var mask: CALayer? { didSet { oldValue?.superlayer = nil; mask?.superlayer = nil } }
    open var masksToBounds = false
    open var isHidden = false
    open var isDoubleSided = true
    open var isGeometryFlipped = false
    open var name: String?
    open weak var delegate: CALayerDelegate?
    open var style: [AnyHashable: Any]?
    open var actions: [String: CAAction]?

    // contents
    open var contents: Any?
    open var contentsRect = CGRect(x: 0, y: 0, width: 1, height: 1)
    open var contentsCenter = CGRect(x: 0, y: 0, width: 1, height: 1)
    open var contentsGravity: CALayerContentsGravity = .resize
    open var contentsScale: CGFloat = 1
    open var contentsFormat: CALayerContentsFormat = .RGBA8Uint
    open var minificationFilter: CALayerContentsFilter = .linear
    open var magnificationFilter: CALayerContentsFilter = .linear
    open var minificationFilterBias: Float = 0
    open var isOpaque = false
    open var needsDisplayOnBoundsChange = false
    open var drawsAsynchronously = false
    open var wantsExtendedDynamicRangeContent = false

    // appearance
    open var backgroundColor: CGColor?
    open var cornerRadius: CGFloat = 0
    open var maskedCorners: CACornerMask = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
    open var cornerCurve: CALayerCornerCurve = .circular
    open var borderWidth: CGFloat = 0
    open var borderColor: CGColor? = CGColor.black
    open var opacity: Float = 1
    open var allowsGroupOpacity = true
    open var allowsEdgeAntialiasing = false
    open var edgeAntialiasingMask: CAEdgeAntialiasingMask = [.layerLeftEdge, .layerRightEdge, .layerBottomEdge, .layerTopEdge]
    open var compositingFilter: Any?
    open var filters: [Any]?
    open var backgroundFilters: [Any]?
    open var shouldRasterize = false
    open var rasterizationScale: CGFloat = 1
    open var shadowColor: CGColor? = CGColor.black
    open var shadowOpacity: Float = 0
    open var shadowOffset = CGSize(width: 0, height: -3)
    open var shadowRadius: CGFloat = 3
    open var shadowPath: CGPath?
    open var autoresizingMask: CAAutoresizingMask = []

    // timing
    open var beginTime: CFTimeInterval = 0
    open var duration: CFTimeInterval = 0
    open var speed: Float = 1
    open var timeOffset: CFTimeInterval = 0
    open var repeatCount: Float = 0
    open var autoreverses = false
    open var fillMode: CAMediaTimingFillMode = .removed

    // state
    private var displayNeeded = false
    private var layoutNeeded = false
    private var animationsByKey: [(String, CAAnimation)] = []
    private var animationSerial = 0
    var extraValues: [String: Any] = [:]

    public override init() { super.init() }
    public init(layer: Any) {
        super.init()
        if let l = layer as? CALayer { copyModel(from: l) }
    }
    public required init?(coder: NSCoder) { super.init() }

    /// Copies every model property (not hierarchy, delegate or animations) from `l`.
    public func webCopyState(from l: CALayer) { copyModel(from: l) }
    func copyModel(from l: CALayer) {
        bounds = l.bounds; position = l.position; zPosition = l.zPosition; anchorPoint = l.anchorPoint; anchorPointZ = l.anchorPointZ
        transform = l.transform; sublayerTransform = l.sublayerTransform; masksToBounds = l.masksToBounds; isHidden = l.isHidden
        isDoubleSided = l.isDoubleSided; isGeometryFlipped = l.isGeometryFlipped; name = l.name; style = l.style; actions = l.actions
        contents = l.contents; contentsRect = l.contentsRect; contentsCenter = l.contentsCenter; contentsGravity = l.contentsGravity
        contentsScale = l.contentsScale; contentsFormat = l.contentsFormat; minificationFilter = l.minificationFilter
        magnificationFilter = l.magnificationFilter; isOpaque = l.isOpaque; needsDisplayOnBoundsChange = l.needsDisplayOnBoundsChange
        drawsAsynchronously = l.drawsAsynchronously; backgroundColor = l.backgroundColor; cornerRadius = l.cornerRadius
        maskedCorners = l.maskedCorners; cornerCurve = l.cornerCurve; borderWidth = l.borderWidth; borderColor = l.borderColor
        opacity = l.opacity; allowsGroupOpacity = l.allowsGroupOpacity; allowsEdgeAntialiasing = l.allowsEdgeAntialiasing
        edgeAntialiasingMask = l.edgeAntialiasingMask; compositingFilter = l.compositingFilter; filters = l.filters
        backgroundFilters = l.backgroundFilters; shouldRasterize = l.shouldRasterize; rasterizationScale = l.rasterizationScale
        shadowColor = l.shadowColor; shadowOpacity = l.shadowOpacity; shadowOffset = l.shadowOffset; shadowRadius = l.shadowRadius
        shadowPath = l.shadowPath; mask = l.mask; for (k, v) in l.extraValues { extraValues[k] = v }
    }

    open class func defaultAction(forKey event: String) -> CAAction? { nil }
    open class func instancesRespond(to selector: Selector) -> Bool { false }
    open class func needsDisplay(forKey key: String) -> Bool { false }
    open class func defaultValue(forKey key: String) -> Any? { nil }

    /// Creates a layer of this class for UIView.layerClass (classes without `required init()` are made by the nearest
    /// QuartzCore ancestor that knows how; see webMakeLayer).
    open class func webMakeLayer() -> CALayer { CALayer() }

    // MARK: hierarchy
    open func addSublayer(_ layer: CALayer) { insertSublayer(layer, at: UInt32(_sublayers.count)) }
    open func insertSublayer(_ layer: CALayer, at idx: UInt32) {
        if layer === self { return }
        var i = Int(idx)
        if layer.superlayer === self, let cur = _sublayers.firstIndex(where: { $0 === layer }) {
            _sublayers.remove(at: cur)
            if cur < i { i -= 1 }
        } else {
            layer.removeFromSuperlayer()
        }
        i = max(0, min(i, _sublayers.count))
        _sublayers.insert(layer, at: i)
        layer.superlayer = self
        setNeedsLayout()
    }
    open func insertSublayer(_ layer: CALayer, below sibling: CALayer?) {
        guard let sibling, let idx = _sublayers.firstIndex(where: { $0 === sibling }) else { insertSublayer(layer, at: 0); return }
        if layer.superlayer === self, let cur = _sublayers.firstIndex(where: { $0 === layer }) {
            _sublayers.remove(at: cur)
            let j = _sublayers.firstIndex(where: { $0 === sibling })!
            _sublayers.insert(layer, at: j)
            return
        }
        insertSublayer(layer, at: UInt32(idx))
    }
    open func insertSublayer(_ layer: CALayer, above sibling: CALayer?) {
        guard let sibling, _sublayers.contains(where: { $0 === sibling }) else { addSublayer(layer); return }
        if layer.superlayer === self, let cur = _sublayers.firstIndex(where: { $0 === layer }) { _sublayers.remove(at: cur) }
        let j = _sublayers.firstIndex(where: { $0 === sibling })!
        if layer.superlayer !== self { layer.removeFromSuperlayer() }
        _sublayers.insert(layer, at: j + 1)
        layer.superlayer = self
    }
    open func replaceSublayer(_ old: CALayer, with new: CALayer) {
        guard let i = _sublayers.firstIndex(where: { $0 === old }) else { return }
        new.removeFromSuperlayer()
        _sublayers[i] = new
        old.superlayer = nil
        new.superlayer = self
    }
    open func removeFromSuperlayer() {
        guard let s = superlayer else { return }
        s._sublayers.removeAll { $0 === self }
        superlayer = nil
    }

    // MARK: display
    open func setNeedsDisplay() { displayNeeded = true; CALayer.webScheduleFlush() }
    open func setNeedsDisplay(_ r: CGRect) { setNeedsDisplay() }
    open func needsDisplay() -> Bool { displayNeeded }
    open func displayIfNeeded() { if displayNeeded { displayNeeded = false; display() } }
    open func display() {
        if let d = delegate, d.webImplementsDisplay { d.display(self); return }
        guard bounds.width > 0, bounds.height > 0 else { return }
        let scale = contentsScale
        let w = Int((bounds.width * scale).rounded(.up)), h = Int((bounds.height * scale).rounded(.up))
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: .deviceRGB,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue) else { return }
        // UIKit-style space: y down, points
        ctx.translateBy(x: 0, y: CGFloat(h))
        ctx.scaleBy(x: scale, y: -scale)
        ctx.translateBy(x: -bounds.minX, y: -bounds.minY)
        delegate?.layerWillDraw(self)
        let setup = ctx.ops.count
        draw(in: ctx)
        if ctx.ops.count > setup { contents = ctx.makeImage() }
    }
    open func draw(in ctx: CGContext) { delegate?.draw(self, in: ctx) }
    open func render(in ctx: CGContext) {}

    // MARK: layout
    open func setNeedsLayout() { layoutNeeded = true; CALayer.webScheduleFlush() }
    open func needsLayout() -> Bool { layoutNeeded }
    open func layoutIfNeeded() {
        if layoutNeeded { layoutNeeded = false; layoutSublayers() }
        for l in _sublayers { l.layoutIfNeeded() }
    }
    open func layoutSublayers() { delegate?.layoutSublayers(of: self) }
    open func preferredFrameSize() -> CGSize { bounds.size }

    nonisolated(unsafe) static var flushScheduled = false
    nonisolated(unsafe) public static var webRootLayers: [() -> CALayer?] = []
    static func webScheduleFlush() {
        guard !flushScheduled else { return }
        flushScheduled = true
        DispatchQueue.main.async { webFlush() }
    }
    /// Runs pending layout and display for every registered root (UIWindow registers itself).
    public static func webFlush() {
        flushScheduled = false
        for r in webRootLayers { r()?.webLayoutAndDisplay() }
    }
    /// Layout pass then display pass over this subtree.
    public func webLayoutAndDisplay() {
        layoutIfNeeded()
        webDisplayTree()
    }
    func webDisplayTree() {
        displayIfNeeded()
        mask?.webDisplayTree()
        for l in _sublayers { l.webDisplayTree() }
    }

    // MARK: geometry conversion
    /// Transform from this layer's coordinate space into its superlayer's.
    func toSuperTransform() -> CATransform3D {
        let ap = CGPoint(x: bounds.minX + bounds.width * anchorPoint.x, y: bounds.minY + bounds.height * anchorPoint.y)
        var t = CATransform3DMakeTranslation(-ap.x, -ap.y, 0)
        t = CATransform3DConcat(t, transform)
        t = CATransform3DConcat(t, CATransform3DMakeTranslation(position.x, position.y, 0))
        if let s = superlayer, s.sublayerTransform != .identity {
            let sap = CGPoint(x: s.bounds.minX + s.bounds.width * s.anchorPoint.x, y: s.bounds.minY + s.bounds.height * s.anchorPoint.y)
            t = CATransform3DConcat(t, CATransform3DMakeTranslation(-sap.x, -sap.y, 0))
            t = CATransform3DConcat(t, s.sublayerTransform)
            t = CATransform3DConcat(t, CATransform3DMakeTranslation(sap.x, sap.y, 0))
        }
        return t
    }
    func toRootTransform() -> (CATransform3D, CALayer) {
        var t = CATransform3D.identity
        var l: CALayer = self
        while let s = l.superlayer { t = CATransform3DConcat(t, l.toSuperTransform()); l = s }
        return (t, l)
    }
    open func convert(_ p: CGPoint, from layer: CALayer?) -> CGPoint {
        let (a, _) = (layer ?? self).toRootTransform()
        let (b, _) = toRootTransform()
        let rootP = layer == nil ? p : a.apply(p)
        return CATransform3DInvert(b).apply(rootP)
    }
    open func convert(_ p: CGPoint, to layer: CALayer?) -> CGPoint {
        let (a, _) = toRootTransform()
        let rootP = a.apply(p)
        guard let layer else { return rootP }
        return CATransform3DInvert(layer.toRootTransform().0).apply(rootP)
    }
    open func convert(_ r: CGRect, from layer: CALayer?) -> CGRect {
        let pts = [CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.maxX, y: r.minY), CGPoint(x: r.minX, y: r.maxY), CGPoint(x: r.maxX, y: r.maxY)].map { convert($0, from: layer) }
        return CALayer.bbox(pts)
    }
    open func convert(_ r: CGRect, to layer: CALayer?) -> CGRect {
        let pts = [CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.maxX, y: r.minY), CGPoint(x: r.minX, y: r.maxY), CGPoint(x: r.maxX, y: r.maxY)].map { convert($0, to: layer) }
        return CALayer.bbox(pts)
    }
    static func bbox(_ pts: [CGPoint]) -> CGRect {
        let xs = pts.map { $0.x }, ys = pts.map { $0.y }
        return CGRect(x: xs.min()!, y: ys.min()!, width: xs.max()! - xs.min()!, height: ys.max()! - ys.min()!)
    }
    open func convertTime(_ t: CFTimeInterval, from l: CALayer?) -> CFTimeInterval { t }
    open func convertTime(_ t: CFTimeInterval, to l: CALayer?) -> CFTimeInterval { t }
    open func contains(_ p: CGPoint) -> Bool { bounds.contains(p) }
    /// `p` in the superlayer's coordinates.
    open func hitTest(_ p: CGPoint) -> CALayer? {
        if isHidden || opacity <= 0 { return nil }
        let local = CATransform3DInvert(toSuperTransform()).apply(p)
        if masksToBounds && !contains(local) { return nil }
        for l in _sublayers.reversed() { if let h = l.hitTest(local) { return h } }
        return contains(local) ? self : nil
    }

    // MARK: animations
    open func add(_ anim: CAAnimation, forKey key: String?) {
        let a = anim.copy() as! CAAnimation
        let k = key ?? "anim-\(animationSerial)"
        animationSerial += 1
        if let i = animationsByKey.firstIndex(where: { $0.0 == k }) {
            let old = animationsByKey.remove(at: i).1
            if let d = old.delegate { DispatchQueue.main.async { d.animationDidStop(old, finished: false) } }
        }
        animationsByKey.append((k, a))
        let now = CACurrentMediaTime()
        let start = a.beginTime > 0 ? a.beginTime : now
        let end = start + a.webActiveDuration
        if end.isFinite { CATransaction.noteAnimation(endingAt: end) }
        a.delegate?.animationDidStart(a)
        guard end.isFinite else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0, end - now)) { [weak self] in
            guard let self else { a.delegate?.animationDidStop(a, finished: true); return }
            guard let i = self.animationsByKey.firstIndex(where: { $0.1 === a }) else { return }
            if a.isRemovedOnCompletion { self.animationsByKey.remove(at: i) }
            a.delegate?.animationDidStop(a, finished: true)
        }
    }
    open func animation(forKey key: String) -> CAAnimation? { animationsByKey.first { $0.0 == key }?.1 }
    open func animationKeys() -> [String]? { animationsByKey.isEmpty ? nil : animationsByKey.map { $0.0 } }
    open func removeAnimation(forKey key: String) {
        guard let i = animationsByKey.firstIndex(where: { $0.0 == key }) else { return }
        let a = animationsByKey.remove(at: i).1
        if let d = a.delegate { DispatchQueue.main.async { d.animationDidStop(a, finished: false) } }
    }
    open func removeAllAnimations() {
        let all = animationsByKey
        animationsByKey = []
        for (_, a) in all { if let d = a.delegate { DispatchQueue.main.async { d.animationDidStop(a, finished: false) } } }
    }
    /// Model values (frames are not interpolated yet).
    open func presentation() -> Self? { self }
    open func model() -> Self { self }
    open func action(forKey event: String) -> CAAction? {
        if let a = delegate?.action(for: self, forKey: event) { return a is NSNull ? nil : a }
        if let a = actions?[event] { return a is NSNull ? nil : a }
        return type(of: self).defaultAction(forKey: event)
    }

    open override var description: String { "<\(type(of: self)) frame=\(frame)>" }
}

extension CALayer: WebKeyValueCoding {
    public func webValue(forKey key: String) -> Any?? {
        switch key {
        case "position": return .some(NSValue(cgPoint: position))
        case "position.x": return .some(NSNumber(value: Double(position.x)))
        case "position.y": return .some(NSNumber(value: Double(position.y)))
        case "bounds": return .some(NSValue(cgRect: bounds))
        case "bounds.size": return .some(NSValue(cgSize: bounds.size))
        case "bounds.origin": return .some(NSValue(cgPoint: bounds.origin))
        case "bounds.size.width": return .some(NSNumber(value: Double(bounds.width)))
        case "bounds.size.height": return .some(NSNumber(value: Double(bounds.height)))
        case "opacity": return .some(NSNumber(value: opacity))
        case "cornerRadius": return .some(NSNumber(value: Double(cornerRadius)))
        case "transform": return .some(NSValue(caTransform3D: transform))
        case "sublayerTransform": return .some(NSValue(caTransform3D: sublayerTransform))
        case "transform.scale", "transform.scale.x": return .some(NSNumber(value: Double(transform.m11)))
        case "transform.scale.y": return .some(NSNumber(value: Double(transform.m22)))
        case "transform.rotation", "transform.rotation.z": return .some(NSNumber(value: Double(atan2(transform.m12, transform.m11))))
        case "transform.translation.x": return .some(NSNumber(value: Double(transform.m41)))
        case "transform.translation.y": return .some(NSNumber(value: Double(transform.m42)))
        case "backgroundColor": return .some(backgroundColor)
        case "contents": return .some(contents)
        case "contentsRect": return .some(NSValue(cgRect: contentsRect))
        case "anchorPoint": return .some(NSValue(cgPoint: anchorPoint))
        case "zPosition": return .some(NSNumber(value: Double(zPosition)))
        case "isHidden", "hidden": return .some(NSNumber(value: isHidden))
        case "shadowOpacity": return .some(NSNumber(value: shadowOpacity))
        case "borderWidth": return .some(NSNumber(value: Double(borderWidth)))
        default: return extraValues[key].map { .some($0) } ?? .some(nil)
        }
    }
    public func webSetValue(_ value: Any?, forKey key: String) -> Bool {
        func f() -> CGFloat { CGFloat((value as? NSNumber)?.doubleValue ?? 0) }
        switch key {
        case "position": position = (value as? NSValue)?.cgPointValue ?? position
        case "position.x": position.x = f()
        case "position.y": position.y = f()
        case "bounds": bounds = (value as? NSValue)?.cgRectValue ?? bounds
        case "bounds.size": bounds.size = (value as? NSValue)?.cgSizeValue ?? bounds.size
        case "bounds.origin": bounds.origin = (value as? NSValue)?.cgPointValue ?? bounds.origin
        case "opacity": opacity = Float(f())
        case "cornerRadius": cornerRadius = f()
        case "transform": transform = (value as? NSValue)?.caTransform3DValue ?? transform
        case "sublayerTransform": sublayerTransform = (value as? NSValue)?.caTransform3DValue ?? sublayerTransform
        case "transform.scale": let s = f(); transform = CATransform3DMakeScale(s, s, 1)
        case "transform.rotation", "transform.rotation.z": transform = CATransform3DMakeRotation(f(), 0, 0, 1)
        case "backgroundColor": backgroundColor = value.map { $0 as AnyObject } as? CGColor
        case "contents": contents = value
        case "anchorPoint": anchorPoint = (value as? NSValue)?.cgPointValue ?? anchorPoint
        case "zPosition": zPosition = f()
        default: extraValues[key] = value
        }
        return true
    }
}

// MARK: specialized layers

public struct CAShapeLayerFillRule: RawRepresentable, Hashable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let nonZero = CAShapeLayerFillRule(rawValue: "non-zero")
    public static let evenOdd = CAShapeLayerFillRule(rawValue: "even-odd")
}
public struct CAShapeLayerLineCap: RawRepresentable, Hashable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let butt = CAShapeLayerLineCap(rawValue: "butt")
    public static let round = CAShapeLayerLineCap(rawValue: "round")
    public static let square = CAShapeLayerLineCap(rawValue: "square")
}
public struct CAShapeLayerLineJoin: RawRepresentable, Hashable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let miter = CAShapeLayerLineJoin(rawValue: "miter")
    public static let round = CAShapeLayerLineJoin(rawValue: "round")
    public static let bevel = CAShapeLayerLineJoin(rawValue: "bevel")
}

open class CAShapeLayer: CALayer {
    open var path: CGPath?
    open var fillColor: CGColor? = CGColor.black
    open var fillRule: CAShapeLayerFillRule = .nonZero
    open var strokeColor: CGColor?
    open var strokeStart: CGFloat = 0
    open var strokeEnd: CGFloat = 1
    open var lineWidth: CGFloat = 1
    open var miterLimit: CGFloat = 10
    open var lineCap: CAShapeLayerLineCap = .butt
    open var lineJoin: CAShapeLayerLineJoin = .miter
    open var lineDashPhase: CGFloat = 0
    open var lineDashPattern: [NSNumber]?
    public override init() { super.init() }
    public override init(layer: Any) {
        super.init(layer: layer)
        if let l = layer as? CAShapeLayer { path = l.path; fillColor = l.fillColor; strokeColor = l.strokeColor; lineWidth = l.lineWidth }
    }
    public required init?(coder: NSCoder) { super.init(coder: coder) }
    open override class func webMakeLayer() -> CALayer { CAShapeLayer() }
}

public struct CAGradientLayerType: RawRepresentable, Hashable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let axial = CAGradientLayerType(rawValue: "axial")
    public static let radial = CAGradientLayerType(rawValue: "radial")
    public static let conic = CAGradientLayerType(rawValue: "conic")
}
open class CAGradientLayer: CALayer {
    open var colors: [Any]?
    open var locations: [NSNumber]?
    open var startPoint = CGPoint(x: 0.5, y: 0)
    open var endPoint = CGPoint(x: 0.5, y: 1)
    open var type: CAGradientLayerType = .axial
    public override init() { super.init() }
    public override init(layer: Any) { super.init(layer: layer) }
    public required init?(coder: NSCoder) { super.init(coder: coder) }
    open override class func webMakeLayer() -> CALayer { CAGradientLayer() }
}

open class CATransformLayer: CALayer {
    public override init() { super.init() }
    public override init(layer: Any) { super.init(layer: layer) }
    public required init?(coder: NSCoder) { super.init(coder: coder) }
    open override class func webMakeLayer() -> CALayer { CATransformLayer() }
}

open class CAReplicatorLayer: CALayer {
    open var instanceCount = 1
    open var preservesDepth = false
    open var instanceDelay: CFTimeInterval = 0
    open var instanceTransform: CATransform3D = .identity
    open var instanceColor: CGColor?
    open var instanceRedOffset: Float = 0
    open var instanceGreenOffset: Float = 0
    open var instanceBlueOffset: Float = 0
    open var instanceAlphaOffset: Float = 0
    public override init() { super.init() }
    public override init(layer: Any) { super.init(layer: layer) }
    public required init?(coder: NSCoder) { super.init(coder: coder) }
    open override class func webMakeLayer() -> CALayer { CAReplicatorLayer() }
}

public struct CATextLayerAlignmentMode: RawRepresentable, Hashable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let natural = CATextLayerAlignmentMode(rawValue: "natural")
    public static let left = CATextLayerAlignmentMode(rawValue: "left")
    public static let right = CATextLayerAlignmentMode(rawValue: "right")
    public static let center = CATextLayerAlignmentMode(rawValue: "center")
    public static let justified = CATextLayerAlignmentMode(rawValue: "justified")
}
open class CATextLayer: CALayer {
    open var string: Any?
    open var font: AnyObject?
    open var fontSize: CGFloat = 36
    open var foregroundColor: CGColor? = CGColor.white
    open var isWrapped = false
    open var alignmentMode: CATextLayerAlignmentMode = .natural
    open override class func webMakeLayer() -> CALayer { CATextLayer() }
}

public struct CAEmitterLayerEmitterShape: RawRepresentable, Hashable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let point = CAEmitterLayerEmitterShape(rawValue: "point")
    public static let line = CAEmitterLayerEmitterShape(rawValue: "line")
    public static let rectangle = CAEmitterLayerEmitterShape(rawValue: "rectangle")
    public static let circle = CAEmitterLayerEmitterShape(rawValue: "circle")
}
public struct CAEmitterLayerEmitterMode: RawRepresentable, Hashable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let points = CAEmitterLayerEmitterMode(rawValue: "points")
    public static let outline = CAEmitterLayerEmitterMode(rawValue: "outline")
    public static let surface = CAEmitterLayerEmitterMode(rawValue: "surface")
    public static let volume = CAEmitterLayerEmitterMode(rawValue: "volume")
}
public struct CAEmitterLayerRenderMode: RawRepresentable, Hashable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let unordered = CAEmitterLayerRenderMode(rawValue: "unordered")
    public static let oldestFirst = CAEmitterLayerRenderMode(rawValue: "oldestFirst")
    public static let oldestLast = CAEmitterLayerRenderMode(rawValue: "oldestLast")
    public static let backToFront = CAEmitterLayerRenderMode(rawValue: "backToFront")
    public static let additive = CAEmitterLayerRenderMode(rawValue: "additive")
}
open class CAEmitterCell: NSObject {
    open var name: String?
    open var isEnabled = true
    open var birthRate: Float = 0
    open var lifetime: Float = 0
    open var lifetimeRange: Float = 0
    open var velocity: CGFloat = 0
    open var velocityRange: CGFloat = 0
    open var emissionLongitude: CGFloat = 0
    open var emissionLatitude: CGFloat = 0
    open var emissionRange: CGFloat = 0
    open var scale: CGFloat = 1
    open var scaleRange: CGFloat = 0
    open var scaleSpeed: CGFloat = 0
    open var spin: CGFloat = 0
    open var spinRange: CGFloat = 0
    open var alphaSpeed: Float = 0
    open var alphaRange: Float = 0
    open var color: CGColor?
    open var contents: Any?
    open var contentsScale: CGFloat = 1
    open var xAcceleration: CGFloat = 0
    open var yAcceleration: CGFloat = 0
    open var emitterCells: [CAEmitterCell]?
    open var beginTime: CFTimeInterval = 0
    open var duration: CFTimeInterval = 0
    public override init() {}
}
open class CAEmitterLayer: CALayer {
    open var emitterCells: [CAEmitterCell]?
    open var birthRate: Float = 1
    open var lifetime: Float = 1
    open var emitterPosition: CGPoint = .zero
    open var emitterZPosition: CGFloat = 0
    open var emitterSize: CGSize = .zero
    open var emitterDepth: CGFloat = 0
    open var emitterShape: CAEmitterLayerEmitterShape = .point
    open var emitterMode: CAEmitterLayerEmitterMode = .volume
    open var renderMode: CAEmitterLayerRenderMode = .unordered
    open var preservesDepth = false
    open var velocity: Float = 1
    open var scale: Float = 1
    open var spin: Float = 1
    open var seed: UInt32 = 0
    open override class func webMakeLayer() -> CALayer { CAEmitterLayer() }
}
