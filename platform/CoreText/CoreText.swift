// Swiftboard CoreText (MIT): fonts, lines, runs and a typesetter for the browser.
// Glyphs are grapheme clusters; advances come from the host (`swiftboard.measure_text`, canvas measureText in the
// browser), cached per font and cluster. Drawing records text runs into the CGContext display list.
@_exported import CoreGraphics
import Foundation

// MARK: host text measurement

@_extern(wasm, module: "swiftboard", name: "measure_text")
func _hostMeasureText(_ font: UnsafePointer<UInt8>, _ fontLen: Int32, _ text: UnsafePointer<UInt8>, _ textLen: Int32) -> Double

public enum WebTextMeasure {
    nonisolated(unsafe) static var cache: [String: [String: CGFloat]] = [:]
    /// Width of `text` in `font` (CSS font shorthand), in points.
    public static func width(_ text: String, font: String) -> CGFloat {
        if let w = cache[font]?[text] { return w }
        var f = font, t = text
        let w = f.withUTF8 { fb in t.withUTF8 { tb in
            _hostMeasureText(fb.baseAddress!, Int32(fb.count), tb.baseAddress ?? UnsafePointer(bitPattern: 1)!, Int32(tb.count))
        } }
        cache[font, default: [:]][text] = CGFloat(w)
        return CGFloat(w)
    }
}

// MARK: fonts

public typealias CTFontSymbolicTraits = CTFontSymbolicTraitsSet
public struct CTFontSymbolicTraitsSet: OptionSet, Hashable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }
    public static let traitItalic = CTFontSymbolicTraitsSet(rawValue: 1 << 0)
    public static let traitBold = CTFontSymbolicTraitsSet(rawValue: 1 << 1)
    public static let traitExpanded = CTFontSymbolicTraitsSet(rawValue: 1 << 5)
    public static let traitCondensed = CTFontSymbolicTraitsSet(rawValue: 1 << 6)
    public static let traitMonoSpace = CTFontSymbolicTraitsSet(rawValue: 1 << 10)
    public static let italicTrait = traitItalic
    public static let boldTrait = traitBold
    public static let monoSpaceTrait = traitMonoSpace
}

public let kCTFontSystemFontFamily = "-apple-system, \"SF Pro Text\", \"Helvetica Neue\", system-ui, sans-serif"
public let kCTFontMonospacedFamily = "ui-monospace, \"SF Mono\", Menlo, monospace"

/// A font: CSS family, size, weight (100-900) and italic. UIFont subclasses it (UIFont and CTFont are toll-free bridged).
open class CTFont: NSObject {
    public let familyName: String
    public let fontName: String
    public let pointSize: CGFloat
    public let weightValue: CGFloat
    public let isItalic: Bool
    public let isMonospaced: Bool
    public var webFeatures: [String] = []

    public required init(webName name: String, family: String, size: CGFloat, weight: CGFloat, italic: Bool, monospaced: Bool) {
        fontName = name; familyName = family; pointSize = size; weightValue = weight; isItalic = italic; isMonospaced = monospaced
    }
    /// The class CoreText instantiates for new fonts (UIKit sets UIFont).
    nonisolated(unsafe) public static var webFontClass: CTFont.Type = CTFont.self
    public static func make(name: String, size: CGFloat) -> CTFont {
        let lower = name.lowercased()
        var weight: CGFloat = 400
        if lower.contains("ultralight") { weight = 100 } else if lower.contains("thin") { weight = 200 }
        else if lower.contains("light") { weight = 300 } else if lower.contains("medium") { weight = 500 }
        else if lower.contains("semibold") { weight = 600 } else if lower.contains("heavy") { weight = 800 }
        else if lower.contains("black") { weight = 900 } else if lower.contains("bold") { weight = 700 }
        let italic = lower.contains("italic") || lower.contains("oblique")
        let mono = lower.contains("mono") || lower.contains("menlo") || lower.contains("courier")
        let isSystem = lower.hasPrefix(".sf") || lower.hasPrefix("sf") || lower.hasPrefix(".apple") || lower.contains("system") || lower.hasPrefix("helvetica")
        let family = mono ? kCTFontMonospacedFamily : (isSystem ? kCTFontSystemFontFamily : "\"\(name.split(separator: "-").first.map(String.init) ?? name)\", \(kCTFontSystemFontFamily)")
        return webFontClass.init(webName: name, family: family, size: size, weight: weight, italic: italic, monospaced: mono)
    }
    open func withSize(_ size: CGFloat) -> CTFont { type(of: self).init(webName: fontName, family: familyName, size: size, weight: weightValue, italic: isItalic, monospaced: isMonospaced) }
    public func with(weight: CGFloat? = nil, italic: Bool? = nil, monospaced: Bool? = nil) -> CTFont {
        type(of: self).init(webName: fontName, family: monospaced == true ? kCTFontMonospacedFamily : familyName, size: pointSize,
                            weight: weight ?? weightValue, italic: italic ?? isItalic, monospaced: monospaced ?? isMonospaced)
    }

