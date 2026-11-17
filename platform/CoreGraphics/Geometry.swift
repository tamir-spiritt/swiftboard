// Swiftboard CoreGraphics for the browser (MIT).
// Foundation on WASI already defines CGFloat/CGPoint/CGSize/CGRect; this adds the rest of CoreGraphics' geometry.
@_exported import Foundation
@_exported import WebCompat

public typealias CGGlyph = UInt16
public typealias UniChar = UInt16
public typealias CGFontIndex = UInt16

public struct CGVector: Equatable, Hashable {
    public var dx: CGFloat
    public var dy: CGFloat
    public init() { dx = 0; dy = 0 }
    public init(dx: CGFloat, dy: CGFloat) { self.dx = dx; self.dy = dy }
    public init(dx: Double, dy: Double) { self.dx = CGFloat(dx); self.dy = CGFloat(dy) }
    public init(dx: Int, dy: Int) { self.dx = CGFloat(dx); self.dy = CGFloat(dy) }
    public static var zero: CGVector { CGVector() }
}

public struct CGAffineTransform: Equatable, Hashable {
    public var a: CGFloat, b: CGFloat, c: CGFloat, d: CGFloat, tx: CGFloat, ty: CGFloat
    public init() { self.init(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0) }
    public init(a: CGFloat, b: CGFloat, c: CGFloat, d: CGFloat, tx: CGFloat, ty: CGFloat) {
        self.a = a; self.b = b; self.c = c; self.d = d; self.tx = tx; self.ty = ty
    }
    public init(_ a: CGFloat, _ b: CGFloat, _ c: CGFloat, _ d: CGFloat, _ tx: CGFloat, _ ty: CGFloat) {
        self.init(a: a, b: b, c: c, d: d, tx: tx, ty: ty)
    }
    public static let identity = CGAffineTransform()
    public init(translationX tx: CGFloat, y ty: CGFloat) { self.init(a: 1, b: 0, c: 0, d: 1, tx: tx, ty: ty) }
    public init(scaleX sx: CGFloat, y sy: CGFloat) { self.init(a: sx, b: 0, c: 0, d: sy, tx: 0, ty: 0) }
    public init(rotationAngle angle: CGFloat) {
        let c = cos(angle), s = sin(angle)
        self.init(a: c, b: s, c: -s, d: c, tx: 0, ty: 0)
    }
    public var isIdentity: Bool { self == .identity }
    /// self then t
    public func concatenating(_ t: CGAffineTransform) -> CGAffineTransform {
        CGAffineTransform(a: a * t.a + b * t.c, b: a * t.b + b * t.d,
                          c: c * t.a + d * t.c, d: c * t.b + d * t.d,
                          tx: tx * t.a + ty * t.c + t.tx, ty: tx * t.b + ty * t.d + t.ty)
    }
    public func translatedBy(x: CGFloat, y: CGFloat) -> CGAffineTransform { CGAffineTransform(translationX: x, y: y).concatenating(self) }
    public func scaledBy(x: CGFloat, y: CGFloat) -> CGAffineTransform { CGAffineTransform(scaleX: x, y: y).concatenating(self) }
    public func rotated(by angle: CGFloat) -> CGAffineTransform { CGAffineTransform(rotationAngle: angle).concatenating(self) }
    public func inverted() -> CGAffineTransform {
        let det = a * d - b * c
        if det == 0 { return self }
        let ia = d / det, ib = -b / det, ic = -c / det, id = a / det
        return CGAffineTransform(a: ia, b: ib, c: ic, d: id, tx: -(tx * ia + ty * ic), ty: -(tx * ib + ty * id))
    }
}

public func CGAffineTransformMakeTranslation(_ tx: CGFloat, _ ty: CGFloat) -> CGAffineTransform { CGAffineTransform(translationX: tx, y: ty) }
public func CGAffineTransformMakeScale(_ sx: CGFloat, _ sy: CGFloat) -> CGAffineTransform { CGAffineTransform(scaleX: sx, y: sy) }
public func CGAffineTransformMakeRotation(_ a: CGFloat) -> CGAffineTransform { CGAffineTransform(rotationAngle: a) }
public func CGAffineTransformIsIdentity(_ t: CGAffineTransform) -> Bool { t.isIdentity }
public func CGAffineTransformConcat(_ a: CGAffineTransform, _ b: CGAffineTransform) -> CGAffineTransform { a.concatenating(b) }
public func CGAffineTransformInvert(_ t: CGAffineTransform) -> CGAffineTransform { t.inverted() }
public func CGAffineTransformTranslate(_ t: CGAffineTransform, _ x: CGFloat, _ y: CGFloat) -> CGAffineTransform { t.translatedBy(x: x, y: y) }
public func CGAffineTransformScale(_ t: CGAffineTransform, _ x: CGFloat, _ y: CGFloat) -> CGAffineTransform { t.scaledBy(x: x, y: y) }
public func CGAffineTransformRotate(_ t: CGAffineTransform, _ a: CGFloat) -> CGAffineTransform { t.rotated(by: a) }
public func CGAffineTransformEqualToTransform(_ a: CGAffineTransform, _ b: CGAffineTransform) -> Bool { a == b }
public let CGAffineTransformIdentity = CGAffineTransform.identity

