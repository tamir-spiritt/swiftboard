// Swiftboard CoreGraphics (MIT): CGContext as a recorder of Canvas-2D-like drawing commands.
// Coordinates are recorded in user space together with the transforms, so a replayer (the browser canvas) just
// mirrors every op. A bitmap context starts in CoreGraphics' y-up pixel space; the replayer flips it once.
import Foundation

/// The font of a recorded text run (CoreText fills it in).
public struct CGTextFont: Hashable {
    public var family: String
    public var size: CGFloat
    public var weight: CGFloat
    public var italic: Bool
    public init(family: String, size: CGFloat, weight: CGFloat = 400, italic: Bool = false) {
        self.family = family; self.size = size; self.weight = weight; self.italic = italic
    }
    /// CSS font shorthand.
    public var css: String { "\(italic ? "italic " : "")\(Int(weight)) \(Double(size))px \(family)" }
}

public enum CGDrawOp {
    case save
    case restore
    case concat(CGAffineTransform)
    case setFillColor(CGColor)
    case setStrokeColor(CGColor)
    case setLineWidth(CGFloat)
    case setLineCap(CGLineCap)
    case setLineJoin(CGLineJoin)
    case setMiterLimit(CGFloat)
    case setLineDash(phase: CGFloat, lengths: [CGFloat])
    case setAlpha(CGFloat)
    case setBlendMode(CGBlendMode)
    case setShadow(offset: CGSize, blur: CGFloat, color: CGColor?)
    case fillPath(CGPath, CGPathFillRule)
    case strokePath(CGPath)
    case clipPath(CGPath, CGPathFillRule)
    case clipMask(CGImage, CGRect)
    case resetClip
    case clearRect(CGRect)
    case drawImage(CGImage, CGRect)
    case linearGradient(CGGradient, start: CGPoint, end: CGPoint, options: CGGradientDrawingOptions)
    case radialGradient(CGGradient, startCenter: CGPoint, startRadius: CGFloat, endCenter: CGPoint, endRadius: CGFloat, options: CGGradientDrawingOptions)
    /// A run of text, baseline origin at `at` in user space; `textMatrix` applied (y-up glyph space).
    case text(String, font: CGTextFont, at: CGPoint, textMatrix: CGAffineTransform, color: CGColor?)
    case beginTransparencyLayer
    case endTransparencyLayer
}

open class CGContext {
    struct GState {
        var ctm: CGAffineTransform
        var fill: CGColor = .black
        var stroke: CGColor = .black
        var lineWidth: CGFloat = 1
        var alpha: CGFloat = 1
        var blendMode: CGBlendMode = .normal
    }

    public let width: Int
    public let height: Int
    public let bitsPerComponent: Int
    public let bitsPerPixel: Int
    public let bytesPerRow: Int
    public let colorSpace: CGColorSpace?
    public let bitmapInfo: CGBitmapInfo
    public let data: UnsafeMutableRawPointer?
    private var ownedData: UnsafeMutableRawPointer?
    public private(set) var ops: [CGDrawOp] = []
    private var path = CGMutablePath()
    private var gstate: GState
    private var stack: [GState] = []
    public var textMatrix: CGAffineTransform = .identity
    public var textPosition: CGPoint = .zero
    public var interpolationQuality: CGInterpolationQuality = .default

    nonisolated(unsafe) private static var byMemory: [UnsafeRawPointer: WeakContext] = [:]
    final class WeakContext { weak var context: CGContext?; init(_ c: CGContext) { context = c } }