    public var css: String { "\(isItalic ? "italic " : "")\(Int(weightValue)) \(Double(pointSize))px \(familyName)" }
    public var textFont: CGTextFont { CGTextFont(family: familyName, size: pointSize, weight: weightValue, italic: isItalic) }
    open var ascender: CGFloat { pointSize * 0.952 }
    /// Negative, as in UIKit.
    open var descender: CGFloat { -pointSize * 0.241 }
    open var leading: CGFloat { 0 }
    open var lineHeight: CGFloat { pointSize * 1.1934 }
    open var capHeight: CGFloat { pointSize * 0.705 }
    open var xHeight: CGFloat { pointSize * 0.528 }
    public var symbolicTraits: CTFontSymbolicTraitsSet {
        var t: CTFontSymbolicTraitsSet = []
        if weightValue >= 600 { t.insert(.traitBold) }
        if isItalic { t.insert(.traitItalic) }
        if isMonospaced { t.insert(.traitMonoSpace) }
        return t
    }
    open override func isEqual(_ object: Any?) -> Bool {
        guard let o = object as? CTFont else { return false }
        return o.familyName == familyName && o.pointSize == pointSize && o.weightValue == weightValue && o.isItalic == isItalic && o.fontName == fontName
    }
    open override var hash: Int { fontName.hashValue ^ pointSize.hashValue }
    open override var description: String { "<font \(fontName) \(pointSize)pt w\(Int(weightValue))>" }

    /// Advance of one grapheme cluster.
    public func advance(of cluster: String) -> CGFloat {
        if cluster == "\n" || cluster == "\r\n" || cluster == "\u{2028}" { return 0 }
        if cluster == "\t" { return WebTextMeasure.width("    ", font: css) }
        return WebTextMeasure.width(cluster, font: css)
    }
}

public typealias CTFontDescriptor = NSDictionary
public typealias CTFontUIFontType = UInt32
public func CTFontCreateWithName(_ name: CFString, _ size: CGFloat, _ matrix: UnsafePointer<CGAffineTransform>?) -> CTFont { CTFont.make(name: name as String, size: size) }
/// CTFont and UIFont are toll-free bridged: where a UIFont is expected, make one.
public func CTFontCreateWithName<F: CTFont>(_ name: CFString, _ size: CGFloat, _ matrix: UnsafePointer<CGAffineTransform>?) -> F {
    let f = CTFont.make(name: name as String, size: size)
    return F(webName: f.fontName, family: f.familyName, size: f.pointSize, weight: f.weightValue, italic: f.isItalic, monospaced: f.isMonospaced)
}
public let kNumberSpacingType = 6
public let kMonospacedNumbersSelector = 0
public let kProportionalNumbersSelector = 1
public let kLowerCaseType = 37
public let kLowerCaseSmallCapsSelector = 1
public let kUpperCaseType = 38
public let kUpperCaseSmallCapsSelector = 1
public func CTFontCreateWithFontDescriptor(_ d: CTFontDescriptor, _ size: CGFloat, _ matrix: UnsafePointer<CGAffineTransform>?) -> CTFont {
    CTFont.make(name: (d["NSFontNameAttribute"] as? String) ?? ".SFUI-Regular", size: size)
}
public func CTFontCreateCopyWithAttributes(_ f: CTFont, _ size: CGFloat, _ matrix: UnsafePointer<CGAffineTransform>?, _ d: CTFontDescriptor?) -> CTFont {
    let c = f.withSize(size == 0 ? f.pointSize : size)
    if let feats = d?["NSCTFontFeatureSettingsAttribute"] as? [Any] { c.webFeatures = feats.map { "\($0)" } }
    return c
}
public func CTFontCreateCopyWithSymbolicTraits(_ f: CTFont, _ size: CGFloat, _ matrix: UnsafePointer<CGAffineTransform>?, _ value: CTFontSymbolicTraitsSet, _ mask: CTFontSymbolicTraitsSet) -> CTFont? {
    let base = f.withSize(size == 0 ? f.pointSize : size)
    let bold = mask.contains(.traitBold) ? value.contains(.traitBold) : f.weightValue >= 600
    let italic = mask.contains(.traitItalic) ? value.contains(.traitItalic) : f.isItalic
    let mono = mask.contains(.traitMonoSpace) ? value.contains(.traitMonoSpace) : f.isMonospaced
    return base.with(weight: bold ? max(700, f.weightValue) : (f.weightValue >= 600 ? 400 : f.weightValue), italic: italic, monospaced: mono)
}
public func CTFontGetSize(_ f: CTFont) -> CGFloat { f.pointSize }
public func CTFontGetAscent(_ f: CTFont) -> CGFloat { f.ascender }
public func CTFontGetDescent(_ f: CTFont) -> CGFloat { -f.descender }
public func CTFontGetLeading(_ f: CTFont) -> CGFloat { f.leading }
public func CTFontGetCapHeight(_ f: CTFont) -> CGFloat { f.capHeight }
public func CTFontGetXHeight(_ f: CTFont) -> CGFloat { f.xHeight }
public func CTFontGetUnderlinePosition(_ f: CTFont) -> CGFloat { -f.pointSize * 0.1 }
public func CTFontGetUnderlineThickness(_ f: CTFont) -> CGFloat { max(1, f.pointSize / 17) }
public func CTFontGetSymbolicTraits(_ f: CTFont) -> CTFontSymbolicTraitsSet { f.symbolicTraits }
public func CTFontCopyPostScriptName(_ f: CTFont) -> CFString { f.fontName as NSString }
public func CTFontCopyFamilyName(_ f: CTFont) -> CFString { f.familyName as NSString }
public func CTFontCopyFullName(_ f: CTFont) -> CFString { f.fontName as NSString }
public func CTFontGetBoundingBox(_ f: CTFont) -> CGRect { CGRect(x: 0, y: f.descender, width: f.pointSize, height: f.ascender - f.descender) }
public func CTFontGetGlyphsForCharacters(_ f: CTFont, _ chars: UnsafePointer<UniChar>, _ glyphs: UnsafeMutablePointer<CGGlyph>, _ count: CFIndex) -> Bool {
    for i in 0..<count { glyphs[i] = chars[i] }
    return true
}
public func CTFontGetAdvancesForGlyphs(_ f: CTFont, _ o: CTFontOrientation, _ glyphs: UnsafePointer<CGGlyph>, _ advances: UnsafeMutablePointer<CGSize>?, _ count: CFIndex) -> Double {
    var total: CGFloat = 0
    for i in 0..<count {
        let s = String(utf16CodeUnits: [glyphs[i]], count: 1)
        let w = f.advance(of: s)
        advances?[i] = CGSize(width: w, height: 0)
        total += w
    }
    return Double(total)
}
public func CTFontGetBoundingRectsForGlyphs(_ f: CTFont, _ o: CTFontOrientation, _ glyphs: UnsafePointer<CGGlyph>, _ rects: UnsafeMutablePointer<CGRect>?, _ count: CFIndex) -> CGRect {
    var total = CGRect.null
    for i in 0..<count {
        let w = f.advance(of: String(utf16CodeUnits: [glyphs[i]], count: 1))
        let r = CGRect(x: 0, y: 0, width: w, height: f.capHeight)
        rects?[i] = r
        total = total.union(r)
    }
    return total
}
public func CTFontCreatePathForGlyph(_ f: CTFont, _ g: CGGlyph, _ m: UnsafePointer<CGAffineTransform>?) -> CGPath? { nil }
public enum CTFontOrientation: UInt32 { case `default` = 0, horizontal, vertical }
public func CTFontDescriptorCreateWithAttributes(_ a: CFDictionary) -> CTFontDescriptor { a }

