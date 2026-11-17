// Swiftboard CoreGraphics (MIT): colors, color spaces, bitmap formats, CF stand-ins.
import Foundation

public typealias CFArray = NSArray
public typealias CFMutableArray = NSMutableArray
public typealias CFString = NSString
public typealias CFDictionary = NSDictionary
public typealias CFMutableDictionary = NSMutableDictionary
public typealias CFData = NSData
public typealias CFMutableData = NSMutableData
public typealias CFNumber = NSNumber
public typealias CFBoolean = NSNumber
public typealias CFTypeRef = AnyObject
public typealias CFIndex = Int
public typealias CFTimeInterval = Double
public typealias CFAllocator = AnyObject
public typealias CFURL = NSURL
public let kCFBooleanTrue: CFBoolean = NSNumber(value: true)
public let kCFBooleanFalse: CFBoolean = NSNumber(value: false)
public let kCFAllocatorDefault: CFAllocator? = nil
public let kCFNull: NSNull = NSNull()
public struct CFRange: Equatable {
    public var location: CFIndex
    public var length: CFIndex
    public init() { location = 0; length = 0 }
    public init(location: CFIndex, length: CFIndex) { self.location = location; self.length = length }
}
public func CFRangeMake(_ loc: CFIndex, _ len: CFIndex) -> CFRange { CFRange(location: loc, length: len) }
public func CFArrayGetCount(_ a: CFArray) -> CFIndex { a.count }
public func CFStringGetLength(_ s: CFString) -> CFIndex { s.length }

public final class CGColorSpace: Hashable {
    public enum Model: Int32 { case unknown = -1, monochrome = 0, rgb = 1, cmyk = 2, lab = 3, deviceN = 4, indexed = 5, pattern = 6, XYZ = 7 }
    public let name: CFString?
    public let model: Model
    public init?(name: CFString) {
        self.name = name
        self.model = (name as String).lowercased().contains("gray") ? .monochrome : .rgb
    }
    init(model: Model, name: String) { self.model = model; self.name = name as NSString }
    public var numberOfComponents: Int { model == .monochrome ? 1 : 3 }
    public static let sRGB: CFString = "kCGColorSpaceSRGB"
    public static let displayP3: CFString = "kCGColorSpaceDisplayP3"
    public static let extendedSRGB: CFString = "kCGColorSpaceExtendedSRGB"
    public static let linearSRGB: CFString = "kCGColorSpaceLinearSRGB"
    public static let genericGrayGamma2_2: CFString = "kCGColorSpaceGenericGrayGamma2_2"
    public static let linearGray: CFString = "kCGColorSpaceLinearGray"
    public static let extendedGray: CFString = "kCGColorSpaceExtendedGray"
    public static let deviceRGB = CGColorSpace(model: .rgb, name: "kCGColorSpaceDeviceRGB")
    public static let deviceGray = CGColorSpace(model: .monochrome, name: "kCGColorSpaceDeviceGray")
    public static func == (a: CGColorSpace, b: CGColorSpace) -> Bool { a.model == b.model }
    public func hash(into h: inout Hasher) { h.combine(model) }
}
public func CGColorSpaceCreateDeviceRGB() -> CGColorSpace { .deviceRGB }
public func CGColorSpaceCreateDeviceGray() -> CGColorSpace { .deviceGray }
public func CGColorSpaceGetNumberOfComponents(_ s: CGColorSpace?) -> Int { s?.numberOfComponents ?? 3 }

public enum CGColorRenderingIntent: Int32 { case defaultIntent, absoluteColorimetric, relativeColorimetric, perceptual, saturation }

/// An RGBA color (sRGB). Gray colors are stored expanded to RGB.
public final class CGColor: Hashable, CustomStringConvertible {
    public let r: CGFloat, g: CGFloat, b: CGFloat
    public let alpha: CGFloat
    public let colorSpace: CGColorSpace?
    /// Pattern colors (UIColor(patternImage:)) keep their image.
    public let patternImage: CGImage?

