// Swiftboard QuartzCore (MIT): CATransform3D and timing basics.
@_exported import CoreGraphics
import Foundation

public struct CATransform3D: Equatable, Hashable {
    public var m11: CGFloat, m12: CGFloat, m13: CGFloat, m14: CGFloat
    public var m21: CGFloat, m22: CGFloat, m23: CGFloat, m24: CGFloat
    public var m31: CGFloat, m32: CGFloat, m33: CGFloat, m34: CGFloat
    public var m41: CGFloat, m42: CGFloat, m43: CGFloat, m44: CGFloat
    public init() {
        m11 = 1; m12 = 0; m13 = 0; m14 = 0; m21 = 0; m22 = 1; m23 = 0; m24 = 0
        m31 = 0; m32 = 0; m33 = 1; m34 = 0; m41 = 0; m42 = 0; m43 = 0; m44 = 1
    }
    public init(m11: CGFloat, m12: CGFloat, m13: CGFloat, m14: CGFloat, m21: CGFloat, m22: CGFloat, m23: CGFloat, m24: CGFloat,
                m31: CGFloat, m32: CGFloat, m33: CGFloat, m34: CGFloat, m41: CGFloat, m42: CGFloat, m43: CGFloat, m44: CGFloat) {
        self.m11 = m11; self.m12 = m12; self.m13 = m13; self.m14 = m14; self.m21 = m21; self.m22 = m22; self.m23 = m23; self.m24 = m24
        self.m31 = m31; self.m32 = m32; self.m33 = m33; self.m34 = m34; self.m41 = m41; self.m42 = m42; self.m43 = m43; self.m44 = m44
    }
    public static let identity = CATransform3D()
    var m: [CGFloat] { [m11, m12, m13, m14, m21, m22, m23, m24, m31, m32, m33, m34, m41, m42, m43, m44] }
    init(_ a: [CGFloat]) {
        self.init(m11: a[0], m12: a[1], m13: a[2], m14: a[3], m21: a[4], m22: a[5], m23: a[6], m24: a[7],
                  m31: a[8], m32: a[9], m33: a[10], m34: a[11], m41: a[12], m42: a[13], m43: a[14], m44: a[15])
    }
    /// Column-major 4x4 matrix values for CSS `matrix3d(...)` (CoreAnimation's row vectors map straight onto it).
    public var cssMatrix3d: [Double] { m.map { Double($0) } }
}

public let CATransform3DIdentity = CATransform3D.identity
public func CATransform3DIsIdentity(_ t: CATransform3D) -> Bool { t == .identity }
public func CATransform3DEqualToTransform(_ a: CATransform3D, _ b: CATransform3D) -> Bool { a == b }
public func CATransform3DMakeTranslation(_ tx: CGFloat, _ ty: CGFloat, _ tz: CGFloat) -> CATransform3D {
    var t = CATransform3D(); t.m41 = tx; t.m42 = ty; t.m43 = tz; return t
}
public func CATransform3DMakeScale(_ sx: CGFloat, _ sy: CGFloat, _ sz: CGFloat) -> CATransform3D {
    var t = CATransform3D(); t.m11 = sx; t.m22 = sy; t.m33 = sz; return t
}
public func CATransform3DMakeRotation(_ angle: CGFloat, _ x: CGFloat, _ y: CGFloat, _ z: CGFloat) -> CATransform3D {
    let len = sqrt(x * x + y * y + z * z)
    if len == 0 { return .identity }
    let x = x / len, y = y / len, z = z / len
    let c = cos(angle), s = sin(angle), t = 1 - c
    return CATransform3D(m11: t * x * x + c, m12: t * x * y + z * s, m13: t * x * z - y * s, m14: 0,
                         m21: t * x * y - z * s, m22: t * y * y + c, m23: t * y * z + x * s, m24: 0,
                         m31: t * x * z + y * s, m32: t * y * z - x * s, m33: t * z * z + c, m34: 0,
                         m41: 0, m42: 0, m43: 0, m44: 1)
}
/// a then b
public func CATransform3DConcat(_ a: CATransform3D, _ b: CATransform3D) -> CATransform3D {
    let x = a.m, y = b.m
    var r = [CGFloat](repeating: 0, count: 16)
    for i in 0..<4 { for j in 0..<4 { var s: CGFloat = 0; for k in 0..<4 { s += x[i * 4 + k] * y[k * 4 + j] }; r[i * 4 + j] = s } }
    return CATransform3D(r)
}
public func CATransform3DTranslate(_ t: CATransform3D, _ tx: CGFloat, _ ty: CGFloat, _ tz: CGFloat) -> CATransform3D {
    CATransform3DConcat(CATransform3DMakeTranslation(tx, ty, tz), t)
}
public func CATransform3DScale(_ t: CATransform3D, _ sx: CGFloat, _ sy: CGFloat, _ sz: CGFloat) -> CATransform3D {
    CATransform3DConcat(CATransform3DMakeScale(sx, sy, sz), t)
}
public func CATransform3DRotate(_ t: CATransform3D, _ a: CGFloat, _ x: CGFloat, _ y: CGFloat, _ z: CGFloat) -> CATransform3D {
    CATransform3DConcat(CATransform3DMakeRotation(a, x, y, z), t)
}
public func CATransform3DInvert(_ t: CATransform3D) -> CATransform3D {
    var a = t.m, inv = [CGFloat](repeating: 0, count: 16)
    for i in 0..<4 { inv[i * 4 + i] = 1 }
    for c in 0..<4 {
        var p = c
        for r in c..<4 where abs(a[r * 4 + c]) > abs(a[p * 4 + c]) { p = r }
        if abs(a[p * 4 + c]) < 1e-12 { return t }
        if p != c { for k in 0..<4 { a.swapAt(c * 4 + k, p * 4 + k); inv.swapAt(c * 4 + k, p * 4 + k) } }
        let d = a[c * 4 + c]
        for k in 0..<4 { a[c * 4 + k] /= d; inv[c * 4 + k] /= d }
        for r in 0..<4 where r != c {
            let f = a[r * 4 + c]
            if f != 0 { for k in 0..<4 { a[r * 4 + k] -= f * a[c * 4 + k]; inv[r * 4 + k] -= f * inv[c * 4 + k] } }
        }
    }
    return CATransform3D(inv)
}
public func CATransform3DMakeAffineTransform(_ m: CGAffineTransform) -> CATransform3D {
    CATransform3D(m11: m.a, m12: m.b, m13: 0, m14: 0, m21: m.c, m22: m.d, m23: 0, m24: 0, m31: 0, m32: 0, m33: 1, m34: 0, m41: m.tx, m42: m.ty, m43: 0, m44: 1)
}
public func CATransform3DIsAffine(_ t: CATransform3D) -> Bool {
    t.m13 == 0 && t.m14 == 0 && t.m23 == 0 && t.m24 == 0 && t.m31 == 0 && t.m32 == 0 && t.m33 == 1 && t.m34 == 0 && t.m43 == 0 && t.m44 == 1
}
public func CATransform3DGetAffineTransform(_ t: CATransform3D) -> CGAffineTransform {
    CGAffineTransform(a: t.m11, b: t.m12, c: t.m21, d: t.m22, tx: t.m41, ty: t.m42)
}

