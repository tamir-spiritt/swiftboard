// Swiftboard UIKit for the browser (MIT): geometry, enums, colors, fonts, images, screen, device.
@_exported import Foundation
@_exported import CoreGraphics
@_exported import QuartzCore
@_exported import CoreText

// MARK: geometry

public struct UIEdgeInsets: Equatable, Hashable, CustomStringConvertible {
    public var top: CGFloat, left: CGFloat, bottom: CGFloat, right: CGFloat
    public init() { top = 0; left = 0; bottom = 0; right = 0 }
    public init(top: CGFloat, left: CGFloat, bottom: CGFloat, right: CGFloat) { self.top = top; self.left = left; self.bottom = bottom; self.right = right }
    public static let zero = UIEdgeInsets()
    public var description: String { "{\(top), \(left), \(bottom), \(right)}" }
}
public func UIEdgeInsetsMake(_ t: CGFloat, _ l: CGFloat, _ b: CGFloat, _ r: CGFloat) -> UIEdgeInsets { UIEdgeInsets(top: t, left: l, bottom: b, right: r) }
public func UIEdgeInsetsInsetRect(_ r: CGRect, _ i: UIEdgeInsets) -> CGRect { r.inset(by: i) }
public func UIEdgeInsetsEqualToEdgeInsets(_ a: UIEdgeInsets, _ b: UIEdgeInsets) -> Bool { a == b }
extension CGRect {
    public func inset(by i: UIEdgeInsets) -> CGRect {
        CGRect(x: minX + i.left, y: minY + i.top, width: width - i.left - i.right, height: height - i.top - i.bottom)
    }
}
public struct NSDirectionalEdgeInsets: Equatable, Hashable {
    public var top: CGFloat, leading: CGFloat, bottom: CGFloat, trailing: CGFloat
    public init() { top = 0; leading = 0; bottom = 0; trailing = 0 }
    public init(top: CGFloat, leading: CGFloat, bottom: CGFloat, trailing: CGFloat) { self.top = top; self.leading = leading; self.bottom = bottom; self.trailing = trailing }
    public static let zero = NSDirectionalEdgeInsets()
}
public struct UIOffset: Equatable, Hashable {
    public var horizontal: CGFloat, vertical: CGFloat
    public init() { horizontal = 0; vertical = 0 }
    public init(horizontal: CGFloat, vertical: CGFloat) { self.horizontal = horizontal; self.vertical = vertical }
    public static let zero = UIOffset()
}
public struct UIRectEdge: OptionSet, Hashable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let top = UIRectEdge(rawValue: 1)
    public static let left = UIRectEdge(rawValue: 2)
    public static let bottom = UIRectEdge(rawValue: 4)
    public static let right = UIRectEdge(rawValue: 8)
    public static let all: UIRectEdge = [.top, .left, .bottom, .right]
}
public struct UIRectCorner: OptionSet, Hashable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let topLeft = UIRectCorner(rawValue: 1)
    public static let topRight = UIRectCorner(rawValue: 2)
    public static let bottomLeft = UIRectCorner(rawValue: 4)
    public static let bottomRight = UIRectCorner(rawValue: 8)
    public static let allCorners: UIRectCorner = [.topLeft, .topRight, .bottomLeft, .bottomRight]
}
extension NSValue {
    public convenience init(uiEdgeInsets i: UIEdgeInsets) { self.init(webBoxing: i) }
    public var uiEdgeInsetsValue: UIEdgeInsets { webBoxed as? UIEdgeInsets ?? .zero }
    public convenience init(uiOffset o: UIOffset) { self.init(webBoxing: o) }
    public var uiOffsetValue: UIOffset { webBoxed as? UIOffset ?? .zero }
}
public func NSStringFromCGRect(_ r: CGRect) -> String { "{{\(r.minX), \(r.minY)}, {\(r.width), \(r.height)}}" }
public func NSStringFromCGPoint(_ p: CGPoint) -> String { "{\(p.x), \(p.y)}" }
public func NSStringFromCGSize(_ s: CGSize) -> String { "{\(s.width), \(s.height)}" }
public func NSStringFromUIEdgeInsets(_ i: UIEdgeInsets) -> String { i.description }

// MARK: orientation, style, idiom

