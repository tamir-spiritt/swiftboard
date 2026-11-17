// Swiftboard UIKit (MIT): UIGraphics contexts, UIBezierPath, attributed string keys, paragraph styles, string drawing.
import Foundation

// MARK: context stack

nonisolated(unsafe) var webContextStack: [CGContext] = []
nonisolated(unsafe) var webImageContextScales: [CGFloat] = []

public func UIGraphicsGetCurrentContext() -> CGContext? { webContextStack.last }
public func UIGraphicsPushContext(_ c: CGContext) { webContextStack.append(c) }
public func UIGraphicsPopContext() { _ = webContextStack.popLast() }

func makeUIKitContext(size: CGSize, scale: CGFloat, opaque: Bool) -> CGContext? {
    let s = scale == 0 ? UIScreen.main.scale : scale
    let w = max(1, Int((size.width * s).rounded(.up))), h = max(1, Int((size.height * s).rounded(.up)))
    guard let c = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: .deviceRGB,
                            bitmapInfo: (opaque ? CGImageAlphaInfo.noneSkipFirst : CGImageAlphaInfo.premultipliedFirst).rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else { return nil }
    c.translateBy(x: 0, y: CGFloat(h))
    c.scaleBy(x: s, y: -s)
    return c
}
public func UIGraphicsBeginImageContextWithOptions(_ size: CGSize, _ opaque: Bool, _ scale: CGFloat) {
    guard let c = makeUIKitContext(size: size, scale: scale, opaque: opaque) else { return }
    webImageContextScales.append(scale == 0 ? UIScreen.main.scale : scale)
    UIGraphicsPushContext(c)
}
public func UIGraphicsBeginImageContext(_ size: CGSize) { UIGraphicsBeginImageContextWithOptions(size, false, 1) }
public func UIGraphicsGetImageFromCurrentImageContext() -> UIImage? {
    guard let c = UIGraphicsGetCurrentContext(), let cg = c.makeImage() else { return nil }
    return UIImage(cgImage: cg, scale: webImageContextScales.last ?? 1, orientation: .up)
}
public func UIGraphicsEndImageContext() { UIGraphicsPopContext(); _ = webImageContextScales.popLast() }
public func UIRectFill(_ r: CGRect) { UIGraphicsGetCurrentContext()?.fill(r) }
public func UIRectFillUsingBlendMode(_ r: CGRect, _ m: CGBlendMode) { let c = UIGraphicsGetCurrentContext(); c?.saveGState(); c?.setBlendMode(m); c?.fill(r); c?.restoreGState() }
public func UIRectFrame(_ r: CGRect) { UIGraphicsGetCurrentContext()?.stroke(r) }
public func UIRectClip(_ r: CGRect) { UIGraphicsGetCurrentContext()?.clip(to: r) }

