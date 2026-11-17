// Swiftboard QuartzCore (MIT): the layer tree as a JSON display list, the form the browser painter consumes.
import Foundation

public enum WebDisplayList {
    /// JSON for `layer` and its sublayers. `annotate` adds a "tag" per layer (e.g. the owning node's class).
    public static func json(_ layer: CALayer, annotate: ((CALayer) -> String?)? = nil) -> String {
        var out = ""
        write(layer, &out, annotate)
        return out
    }

    static func num(_ v: CGFloat) -> String {
        let d = Double(v)
        if d.isNaN || d.isInfinite { return "0" }
        let r = (d * 1000).rounded() / 1000
        return r == r.rounded() ? String(Int(r)) : String(r)
    }
    static func str(_ s: String) -> String {
        var o = "\""
        for u in s.unicodeScalars {
            switch u {
            case "\"": o += "\\\""
            case "\\": o += "\\\\"
            case "\n": o += "\\n"
            case "\r": o += "\\r"
            case "\t": o += "\\t"
            default: if u.value < 0x20 { o += String(format: "\\u%04x", u.value) } else { o.unicodeScalars.append(u) }
            }
        }
        return o + "\""
    }
    static func rect(_ r: CGRect) -> String { "[\(num(r.minX)),\(num(r.minY)),\(num(r.width)),\(num(r.height))]" }
    static func point(_ p: CGPoint) -> String { "[\(num(p.x)),\(num(p.y))]" }
    static func affine(_ t: CGAffineTransform) -> String { "[\(num(t.a)),\(num(t.b)),\(num(t.c)),\(num(t.d)),\(num(t.tx)),\(num(t.ty))]" }

    static func write(_ l: CALayer, _ o: inout String, _ annotate: ((CALayer) -> String?)?) {
        var f: [String] = []
        f.append("\"class\":\(str(String(describing: type(of: l))))")
        if let tag = annotate?(l) { f.append("\"tag\":\(str(tag))") }
        if let n = l.name { f.append("\"name\":\(str(n))") }
        f.append("\"frame\":\(rect(l.frame))")
        f.append("\"position\":\(point(l.position)),\"size\":[\(num(l.bounds.width)),\(num(l.bounds.height))]")
        if l.bounds.origin != .zero { f.append("\"boundsOrigin\":\(point(l.bounds.origin))") }
        if l.anchorPoint != CGPoint(x: 0.5, y: 0.5) { f.append("\"anchorPoint\":\(point(l.anchorPoint))") }
        if l.transform != .identity { f.append("\"transform\":[\(l.transform.cssMatrix3d.map { num(CGFloat($0)) }.joined(separator: ","))]") }
        if l.sublayerTransform != .identity { f.append("\"sublayerTransform\":[\(l.sublayerTransform.cssMatrix3d.map { num(CGFloat($0)) }.joined(separator: ","))]") }
        if l.opacity != 1 { f.append("\"opacity\":\(num(CGFloat(l.opacity)))") }
        if l.isHidden { f.append("\"hidden\":true") }
        if let c = l.backgroundColor { f.append("\"backgroundColor\":\(str(c.css))") }
        if l.cornerRadius != 0 { f.append("\"cornerRadius\":\(num(l.cornerRadius))") }
        if l.masksToBounds { f.append("\"masksToBounds\":true") }
        if l.borderWidth != 0 { f.append("\"border\":{\"width\":\(num(l.borderWidth)),\"color\":\(str(l.borderColor?.css ?? "black"))}") }
        if l.shadowOpacity != 0 { f.append("\"shadow\":{\"opacity\":\(num(CGFloat(l.shadowOpacity))),\"radius\":\(num(l.shadowRadius)),\"offset\":[\(num(l.shadowOffset.width)),\(num(l.shadowOffset.height))],\"color\":\(str(l.shadowColor?.css ?? "black"))}") }
        if let t = l.webTintColorValue { f.append("\"tintColor\":\(str(t.css))") }
        if let shape = l as? CAShapeLayer, let p = shape.path {
            var s = "\"shape\":{\"path\":\(str(p.svg))"
            if let c = shape.fillColor { s += ",\"fill\":\(str(c.css))" }
            if let c = shape.strokeColor { s += ",\"stroke\":\(str(c.css)),\"lineWidth\":\(num(shape.lineWidth))" }
            f.append(s + "}")
        }
        if let g = l as? CAGradientLayer, let colors = g.colors {
            let cs = colors.compactMap { ($0 as AnyObject) as? CGColor }.map { str($0.css) }
            f.append("\"gradient\":{\"colors\":[\(cs.joined(separator: ","))],\"start\":\(point(g.startPoint)),\"end\":\(point(g.endPoint))}")
        }
        if let c = l.contents {
            if let img = (c as AnyObject) as? CGImage {
                f.append("\"contentsScale\":\(num(l.contentsScale))")
                if l.contentsGravity != .resize { f.append("\"contentsGravity\":\(str(l.contentsGravity.rawValue))") }
                if l.contentsCenter != CGRect(x: 0, y: 0, width: 1, height: 1) { f.append("\"contentsCenter\":\(rect(l.contentsCenter))") }
                f.append("\"contents\":\(image(img))")
            } else {
                f.append("\"contents\":\(str(String(describing: type(of: c))))")
            }
        }
        if let m = l.mask { var mo = ""; write(m, &mo, annotate); f.append("\"mask\":\(mo)") }
        if let subs = l.sublayers, !subs.isEmpty {
            var parts: [String] = []
            for s in subs { var so = ""; write(s, &so, annotate); parts.append(so) }
            f.append("\"sublayers\":[\(parts.joined(separator: ","))]")
        }
        o += "{" + f.joined(separator: ",") + "}"
    }