public enum UIInterfaceOrientation: Int { case unknown = 0, portrait = 1, portraitUpsideDown = 2, landscapeLeft = 4, landscapeRight = 3
    public var isPortrait: Bool { self == .portrait || self == .portraitUpsideDown }
    public var isLandscape: Bool { self == .landscapeLeft || self == .landscapeRight }
}
public struct UIInterfaceOrientationMask: OptionSet, Hashable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let portrait = UIInterfaceOrientationMask(rawValue: 1 << 1)
    public static let landscapeLeft = UIInterfaceOrientationMask(rawValue: 1 << 4)
    public static let landscapeRight = UIInterfaceOrientationMask(rawValue: 1 << 3)
    public static let portraitUpsideDown = UIInterfaceOrientationMask(rawValue: 1 << 2)
    public static let landscape: UIInterfaceOrientationMask = [.landscapeLeft, .landscapeRight]
    public static let all: UIInterfaceOrientationMask = [.portrait, .landscapeLeft, .landscapeRight, .portraitUpsideDown]
    public static let allButUpsideDown: UIInterfaceOrientationMask = [.portrait, .landscapeLeft, .landscapeRight]
}
public enum UIDeviceOrientation: Int { case unknown, portrait, portraitUpsideDown, landscapeLeft, landscapeRight, faceUp, faceDown
    public var isPortrait: Bool { self == .portrait || self == .portraitUpsideDown }
    public var isLandscape: Bool { self == .landscapeLeft || self == .landscapeRight }
    public var isFlat: Bool { self == .faceUp || self == .faceDown }
    public var isValidInterfaceOrientation: Bool { isPortrait || isLandscape }
}
public enum UIStatusBarStyle: Int { case `default` = 0, lightContent = 1, darkContent = 3; public static let blackOpaque = UIStatusBarStyle.lightContent }
public enum UIDisplayGamut: Int { case unspecified = -1, SRGB = 0, P3 = 1 }
public enum UIStatusBarAnimation: Int { case none, fade, slide }
public enum UIUserInterfaceStyle: Int { case unspecified, light, dark }
public enum UIUserInterfaceIdiom: Int { case unspecified = -1, phone, pad, tv, carPlay, mac = 5, vision = 6 }
public enum UIUserInterfaceSizeClass: Int { case unspecified, compact, regular }
public enum UIUserInterfaceLayoutDirection: Int { case leftToRight, rightToLeft }
public enum UISemanticContentAttribute: Int { case unspecified, playback, spatial, forceLeftToRight, forceRightToLeft }
public enum UIKeyboardAppearance: Int { case `default`, dark, light; public static let alert = UIKeyboardAppearance.dark }
public enum UIKeyboardType: Int { case `default`, asciiCapable, numbersAndPunctuation, URL, numberPad, phonePad, namePhonePad, emailAddress, decimalPad, twitter, webSearch, asciiCapableNumberPad }
public enum UIReturnKeyType: Int { case `default`, go, google, join, next, route, search, send, yahoo, done, emergencyCall, `continue` }
public enum UITextAutocapitalizationType: Int { case none, words, sentences, allCharacters }
public enum UITextAutocorrectionType: Int { case `default`, no, yes }
public enum UITextSpellCheckingType: Int { case `default`, no, yes }
public enum UITextSmartQuotesType: Int { case `default`, no, yes }
public enum UITextSmartDashesType: Int { case `default`, no, yes }
public enum UITextSmartInsertDeleteType: Int { case `default`, no, yes }
public struct UITextContentType: RawRepresentable, Hashable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let oneTimeCode = UITextContentType(rawValue: "one-time-code")
    public static let password = UITextContentType(rawValue: "password")
    public static let newPassword = UITextContentType(rawValue: "new-password")
    public static let username = UITextContentType(rawValue: "username")
    public static let emailAddress = UITextContentType(rawValue: "email")
    public static let telephoneNumber = UITextContentType(rawValue: "tel")
    public static let name = UITextContentType(rawValue: "name")
    public static let givenName = UITextContentType(rawValue: "given-name")
    public static let familyName = UITextContentType(rawValue: "family-name")
    public static let URL = UITextContentType(rawValue: "url")
}
public struct UIContentSizeCategory: RawRepresentable, Hashable, Comparable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let unspecified = UIContentSizeCategory(rawValue: "_UICTContentSizeCategoryUnspecified")
    public static let extraSmall = UIContentSizeCategory(rawValue: "UICTContentSizeCategoryXS")
    public static let small = UIContentSizeCategory(rawValue: "UICTContentSizeCategoryS")
    public static let medium = UIContentSizeCategory(rawValue: "UICTContentSizeCategoryM")
    public static let large = UIContentSizeCategory(rawValue: "UICTContentSizeCategoryL")
    public static let extraLarge = UIContentSizeCategory(rawValue: "UICTContentSizeCategoryXL")
    public static let extraExtraLarge = UIContentSizeCategory(rawValue: "UICTContentSizeCategoryXXL")
    public static let extraExtraExtraLarge = UIContentSizeCategory(rawValue: "UICTContentSizeCategoryXXXL")
    public static let accessibilityMedium = UIContentSizeCategory(rawValue: "UICTContentSizeCategoryAccessibilityM")
    public static let accessibilityLarge = UIContentSizeCategory(rawValue: "UICTContentSizeCategoryAccessibilityL")
    public static let accessibilityExtraLarge = UIContentSizeCategory(rawValue: "UICTContentSizeCategoryAccessibilityXL")
    public static let accessibilityExtraExtraLarge = UIContentSizeCategory(rawValue: "UICTContentSizeCategoryAccessibilityXXL")
    public static let accessibilityExtraExtraExtraLarge = UIContentSizeCategory(rawValue: "UICTContentSizeCategoryAccessibilityXXXL")
    static let order: [String] = ["XS", "S", "M", "L", "XL", "XXL", "XXXL", "AccessibilityM", "AccessibilityL", "AccessibilityXL", "AccessibilityXXL", "AccessibilityXXXL"]
    var rank: Int { UIContentSizeCategory.order.firstIndex { rawValue.hasSuffix("Category" + $0) } ?? 3 }
    public var isAccessibilityCategory: Bool { rawValue.contains("Accessibility") }
    public static func < (a: UIContentSizeCategory, b: UIContentSizeCategory) -> Bool { a.rank < b.rank }
    public static let didChangeNotification = Notification.Name("UIContentSizeCategoryDidChangeNotification")
}