open class UIGraphicsRendererFormat: NSObject {
    public override init() {}
}
open class UIGraphicsImageRendererFormat: UIGraphicsRendererFormat {
    public enum Range: Int { case unspecified = -1, automatic = 0, extended, standard }
    open var scale: CGFloat = UIScreen.main.scale
    open var opaque = false
    open var preferredRange: Range = .automatic
    public class func `default`() -> UIGraphicsImageRendererFormat { UIGraphicsImageRendererFormat() }
    public class func preferred() -> UIGraphicsImageRendererFormat { UIGraphicsImageRendererFormat() }
}
open class UIGraphicsRendererContext: NSObject {
    public let cgContext: CGContext
    init(_ c: CGContext) { cgContext = c }
    public func fill(_ r: CGRect) { cgContext.fill(r) }
    public func fill(_ r: CGRect, blendMode: CGBlendMode) { cgContext.saveGState(); cgContext.setBlendMode(blendMode); cgContext.fill(r); cgContext.restoreGState() }
    public func stroke(_ r: CGRect) { cgContext.stroke(r) }
    public func clip(to r: CGRect) { cgContext.clip(to: r) }
}
open class UIGraphicsImageRendererContext: UIGraphicsRendererContext {
    public let format: UIGraphicsImageRendererFormat
    init(_ c: CGContext, format: UIGraphicsImageRendererFormat) { self.format = format; super.init(c) }
    public var currentImage: UIImage { UIImage(cgImage: cgContext.makeImage()!, scale: format.scale, orientation: .up) }
}
open class UIGraphicsImageRenderer: NSObject {
    public let format: UIGraphicsImageRendererFormat
    let size: CGSize
    public init(size: CGSize, format: UIGraphicsImageRendererFormat) { self.size = size; self.format = format }
    public convenience init(size: CGSize) { self.init(size: size, format: UIGraphicsImageRendererFormat()) }
    public convenience init(bounds: CGRect, format: UIGraphicsImageRendererFormat) { self.init(size: bounds.size, format: format) }
    public convenience init(bounds: CGRect) { self.init(size: bounds.size) }
    public func image(actions: (UIGraphicsImageRendererContext) -> Void) -> UIImage {
        let c = makeUIKitContext(size: size, scale: format.scale, opaque: format.opaque)!
        let rc = UIGraphicsImageRendererContext(c, format: format)
        UIGraphicsPushContext(c)
        actions(rc)
        UIGraphicsPopContext()
        return UIImage(cgImage: c.makeImage()!, scale: format.scale, orientation: .up)
    }
    public func pngData(actions: (UIGraphicsImageRendererContext) -> Void) -> Data { _ = image(actions: actions); return Data() }
}

// MARK: bezier paths