public let kCTFontAttributeName: CFString = "NSFont"
public let kCTForegroundColorAttributeName: CFString = "CTForegroundColor"
public let kCTForegroundColorFromContextAttributeName: CFString = "CTForegroundColorFromContext"
public let kCTKernAttributeName: CFString = "NSKern"
public let kCTParagraphStyleAttributeName: CFString = "NSParagraphStyle"
public let kCTUnderlineStyleAttributeName: CFString = "NSUnderline"
public let kCTUnderlineColorAttributeName: CFString = "CTUnderlineColor"
public let kCTStrokeWidthAttributeName: CFString = "NSStrokeWidth"
public let kCTStrokeColorAttributeName: CFString = "CTStrokeColor"
public let kCTBaselineOffsetAttributeName: CFString = "NSBaselineOffset"
public let kCTRunDelegateAttributeName: CFString = "CTRunDelegate"
public let kCTLigatureAttributeName: CFString = "NSLigature"
public let kCTFontFeatureSettingsAttribute: CFString = "NSCTFontFeatureSettingsAttribute"
public let kCTFontFeatureTypeIdentifierKey: CFString = "CTFeatureTypeIdentifier"
public let kCTFontFeatureSelectorIdentifierKey: CFString = "CTFeatureSelectorIdentifier"
public let kCTFontOpenTypeFeatureTag: CFString = "CTFeatureOpenTypeTag"
public let kCTFontOpenTypeFeatureValue: CFString = "CTFeatureOpenTypeValue"
public let kCTFontNameAttribute: CFString = "NSFontNameAttribute"
public let kCTFontFamilyNameAttribute: CFString = "NSFontFamilyAttribute"
public let kCTFontSizeAttribute: CFString = "NSFontSizeAttribute"
public let kCTFontTraitsAttribute: CFString = "NSCTFontTraitsAttribute"
public let kCTFontWeightTrait: CFString = "NSCTFontWeightTrait"
public let kCTFontSymbolicTrait: CFString = "NSCTFontSymbolicTrait"