public final class UITraitCollection: NSObject {
    public let userInterfaceStyle: UIUserInterfaceStyle
    public let horizontalSizeClass: UIUserInterfaceSizeClass
    public let verticalSizeClass: UIUserInterfaceSizeClass
    public let displayScale: CGFloat
    public let userInterfaceIdiom: UIUserInterfaceIdiom
    public let preferredContentSizeCategory: UIContentSizeCategory
    public let layoutDirection: UIUserInterfaceLayoutDirection = .leftToRight
    public let displayGamut: UIDisplayGamut = .SRGB
    public let accessibilityContrast: Int = 0
    public init(userInterfaceStyle: UIUserInterfaceStyle = .light, horizontalSizeClass: UIUserInterfaceSizeClass = .compact, verticalSizeClass: UIUserInterfaceSizeClass = .regular,
                displayScale: CGFloat = UIScreen.main.scale, userInterfaceIdiom: UIUserInterfaceIdiom = .phone, preferredContentSizeCategory: UIContentSizeCategory = .large) {
        self.userInterfaceStyle = userInterfaceStyle; self.horizontalSizeClass = horizontalSizeClass; self.verticalSizeClass = verticalSizeClass
        self.displayScale = displayScale; self.userInterfaceIdiom = userInterfaceIdiom; self.preferredContentSizeCategory = preferredContentSizeCategory
    }
    public convenience init(userInterfaceStyle: UIUserInterfaceStyle) { self.init(userInterfaceStyle: userInterfaceStyle, horizontalSizeClass: .compact) }
    public convenience init(displayScale: CGFloat) { self.init(userInterfaceStyle: .light, displayScale: displayScale) }
    public convenience init(horizontalSizeClass: UIUserInterfaceSizeClass) { self.init(userInterfaceStyle: .light, horizontalSizeClass: horizontalSizeClass) }
    public convenience init(verticalSizeClass: UIUserInterfaceSizeClass) { self.init(userInterfaceStyle: .light, verticalSizeClass: verticalSizeClass) }
    public convenience init(preferredContentSizeCategory: UIContentSizeCategory) { self.init(userInterfaceStyle: .light, preferredContentSizeCategory: preferredContentSizeCategory) }
    public convenience init(userInterfaceIdiom: UIUserInterfaceIdiom) { self.init(userInterfaceStyle: .light, userInterfaceIdiom: userInterfaceIdiom) }
    public convenience init(traitsFrom: [UITraitCollection]) {
        let last = traitsFrom.last
        self.init(userInterfaceStyle: last?.userInterfaceStyle ?? .light, horizontalSizeClass: last?.horizontalSizeClass ?? .compact)
    }
    nonisolated(unsafe) public static var current = UITraitCollection(userInterfaceStyle: .light, horizontalSizeClass: .compact)
    public func hasDifferentColorAppearance(comparedTo t: UITraitCollection?) -> Bool { t?.userInterfaceStyle != userInterfaceStyle }
    public func containsTraits(in t: UITraitCollection?) -> Bool { true }
    public func performAsCurrent(_ f: () -> Void) { let old = UITraitCollection.current; UITraitCollection.current = self; f(); UITraitCollection.current = old }
}
public protocol UITraitEnvironment: AnyObject {
    var traitCollection: UITraitCollection { get }
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?)
}
public protocol UICoordinateSpace: AnyObject {
    var bounds: CGRect { get }
    func convert(_ point: CGPoint, to coordinateSpace: UICoordinateSpace) -> CGPoint
    func convert(_ point: CGPoint, from coordinateSpace: UICoordinateSpace) -> CGPoint
    func convert(_ rect: CGRect, to coordinateSpace: UICoordinateSpace) -> CGRect
    func convert(_ rect: CGRect, from coordinateSpace: UICoordinateSpace) -> CGRect
}

// MARK: color