open class UIBezierPath: NSObject {
    public var cgPath: CGPath {
        get { path.copy()! }
        set { path = newValue.mutableCopy()! }
    }
    var path = CGMutablePath()
    open var lineWidth: CGFloat = 1
    open var lineCapStyle: CGLineCap = .butt
    open var lineJoinStyle: CGLineJoin = .miter
    open var miterLimit: CGFloat = 10
    open var flatness: CGFloat = 0.6
    open var usesEvenOddFillRule = false
    private var dash: (CGFloat, [CGFloat])?
    public override init() {}
    public convenience init(rect: CGRect) { self.init(); path.addRect(rect) }
    public convenience init(ovalIn rect: CGRect) { self.init(); path.addEllipse(in: rect) }
    public convenience init(roundedRect rect: CGRect, cornerRadius: CGFloat) { self.init(); path.addRoundedRect(in: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius) }
    public convenience init(roundedRect r: CGRect, byRoundingCorners corners: UIRectCorner, cornerRadii: CGSize) {
        self.init()
        let rx = min(cornerRadii.width, r.width / 2), ry = min(cornerRadii.height, r.height / 2)
        func c(_ k: UIRectCorner) -> Bool { corners.contains(k) }
        path.move(to: CGPoint(x: r.minX + (c(.topLeft) ? rx : 0), y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX - (c(.topRight) ? rx : 0), y: r.minY))
        if c(.topRight) { path.addArc(tangent1End: CGPoint(x: r.maxX, y: r.minY), tangent2End: CGPoint(x: r.maxX, y: r.minY + ry), radius: rx) }
        path.addLine(to: CGPoint(x: r.maxX, y: r.maxY - (c(.bottomRight) ? ry : 0)))
        if c(.bottomRight) { path.addArc(tangent1End: CGPoint(x: r.maxX, y: r.maxY), tangent2End: CGPoint(x: r.maxX - rx, y: r.maxY), radius: rx) }
        path.addLine(to: CGPoint(x: r.minX + (c(.bottomLeft) ? rx : 0), y: r.maxY))
        if c(.bottomLeft) { path.addArc(tangent1End: CGPoint(x: r.minX, y: r.maxY), tangent2End: CGPoint(x: r.minX, y: r.maxY - ry), radius: rx) }
        path.addLine(to: CGPoint(x: r.minX, y: r.minY + (c(.topLeft) ? ry : 0)))
        if c(.topLeft) { path.addArc(tangent1End: CGPoint(x: r.minX, y: r.minY), tangent2End: CGPoint(x: r.minX + rx, y: r.minY), radius: rx) }
        path.closeSubpath()
    }
    public convenience init(arcCenter: CGPoint, radius: CGFloat, startAngle: CGFloat, endAngle: CGFloat, clockwise: Bool) {
        self.init(); path.addArc(center: arcCenter, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: !clockwise)
    }
    public convenience init(cgPath: CGPath) { self.init(); path = cgPath.mutableCopy()! }
    open func move(to p: CGPoint) { path.move(to: p) }
    open func addLine(to p: CGPoint) { path.addLine(to: p) }
    open func addCurve(to p: CGPoint, controlPoint1: CGPoint, controlPoint2: CGPoint) { path.addCurve(to: p, control1: controlPoint1, control2: controlPoint2) }
    open func addQuadCurve(to p: CGPoint, controlPoint: CGPoint) { path.addQuadCurve(to: p, control: controlPoint) }
    open func addArc(withCenter c: CGPoint, radius: CGFloat, startAngle: CGFloat, endAngle: CGFloat, clockwise: Bool) {
        path.addArc(center: c, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: !clockwise)
    }
    open func close() { path.closeSubpath() }
    open func removeAllPoints() { path = CGMutablePath() }
    open func append(_ p: UIBezierPath) { path.addPath(p.path) }
    open func apply(_ t: CGAffineTransform) { path = path.mutableCopy(using: [t])! }
    open func reversing() -> UIBezierPath { UIBezierPath(cgPath: path) }
    open var isEmpty: Bool { path.isEmpty }
    open var bounds: CGRect { path.boundingBox }
    open var currentPoint: CGPoint { path.currentPoint }
    open func contains(_ p: CGPoint) -> Bool { path.contains(p, using: usesEvenOddFillRule ? .evenOdd : .winding) }
    open func setLineDash(_ pattern: UnsafePointer<CGFloat>?, count: Int, phase: CGFloat) {
        dash = pattern.map { p in (phase, (0..<count).map { p[$0] }) }
    }
    private func applyStyle(_ c: CGContext) {
        c.setLineWidth(lineWidth); c.setLineCap(lineCapStyle); c.setLineJoin(lineJoinStyle); c.setMiterLimit(miterLimit)
        if let d = dash { c.setLineDash(phase: d.0, lengths: d.1) }
    }
    open func fill() { guard let c = UIGraphicsGetCurrentContext() else { return }; c.addPath(path); c.fillPath(using: usesEvenOddFillRule ? .evenOdd : .winding) }
    open func fill(with m: CGBlendMode, alpha: CGFloat) { guard let c = UIGraphicsGetCurrentContext() else { return }; c.saveGState(); c.setBlendMode(m); c.setAlpha(alpha); fill(); c.restoreGState() }
    open func stroke() { guard let c = UIGraphicsGetCurrentContext() else { return }; c.saveGState(); applyStyle(c); c.addPath(path); c.strokePath(); c.restoreGState() }
    open func stroke(with m: CGBlendMode, alpha: CGFloat) { guard let c = UIGraphicsGetCurrentContext() else { return }; c.saveGState(); c.setBlendMode(m); c.setAlpha(alpha); stroke(); c.restoreGState() }
    open func addClip() { guard let c = UIGraphicsGetCurrentContext() else { return }; c.addPath(path); c.clip(using: usesEvenOddFillRule ? .evenOdd : .winding) }
}

// MARK: attributed text

