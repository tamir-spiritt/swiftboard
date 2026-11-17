// Swiftboard CoreGraphics (MIT): paths as element lists (arcs and ellipses become cubic Béziers).
import Foundation

public enum CGPathElementType: Int32 { case moveToPoint, addLineToPoint, addQuadCurveToPoint, addCurveToPoint, closeSubpath }

public struct CGPathElement {
    public var type: CGPathElementType
    public var points: UnsafeMutablePointer<CGPoint>
}

/// One path segment, in path coordinates.
public enum CGPathOp: Equatable {
    case move(CGPoint)
    case line(CGPoint)
    case quad(CGPoint, CGPoint)
    case cubic(CGPoint, CGPoint, CGPoint)
    case close

    func applying(_ t: CGAffineTransform) -> CGPathOp {
        switch self {
        case let .move(p): return .move(p.applying(t))
        case let .line(p): return .line(p.applying(t))
        case let .quad(c, p): return .quad(c.applying(t), p.applying(t))
        case let .cubic(a, b, p): return .cubic(a.applying(t), b.applying(t), p.applying(t))
        case .close: return .close
        }
    }
    var points: [CGPoint] {
        switch self {
        case let .move(p), let .line(p): return [p]
        case let .quad(c, p): return [c, p]
        case let .cubic(a, b, p): return [a, b, p]
        case .close: return []
        }
    }
}


open class CGPath: Hashable {
    public internal(set) var ops: [CGPathOp] = []
    var start: CGPoint = .zero
    public internal(set) var currentPoint: CGPoint = .zero

    public init() {}
    init(ops: [CGPathOp]) { self.ops = ops; recomputeCurrent() }

    public convenience init(rect: CGRect, transform: UnsafePointer<CGAffineTransform>?) {
        let m = CGMutablePath(); m.addRect(rect, transform: transform?.pointee ?? .identity); self.init(ops: m.ops)
    }
    public convenience init(ellipseIn rect: CGRect, transform: UnsafePointer<CGAffineTransform>?) {
        let m = CGMutablePath(); m.addEllipse(in: rect, transform: transform?.pointee ?? .identity); self.init(ops: m.ops)
    }
    public convenience init(roundedRect rect: CGRect, cornerWidth: CGFloat, cornerHeight: CGFloat, transform: UnsafePointer<CGAffineTransform>?) {
        let m = CGMutablePath(); m.addRoundedRect(in: rect, cornerWidth: cornerWidth, cornerHeight: cornerHeight, transform: transform?.pointee ?? .identity); self.init(ops: m.ops)
    }

    func recomputeCurrent() {
        for op in ops {
            switch op {
            case let .move(p): start = p; currentPoint = p
            case .close: currentPoint = start
            default: currentPoint = op.points.last ?? currentPoint
            }
        }
    }