open class UIColor: NSObject, WebCGColorConvertible {
    public let cgColor: CGColor
    let provider: ((UITraitCollection) -> UIColor)?
    public init(cgColor: CGColor) { self.cgColor = cgColor; provider = nil }
    public init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) { cgColor = CGColor(red: red, green: green, blue: blue, alpha: alpha); provider = nil }
    public init(displayP3Red red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) { cgColor = CGColor(red: red, green: green, blue: blue, alpha: alpha); provider = nil }
    public init(white: CGFloat, alpha: CGFloat) { cgColor = CGColor(gray: white, alpha: alpha); provider = nil }
    public init(hue h: CGFloat, saturation s: CGFloat, brightness v: CGFloat, alpha: CGFloat) {
        let i = floor(h * 6), f = h * 6 - i, p = v * (1 - s), q = v * (1 - f * s), t = v * (1 - (1 - f) * s)
        let (r, g, b): (CGFloat, CGFloat, CGFloat)
        switch Int(i) % 6 {
        case 0: (r, g, b) = (v, t, p)
        case 1: (r, g, b) = (q, v, p)
        case 2: (r, g, b) = (p, v, t)
        case 3: (r, g, b) = (p, q, v)
        case 4: (r, g, b) = (t, p, v)
        default: (r, g, b) = (v, p, q)
        }
        cgColor = CGColor(red: r, green: g, blue: b, alpha: alpha); provider = nil
    }
    public init(patternImage image: UIImage) {
        cgColor = image.cgImage.map { CGColor(patternImage: $0) } ?? .clear; provider = nil
    }
    public init(dynamicProvider: @escaping (UITraitCollection) -> UIColor) {
        provider = dynamicProvider
        cgColor = dynamicProvider(UITraitCollection.current).cgColor
    }
    public convenience init(ciColor: AnyObject) { self.init(white: 0, alpha: 1) }
    public func resolvedColor(with t: UITraitCollection) -> UIColor { provider?(t) ?? self }

    var webAlpha: CGFloat { cgColor.alpha }
    public func withAlphaComponent(_ a: CGFloat) -> UIColor { UIColor(cgColor: cgColor.copy(alpha: a)!) }
    @discardableResult
    public func getRed(_ r: UnsafeMutablePointer<CGFloat>?, green g: UnsafeMutablePointer<CGFloat>?, blue b: UnsafeMutablePointer<CGFloat>?, alpha a: UnsafeMutablePointer<CGFloat>?) -> Bool {
        r?.pointee = cgColor.r; g?.pointee = cgColor.g; b?.pointee = cgColor.b; a?.pointee = cgColor.alpha; return true
    }
    @discardableResult
    public func getWhite(_ w: UnsafeMutablePointer<CGFloat>?, alpha a: UnsafeMutablePointer<CGFloat>?) -> Bool {
        w?.pointee = (cgColor.r + cgColor.g + cgColor.b) / 3; a?.pointee = cgColor.alpha
        return cgColor.colorSpace?.model == .monochrome
    }
    @discardableResult
    public func getHue(_ h: UnsafeMutablePointer<CGFloat>?, saturation s: UnsafeMutablePointer<CGFloat>?, brightness v: UnsafeMutablePointer<CGFloat>?, alpha a: UnsafeMutablePointer<CGFloat>?) -> Bool {
        let r = cgColor.r, g = cgColor.g, b = cgColor.b
        let mx = max(r, g, b), mn = min(r, g, b), d = mx - mn
        var hue: CGFloat = 0
        if d != 0 {
            if mx == r { hue = ((g - b) / d).truncatingRemainder(dividingBy: 6) } else if mx == g { hue = (b - r) / d + 2 } else { hue = (r - g) / d + 4 }
            hue /= 6; if hue < 0 { hue += 1 }
        }
        h?.pointee = hue; s?.pointee = mx == 0 ? 0 : d / mx; v?.pointee = mx; a?.pointee = cgColor.alpha
        return true
    }
    open override func isEqual(_ object: Any?) -> Bool { (object as? UIColor)?.cgColor == cgColor }
    open override var hash: Int { cgColor.hashValue }
    open override var description: String { "UIColor(\(cgColor.css))" }
    public func set() { UIGraphicsGetCurrentContext()?.setFillColor(cgColor); UIGraphicsGetCurrentContext()?.setStrokeColor(cgColor) }
    public func setFill() { UIGraphicsGetCurrentContext()?.setFillColor(cgColor) }
    public func setStroke() { UIGraphicsGetCurrentContext()?.setStrokeColor(cgColor) }

    public static var black: UIColor { UIColor(white: 0, alpha: 1) }
    public static var white: UIColor { UIColor(white: 1, alpha: 1) }
    public static var clear: UIColor { UIColor(white: 0, alpha: 0) }
    public static var darkGray: UIColor { UIColor(white: 1.0 / 3.0, alpha: 1) }
    public static var lightGray: UIColor { UIColor(white: 2.0 / 3.0, alpha: 1) }
    public static var gray: UIColor { UIColor(white: 0.5, alpha: 1) }
    public static var red: UIColor { UIColor(red: 1, green: 0, blue: 0, alpha: 1) }
    public static var green: UIColor { UIColor(red: 0, green: 1, blue: 0, alpha: 1) }
    public static var blue: UIColor { UIColor(red: 0, green: 0, blue: 1, alpha: 1) }
    public static var cyan: UIColor { UIColor(red: 0, green: 1, blue: 1, alpha: 1) }
    public static var yellow: UIColor { UIColor(red: 1, green: 1, blue: 0, alpha: 1) }
    public static var magenta: UIColor { UIColor(red: 1, green: 0, blue: 1, alpha: 1) }
    public static var orange: UIColor { UIColor(red: 1, green: 0.5, blue: 0, alpha: 1) }
    public static var purple: UIColor { UIColor(red: 0.5, green: 0, blue: 0.5, alpha: 1) }
    public static var brown: UIColor { UIColor(red: 0.6, green: 0.4, blue: 0.2, alpha: 1) }
    public static var systemRed: UIColor { UIColor(red: 1, green: 59 / 255, blue: 48 / 255, alpha: 1) }
    public static var systemGreen: UIColor { UIColor(red: 52 / 255, green: 199 / 255, blue: 89 / 255, alpha: 1) }
    public static var systemBlue: UIColor { UIColor(red: 0, green: 122 / 255, blue: 1, alpha: 1) }
    public static var systemOrange: UIColor { UIColor(red: 1, green: 149 / 255, blue: 0, alpha: 1) }
    public static var systemYellow: UIColor { UIColor(red: 1, green: 204 / 255, blue: 0, alpha: 1) }
    public static var systemGray: UIColor { UIColor(red: 142 / 255, green: 142 / 255, blue: 147 / 255, alpha: 1) }
    public static var label: UIColor { .black }
    public static var secondaryLabel: UIColor { UIColor(red: 60 / 255, green: 60 / 255, blue: 67 / 255, alpha: 0.6) }
    public static var systemBackground: UIColor { .white }
    public static var secondarySystemBackground: UIColor { UIColor(red: 242 / 255, green: 242 / 255, blue: 247 / 255, alpha: 1) }
    public static var separator: UIColor { UIColor(red: 60 / 255, green: 60 / 255, blue: 67 / 255, alpha: 0.29) }
    public static var tintColor: UIColor { .systemBlue }
    public static var groupTableViewBackground: UIColor { secondarySystemBackground }
}

// MARK: fonts