/// Anything that can give a CGColor (UIColor adopts this so CoreText can read "NSColor" attributes).
public protocol WebCGColorConvertible { var cgColor: CGColor { get } }

/// Run delegates (inline attachments): fixed metrics from callbacks.
public final class CTRunDelegate {
    public let ascent: CGFloat, descent: CGFloat, width: CGFloat
    public let refCon: UnsafeMutableRawPointer?
    init(ascent: CGFloat, descent: CGFloat, width: CGFloat, refCon: UnsafeMutableRawPointer?) { self.ascent = ascent; self.descent = descent; self.width = width; self.refCon = refCon }
}
public struct CTRunDelegateCallbacks {
    public var version: Int32
    public var dealloc: @convention(c) (UnsafeMutableRawPointer) -> Void
    public var getAscent: (UnsafeMutableRawPointer) -> CGFloat
    public var getDescent: (UnsafeMutableRawPointer) -> CGFloat
    public var getWidth: (UnsafeMutableRawPointer) -> CGFloat
    public init(version: Int32, dealloc: @escaping @convention(c) (UnsafeMutableRawPointer) -> Void, getAscent: @escaping (UnsafeMutableRawPointer) -> CGFloat,
                getDescent: @escaping (UnsafeMutableRawPointer) -> CGFloat, getWidth: @escaping (UnsafeMutableRawPointer) -> CGFloat) {
        self.version = version; self.dealloc = dealloc; self.getAscent = getAscent; self.getDescent = getDescent; self.getWidth = getWidth
    }
}
public let kCTRunDelegateVersion1: Int32 = 1
public let kCTRunDelegateCurrentVersion: Int32 = 1
public func CTRunDelegateCreate(_ cb: UnsafePointer<CTRunDelegateCallbacks>, _ ref: UnsafeMutableRawPointer?) -> CTRunDelegate? {
    guard let ref else { return CTRunDelegate(ascent: 0, descent: 0, width: 0, refCon: nil) }
    let c = cb.pointee
    return CTRunDelegate(ascent: c.getAscent(ref), descent: c.getDescent(ref), width: c.getWidth(ref), refCon: ref)
}
public func CTRunDelegateGetRefCon(_ d: CTRunDelegate) -> UnsafeMutableRawPointer { d.refCon ?? UnsafeMutableRawPointer(bitPattern: 1)! }

// MARK: runs and lines

public struct CTRunStatus: OptionSet {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }
    public static let noStatus = CTRunStatus([])
    public static let rightToLeft = CTRunStatus(rawValue: 1)
    public static let nonMonotonic = CTRunStatus(rawValue: 2)
    public static let hasNonIdentityMatrix = CTRunStatus(rawValue: 4)
}

public final class CTRun {
    public let attributes: NSDictionary
    public let font: CTFont
    /// UTF-16 offset in the source string of each glyph (cluster).
    public internal(set) var indices: [CFIndex]
    public internal(set) var glyphs: [CGGlyph]
    public internal(set) var clusters: [String]
    /// x of each glyph relative to the line origin
    public internal(set) var positions: [CGPoint]
    public internal(set) var advances: [CGSize]
    public internal(set) var stringRange: CFRange
    public let status: CTRunStatus
    let delegate: CTRunDelegate?

    init(attributes: NSDictionary, font: CTFont, indices: [CFIndex], clusters: [String], positions: [CGPoint], advances: [CGSize], stringRange: CFRange, delegate: CTRunDelegate?) {
        self.attributes = attributes; self.font = font; self.indices = indices; self.clusters = clusters
        self.glyphs = clusters.map { $0.utf16.first ?? 0 }
        self.positions = positions; self.advances = advances; self.stringRange = stringRange
        self.status = clusters.contains(where: { c in c.unicodeScalars.first.map { (0x0590...0x08FF).contains($0.value) } ?? false }) ? .rightToLeft : []
        self.delegate = delegate
    }
    public var width: CGFloat { advances.reduce(0) { $0 + $1.width } }
    public var ascent: CGFloat { delegate?.ascent ?? font.ascender }
    public var descent: CGFloat { delegate?.descent ?? -font.descender }
    var text: String { clusters.joined() }
    var color: CGColor? {
        if attributes[kCTForegroundColorFromContextAttributeName as String] != nil { return nil }
        if let c = attributes["NSColor"] as? WebCGColorConvertible { return c.cgColor }
        if let c = attributes["NSColor"].map({ $0 as AnyObject }) as? CGColor { return c }
        if let c = attributes[kCTForegroundColorAttributeName as String].map({ $0 as AnyObject }) as? CGColor { return c }
        return CGColor.black
    }
}