    public init?(data: UnsafeMutableRawPointer?, width: Int, height: Int, bitsPerComponent: Int, bytesPerRow: Int,
                 space: CGColorSpace, bitmapInfo: UInt32) {
        self.width = width; self.height = height; self.bitsPerComponent = bitsPerComponent
        self.bitsPerPixel = space.numberOfComponents == 1 && (bitmapInfo & 0x1F) == 0 ? bitsPerComponent : bitsPerComponent * 4
        // CoreGraphics pads automatic row strides to 64 bytes
        self.bytesPerRow = bytesPerRow == 0 ? ((width * self.bitsPerPixel / 8) + 63) / 64 * 64 : bytesPerRow
        self.colorSpace = space; self.bitmapInfo = CGBitmapInfo(rawValue: bitmapInfo)
        if let data {
            self.data = data
        } else {
            let p = UnsafeMutableRawPointer.allocate(byteCount: max(1, self.bytesPerRow * height), alignment: 16)
            p.initializeMemory(as: UInt8.self, repeating: 0, count: max(1, self.bytesPerRow * height))
            self.data = p; ownedData = p
        }
        gstate = GState(ctm: .identity)
        CGContext.byMemory[UnsafeRawPointer(self.data!)] = WeakContext(self)
    }
    public convenience init?(data: UnsafeMutableRawPointer?, width: Int, height: Int, bitsPerComponent: Int, bytesPerRow: Int,
                             space: CGColorSpace, bitmapInfo: UInt32, releaseCallback: ((UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> Void)?,
                             releaseInfo: UnsafeMutableRawPointer?) {
        self.init(data: data, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: space, bitmapInfo: bitmapInfo)
    }
    deinit {
        if let data, CGContext.byMemory[UnsafeRawPointer(data)]?.context == nil || CGContext.byMemory[UnsafeRawPointer(data)]?.context === self {
            CGContext.byMemory[UnsafeRawPointer(data)] = nil
        }
        ownedData?.deallocate()
    }

    /// The drawing recorded so far by the context that draws into `memory` (if any).
    public static func recording(forMemory memory: UnsafeRawPointer) -> CGRecording? {
        guard let c = byMemory[memory]?.context else { return nil }
        return CGRecording(width: c.width, height: c.height, ops: c.ops)
    }

    public func makeImage() -> CGImage? {
        CGImage(recording: CGRecording(width: width, height: height, ops: ops), colorSpace: colorSpace, bitmapInfo: bitmapInfo)
    }

    /// Appends a command (used by CoreText and UIKit drawing).
    public func record(_ op: CGDrawOp) { ops.append(op) }

    // MARK: state
    public var ctm: CGAffineTransform { gstate.ctm }
    public var userSpaceToDeviceSpaceTransform: CGAffineTransform { gstate.ctm }
    public var fillColor: CGColor { gstate.fill }
    public var strokeColor: CGColor { gstate.stroke }
    public func saveGState() { stack.append(gstate); ops.append(.save) }
    public func restoreGState() { if let s = stack.popLast() { gstate = s }; ops.append(.restore) }
    public func concatenate(_ t: CGAffineTransform) { gstate.ctm = t.concatenating(gstate.ctm); ops.append(.concat(t)) }
    public func translateBy(x: CGFloat, y: CGFloat) { concatenate(CGAffineTransform(translationX: x, y: y)) }
    public func scaleBy(x: CGFloat, y: CGFloat) { concatenate(CGAffineTransform(scaleX: x, y: y)) }
    public func rotate(by angle: CGFloat) { concatenate(CGAffineTransform(rotationAngle: angle)) }
    public func convertToDeviceSpace(_ p: CGPoint) -> CGPoint { p.applying(gstate.ctm) }
    public func convertToDeviceSpace(_ r: CGRect) -> CGRect { r.applying(gstate.ctm) }
    public func convertToUserSpace(_ p: CGPoint) -> CGPoint { p.applying(gstate.ctm.inverted()) }
    public func convertToUserSpace(_ r: CGRect) -> CGRect { r.applying(gstate.ctm.inverted()) }
    public var boundingBoxOfClipPath: CGRect { CGRect(x: 0, y: 0, width: width, height: height).applying(gstate.ctm.inverted()) }

    public func setFillColor(_ c: CGColor) { gstate.fill = c; ops.append(.setFillColor(c)) }
    public func setStrokeColor(_ c: CGColor) { gstate.stroke = c; ops.append(.setStrokeColor(c)) }
    public func setFillColor(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) { setFillColor(CGColor(red: red, green: green, blue: blue, alpha: alpha)) }
    public func setStrokeColor(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) { setStrokeColor(CGColor(red: red, green: green, blue: blue, alpha: alpha)) }
    public func setFillColor(gray: CGFloat, alpha: CGFloat) { setFillColor(CGColor(gray: gray, alpha: alpha)) }
    public func setStrokeColor(gray: CGFloat, alpha: CGFloat) { setStrokeColor(CGColor(gray: gray, alpha: alpha)) }
    public func setFillColorSpace(_ s: CGColorSpace) {}
    public func setStrokeColorSpace(_ s: CGColorSpace) {}
    public func setPatternPhase(_ phase: CGSize) {}
    public func setLineWidth(_ w: CGFloat) { gstate.lineWidth = w; ops.append(.setLineWidth(w)) }
    public func setLineCap(_ c: CGLineCap) { ops.append(.setLineCap(c)) }
    public func setLineJoin(_ j: CGLineJoin) { ops.append(.setLineJoin(j)) }
    public func setMiterLimit(_ l: CGFloat) { ops.append(.setMiterLimit(l)) }
    public func setLineDash(phase: CGFloat, lengths: [CGFloat]) { ops.append(.setLineDash(phase: phase, lengths: lengths)) }
    public func setAlpha(_ a: CGFloat) { gstate.alpha = a; ops.append(.setAlpha(a)) }
    public func setBlendMode(_ m: CGBlendMode) { gstate.blendMode = m; ops.append(.setBlendMode(m)) }
    public func setShadow(offset: CGSize, blur: CGFloat, color: CGColor?) { ops.append(.setShadow(offset: offset, blur: blur, color: color)) }
    public func setShadow(offset: CGSize, blur: CGFloat) { setShadow(offset: offset, blur: blur, color: CGColor(gray: 0, alpha: 1.0 / 3.0)) }
    public func setAllowsAntialiasing(_ v: Bool) {}
    public func setShouldAntialias(_ v: Bool) {}
    public func setAllowsFontSmoothing(_ v: Bool) {}
    public func setShouldSmoothFonts(_ v: Bool) {}
    public func setAllowsFontSubpixelPositioning(_ v: Bool) {}
    public func setShouldSubpixelPositionFonts(_ v: Bool) {}
    public func setAllowsFontSubpixelQuantization(_ v: Bool) {}
    public func setShouldSubpixelQuantizeFonts(_ v: Bool) {}
    public func setTextDrawingMode(_ m: CGTextDrawingMode) {}
    public func setFlatness(_ f: CGFloat) {}
    public func setCharacterSpacing(_ s: CGFloat) {}
    public func setRenderingIntent(_ i: CGColorRenderingIntent) {}
    public func flush() {}
    public func synchronize() {}

    // MARK: path construction
    public func beginPath() { path = CGMutablePath() }
    public func move(to p: CGPoint) { path.move(to: p) }
    public func addLine(to p: CGPoint) { path.addLine(to: p) }
    public func addLines(between points: [CGPoint]) { path.addLines(between: points) }
    public func addCurve(to p: CGPoint, control1: CGPoint, control2: CGPoint) { path.addCurve(to: p, control1: control1, control2: control2) }
    public func addQuadCurve(to p: CGPoint, control: CGPoint) { path.addQuadCurve(to: p, control: control) }
    public func addRect(_ r: CGRect) { path.addRect(r) }
    public func addRects(_ r: [CGRect]) { path.addRects(r) }
    public func addEllipse(in r: CGRect) { path.addEllipse(in: r) }
    public func addArc(center: CGPoint, radius: CGFloat, startAngle: CGFloat, endAngle: CGFloat, clockwise: Bool) {
        path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: clockwise)
    }
    public func addArc(tangent1End: CGPoint, tangent2End: CGPoint, radius: CGFloat) { path.addArc(tangent1End: tangent1End, tangent2End: tangent2End, radius: radius) }
    public func addPath(_ p: CGPath) { path.addPath(p) }
    public func closePath() { path.closeSubpath() }
    public var isPathEmpty: Bool { path.isEmpty }
    public var currentPointOfPath: CGPoint { path.currentPoint }
    public var boundingBoxOfPath: CGRect { path.boundingBox }
    public var path_: CGPath? { path.isEmpty ? nil : path.copy() }
    public func replacePathWithStrokedPath() { path = path.copy(strokingWithWidth: gstate.lineWidth, lineCap: .butt, lineJoin: .miter, miterLimit: 10).mutableCopy()! }