extension NSAttributedString.Key {
    public static let font = NSAttributedString.Key("NSFont")
    public static let foregroundColor = NSAttributedString.Key("NSColor")
    public static let backgroundColor = NSAttributedString.Key("NSBackgroundColor")
    public static let paragraphStyle = NSAttributedString.Key("NSParagraphStyle")
    public static let kern = NSAttributedString.Key("NSKern")
    public static let tracking = NSAttributedString.Key("NSTracking")
    public static let ligature = NSAttributedString.Key("NSLigature")
    public static let strikethroughStyle = NSAttributedString.Key("NSStrikethrough")
    public static let strikethroughColor = NSAttributedString.Key("NSStrikethroughColor")
    public static let underlineStyle = NSAttributedString.Key("NSUnderline")
    public static let underlineColor = NSAttributedString.Key("NSUnderlineColor")
    public static let strokeColor = NSAttributedString.Key("NSStrokeColor")
    public static let strokeWidth = NSAttributedString.Key("NSStrokeWidth")
    public static let shadow = NSAttributedString.Key("NSShadow")
    public static let textEffect = NSAttributedString.Key("NSTextEffect")
    public static let attachment = NSAttributedString.Key("NSAttachment")
    public static let link = NSAttributedString.Key("NSLink")
    public static let baselineOffset = NSAttributedString.Key("NSBaselineOffset")
    public static let obliqueness = NSAttributedString.Key("NSObliqueness")
    public static let expansion = NSAttributedString.Key("NSExpansion")
    public static let writingDirection = NSAttributedString.Key("NSWritingDirection")
    public static let verticalGlyphForm = NSAttributedString.Key("CTVerticalForms")
}