public final class CTLine {
    public let runs: [CTRun]
    public let stringRange: CFRange
    init(runs: [CTRun], stringRange: CFRange) { self.runs = runs; self.stringRange = stringRange }
    public var width: CGFloat { runs.last.map { ($0.positions.last?.x ?? 0) + ($0.advances.last?.width ?? 0) } ?? 0 }
    public var ascent: CGFloat { runs.map { $0.ascent }.max() ?? 0 }
    public var descent: CGFloat { runs.map { $0.descent }.max() ?? 0 }
    public var leading: CGFloat { runs.map { $0.font.leading }.max() ?? 0 }
    public var trailingWhitespaceWidth: CGFloat {
        var w: CGFloat = 0
        outer: for r in runs.reversed() {
            for (i, c) in r.clusters.enumerated().reversed() {
                if c.allSatisfy({ $0.isWhitespace }) { w += r.advances[i].width } else { break outer }
            }
        }
        return w
    }
}

/// Lays out [start, end) of an attributed string into runs (no wrapping). `x0` is the starting pen position.
func layoutRuns(_ s: NSAttributedString, _ range: NSRange, x0: CGFloat = 0) -> [CTRun] {
    var runs: [CTRun] = []
    var x = x0
    let ns = s.string as NSString
    guard range.length > 0 else { return [] }
    s.enumerateAttributes(in: range, options: []) { attrs, r, _ in
        let dict = NSMutableDictionary()
        for (k, v) in attrs { dict[k.rawValue] = v }
        let font = (attrs[NSAttributedString.Key("NSFont")] as? CTFont) ?? CTFont.make(name: ".SFUI-Regular", size: 12)
        let kern = CGFloat((attrs[NSAttributedString.Key("NSKern")] as? NSNumber)?.doubleValue ?? 0)
        let delegate = attrs[NSAttributedString.Key(kCTRunDelegateAttributeName as String)].map { $0 as AnyObject } as? CTRunDelegate
        let sub = ns.substring(with: r)
        var indices: [CFIndex] = [], clusters: [String] = [], positions: [CGPoint] = [], advances: [CGSize] = []
        var off = r.location
        for ch in sub {
            let c = String(ch)
            let n = c.utf16.count
            let w = delegate.map { $0.width / CGFloat(max(1, sub.count)) } ?? (font.advance(of: c) + kern)
            indices.append(off); clusters.append(c); positions.append(CGPoint(x: x, y: 0)); advances.append(CGSize(width: w, height: 0))
            x += w
            off += n
        }
        runs.append(CTRun(attributes: dict, font: font, indices: indices, clusters: clusters, positions: positions, advances: advances,
                          stringRange: CFRange(location: r.location, length: r.length), delegate: delegate))
    }
    return runs
}

public func CTLineCreateWithAttributedString(_ s: CFAttributedString) -> CTLine {
    let len = s.length
    return CTLine(runs: layoutRuns(s, NSRange(location: 0, length: len)), stringRange: CFRange(location: 0, length: len))
}
public typealias CFAttributedString = NSAttributedString
public typealias CFMutableAttributedString = NSMutableAttributedString

public func CTLineGetGlyphRuns(_ l: CTLine) -> CFArray { l.runs as NSArray }
public func CTLineGetGlyphCount(_ l: CTLine) -> CFIndex { l.runs.reduce(0) { $0 + $1.glyphs.count } }
public func CTLineGetStringRange(_ l: CTLine) -> CFRange { l.stringRange }
public func CTLineGetTypographicBounds(_ l: CTLine, _ ascent: UnsafeMutablePointer<CGFloat>?, _ descent: UnsafeMutablePointer<CGFloat>?, _ leading: UnsafeMutablePointer<CGFloat>?) -> Double {
    ascent?.pointee = l.ascent; descent?.pointee = l.descent; leading?.pointee = l.leading
    return Double(l.width)
}
public func CTLineGetTrailingWhitespaceWidth(_ l: CTLine) -> Double { Double(l.trailingWhitespaceWidth) }
public func CTLineGetPenOffsetForFlush(_ l: CTLine, _ flushFactor: CGFloat, _ width: Double) -> Double {
    Double(max(0, (CGFloat(width) - (l.width - l.trailingWhitespaceWidth)) * flushFactor))
}
public func CTLineGetImageBounds(_ l: CTLine, _ ctx: CGContext?) -> CGRect { CGRect(x: 0, y: -l.descent, width: l.width, height: l.ascent + l.descent) }
public struct CTLineBoundsOptions: OptionSet {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let excludeTypographicLeading = CTLineBoundsOptions(rawValue: 1)
    public static let excludeTypographicShifts = CTLineBoundsOptions(rawValue: 2)
    public static let useHangingPunctuation = CTLineBoundsOptions(rawValue: 4)
    public static let useGlyphPathBounds = CTLineBoundsOptions(rawValue: 8)
    public static let useOpticalBounds = CTLineBoundsOptions(rawValue: 16)
    public static let includeLanguageExtents = CTLineBoundsOptions(rawValue: 32)
}
public func CTLineGetBoundsWithOptions(_ l: CTLine, _ o: CTLineBoundsOptions) -> CGRect {
    CGRect(x: 0, y: -l.descent, width: l.width, height: l.ascent + l.descent + (o.contains(.excludeTypographicLeading) ? 0 : l.leading))
}
public func CTLineGetOffsetForStringIndex(_ l: CTLine, _ idx: CFIndex, _ secondary: UnsafeMutablePointer<CGFloat>?) -> CGFloat {
    var result = l.width
    outer: for r in l.runs {
        for (i, gi) in r.indices.enumerated() where gi >= idx {
            result = r.positions[i].x
            break outer
        }
    }
    secondary?.pointee = result
    return result
}
public func CTLineGetStringIndexForPosition(_ l: CTLine, _ p: CGPoint) -> CFIndex {
    for r in l.runs {
        for (i, gi) in r.indices.enumerated() {
            if p.x < r.positions[i].x + r.advances[i].width / 2 { return gi }
        }
    }
    return l.stringRange.location + l.stringRange.length
}
public func CTLineEnumerateCaretOffsets(_ l: CTLine, _ block: (Double, CFIndex, Bool, UnsafeMutablePointer<Bool>) -> Void) {
    var stop = false
    for r in l.runs { for (i, gi) in r.indices.enumerated() { block(Double(r.positions[i].x), gi, true, &stop); if stop { return } } }
}