extension CGPoint {
    public func applying(_ t: CGAffineTransform) -> CGPoint {
        CGPoint(x: t.a * x + t.c * y + t.tx, y: t.b * x + t.d * y + t.ty)
    }
}

extension CGSize {
    public func applying(_ t: CGAffineTransform) -> CGSize {
        CGSize(width: t.a * width + t.c * height, height: t.b * width + t.d * height)
    }
}

extension CGRect {
    public func applying(_ t: CGAffineTransform) -> CGRect {
        if isNull { return self }
        let pts = [CGPoint(x: minX, y: minY), CGPoint(x: maxX, y: minY), CGPoint(x: minX, y: maxY), CGPoint(x: maxX, y: maxY)].map { $0.applying(t) }
        let xs = pts.map { $0.x }, ys = pts.map { $0.y }
        return CGRect(x: xs.min()!, y: ys.min()!, width: xs.max()! - xs.min()!, height: ys.max()! - ys.min()!)
    }
}

public func CGRectGetMinX(_ r: CGRect) -> CGFloat { r.minX }
public func CGRectGetMaxX(_ r: CGRect) -> CGFloat { r.maxX }
public func CGRectGetMinY(_ r: CGRect) -> CGFloat { r.minY }
public func CGRectGetMaxY(_ r: CGRect) -> CGFloat { r.maxY }
public func CGRectGetMidX(_ r: CGRect) -> CGFloat { r.midX }
public func CGRectGetMidY(_ r: CGRect) -> CGFloat { r.midY }
public func CGRectGetWidth(_ r: CGRect) -> CGFloat { r.width }
public func CGRectGetHeight(_ r: CGRect) -> CGFloat { r.height }
public func CGRectIsEmpty(_ r: CGRect) -> Bool { r.isEmpty }
public func CGRectIsNull(_ r: CGRect) -> Bool { r.isNull }
public func CGRectEqualToRect(_ a: CGRect, _ b: CGRect) -> Bool { a == b }
public func CGRectMake(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect { CGRect(x: x, y: y, width: w, height: h) }
public func CGPointMake(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }
public func CGSizeMake(_ w: CGFloat, _ h: CGFloat) -> CGSize { CGSize(width: w, height: h) }
public func CGRectInset(_ r: CGRect, _ dx: CGFloat, _ dy: CGFloat) -> CGRect { r.insetBy(dx: dx, dy: dy) }
public func CGRectIntersectsRect(_ a: CGRect, _ b: CGRect) -> Bool { a.intersects(b) }
public func CGRectContainsPoint(_ r: CGRect, _ p: CGPoint) -> Bool { r.contains(p) }
public func CGPointEqualToPoint(_ a: CGPoint, _ b: CGPoint) -> Bool { a == b }
public func CGSizeEqualToSize(_ a: CGSize, _ b: CGSize) -> Bool { a == b }
public let CGRectZero = CGRect.zero
public let CGPointZero = CGPoint.zero
public let CGSizeZero = CGSize.zero
public let CGRectNull = CGRect.null

extension CGRect { public func equalTo(_ r: CGRect) -> Bool { self == r } }
extension CGPoint { public func equalTo(_ p: CGPoint) -> Bool { self == p } }
extension CGSize { public func equalTo(_ s: CGSize) -> Bool { self == s } }

/// CoreFoundation type identity for the CF-like classes.
public typealias CFTypeID = UInt
public protocol WebCFType: AnyObject { static var typeID: CFTypeID { get } }
public func CFGetTypeID(_ o: CFTypeRef?) -> CFTypeID {
    guard let o else { return 0 }
    if o is CGImage { return CGImage.typeID }
    if o is CGColor { return CGColor.typeID }
    if o is CGPath { return CGPath.typeID }
    if o is CGGradient { return CGGradient.typeID }
    if o is CGContext { return CGContext.typeID }
    if let t = type(of: o) as? WebCFType.Type { return t.typeID }
    return UInt(bitPattern: ObjectIdentifier(type(of: o)).hashValue)
}
extension CGImage: WebCFType { public static var typeID: CFTypeID { 1 } }
extension CGColor: WebCFType { public static var typeID: CFTypeID { 2 } }
extension CGPath: WebCFType { public static var typeID: CFTypeID { 3 } }
extension CGGradient: WebCFType { public static var typeID: CFTypeID { 4 } }
extension CGContext: WebCFType { public static var typeID: CFTypeID { 5 } }