    public init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        r = red; g = green; b = blue; self.alpha = alpha; colorSpace = .deviceRGB; patternImage = nil
    }
    public convenience init(srgbRed red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) { self.init(red: red, green: green, blue: blue, alpha: alpha) }
    public init(gray: CGFloat, alpha: CGFloat) {
        r = gray; g = gray; b = gray; self.alpha = alpha; colorSpace = .deviceGray; patternImage = nil
    }
    public init(patternImage: CGImage) { r = 0; g = 0; b = 0; alpha = 1; colorSpace = .deviceRGB; self.patternImage = patternImage }
    public convenience init?(colorSpace: CGColorSpace, components: UnsafePointer<CGFloat>) {
        if colorSpace.model == .monochrome { self.init(gray: components[0], alpha: components[1]) }
        else { self.init(red: components[0], green: components[1], blue: components[2], alpha: components[3]) }
    }
    public var components: [CGFloat]? { colorSpace?.model == .monochrome ? [r, alpha] : [r, g, b, alpha] }
    public var numberOfComponents: Int { components!.count }
    public func copy(alpha: CGFloat) -> CGColor? {
        colorSpace?.model == .monochrome ? CGColor(gray: r, alpha: alpha) : CGColor(red: r, green: g, blue: b, alpha: alpha)
    }
    public func converted(to space: CGColorSpace, intent: CGColorRenderingIntent, options: CFDictionary?) -> CGColor? {
        space.model == .monochrome ? CGColor(gray: (r + g + b) / 3, alpha: alpha) : CGColor(red: r, green: g, blue: b, alpha: alpha)
    }
    public static let black = CGColor(gray: 0, alpha: 1)
    public static let white = CGColor(gray: 1, alpha: 1)
    public static let clear = CGColor(gray: 0, alpha: 0)
    public static func == (a: CGColor, b: CGColor) -> Bool { a.r == b.r && a.g == b.g && a.b == b.b && a.alpha == b.alpha && a.patternImage === b.patternImage }
    public func hash(into h: inout Hasher) { h.combine(r); h.combine(g); h.combine(b); h.combine(alpha) }
    /// CSS color string, e.g. `rgba(255,0,0,0.5)`.
    public var css: String {
        func c(_ v: CGFloat) -> Int { Int((max(0, min(1, v)) * 255).rounded()) }
        return "rgba(\(c(r)),\(c(g)),\(c(b)),\(Double(Int(alpha * 1000)) / 1000))"
    }
    public var description: String { css }
}
public func CGColorCreate(_ space: CGColorSpace?, _ components: UnsafePointer<CGFloat>?) -> CGColor? {
    guard let space, let components else { return nil }
    return CGColor(colorSpace: space, components: components)
}
public func CGColorEqualToColor(_ a: CGColor?, _ b: CGColor?) -> Bool { a == b }
public func CGColorGetAlpha(_ c: CGColor) -> CGFloat { c.alpha }

public enum CGImageAlphaInfo: UInt32 {
    case none = 0, premultipliedLast, premultipliedFirst, last, first, noneSkipLast, noneSkipFirst, alphaOnly
}
public enum CGImageByteOrderInfo: UInt32 {
    case orderMask = 0x7000, orderDefault = 0, order16Little = 0x1000, order32Little = 0x2000, order16Big = 0x3000, order32Big = 0x4000
}
public struct CGBitmapInfo: OptionSet, Hashable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }
    public init(alphaInfo: CGImageAlphaInfo) { rawValue = alphaInfo.rawValue }
    public static let alphaInfoMask = CGBitmapInfo(rawValue: 0x1F)
    public static let floatInfoMask = CGBitmapInfo(rawValue: 0xF00)
    public static let floatComponents = CGBitmapInfo(rawValue: 1 << 8)
    public static let byteOrderMask = CGBitmapInfo(rawValue: 0x7000)
    public static let byteOrderDefault = CGBitmapInfo(rawValue: 0)
    public static let byteOrder16Little = CGBitmapInfo(rawValue: 0x1000)
    public static let byteOrder32Little = CGBitmapInfo(rawValue: 0x2000)
    public static let byteOrder16Big = CGBitmapInfo(rawValue: 0x3000)
    public static let byteOrder32Big = CGBitmapInfo(rawValue: 0x4000)
    public static var byteOrder32Host: CGBitmapInfo { .byteOrder32Little }
    public static var byteOrder16Host: CGBitmapInfo { .byteOrder16Little }
}