public enum NSTextAlignment: Int { case left = 0, center = 1, right = 2, justified = 3, natural = 4 }
public enum NSLineBreakMode: Int { case byWordWrapping = 0, byCharWrapping, byClipping, byTruncatingHead, byTruncatingTail, byTruncatingMiddle }
public enum NSWritingDirection: Int { case natural = -1, leftToRight = 0, rightToLeft = 1 }
public enum NSLineBreakStrategy: Int { case none = 0, pushOut = 1, hangulWordPriority = 2, standard = 0xFFFF }
public struct NSUnderlineStyle: OptionSet, Hashable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let single = NSUnderlineStyle(rawValue: 1)
    public static let thick = NSUnderlineStyle(rawValue: 2)
    public static let double = NSUnderlineStyle(rawValue: 9)
    public static let patternDot = NSUnderlineStyle(rawValue: 0x100)
    public static let patternDash = NSUnderlineStyle(rawValue: 0x200)
    public static let patternDashDot = NSUnderlineStyle(rawValue: 0x300)
    public static let patternDashDotDot = NSUnderlineStyle(rawValue: 0x400)
    public static let byWord = NSUnderlineStyle(rawValue: 0x8000)
}
public struct NSStringDrawingOptions: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let usesLineFragmentOrigin = NSStringDrawingOptions(rawValue: 1)
    public static let usesFontLeading = NSStringDrawingOptions(rawValue: 2)
    public static let usesDeviceMetrics = NSStringDrawingOptions(rawValue: 8)
    public static let truncatesLastVisibleLine = NSStringDrawingOptions(rawValue: 32)
}
open class NSStringDrawingContext: NSObject {
    open var minimumScaleFactor: CGFloat = 0
    public private(set) var actualScaleFactor: CGFloat = 1
    public internal(set) var totalBounds: CGRect = .zero
    public override init() {}
}
open class NSTextTab: NSObject {
    public let alignment: NSTextAlignment
    public let location: CGFloat
    public init(textAlignment: NSTextAlignment, location: CGFloat, options: [String: Any] = [:]) { alignment = textAlignment; self.location = location }
}
open class NSParagraphStyle: NSObject, NSCopying, NSMutableCopying {
    open internal(set) var alignment: NSTextAlignment = .natural
    open internal(set) var lineSpacing: CGFloat = 0
    open internal(set) var paragraphSpacing: CGFloat = 0
    open internal(set) var paragraphSpacingBefore: CGFloat = 0
    open internal(set) var headIndent: CGFloat = 0
    open internal(set) var tailIndent: CGFloat = 0
    open internal(set) var firstLineHeadIndent: CGFloat = 0
    open internal(set) var minimumLineHeight: CGFloat = 0
    open internal(set) var maximumLineHeight: CGFloat = 0
    open internal(set) var lineHeightMultiple: CGFloat = 0
    open internal(set) var lineBreakMode: NSLineBreakMode = .byWordWrapping
    open internal(set) var baseWritingDirection: NSWritingDirection = .natural
    open internal(set) var hyphenationFactor: Float = 0
    open internal(set) var tabStops: [NSTextTab] = []
    open internal(set) var defaultTabInterval: CGFloat = 0
    open internal(set) var allowsDefaultTighteningForTruncation = false
    open internal(set) var lineBreakStrategy: NSLineBreakStrategy = .none
    public override init() {}
    nonisolated(unsafe) public static let `default` = NSParagraphStyle()
    public class func defaultWritingDirection(forLanguage l: String?) -> NSWritingDirection { .leftToRight }
    func copyValues(to p: NSParagraphStyle) {
        p.alignment = alignment; p.lineSpacing = lineSpacing; p.paragraphSpacing = paragraphSpacing; p.paragraphSpacingBefore = paragraphSpacingBefore
        p.headIndent = headIndent; p.tailIndent = tailIndent; p.firstLineHeadIndent = firstLineHeadIndent; p.minimumLineHeight = minimumLineHeight
        p.maximumLineHeight = maximumLineHeight; p.lineHeightMultiple = lineHeightMultiple; p.lineBreakMode = lineBreakMode
        p.baseWritingDirection = baseWritingDirection; p.hyphenationFactor = hyphenationFactor; p.tabStops = tabStops; p.defaultTabInterval = defaultTabInterval
    }
    open func copy(with zone: NSZone? = nil) -> Any { let p = NSParagraphStyle(); copyValues(to: p); return p }
    open func mutableCopy(with zone: NSZone? = nil) -> Any { let p = NSMutableParagraphStyle(); copyValues(to: p); return p }
}
open class NSMutableParagraphStyle: NSParagraphStyle {
    open override var alignment: NSTextAlignment { get { super.alignment } set { super.alignment = newValue } }
    open override var lineSpacing: CGFloat { get { super.lineSpacing } set { super.lineSpacing = newValue } }
    open override var paragraphSpacing: CGFloat { get { super.paragraphSpacing } set { super.paragraphSpacing = newValue } }
    open override var paragraphSpacingBefore: CGFloat { get { super.paragraphSpacingBefore } set { super.paragraphSpacingBefore = newValue } }
    open override var headIndent: CGFloat { get { super.headIndent } set { super.headIndent = newValue } }
    open override var tailIndent: CGFloat { get { super.tailIndent } set { super.tailIndent = newValue } }
    open override var firstLineHeadIndent: CGFloat { get { super.firstLineHeadIndent } set { super.firstLineHeadIndent = newValue } }
    open override var minimumLineHeight: CGFloat { get { super.minimumLineHeight } set { super.minimumLineHeight = newValue } }
    open override var maximumLineHeight: CGFloat { get { super.maximumLineHeight } set { super.maximumLineHeight = newValue } }
    open override var lineHeightMultiple: CGFloat { get { super.lineHeightMultiple } set { super.lineHeightMultiple = newValue } }
    open override var lineBreakMode: NSLineBreakMode { get { super.lineBreakMode } set { super.lineBreakMode = newValue } }
    open override var baseWritingDirection: NSWritingDirection { get { super.baseWritingDirection } set { super.baseWritingDirection = newValue } }
    open override var hyphenationFactor: Float { get { super.hyphenationFactor } set { super.hyphenationFactor = newValue } }
    open override var tabStops: [NSTextTab] { get { super.tabStops } set { super.tabStops = newValue } }
    open override var defaultTabInterval: CGFloat { get { super.defaultTabInterval } set { super.defaultTabInterval = newValue } }
    open override var allowsDefaultTighteningForTruncation: Bool { get { super.allowsDefaultTighteningForTruncation } set { super.allowsDefaultTighteningForTruncation = newValue } }
    open override var lineBreakStrategy: NSLineBreakStrategy { get { super.lineBreakStrategy } set { super.lineBreakStrategy = newValue } }
    public override init() { super.init() }
    open func setParagraphStyle(_ p: NSParagraphStyle) { p.copyValues(to: self) }
    open func addTabStop(_ t: NSTextTab) { tabStops.append(t) }
}
open class NSShadow: NSObject {
    open var shadowOffset: CGSize = .zero
    open var shadowBlurRadius: CGFloat = 0
    open var shadowColor: Any?
    public override init() {}
}
extension NSAttributedString {
    /// U+FFFC with the attachment attribute, as on Darwin.
    public convenience init(attachment: NSTextAttachment) { self.init(string: "\u{FFFC}", attributes: [.attachment: attachment]) }
}