open class UIFont: CTFont {
    public struct Weight: RawRepresentable, Hashable, Comparable {
        public let rawValue: CGFloat
        public init(rawValue: CGFloat) { self.rawValue = rawValue }
        public init(_ rawValue: CGFloat) { self.rawValue = rawValue }
        public static let ultraLight = Weight(rawValue: -0.8)
        public static let thin = Weight(rawValue: -0.6)
        public static let light = Weight(rawValue: -0.4)
        public static let regular = Weight(rawValue: 0)
        public static let medium = Weight(rawValue: 0.23)
        public static let semibold = Weight(rawValue: 0.3)
        public static let bold = Weight(rawValue: 0.4)
        public static let heavy = Weight(rawValue: 0.56)
        public static let black = Weight(rawValue: 0.62)
        public static func < (a: Weight, b: Weight) -> Bool { a.rawValue < b.rawValue }
        /// CSS numeric weight.
        public var css: CGFloat {
            let table: [(CGFloat, CGFloat)] = [(-0.8, 100), (-0.6, 200), (-0.4, 300), (0, 400), (0.23, 500), (0.3, 600), (0.4, 700), (0.56, 800), (0.62, 900)]
            return table.min { abs($0.0 - rawValue) < abs($1.0 - rawValue) }!.1
        }
    }
    public struct Width: RawRepresentable, Hashable {
        public let rawValue: CGFloat
        public init(rawValue: CGFloat) { self.rawValue = rawValue }
        public static let condensed = Width(rawValue: -0.2)
        public static let standard = Width(rawValue: 0)
        public static let expanded = Width(rawValue: 0.2)
        public static let compressed = Width(rawValue: -0.4)
    }
    public struct TextStyle: RawRepresentable, Hashable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public static let largeTitle = TextStyle(rawValue: "UICTFontTextStyleTitle0")
        public static let title1 = TextStyle(rawValue: "UICTFontTextStyleTitle1")
        public static let title2 = TextStyle(rawValue: "UICTFontTextStyleTitle2")
        public static let title3 = TextStyle(rawValue: "UICTFontTextStyleTitle3")
        public static let headline = TextStyle(rawValue: "UICTFontTextStyleHeadline")
        public static let subheadline = TextStyle(rawValue: "UICTFontTextStyleSubhead")
        public static let body = TextStyle(rawValue: "UICTFontTextStyleBody")
        public static let callout = TextStyle(rawValue: "UICTFontTextStyleCallout")
        public static let footnote = TextStyle(rawValue: "UICTFontTextStyleFootnote")
        public static let caption1 = TextStyle(rawValue: "UICTFontTextStyleCaption1")
        public static let caption2 = TextStyle(rawValue: "UICTFontTextStyleCaption2")
        var size: CGFloat {
            switch self {
            case .largeTitle: return 34
            case .title1: return 28
            case .title2: return 22
            case .title3: return 20
            case .headline, .body: return 17
            case .callout: return 16
            case .subheadline: return 15
            case .footnote: return 13
            case .caption1: return 12
            default: return 11
            }
        }
    }
    nonisolated(unsafe) static var registered = false
    static func register() { if !registered { registered = true; CTFont.webFontClass = UIFont.self } }

    public required init(webName name: String, family: String, size: CGFloat, weight: CGFloat, italic: Bool, monospaced: Bool) {
        super.init(webName: name, family: family, size: size, weight: weight, italic: italic, monospaced: monospaced)
    }
    public convenience init?(name: String, size: CGFloat) {
        UIFont.register()
        let f = CTFont.make(name: name, size: size == 0 ? 17 : size)
        self.init(webName: f.fontName, family: f.familyName, size: f.pointSize, weight: f.weightValue, italic: f.isItalic, monospaced: f.isMonospaced)
    }
    public convenience init(descriptor: UIFontDescriptor, size: CGFloat) {
        UIFont.register()
        let d = descriptor
        let size = size == 0 ? (d.pointSize == 0 ? 17 : d.pointSize) : size
        var weight: CGFloat = d.weightCSS ?? 400
        if d.symbolicTraits.contains(.traitBold) { weight = max(weight, 700) }
        let mono = d.symbolicTraits.contains(.traitMonoSpace) || d.design == .monospaced
        var family = mono ? kCTFontMonospacedFamily : kCTFontSystemFontFamily
        if d.design == .rounded { family = "ui-rounded, \"SF Pro Rounded\", " + kCTFontSystemFontFamily }
        if d.design == .serif { family = "ui-serif, \"New York\", Georgia, serif" }
        if let fam = d.familyName, !fam.hasPrefix(".") { family = "\"\(fam)\", " + family }
        self.init(webName: d.fontName ?? ".SFUI-Regular", family: family, size: size, weight: weight, italic: d.symbolicTraits.contains(.traitItalic), monospaced: mono)
        self.webFeatures = d.features
    }
    public class func systemFont(ofSize size: CGFloat) -> UIFont { systemFont(ofSize: size, weight: .regular) }
    public class func systemFont(ofSize size: CGFloat, weight: Weight) -> UIFont {
        register()
        return UIFont(webName: ".SFUI-\(weight.css)", family: kCTFontSystemFontFamily, size: size, weight: weight.css, italic: false, monospaced: false)
    }
    public class func systemFont(ofSize size: CGFloat, weight: Weight, width: Width) -> UIFont { systemFont(ofSize: size, weight: weight) }
    public class func boldSystemFont(ofSize size: CGFloat) -> UIFont { systemFont(ofSize: size, weight: .bold) }
    public class func italicSystemFont(ofSize size: CGFloat) -> UIFont {
        register()
        return UIFont(webName: ".SFUI-Italic", family: kCTFontSystemFontFamily, size: size, weight: 400, italic: true, monospaced: false)
    }
    public class func monospacedDigitSystemFont(ofSize size: CGFloat, weight: Weight) -> UIFont {
        let f = systemFont(ofSize: size, weight: weight); f.webFeatures = ["tnum"]; return f
    }
    public class func monospacedSystemFont(ofSize size: CGFloat, weight: Weight) -> UIFont {
        register()
        return UIFont(webName: ".SFMono-\(weight.css)", family: kCTFontMonospacedFamily, size: size, weight: weight.css, italic: false, monospaced: true)
    }
    public class func preferredFont(forTextStyle style: TextStyle) -> UIFont {
        systemFont(ofSize: style.size, weight: style == .headline ? .semibold : .regular)
    }
    public class func preferredFont(forTextStyle style: TextStyle, compatibleWith t: UITraitCollection?) -> UIFont { preferredFont(forTextStyle: style) }
    public class var systemFontSize: CGFloat { 17 }
    public class var labelFontSize: CGFloat { 17 }
    public class var buttonFontSize: CGFloat { 18 }
    public class var smallSystemFontSize: CGFloat { 12 }
    public class var familyNames: [String] { ["System"] }
    public class func fontNames(forFamilyName name: String) -> [String] { [] }

    open override func withSize(_ size: CGFloat) -> UIFont { super.withSize(size) as! UIFont }
    public var fontDescriptor: UIFontDescriptor {
        var traits: UIFontDescriptor.SymbolicTraits = []
        if weightValue >= 600 { traits.insert(.traitBold) }
        if isItalic { traits.insert(.traitItalic) }
        if isMonospaced { traits.insert(.traitMonoSpace) }
        let d = UIFontDescriptor(fontAttributes: [.name: fontName, .size: pointSize])
        d.symbolicTraits = traits
        d.weightCSS = weightValue
        d.familyCSS = familyName
        d.features = webFeatures
        return d
    }
    public override var ascender: CGFloat { super.ascender }
}