    private func takePath() -> CGPath { let p = path.copy()!; path = CGMutablePath(); return p }

    // MARK: painting
    public func fillPath(using rule: CGPathFillRule = .winding) { ops.append(.fillPath(takePath(), rule)) }
    public func eoFillPath() { fillPath(using: .evenOdd) }
    public func strokePath() { ops.append(.strokePath(takePath())) }
    public func drawPath(using mode: CGPathDrawingMode) {
        let p = takePath()
        switch mode {
        case .fill: ops.append(.fillPath(p, .winding))
        case .eoFill: ops.append(.fillPath(p, .evenOdd))
        case .stroke: ops.append(.strokePath(p))
        case .fillStroke: ops.append(.fillPath(p, .winding)); ops.append(.strokePath(p))
        case .eoFillStroke: ops.append(.fillPath(p, .evenOdd)); ops.append(.strokePath(p))
        }
    }
    public func fill(_ r: CGRect) { ops.append(.fillPath(CGPath(rect: r, transform: nil), .winding)) }
    public func fill(_ rects: [CGRect]) { let m = CGMutablePath(); m.addRects(rects); ops.append(.fillPath(m, .winding)) }
    public func fillEllipse(in r: CGRect) { ops.append(.fillPath(CGPath(ellipseIn: r, transform: nil), .winding)) }
    public func stroke(_ r: CGRect) { ops.append(.strokePath(CGPath(rect: r, transform: nil))) }
    public func stroke(_ r: CGRect, width: CGFloat) { saveGState(); setLineWidth(width); stroke(r); restoreGState() }
    public func strokeEllipse(in r: CGRect) { ops.append(.strokePath(CGPath(ellipseIn: r, transform: nil))) }
    public func strokeLineSegments(between points: [CGPoint]) {
        let m = CGMutablePath()
        var i = 0
        while i + 1 < points.count { m.move(to: points[i]); m.addLine(to: points[i + 1]); i += 2 }
        ops.append(.strokePath(m))
    }
    public func clear(_ r: CGRect) { ops.append(.clearRect(r)) }
    public func clip(using rule: CGPathFillRule = .winding) { ops.append(.clipPath(takePath(), rule)) }
    public func clip(to r: CGRect) { ops.append(.clipPath(CGPath(rect: r, transform: nil), .winding)) }
    public func clip(to rects: [CGRect]) { let m = CGMutablePath(); m.addRects(rects); ops.append(.clipPath(m, .winding)) }
    public func clip(to r: CGRect, mask: CGImage) { ops.append(.clipMask(mask, r)) }
    public func resetClip() { ops.append(.resetClip) }
    public func draw(_ image: CGImage, in r: CGRect, byTiling: Bool = false) { ops.append(.drawImage(image, r)) }
    public func drawLinearGradient(_ g: CGGradient, start: CGPoint, end: CGPoint, options: CGGradientDrawingOptions) {
        ops.append(.linearGradient(g, start: start, end: end, options: options))
    }
    public func drawRadialGradient(_ g: CGGradient, startCenter: CGPoint, startRadius: CGFloat, endCenter: CGPoint, endRadius: CGFloat, options: CGGradientDrawingOptions) {
        ops.append(.radialGradient(g, startCenter: startCenter, startRadius: startRadius, endCenter: endCenter, endRadius: endRadius, options: options))
    }
    public func beginTransparencyLayer(auxiliaryInfo: CFDictionary?) { ops.append(.beginTransparencyLayer) }
    public func beginTransparencyLayer(in r: CGRect, auxiliaryInfo: CFDictionary?) { ops.append(.beginTransparencyLayer) }
    public func endTransparencyLayer() { ops.append(.endTransparencyLayer) }
}

public func CGBitmapContextCreate(_ data: UnsafeMutableRawPointer?, _ width: Int, _ height: Int, _ bpc: Int, _ bpr: Int, _ space: CGColorSpace?, _ info: UInt32) -> CGContext? {
    CGContext(data: data, width: width, height: height, bitsPerComponent: bpc, bytesPerRow: bpr, space: space ?? .deviceRGB, bitmapInfo: info)
}
public func CGBitmapContextCreateImage(_ c: CGContext?) -> CGImage? { c?.makeImage() }
public func CGContextBeginPath(_ c: CGContext?) { c?.beginPath() }
public func CGContextClosePath(_ c: CGContext?) { c?.closePath() }
public func CGContextFillRect(_ c: CGContext?, _ r: CGRect) { c?.fill(r) }
public func CGContextSaveGState(_ c: CGContext?) { c?.saveGState() }
public func CGContextRestoreGState(_ c: CGContext?) { c?.restoreGState() }
public func CGContextTranslateCTM(_ c: CGContext?, _ x: CGFloat, _ y: CGFloat) { c?.translateBy(x: x, y: y) }
public func CGContextScaleCTM(_ c: CGContext?, _ x: CGFloat, _ y: CGFloat) { c?.scaleBy(x: x, y: y) }