public enum CTLineTruncationType: UInt32 { case start = 0, end = 1, middle = 2 }

public func CTLineCreateTruncatedLine(_ l: CTLine, _ width: Double, _ type: CTLineTruncationType, _ token: CTLine?) -> CTLine? {
    if Double(l.width) <= width { return l }
    let tokenWidth = token?.width ?? 0
    let avail = CGFloat(width) - tokenWidth
    if avail < 0 { return token }
    var out: [CTRun] = []
    var cutIndex = l.stringRange.location
    switch type {
    case .end, .middle:
        for r in l.runs {
            var keep = 0
            for (i, p) in r.positions.enumerated() where p.x + r.advances[i].width <= avail { keep = i + 1 }
            if keep > 0 {
                let len = keep < r.indices.count ? r.indices[keep] - r.stringRange.location : r.stringRange.length
                out.append(CTRun(attributes: r.attributes, font: r.font, indices: Array(r.indices[..<keep]), clusters: Array(r.clusters[..<keep]),
                                 positions: Array(r.positions[..<keep]), advances: Array(r.advances[..<keep]),
                                 stringRange: CFRange(location: r.stringRange.location, length: len), delegate: r.delegate))
                cutIndex = r.stringRange.location + len
            }
            if keep < r.indices.count { break }
        }
        // trim trailing whitespace before the ellipsis
        if let token {
            let x = out.last.map { ($0.positions.last?.x ?? 0) + ($0.advances.last?.width ?? 0) } ?? 0
            for t in token.runs {
                out.append(CTRun(attributes: t.attributes, font: t.font, indices: t.indices.map { _ in cutIndex }, clusters: t.clusters,
                                 positions: t.positions.map { CGPoint(x: $0.x + x, y: 0) }, advances: t.advances,
                                 stringRange: CFRange(location: cutIndex, length: 0), delegate: nil))
            }
        }
    case .start:
        let total = l.width
        var x = tokenWidth
        if let token { out.append(contentsOf: token.runs) }
        for r in l.runs {
            var from = r.indices.count
            for (i, p) in r.positions.enumerated() where total - p.x <= avail { from = i; break }
            if from < r.indices.count {
                let shift = r.positions[from].x - x
                out.append(CTRun(attributes: r.attributes, font: r.font, indices: Array(r.indices[from...]), clusters: Array(r.clusters[from...]),
                                 positions: r.positions[from...].map { CGPoint(x: $0.x - shift, y: 0) }, advances: Array(r.advances[from...]),
                                 stringRange: CFRange(location: r.indices[from], length: r.stringRange.location + r.stringRange.length - r.indices[from]), delegate: r.delegate))
                x = out.last!.positions.last!.x + out.last!.advances.last!.width
            }
        }
    }
    return CTLine(runs: out, stringRange: l.stringRange)
}
public func CTLineCreateJustifiedLine(_ l: CTLine, _ factor: CGFloat, _ width: Double) -> CTLine? { l }