public enum CGBlendMode: Int32 {
    case normal, multiply, screen, overlay, darken, lighten, colorDodge, colorBurn, softLight, hardLight, difference, exclusion,
         hue, saturation, color, luminosity, clear, copy, sourceIn, sourceOut, sourceAtop, destinationOver, destinationIn,
         destinationOut, destinationAtop, xor, plusDarker, plusLighter
    /// Canvas 2D globalCompositeOperation.
    public var css: String {
        switch self {
        case .normal: return "source-over"
        case .multiply: return "multiply"
        case .screen: return "screen"
        case .overlay: return "overlay"
        case .darken: return "darken"
        case .lighten: return "lighten"
        case .colorDodge: return "color-dodge"
        case .colorBurn: return "color-burn"
        case .softLight: return "soft-light"
        case .hardLight: return "hard-light"
        case .difference: return "difference"
        case .exclusion: return "exclusion"
        case .hue: return "hue"
        case .saturation: return "saturation"
        case .color: return "color"
        case .luminosity: return "luminosity"
        case .clear: return "destination-out"
        case .copy: return "copy"
        case .sourceIn: return "source-in"
        case .sourceOut: return "source-out"
        case .sourceAtop: return "source-atop"
        case .destinationOver: return "destination-over"
        case .destinationIn: return "destination-in"
        case .destinationOut: return "destination-out"
        case .destinationAtop: return "destination-atop"
        case .xor: return "xor"
        case .plusDarker: return "darken"
        case .plusLighter: return "lighter"
        }
    }
}
public enum CGLineCap: Int32 { case butt, round, square }
public enum CGLineJoin: Int32 { case miter, round, bevel }
public enum CGPathFillRule: Int { case winding, evenOdd }
public enum CGPathDrawingMode: Int32 { case fill, eoFill, stroke, fillStroke, eoFillStroke }
public enum CGInterpolationQuality: Int32 { case `default`, none, low, medium, high }
public enum CGTextDrawingMode: Int32 { case fill, stroke, fillStroke, invisible, fillClip, strokeClip, fillStrokeClip, clip }
public struct CGGradientDrawingOptions: OptionSet {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }
    public static let drawsBeforeStartLocation = CGGradientDrawingOptions(rawValue: 1)
    public static let drawsAfterEndLocation = CGGradientDrawingOptions(rawValue: 2)
}

public final class CGGradient {
    public let colors: [CGColor]
    public let locations: [CGFloat]
    public init?(colorsSpace: CGColorSpace?, colors: CFArray, locations: UnsafePointer<CGFloat>?) {
        let cs = colors.compactMap { $0 as? CGColor }
        self.colors = cs
        if let locations { self.locations = (0..<cs.count).map { locations[$0] } }
        else { self.locations = cs.count < 2 ? [0] : (0..<cs.count).map { CGFloat($0) / CGFloat(cs.count - 1) } }
    }
    public init?(colorSpace: CGColorSpace, colorComponents: UnsafePointer<CGFloat>, locations: UnsafePointer<CGFloat>?, count: Int) {
        let n = colorSpace.numberOfComponents + 1
        colors = (0..<count).map { i in
            n == 2 ? CGColor(gray: colorComponents[i * n], alpha: colorComponents[i * n + 1])
                   : CGColor(red: colorComponents[i * n], green: colorComponents[i * n + 1], blue: colorComponents[i * n + 2], alpha: colorComponents[i * n + 3])
        }
        if let locations { self.locations = (0..<count).map { locations[$0] } }
        else { self.locations = (0..<count).map { CGFloat($0) / CGFloat(max(1, count - 1)) } }
    }
}