open class UIFontDescriptor: NSObject {
    public struct AttributeName: RawRepresentable, Hashable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public static let family = AttributeName(rawValue: "NSFontFamilyAttribute")
        public static let name = AttributeName(rawValue: "NSFontNameAttribute")
        public static let face = AttributeName(rawValue: "NSFontFaceAttribute")
        public static let size = AttributeName(rawValue: "NSFontSizeAttribute")
        public static let traits = AttributeName(rawValue: "NSCTFontTraitsAttribute")
        public static let featureSettings = AttributeName(rawValue: "NSCTFontFeatureSettingsAttribute")
        public static let textStyle = AttributeName(rawValue: "NSCTFontUIUsageAttribute")
        public static let cascadeList = AttributeName(rawValue: "NSCTFontCascadeListAttribute")
    }
    public struct TraitKey: RawRepresentable, Hashable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public static let symbolic = TraitKey(rawValue: "NSCTFontSymbolicTrait")
        public static let weight = TraitKey(rawValue: "NSCTFontWeightTrait")
        public static let width = TraitKey(rawValue: "NSCTFontProportionTrait")
        public static let slant = TraitKey(rawValue: "NSCTFontSlantTrait")
    }
    public struct FeatureKey: RawRepresentable, Hashable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public static let featureIdentifier = FeatureKey(rawValue: "CTFeatureTypeIdentifier")
        public static let typeIdentifier = FeatureKey(rawValue: "CTFeatureTypeIdentifier")
        public static let selectorIdentifier = FeatureKey(rawValue: "CTFeatureSelectorIdentifier")
        public static let type = FeatureKey(rawValue: "CTFeatureTypeIdentifier")
        public static let selector = FeatureKey(rawValue: "CTFeatureSelectorIdentifier")
    }
    public struct SymbolicTraits: OptionSet, Hashable {
        public let rawValue: UInt32
        public init(rawValue: UInt32) { self.rawValue = rawValue }
        public static let traitItalic = SymbolicTraits(rawValue: 1 << 0)
        public static let traitBold = SymbolicTraits(rawValue: 1 << 1)
        public static let traitExpanded = SymbolicTraits(rawValue: 1 << 5)
        public static let traitCondensed = SymbolicTraits(rawValue: 1 << 6)
        public static let traitMonoSpace = SymbolicTraits(rawValue: 1 << 10)
        public static let traitVertical = SymbolicTraits(rawValue: 1 << 11)
        public static let traitUIOptimized = SymbolicTraits(rawValue: 1 << 12)
        public static let traitTightLeading = SymbolicTraits(rawValue: 1 << 15)
        public static let traitLooseLeading = SymbolicTraits(rawValue: 1 << 16)
    }
    public struct SystemDesign: RawRepresentable, Hashable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public static let `default` = SystemDesign(rawValue: "NSCTFontUIFontDesignDefault")
        public static let rounded = SystemDesign(rawValue: "NSCTFontUIFontDesignRounded")
        public static let monospaced = SystemDesign(rawValue: "NSCTFontUIFontDesignMonospaced")
        public static let serif = SystemDesign(rawValue: "NSCTFontUIFontDesignSerif")
    }
    public internal(set) var fontAttributes: [AttributeName: Any]
    public internal(set) var symbolicTraits: SymbolicTraits = []
    var weightCSS: CGFloat?
    var familyCSS: String?
    var design: SystemDesign?
    var features: [String] = []
    public init(fontAttributes: [AttributeName: Any]) {
        self.fontAttributes = fontAttributes
        super.init()
        absorb(fontAttributes)
    }
    public convenience init(name: String, size: CGFloat) { self.init(fontAttributes: [.name: name, .size: size]) }
    public override convenience init() { self.init(fontAttributes: [:]) }
    func absorb(_ a: [AttributeName: Any]) {
        if let t = a[.traits] as? [TraitKey: Any] {
            if let w = (t[.weight] as? CGFloat) ?? (t[.weight] as? NSNumber).map({ CGFloat($0.doubleValue) }) { weightCSS = UIFont.Weight(rawValue: w).css }
            if let s = (t[.symbolic] as? NSNumber)?.uint32Value { symbolicTraits.formUnion(SymbolicTraits(rawValue: s)) }
        }
        if let feats = a[.featureSettings] as? [Any] { features += feats.map { "\($0)" } }
    }
    func copyState(to d: UIFontDescriptor) {
        d.symbolicTraits = symbolicTraits; d.weightCSS = weightCSS; d.familyCSS = familyCSS; d.design = design; d.features = features
    }
    public var pointSize: CGFloat { (fontAttributes[.size] as? CGFloat) ?? CGFloat((fontAttributes[.size] as? NSNumber)?.doubleValue ?? 0) }
    public var fontName: String? { fontAttributes[.name] as? String }
    public var familyName: String? { fontAttributes[.family] as? String }
    public func withSymbolicTraits(_ t: SymbolicTraits) -> UIFontDescriptor? {
        let d = UIFontDescriptor(fontAttributes: fontAttributes); copyState(to: d); d.symbolicTraits = t; return d
    }
    public func withDesign(_ design: SystemDesign) -> UIFontDescriptor? {
        let d = UIFontDescriptor(fontAttributes: fontAttributes); copyState(to: d); d.design = design; return d
    }
    public func addingAttributes(_ a: [AttributeName: Any]) -> UIFontDescriptor {
        var all = fontAttributes; for (k, v) in a { all[k] = v }
        let d = UIFontDescriptor(fontAttributes: all); copyState(to: d); d.absorb(a); return d
    }
    public func withSize(_ s: CGFloat) -> UIFontDescriptor { addingAttributes([.size: s]) }
    public func object(forKey k: AttributeName) -> Any? { fontAttributes[k] }
    public class func preferredFontDescriptor(withTextStyle style: UIFont.TextStyle) -> UIFontDescriptor {
        UIFontDescriptor(fontAttributes: [.size: style.size, .textStyle: style.rawValue])
    }
}

// MARK: images

open class UIImage: NSObject {
    public enum Orientation: Int { case up, down, left, right, upMirrored, downMirrored, leftMirrored, rightMirrored }
    public enum ResizingMode: Int { case tile, stretch }
    public enum RenderingMode: Int { case automatic, alwaysOriginal, alwaysTemplate }
    public struct SymbolWeight: RawRepresentable, Hashable { public let rawValue: Int; public init(rawValue: Int) { self.rawValue = rawValue }
        public static let regular = SymbolWeight(rawValue: 4); public static let medium = SymbolWeight(rawValue: 5); public static let semibold = SymbolWeight(rawValue: 6); public static let bold = SymbolWeight(rawValue: 7) }