public func CTRunGetGlyphCount(_ r: CTRun) -> CFIndex { r.glyphs.count }
public func CTRunGetAttributes(_ r: CTRun) -> CFDictionary { r.attributes }
public func CTRunGetStatus(_ r: CTRun) -> CTRunStatus { r.status }
public func CTRunGetStringRange(_ r: CTRun) -> CFRange { r.stringRange }
public func CTRunGetGlyphsPtr(_ r: CTRun) -> UnsafePointer<CGGlyph>? { nil }
public func CTRunGetPositionsPtr(_ r: CTRun) -> UnsafePointer<CGPoint>? { nil }
public func CTRunGetAdvancesPtr(_ r: CTRun) -> UnsafePointer<CGSize>? { nil }
public func CTRunGetStringIndicesPtr(_ r: CTRun) -> UnsafePointer<CFIndex>? { nil }
private func copyOut<T>(_ src: [T], _ range: CFRange, _ dst: UnsafeMutablePointer<T>) {
    let start = range.location, n = range.length == 0 ? src.count - start : range.length
    for i in 0..<max(0, n) where start + i < src.count { dst[i] = src[start + i] }
}
public func CTRunGetGlyphs(_ r: CTRun, _ range: CFRange, _ buf: UnsafeMutablePointer<CGGlyph>) { copyOut(r.glyphs, range, buf) }
public func CTRunGetPositions(_ r: CTRun, _ range: CFRange, _ buf: UnsafeMutablePointer<CGPoint>) { copyOut(r.positions, range, buf) }
public func CTRunGetAdvances(_ r: CTRun, _ range: CFRange, _ buf: UnsafeMutablePointer<CGSize>) { copyOut(r.advances, range, buf) }
public func CTRunGetStringIndices(_ r: CTRun, _ range: CFRange, _ buf: UnsafeMutablePointer<CFIndex>) { copyOut(r.indices, range, buf) }
public func CTRunGetTypographicBounds(_ r: CTRun, _ range: CFRange, _ ascent: UnsafeMutablePointer<CGFloat>?, _ descent: UnsafeMutablePointer<CGFloat>?, _ leading: UnsafeMutablePointer<CGFloat>?) -> Double {
    ascent?.pointee = r.ascent; descent?.pointee = r.descent; leading?.pointee = r.font.leading
    let start = range.location, n = range.length == 0 ? r.advances.count - start : range.length
    var w: CGFloat = 0
    for i in 0..<max(0, n) where start + i < r.advances.count { w += r.advances[start + i].width }
    return Double(w)
}
public func CTRunGetImageBounds(_ r: CTRun, _ ctx: CGContext?, _ range: CFRange) -> CGRect {
    let w = CTRunGetTypographicBounds(r, range, nil, nil, nil)
    let x = r.positions.indices.contains(range.location) ? r.positions[range.location].x : 0
    return CGRect(x: x, y: -r.descent, width: CGFloat(w), height: r.ascent + r.descent)
}
public func CTRunGetTextMatrix(_ r: CTRun) -> CGAffineTransform { .identity }

// MARK: drawing

private func drawRun(_ r: CTRun, _ range: CFRange, _ ctx: CGContext) {
    guard r.delegate == nil else { return }
    let start = range.location, n = range.length == 0 ? r.clusters.count - start : range.length
    guard n > 0, start < r.clusters.count else { return }
    let end = min(r.clusters.count, start + n)
    let text = r.clusters[start..<end].joined()
    if text.allSatisfy({ $0.isWhitespace }) { return }
    let p = CGPoint(x: ctx.textPosition.x + r.positions[start].x, y: ctx.textPosition.y)
    // CoreText leaves a run's foreground color as the context fill color (runs "from context" then inherit it)
    let color = r.color
    if let color { ctx.setFillColor(color) }
    ctx.record(.text(text, font: r.font.textFont, at: p, textMatrix: ctx.textMatrix, color: color))
}
public func CTLineDraw(_ l: CTLine, _ ctx: CGContext) { for r in l.runs { drawRun(r, CFRange(location: 0, length: 0), ctx) } }
public func CTRunDraw(_ r: CTRun, _ ctx: CGContext, _ range: CFRange) { drawRun(r, range, ctx) }

// MARK: typesetter