/// TextKit 2 attachment view provider (iOS 15). Registered classes are kept; text layout does not host views yet.
open class NSTextAttachmentViewProvider: NSObject {
    public weak var textAttachment: NSTextAttachment?
    public var view: UIView?
    public init(textAttachment: NSTextAttachment, parentView: UIView?, textLayoutManager: AnyObject?, location: AnyObject?) { self.textAttachment = textAttachment }
    open func loadView() {}
}

open class NSTextAttachment: NSObject {
    open var image: UIImage?
    open var bounds: CGRect = .zero
    open var contents: Data?
    open var fileType: String?
    public override init() {}
    public init(data: Data?, ofType uti: String?) { contents = data; fileType = uti }
    nonisolated(unsafe) static var viewProviders: [String: NSTextAttachmentViewProvider.Type] = [:]
    open class func registerViewProviderClass(_ cls: NSTextAttachmentViewProvider.Type, forFileType fileType: String) { viewProviders[fileType] = cls }
    public convenience init(image: UIImage) { self.init(); self.image = image }
}

// MARK: layout & drawing of attributed strings

/// Paragraph layout used by string drawing and UILabel: word wrap with CoreText, alignment from the paragraph style.
enum WebTextLayout {
    struct Line { let line: CTLine; let origin: CGPoint /* baseline-left, y down */; let height: CGFloat }
    static func layout(_ s: NSAttributedString, width: CGFloat, maxHeight: CGFloat = .greatestFiniteMagnitude, singleLine: Bool = false) -> (lines: [Line], size: CGSize) {
        let ts = CTTypesetterCreateWithAttributedString(s)
        var lines: [Line] = []
        var y: CGFloat = 0, maxW: CGFloat = 0
        var start = 0
        let len = s.length
        while start < len {
            let para = (start < len ? s.attribute(.paragraphStyle, at: start, effectiveRange: nil) : nil) as? NSParagraphStyle
            let n = singleLine ? len - start : max(1, CTTypesetterSuggestLineBreak(ts, start, Double(width)))
            var line = CTTypesetterCreateLine(ts, CFRange(location: start, length: n))
            if singleLine && Double(line.width) > Double(width) {
                let token = CTLineCreateWithAttributedString(NSAttributedString(string: "\u{2026}", attributes: s.attributes(at: max(0, start + n - 1), effectiveRange: nil)))
                line = CTLineCreateTruncatedLine(line, Double(width), .end, token) ?? line
            }
            var h = line.ascent + line.descent + line.leading
            if let p = para {
                if p.lineHeightMultiple > 0 { h *= p.lineHeightMultiple }
                if p.minimumLineHeight > 0 { h = max(h, p.minimumLineHeight) }
                if p.maximumLineHeight > 0 { h = min(h, p.maximumLineHeight) }
            }
            if y + h > maxHeight + 0.01 && !lines.isEmpty { break }
            let lw = line.width - line.trailingWhitespaceWidth
            var x: CGFloat = 0
            if width < .greatestFiniteMagnitude / 2 {
                switch para?.alignment ?? .natural {
                case .center: x = (width - lw) / 2
                case .right: x = width - lw
                default: break
                }
            }
            lines.append(Line(line: line, origin: CGPoint(x: x, y: y + h - line.descent), height: h))
            maxW = max(maxW, lw)
            y += h + (para?.lineSpacing ?? 0)
            start += n
        }
        return (lines, CGSize(width: maxW, height: y))
    }
    static func draw(_ s: NSAttributedString, in rect: CGRect, singleLine: Bool = false) {
        guard let c = UIGraphicsGetCurrentContext() else { return }
        let (lines, _) = layout(s, width: rect.width, maxHeight: rect.height, singleLine: singleLine)
        let saved = c.textMatrix
        c.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
        for l in lines {
            c.textPosition = CGPoint(x: rect.minX + l.origin.x, y: rect.minY + l.origin.y)
            CTLineDraw(l.line, c)
        }
        c.textMatrix = saved
    }
}