    public let cgImage: CGImage?
    public let scale: CGFloat
    public let imageOrientation: Orientation
    public internal(set) var capInsets: UIEdgeInsets = .zero
    public internal(set) var resizingMode: ResizingMode = .tile
    public internal(set) var renderingMode: RenderingMode = .automatic
    public internal(set) var images: [UIImage]?
    public internal(set) var duration: TimeInterval = 0
    public internal(set) var tintColor: UIColor?
    public var flipsForRightToLeftLayoutDirection: Bool { false }
    public var isSymbolImage: Bool { false }
    public var accessibilityIdentifier: String?
    public var size: CGSize {
        guard let cg = cgImage else { return .zero }
        let s = CGSize(width: CGFloat(cg.width) / scale, height: CGFloat(cg.height) / scale)
        switch imageOrientation { case .left, .right, .leftMirrored, .rightMirrored: return CGSize(width: s.height, height: s.width); default: return s }
    }

    public init(cgImage: CGImage, scale: CGFloat, orientation: Orientation) { self.cgImage = cgImage; self.scale = scale; imageOrientation = orientation }
    public convenience init(cgImage: CGImage) { self.init(cgImage: cgImage, scale: 1, orientation: .up) }
    public override init() { cgImage = nil; scale = 1; imageOrientation = .up }
    init(copying i: UIImage) {
        cgImage = i.cgImage; scale = i.scale; imageOrientation = i.imageOrientation
        super.init()
        capInsets = i.capInsets; resizingMode = i.resizingMode; renderingMode = i.renderingMode; images = i.images; duration = i.duration; tintColor = i.tintColor
    }
    /// Bundle images: the host serves them by name (see WebAssets).
    public convenience init?(named name: String) {
        guard let (cg, scale) = WebAssets.image(named: name) else { return nil }
        self.init(cgImage: cg, scale: scale, orientation: .up)
    }
    public convenience init?(named name: String, in bundle: Bundle?, compatibleWith t: UITraitCollection?) { self.init(named: name) }
    public convenience init?(named name: String, in bundle: Bundle?, with configuration: AnyObject?) { self.init(named: name) }
    public convenience init?(systemName name: String) { self.init(named: "sf:" + name) }
    public convenience init?(systemName name: String, withConfiguration c: AnyObject?) { self.init(named: "sf:" + name) }
    public convenience init?(data: Data) { self.init(data: data, scale: 1) }
    public convenience init?(data: Data, scale: CGFloat) {
        guard let (cg, _) = WebAssets.image(data: data) else { return nil }
        self.init(cgImage: cg, scale: scale, orientation: .up)
    }
    public convenience init?(contentsOfFile path: String) {
        guard let d = FileManager.default.contents(atPath: path) else { return nil }
        self.init(data: d)
    }
    public class func animatedImage(with images: [UIImage], duration: TimeInterval) -> UIImage? {
        guard let f = images.first else { return nil }
        let i = UIImage(copying: f); i.images = images; i.duration = duration; return i
    }
    public func resizableImage(withCapInsets insets: UIEdgeInsets) -> UIImage { resizableImage(withCapInsets: insets, resizingMode: .tile) }
    public func resizableImage(withCapInsets insets: UIEdgeInsets, resizingMode: ResizingMode) -> UIImage {
        let i = UIImage(copying: self); i.capInsets = insets; i.resizingMode = resizingMode; return i
    }
    public func stretchableImage(withLeftCapWidth l: Int, topCapHeight t: Int) -> UIImage {
        let s = size
        return resizableImage(withCapInsets: UIEdgeInsets(top: CGFloat(t), left: CGFloat(l), bottom: s.height - CGFloat(t) - 1, right: s.width - CGFloat(l) - 1), resizingMode: .stretch)
    }
    public var leftCapWidth: Int { Int(capInsets.left) }
    public var topCapHeight: Int { Int(capInsets.top) }
    public func withRenderingMode(_ m: RenderingMode) -> UIImage { let i = UIImage(copying: self); i.renderingMode = m; return i }
    public func withTintColor(_ c: UIColor) -> UIImage { let i = UIImage(copying: self); i.tintColor = c; i.renderingMode = .alwaysOriginal; return i }
    public func withTintColor(_ c: UIColor, renderingMode: RenderingMode) -> UIImage { let i = withTintColor(c); i.renderingMode = renderingMode; return i }
    public func withHorizontallyFlippedOrientation() -> UIImage { self }
    public func imageFlippedForRightToLeftLayoutDirection() -> UIImage { self }
    public func withAlignmentRectInsets(_ i: UIEdgeInsets) -> UIImage { self }
    public func withConfiguration(_ c: AnyObject?) -> UIImage { self }
    public func preparingForDisplay() -> UIImage? { self }
    public func preparingThumbnail(of size: CGSize) -> UIImage? { self }
    public func pngData() -> Data? { nil }
    public func jpegData(compressionQuality: CGFloat) -> Data? { nil }

    public func draw(in rect: CGRect) { draw(in: rect, blendMode: .normal, alpha: 1) }
    public func draw(at p: CGPoint) { draw(in: CGRect(origin: p, size: size)) }
    public func draw(at p: CGPoint, blendMode: CGBlendMode, alpha: CGFloat) { draw(in: CGRect(origin: p, size: size), blendMode: blendMode, alpha: alpha) }
    public func draw(in rect: CGRect, blendMode: CGBlendMode, alpha: CGFloat) {
        guard let ctx = UIGraphicsGetCurrentContext(), let cg = cgImage else { return }
        ctx.saveGState()
        ctx.setBlendMode(blendMode); ctx.setAlpha(alpha)
        // CGContext draws images y-up: flip around the rect so the image appears upright in UIKit space
        ctx.translateBy(x: rect.minX, y: rect.maxY); ctx.scaleBy(x: 1, y: -1)
        ctx.draw(cg, in: CGRect(origin: .zero, size: rect.size))
        ctx.restoreGState()
    }
    public func drawAsPattern(in rect: CGRect) { draw(in: rect) }
    open override func isEqual(_ object: Any?) -> Bool {
        guard let o = object as? UIImage else { return false }
        return o === self || (o.cgImage === cgImage && o.scale == scale && o.capInsets == capInsets && o.renderingMode == renderingMode)
    }
}