public final class CTTypesetter {
    let string: NSAttributedString
    init(_ s: NSAttributedString) { string = s }
}
public func CTTypesetterCreateWithAttributedString(_ s: CFAttributedString) -> CTTypesetter { CTTypesetter(s) }
public func CTTypesetterCreateLine(_ t: CTTypesetter, _ range: CFRange) -> CTLine { CTTypesetterCreateLineWithOffset(t, range, 0) }
public func CTTypesetterCreateLineWithOffset(_ t: CTTypesetter, _ range: CFRange, _ offset: Double) -> CTLine {
    let len = range.length == 0 ? t.string.length - range.location : range.length
    let r = NSRange(location: range.location, length: max(0, len))
    return CTLine(runs: layoutRuns(t.string, r, x0: 0), stringRange: CFRange(location: r.location, length: r.length))
}
/// UTF-16 count from `start` that fits in `width`, breaking after whitespace when possible (word wrap).
public func CTTypesetterSuggestLineBreak(_ t: CTTypesetter, _ start: CFIndex, _ width: Double) -> CFIndex {
    suggestBreak(t, start, width, words: true)
}
public func CTTypesetterSuggestLineBreakWithOffset(_ t: CTTypesetter, _ start: CFIndex, _ width: Double, _ offset: Double) -> CFIndex {
    suggestBreak(t, start, width - offset, words: true)
}
public func CTTypesetterSuggestClusterBreak(_ t: CTTypesetter, _ start: CFIndex, _ width: Double) -> CFIndex {
    suggestBreak(t, start, width, words: false)
}
public func CTTypesetterSuggestClusterBreakWithOffset(_ t: CTTypesetter, _ start: CFIndex, _ width: Double, _ offset: Double) -> CFIndex {
    suggestBreak(t, start, width - offset, words: false)
}
private func suggestBreak(_ t: CTTypesetter, _ start: CFIndex, _ width: Double, words: Bool) -> CFIndex {
    let total = t.string.length
    guard start < total else { return 0 }
    let runs = layoutRuns(t.string, NSRange(location: start, length: total - start))
    var lastFit = 0, lastSpaceBreak = 0
    for r in runs {
        for (i, c) in r.clusters.enumerated() {
            let endUTF16 = r.indices[i] + c.utf16.count - start
            if c == "\n" || c == "\r\n" || c == "\u{2028}" || c == "\r" { return endUTF16 }
            let fits = Double(r.positions[i].x + r.advances[i].width) <= width + 0.001
            if c.allSatisfy({ $0.isWhitespace }) { lastSpaceBreak = endUTF16; lastFit = endUTF16; continue }
            if !fits {
                if words && lastSpaceBreak > 0 { return lastSpaceBreak }
                return max(lastFit, c.utf16.count == 0 ? 1 : (lastFit == 0 ? endUTF16 : lastFit))
            }
            lastFit = endUTF16
        }
    }
    return total - start
}

// MARK: framesetter (whole-paragraph layout)

public final class CTFramesetter { let typesetter: CTTypesetter; init(_ s: NSAttributedString) { typesetter = CTTypesetter(s) } }
public final class CTFrame {
    public let lines: [CTLine]
    public let origins: [CGPoint]
    public let path: CGPath
    init(lines: [CTLine], origins: [CGPoint], path: CGPath) { self.lines = lines; self.origins = origins; self.path = path }
}
public func CTFramesetterCreateWithAttributedString(_ s: CFAttributedString) -> CTFramesetter { CTFramesetter(s) }
public func CTFramesetterGetTypesetter(_ f: CTFramesetter) -> CTTypesetter { f.typesetter }
private func frameLines(_ f: CTFramesetter, _ range: CFRange, width: CGFloat, maxHeight: CGFloat) -> ([CTLine], [CGFloat]) {
    let ts = f.typesetter
    var lines: [CTLine] = [], baselines: [CGFloat] = []
    var start = range.location
    let end = range.length == 0 ? ts.string.length : range.location + range.length
    var y: CGFloat = 0
    while start < end {
        let n = max(1, CTTypesetterSuggestLineBreak(ts, start, Double(width)))
        let line = CTTypesetterCreateLine(ts, CFRange(location: start, length: min(n, end - start)))
        let h = line.ascent + line.descent + line.leading
        if y + h > maxHeight + 0.01 && !lines.isEmpty { break }
        lines.append(line); baselines.append(y + line.ascent)
        y += h
        start += n
    }
    return (lines, baselines)
}
public func CTFramesetterSuggestFrameSizeWithConstraints(_ f: CTFramesetter, _ range: CFRange, _ attrs: CFDictionary?, _ constraints: CGSize, _ fitRange: UnsafeMutablePointer<CFRange>?) -> CGSize {
    let (lines, _) = frameLines(f, range, width: constraints.width, maxHeight: constraints.height)
    let w = lines.map { $0.width - $0.trailingWhitespaceWidth }.max() ?? 0
    let h = lines.reduce(0) { $0 + $1.ascent + $1.descent + $1.leading }
    fitRange?.pointee = CFRange(location: range.location, length: lines.reduce(0) { $0 + $1.stringRange.length })
    return CGSize(width: ceil(w), height: ceil(h))
}
public func CTFramesetterCreateFrame(_ f: CTFramesetter, _ range: CFRange, _ path: CGPath, _ attrs: CFDictionary?) -> CTFrame {
    let box = path.boundingBox
    let (lines, baselines) = frameLines(f, range, width: box.width, maxHeight: box.height)
    // CoreText origins are y-up relative to the path's bottom-left
    let origins = baselines.map { CGPoint(x: 0, y: box.height - $0) }
    return CTFrame(lines: lines, origins: origins, path: path)
}
public func CTFrameGetLines(_ f: CTFrame) -> CFArray { f.lines as NSArray }
public func CTFrameGetLineOrigins(_ f: CTFrame, _ range: CFRange, _ origins: UnsafeMutablePointer<CGPoint>) { copyOut(f.origins, range, origins) }
public func CTFrameDraw(_ f: CTFrame, _ ctx: CGContext) {
    let box = f.path.boundingBox
    for (l, o) in zip(f.lines, f.origins) { ctx.textPosition = CGPoint(x: box.minX + o.x, y: box.minY + o.y); CTLineDraw(l, ctx) }
}