    public var isEmpty: Bool { ops.isEmpty }
    public var boundingBox: CGRect {
        let pts = ops.flatMap { $0.points }
        guard let f = pts.first else { return .null }
        var minX = f.x, minY = f.y, maxX = f.x, maxY = f.y
        for p in pts { minX = min(minX, p.x); minY = min(minY, p.y); maxX = max(maxX, p.x); maxY = max(maxY, p.y) }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    public var boundingBoxOfPath: CGRect { boundingBox }

    public func copy() -> CGPath? { CGPath(ops: ops) }
    public func copy(using transform: UnsafePointer<CGAffineTransform>?) -> CGPath? {
        let t = transform?.pointee ?? .identity
        return CGPath(ops: ops.map { $0.applying(t) })
    }
    public func mutableCopy() -> CGMutablePath? { let m = CGMutablePath(); m.ops = ops; m.recomputeCurrent(); return m }
    public func mutableCopy(using transform: UnsafePointer<CGAffineTransform>?) -> CGMutablePath? {
        let t = transform?.pointee ?? .identity
        let m = CGMutablePath(); m.ops = ops.map { $0.applying(t) }; m.recomputeCurrent(); return m
    }
    public func copy(strokingWithWidth lineWidth: CGFloat, lineCap: CGLineCap, lineJoin: CGLineJoin, miterLimit: CGFloat, transform: CGAffineTransform = .identity) -> CGPath {
        // Approximation: the outline of the bounding box grown by half the line width.
        CGPath(rect: boundingBox.insetBy(dx: -lineWidth / 2, dy: -lineWidth / 2).applying(transform), transform: nil)
    }
    public func copy(dashingWithPhase phase: CGFloat, lengths: [CGFloat], transform: CGAffineTransform = .identity) -> CGPath {
        copy(using: [transform])!
    }

    /// Point-in-path test (flattened curves, non-zero or even-odd).
    public func contains(_ point: CGPoint, using rule: CGPathFillRule = .winding, transform: CGAffineTransform = .identity) -> Bool {
        let p = point.applying(transform.inverted())
        var winding = 0, crossings = 0
        for (a, b) in flattenedSegments() {
            if (a.y <= p.y) != (b.y <= p.y) {
                let x = a.x + (p.y - a.y) / (b.y - a.y) * (b.x - a.x)
                if x > p.x { crossings += 1; winding += b.y > a.y ? 1 : -1 }
            }
        }
        return rule == .evenOdd ? crossings % 2 == 1 : winding != 0
    }

    func flattenedSegments() -> [(CGPoint, CGPoint)] {
        var segs: [(CGPoint, CGPoint)] = []
        var cur = CGPoint.zero, st = CGPoint.zero
        for op in ops {
            switch op {
            case let .move(p): if cur != st { segs.append((cur, st)) }; cur = p; st = p
            case let .line(p): segs.append((cur, p)); cur = p
            case let .quad(c, p):
                var prev = cur
                for i in 1...8 { let t = CGFloat(i) / 8; let u = 1 - t
                    let q = CGPoint(x: u * u * cur.x + 2 * u * t * c.x + t * t * p.x, y: u * u * cur.y + 2 * u * t * c.y + t * t * p.y)
                    segs.append((prev, q)); prev = q }
                cur = p
            case let .cubic(c1, c2, p):
                var prev = cur
                for i in 1...12 { let t = CGFloat(i) / 12; let u = 1 - t
                    let q = CGPoint(x: u * u * u * cur.x + 3 * u * u * t * c1.x + 3 * u * t * t * c2.x + t * t * t * p.x,
                                    y: u * u * u * cur.y + 3 * u * u * t * c1.y + 3 * u * t * t * c2.y + t * t * t * p.y)
                    segs.append((prev, q)); prev = q }
                cur = p
            case .close: segs.append((cur, st)); cur = st
            }
        }
        if cur != st { segs.append((cur, st)) }
        return segs
    }

    public func applyWithBlock(_ block: (UnsafePointer<CGPathElement>) -> Void) {
        let buf = UnsafeMutablePointer<CGPoint>.allocate(capacity: 3)
        defer { buf.deallocate() }
        for op in ops {
            let pts = op.points
            for (i, p) in pts.enumerated() { buf[i] = p }
            let type: CGPathElementType
            switch op {
            case .move: type = .moveToPoint
            case .line: type = .addLineToPoint
            case .quad: type = .addQuadCurveToPoint
            case .cubic: type = .addCurveToPoint
            case .close: type = .closeSubpath
            }
            var el = CGPathElement(type: type, points: buf)
            block(&el)
        }
    }

    public static func == (a: CGPath, b: CGPath) -> Bool { a.ops == b.ops }
    public func hash(into h: inout Hasher) { h.combine(ops.count) }

    /// SVG path data.
    public var svg: String {
        func f(_ v: CGFloat) -> String { let d = Double(v); return d == d.rounded() ? String(Int(d)) : String(Double(Int(d * 100)) / 100) }
        func p(_ q: CGPoint) -> String { "\(f(q.x)) \(f(q.y))" }
        return ops.map { op -> String in
            switch op {
            case let .move(a): return "M\(p(a))"
            case let .line(a): return "L\(p(a))"
            case let .quad(c, a): return "Q\(p(c)) \(p(a))"
            case let .cubic(c1, c2, a): return "C\(p(c1)) \(p(c2)) \(p(a))"
            case .close: return "Z"
            }
        }.joined()
    }
}

public final class CGMutablePath: CGPath {
    public override init() { super.init() }