extension NSAttributedString {
    public func boundingRect(with size: CGSize, options: NSStringDrawingOptions = [], context: NSStringDrawingContext?) -> CGRect {
        let single = !options.contains(.usesLineFragmentOrigin)
        let (_, s) = WebTextLayout.layout(self, width: single ? .greatestFiniteMagnitude : size.width, maxHeight: size.height, singleLine: single)
        context?.totalBounds = CGRect(origin: .zero, size: s)
        return CGRect(origin: .zero, size: s)
    }
    public func size() -> CGSize { boundingRect(with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude), options: [], context: nil).size }
    public func draw(at p: CGPoint) { WebTextLayout.draw(self, in: CGRect(origin: p, size: CGSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)), singleLine: true) }
    public func draw(in r: CGRect) { WebTextLayout.draw(self, in: r) }
    public func draw(with r: CGRect, options: NSStringDrawingOptions = [], context: NSStringDrawingContext?) {
        WebTextLayout.draw(self, in: r, singleLine: !options.contains(.usesLineFragmentOrigin))
    }
}
extension NSString {
    public func size(withAttributes attrs: [NSAttributedString.Key: Any]? = nil) -> CGSize { NSAttributedString(string: self as String, attributes: attrs).size() }
    public func boundingRect(with size: CGSize, options: NSStringDrawingOptions = [], attributes: [NSAttributedString.Key: Any]? = nil, context: NSStringDrawingContext?) -> CGRect {
        NSAttributedString(string: self as String, attributes: attrs(attributes)).boundingRect(with: size, options: options, context: context)
    }
    public func draw(at p: CGPoint, withAttributes a: [NSAttributedString.Key: Any]? = nil) { NSAttributedString(string: self as String, attributes: attrs(a)).draw(at: p) }
    public func draw(in r: CGRect, withAttributes a: [NSAttributedString.Key: Any]? = nil) { NSAttributedString(string: self as String, attributes: attrs(a)).draw(in: r) }
    public func draw(with r: CGRect, options: NSStringDrawingOptions = [], attributes a: [NSAttributedString.Key: Any]? = nil, context: NSStringDrawingContext?) {
        NSAttributedString(string: self as String, attributes: attrs(a)).draw(with: r, options: options, context: context)
    }
    private func attrs(_ a: [NSAttributedString.Key: Any]?) -> [NSAttributedString.Key: Any]? { a }
}
extension String {
    public func size(withAttributes attrs: [NSAttributedString.Key: Any]? = nil) -> CGSize { (self as NSString).size(withAttributes: attrs) }
    public func boundingRect(with size: CGSize, options: NSStringDrawingOptions = [], attributes: [NSAttributedString.Key: Any]? = nil, context: NSStringDrawingContext?) -> CGRect {
        (self as NSString).boundingRect(with: size, options: options, attributes: attributes, context: context)
    }
    public func draw(at p: CGPoint, withAttributes a: [NSAttributedString.Key: Any]? = nil) { (self as NSString).draw(at: p, withAttributes: a) }
    public func draw(in r: CGRect, withAttributes a: [NSAttributedString.Key: Any]? = nil) { (self as NSString).draw(in: r, withAttributes: a) }
}