@_extern(wasm, module: "swiftboard", name: "asset_info")
func _hostAssetInfo(_ name: UnsafePointer<UInt8>, _ nameLen: Int32, _ out: UnsafeMutablePointer<Double>) -> Int32

/// Image assets the host provides (bundle PNGs, SF Symbols) and decoding of image data, both done by the browser.
public enum WebAssets {
    /// Resolver: name -> (pixel width, pixel height, scale) when the asset exists. Defaults to the host's
    /// `swiftboard.asset_info` import (web/uikit-host.js, from the app's asset manifest).
    nonisolated(unsafe) public static var lookup: ((String) -> (Int, Int, CGFloat)?)? = { name in
        var out: (Double, Double, Double) = (0, 0, 0)
        var n = name
        let found = n.withUTF8 { b in withUnsafeMutablePointer(to: &out) { o in
            o.withMemoryRebound(to: Double.self, capacity: 3) { _hostAssetInfo(b.baseAddress ?? UnsafePointer(bitPattern: 1)!, Int32(b.count), $0) }
        } }
        return found != 0 ? (Int(out.0), Int(out.1), CGFloat(out.2)) : nil
    }
    nonisolated(unsafe) public static var decode: ((Data) -> (Int, Int)?)?
    static func image(named name: String) -> (CGImage, CGFloat)? {
        guard let (w, h, s) = lookup?(name) else { return nil }
        return (CGImage(externalSource: "asset:" + name, width: w, height: h), s)
    }
    static func image(data: Data) -> (CGImage, CGFloat)? {
        guard let (w, h) = decode?(data) else { return nil }
        return (CGImage(externalSource: "data:\(data.count)", width: w, height: h), 1)
    }
}

// MARK: screen & device

open class UIScreen: NSObject, UITraitEnvironment {
    nonisolated(unsafe) public static let main = UIScreen()
    nonisolated(unsafe) public static var webSize = CGSize(width: 390, height: 844)
    nonisolated(unsafe) public static var webScale: CGFloat = 3
    public var bounds: CGRect { CGRect(origin: .zero, size: UIScreen.webSize) }
    public var nativeBounds: CGRect { CGRect(x: 0, y: 0, width: UIScreen.webSize.width * scale, height: UIScreen.webSize.height * scale) }
    public var scale: CGFloat { UIScreen.webScale }
    public var nativeScale: CGFloat { UIScreen.webScale }
    public var brightness: CGFloat = 1
    public var maximumFramesPerSecond: Int { 60 }
    public var coordinateSpace: UICoordinateSpace { UIScreenCoordinateSpace(self) }
    public var fixedCoordinateSpace: UICoordinateSpace { UIScreenCoordinateSpace(self) }
    public var traitCollection: UITraitCollection { UITraitCollection.current }
    public func traitCollectionDidChange(_ p: UITraitCollection?) {}
    public var isCaptured: Bool { false }
    public var mirrored: UIScreen? { nil }
    public static var screens: [UIScreen] { [main] }
    public static let capturedDidChangeNotification = Notification.Name("UIScreenCapturedDidChangeNotification")
    public static let brightnessDidChangeNotification = Notification.Name("UIScreenBrightnessDidChangeNotification")
}
final class UIScreenCoordinateSpace: UICoordinateSpace {
    let screen: UIScreen
    init(_ s: UIScreen) { screen = s }
    var bounds: CGRect { screen.bounds }
    func convert(_ p: CGPoint, to c: UICoordinateSpace) -> CGPoint { (c as? UIView)?.convert(p, from: nil) ?? p }
    func convert(_ p: CGPoint, from c: UICoordinateSpace) -> CGPoint { (c as? UIView)?.convert(p, to: nil) ?? p }
    func convert(_ r: CGRect, to c: UICoordinateSpace) -> CGRect { (c as? UIView)?.convert(r, from: nil) ?? r }
    func convert(_ r: CGRect, from c: UICoordinateSpace) -> CGRect { (c as? UIView)?.convert(r, to: nil) ?? r }
}

open class UIDevice: NSObject {
    public enum BatteryState: Int { case unknown, unplugged, charging, full }
    nonisolated(unsafe) public static let current = UIDevice()
    public var userInterfaceIdiom: UIUserInterfaceIdiom { .phone }
    public var systemVersion: String { "18.0" }
    public var systemName: String { "iOS" }
    public var model: String { "iPhone" }
    public var localizedModel: String { "iPhone" }
    public var name: String { "iPhone" }
    public var orientation: UIDeviceOrientation { .portrait }
    public var isBatteryMonitoringEnabled = false
    public var batteryLevel: Float { 1 }
    public var batteryState: BatteryState { .full }
    public var isProximityMonitoringEnabled = false
    public var proximityState: Bool { false }
    public var isMultitaskingSupported: Bool { false }
    public var identifierForVendor: UUID? { UUID(uuidString: "00000000-0000-0000-0000-000000000000") }
    public var isGeneratingDeviceOrientationNotifications: Bool { false }
    public func beginGeneratingDeviceOrientationNotifications() {}
    public func endGeneratingDeviceOrientationNotifications() {}
    public func playInputClick() {}
    public static let orientationDidChangeNotification = Notification.Name("UIDeviceOrientationDidChangeNotification")
    public static let batteryLevelDidChangeNotification = Notification.Name("UIDeviceBatteryLevelDidChangeNotification")
    public static let batteryStateDidChangeNotification = Notification.Name("UIDeviceBatteryStateDidChangeNotification")
    public static let proximityStateDidChangeNotification = Notification.Name("UIDeviceProximityStateDidChangeNotification")
}