    public func move(to p: CGPoint, transform: CGAffineTransform = .identity) {
        let q = p.applying(transform); ops.append(.move(q)); start = q; currentPoint = q
    }
    public func addLine(to p: CGPoint, transform: CGAffineTransform = .identity) {
        if ops.isEmpty { move(to: p, transform: transform); return }
        let q = p.applying(transform); ops.append(.line(q)); currentPoint = q
    }
    public func addLines(between points: [CGPoint], transform: CGAffineTransform = .identity) {
        for (i, p) in points.enumerated() { if i == 0 { move(to: p, transform: transform) } else { addLine(to: p, transform: transform) } }
    }
    public func addQuadCurve(to p: CGPoint, control: CGPoint, transform: CGAffineTransform = .identity) {
        let q = p.applying(transform); ops.append(.quad(control.applying(transform), q)); currentPoint = q
    }
    public func addCurve(to p: CGPoint, control1: CGPoint, control2: CGPoint, transform: CGAffineTransform = .identity) {
        let q = p.applying(transform); ops.append(.cubic(control1.applying(transform), control2.applying(transform), q)); currentPoint = q
    }
    public func closeSubpath() { if !ops.isEmpty { ops.append(.close); currentPoint = start } }
    public func addRect(_ r: CGRect, transform: CGAffineTransform = .identity) {
        let r = r.standardized
        move(to: CGPoint(x: r.minX, y: r.minY), transform: transform)
        addLine(to: CGPoint(x: r.maxX, y: r.minY), transform: transform)
        addLine(to: CGPoint(x: r.maxX, y: r.maxY), transform: transform)
        addLine(to: CGPoint(x: r.minX, y: r.maxY), transform: transform)
        closeSubpath()
    }
    public func addRects(_ rects: [CGRect], transform: CGAffineTransform = .identity) { rects.forEach { addRect($0, transform: transform) } }
    public func addEllipse(in r: CGRect, transform: CGAffineTransform = .identity) {
        let k: CGFloat = 0.5522847498
        let cx = r.midX, cy = r.midY, rx = r.width / 2, ry = r.height / 2
        move(to: CGPoint(x: cx + rx, y: cy), transform: transform)
        addCurve(to: CGPoint(x: cx, y: cy + ry), control1: CGPoint(x: cx + rx, y: cy + ry * k), control2: CGPoint(x: cx + rx * k, y: cy + ry), transform: transform)
        addCurve(to: CGPoint(x: cx - rx, y: cy), control1: CGPoint(x: cx - rx * k, y: cy + ry), control2: CGPoint(x: cx - rx, y: cy + ry * k), transform: transform)
        addCurve(to: CGPoint(x: cx, y: cy - ry), control1: CGPoint(x: cx - rx, y: cy - ry * k), control2: CGPoint(x: cx - rx * k, y: cy - ry), transform: transform)
        addCurve(to: CGPoint(x: cx + rx, y: cy), control1: CGPoint(x: cx + rx * k, y: cy - ry), control2: CGPoint(x: cx + rx, y: cy - ry * k), transform: transform)
        closeSubpath()
    }
    public func addRoundedRect(in r: CGRect, cornerWidth cw: CGFloat, cornerHeight ch: CGFloat, transform: CGAffineTransform = .identity) {
        let cw = min(cw, r.width / 2), ch = min(ch, r.height / 2)
        if cw <= 0 || ch <= 0 { addRect(r, transform: transform); return }
        let k: CGFloat = 0.5522847498
        move(to: CGPoint(x: r.minX + cw, y: r.minY), transform: transform)
        addLine(to: CGPoint(x: r.maxX - cw, y: r.minY), transform: transform)
        addCurve(to: CGPoint(x: r.maxX, y: r.minY + ch), control1: CGPoint(x: r.maxX - cw + cw * k, y: r.minY), control2: CGPoint(x: r.maxX, y: r.minY + ch - ch * k), transform: transform)
        addLine(to: CGPoint(x: r.maxX, y: r.maxY - ch), transform: transform)
        addCurve(to: CGPoint(x: r.maxX - cw, y: r.maxY), control1: CGPoint(x: r.maxX, y: r.maxY - ch + ch * k), control2: CGPoint(x: r.maxX - cw + cw * k, y: r.maxY), transform: transform)
        addLine(to: CGPoint(x: r.minX + cw, y: r.maxY), transform: transform)
        addCurve(to: CGPoint(x: r.minX, y: r.maxY - ch), control1: CGPoint(x: r.minX + cw - cw * k, y: r.maxY), control2: CGPoint(x: r.minX, y: r.maxY - ch + ch * k), transform: transform)
        addLine(to: CGPoint(x: r.minX, y: r.minY + ch), transform: transform)
        addCurve(to: CGPoint(x: r.minX + cw, y: r.minY), control1: CGPoint(x: r.minX, y: r.minY + ch - ch * k), control2: CGPoint(x: r.minX + cw - cw * k, y: r.minY), transform: transform)
        closeSubpath()
    }
    /// Arc around `center` from `startAngle` to `endAngle` (radians). `clockwise` follows CoreGraphics (in a y-up space).
    public func addArc(center: CGPoint, radius: CGFloat, startAngle: CGFloat, endAngle: CGFloat, clockwise: Bool, transform: CGAffineTransform = .identity) {
        var sweep = endAngle - startAngle
        let twoPi = CGFloat.pi * 2
        if clockwise { while sweep > 0 { sweep -= twoPi }; if sweep < -twoPi { sweep = -twoPi } }
        else { while sweep < 0 { sweep += twoPi }; if sweep > twoPi { sweep = twoPi } }
        let startP = CGPoint(x: center.x + radius * cos(startAngle), y: center.y + radius * sin(startAngle))
        if ops.isEmpty || isClosedAtEnd { move(to: startP, transform: transform) } else { addLine(to: startP, transform: transform) }
        let n = max(1, Int((abs(sweep) / (CGFloat.pi / 2)).rounded(.up)))
        let step = sweep / CGFloat(n)
        var a = startAngle
        for _ in 0..<n {
            let b = a + step
            let k = 4.0 / 3.0 * tan((b - a) / 4) * radius
            let p0 = CGPoint(x: center.x + radius * cos(a), y: center.y + radius * sin(a))
            let p3 = CGPoint(x: center.x + radius * cos(b), y: center.y + radius * sin(b))
            let c1 = CGPoint(x: p0.x - k * sin(a), y: p0.y + k * cos(a))
            let c2 = CGPoint(x: p3.x + k * sin(b), y: p3.y - k * cos(b))
            addCurve(to: p3, control1: c1, control2: c2, transform: transform)
            a = b
        }
    }
    private var isClosedAtEnd: Bool { if case .close = ops.last { return true }; return false }
    public func addRelativeArc(center: CGPoint, radius: CGFloat, startAngle: CGFloat, delta: CGFloat, transform: CGAffineTransform = .identity) {
        addArc(center: center, radius: radius, startAngle: startAngle, endAngle: startAngle + delta, clockwise: delta < 0, transform: transform)
    }
    public func addArc(tangent1End p1: CGPoint, tangent2End p2: CGPoint, radius: CGFloat, transform: CGAffineTransform = .identity) {
        let p0 = currentPoint
        let v1 = CGPoint(x: p0.x - p1.x, y: p0.y - p1.y), v2 = CGPoint(x: p2.x - p1.x, y: p2.y - p1.y)
        let l1 = hypot(v1.x, v1.y), l2 = hypot(v2.x, v2.y)
        if l1 == 0 || l2 == 0 || radius == 0 { addLine(to: p1, transform: transform); return }
        let cosA = (v1.x * v2.x + v1.y * v2.y) / (l1 * l2)
        let angle = acos(max(-1, min(1, cosA)))
        if angle == 0 || angle == .pi { addLine(to: p1, transform: transform); return }
        let d = radius / tan(angle / 2)
        let t1 = CGPoint(x: p1.x + v1.x / l1 * d, y: p1.y + v1.y / l1 * d)
        let t2 = CGPoint(x: p1.x + v2.x / l2 * d, y: p1.y + v2.y / l2 * d)
        addLine(to: t1, transform: transform)
        let k = 4.0 / 3.0 * tan((CGFloat.pi - angle) / 4) * radius
        let c1 = CGPoint(x: t1.x - v1.x / l1 * k, y: t1.y - v1.y / l1 * k)
        let c2 = CGPoint(x: t2.x - v2.x / l2 * k, y: t2.y - v2.y / l2 * k)
        addCurve(to: t2, control1: c1, control2: c2, transform: transform)
    }
    public func addPath(_ path: CGPath, transform: CGAffineTransform = .identity) {
        ops.append(contentsOf: path.ops.map { $0.applying(transform) }); recomputeCurrent()
    }
}

public func CGPathCreateMutable() -> CGMutablePath { CGMutablePath() }
public func CGPathMoveToPoint(_ p: CGMutablePath, _ m: UnsafePointer<CGAffineTransform>?, _ x: CGFloat, _ y: CGFloat) { p.move(to: CGPoint(x: x, y: y), transform: m?.pointee ?? .identity) }
public func CGPathAddLineToPoint(_ p: CGMutablePath, _ m: UnsafePointer<CGAffineTransform>?, _ x: CGFloat, _ y: CGFloat) { p.addLine(to: CGPoint(x: x, y: y), transform: m?.pointee ?? .identity) }
public func CGPathCloseSubpath(_ p: CGMutablePath) { p.closeSubpath() }
public func CGPathAddRect(_ p: CGMutablePath, _ m: UnsafePointer<CGAffineTransform>?, _ r: CGRect) { p.addRect(r, transform: m?.pointee ?? .identity) }
public func CGPathGetBoundingBox(_ p: CGPath?) -> CGRect { p?.boundingBox ?? .null }