    public static func image(_ img: CGImage) -> String {
        var f = ["\"id\":\(img.webSerial)", "\"width\":\(img.width)", "\"height\":\(img.height)"]
        switch img.sourceKind {
        case .recording:
            f.append("\"kind\":\"recording\"")
            if let r = img.recording { f.append("\"ops\":[\(r.ops.map(op).joined(separator: ","))]") }
        case .external: f.append("\"kind\":\"external\",\"source\":\(str(img.externalSource ?? ""))")
        case .pixels: f.append("\"kind\":\"pixels\"")
        }
        if let c = img.crop { f.append("\"crop\":\(rect(c))") }
        return "{" + f.joined(separator: ",") + "}"
    }

    static func op(_ o: CGDrawOp) -> String {
        switch o {
        case .save: return "[\"save\"]"
        case .restore: return "[\"restore\"]"
        case let .concat(t): return "[\"concat\",\(affine(t))]"
        case let .setFillColor(c): return "[\"fillColor\",\(str(c.css))]"
        case let .setStrokeColor(c): return "[\"strokeColor\",\(str(c.css))]"
        case let .setLineWidth(w): return "[\"lineWidth\",\(num(w))]"
        case let .setLineCap(c): return "[\"lineCap\",\(str(["butt", "round", "square"][Int(c.rawValue)]))]"
        case let .setLineJoin(j): return "[\"lineJoin\",\(str(["miter", "round", "bevel"][Int(j.rawValue)]))]"
        case let .setMiterLimit(m): return "[\"miterLimit\",\(num(m))]"
        case let .setLineDash(p, l): return "[\"lineDash\",\(num(p)),[\(l.map(num).joined(separator: ","))]]"
        case let .setAlpha(a): return "[\"alpha\",\(num(a))]"
        case let .setBlendMode(m): return "[\"blend\",\(str(m.css))]"
        case let .setShadow(off, blur, c): return "[\"shadow\",[\(num(off.width)),\(num(off.height))],\(num(blur)),\(str(c?.css ?? "transparent"))]"
        case let .fillPath(p, r): return "[\"fill\",\(str(p.svg)),\(str(r == .evenOdd ? "evenodd" : "nonzero"))]"
        case let .strokePath(p): return "[\"stroke\",\(str(p.svg))]"
        case let .clipPath(p, r): return "[\"clip\",\(str(p.svg)),\(str(r == .evenOdd ? "evenodd" : "nonzero"))]"
        case let .clipMask(i, r): return "[\"clipMask\",\(image(i)),\(rect(r))]"
        case .resetClip: return "[\"resetClip\"]"
        case let .clearRect(r): return "[\"clear\",\(rect(r))]"
        case let .drawImage(i, r): return "[\"image\",\(image(i)),\(rect(r))]"
        case let .linearGradient(g, s, e, _):
            return "[\"linearGradient\",[\(g.colors.map { str($0.css) }.joined(separator: ","))],[\(g.locations.map(num).joined(separator: ","))],\(point(s)),\(point(e))]"
        case let .radialGradient(g, sc, sr, ec, er, _):
            return "[\"radialGradient\",[\(g.colors.map { str($0.css) }.joined(separator: ","))],[\(g.locations.map(num).joined(separator: ","))],\(point(sc)),\(num(sr)),\(point(ec)),\(num(er))]"
        case let .text(t, font, at, m, color): return "[\"text\",\(str(t)),\(str(font.css)),\(point(at)),\(affine(m)),\(str(color?.css ?? "fill"))]"
        case .beginTransparencyLayer: return "[\"beginLayer\"]"
        case .endTransparencyLayer: return "[\"endLayer\"]"
        }
    }
}

extension CALayer {
    var webTintColorValue: CGColor? { extraValues["webTintColor"].map { $0 as AnyObject } as? CGColor }
}