extension CATransform3D {
    public func concatenating(_ t: CATransform3D) -> CATransform3D { CATransform3DConcat(self, t) }
    public func translated(_ x: CGFloat, _ y: CGFloat, _ z: CGFloat) -> CATransform3D { CATransform3DTranslate(self, x, y, z) }
    public func scaled(_ x: CGFloat, _ y: CGFloat, _ z: CGFloat) -> CATransform3D { CATransform3DScale(self, x, y, z) }
    /// Applies to a 2D point (z = 0) with perspective divide.
    public func apply(_ p: CGPoint) -> CGPoint {
        let x = p.x * m11 + p.y * m21 + m41, y = p.x * m12 + p.y * m22 + m42, w = p.x * m14 + p.y * m24 + m44
        return w == 0 || w == 1 ? CGPoint(x: x, y: y) : CGPoint(x: x / w, y: y / w)
    }
}

public func CACurrentMediaTime() -> CFTimeInterval { ProcessInfo.processInfo.systemUptime }

public struct CAFrameRateRange: Equatable {
    public var minimum: Float
    public var maximum: Float
    public var preferred: Float?
    public init(minimum: Float, maximum: Float, preferred: Float? = nil) { self.minimum = minimum; self.maximum = maximum; self.preferred = preferred }
    public init(minimum: Float, maximum: Float, __preferred: Float) { self.init(minimum: minimum, maximum: maximum, preferred: __preferred) }
    public static let `default` = CAFrameRateRange(minimum: 0, maximum: 0, preferred: 0)
    public func isEqual(to r: CAFrameRateRange) -> Bool { self == r }
}

extension NSValue {
    public convenience init(caTransform3D t: CATransform3D) { self.init(webBoxing: t) }
    public var caTransform3DValue: CATransform3D { webBoxed as? CATransform3D ?? .identity }
    public convenience init(cgAffineTransform t: CGAffineTransform) { self.init(webBoxing: t) }
    public var cgAffineTransformValue: CGAffineTransform { webBoxed as? CGAffineTransform ?? .identity }
    public convenience init(cgPoint p: CGPoint) { self.init(point: p) }
    public convenience init(cgSize s: CGSize) { self.init(size: s) }
    public convenience init(cgRect r: CGRect) { self.init(rect: r) }
    public convenience init(cgVector v: CGVector) { self.init(webBoxing: v) }
    public var cgPointValue: CGPoint { pointValue }
    public var cgSizeValue: CGSize { sizeValue }
    public var cgRectValue: CGRect { rectValue }
    public var cgVectorValue: CGVector { webBoxed as? CGVector ?? CGVector() }
}
