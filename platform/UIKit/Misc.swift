// Swiftboard UIKit (MIT): key commands, feedback, pointer interactions, accessibility, menus, pasteboard.
import Foundation

public struct UIKeyModifierFlags: OptionSet, Hashable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let alphaShift = UIKeyModifierFlags(rawValue: 1 << 16)
    public static let shift = UIKeyModifierFlags(rawValue: 1 << 17)
    public static let control = UIKeyModifierFlags(rawValue: 1 << 18)
    public static let alternate = UIKeyModifierFlags(rawValue: 1 << 19)
    public static let command = UIKeyModifierFlags(rawValue: 1 << 20)
    public static let numericPad = UIKeyModifierFlags(rawValue: 1 << 21)
}
open class UICommand: UIMenuElement {
    public var action: Selector
    public var discoverabilityTitle: String?
    public var attributes: UIMenuElement.Attributes = []
    public var state: UIMenuElement.State = .off
    init(title: String, image: UIImage?, action: Selector) { self.action = action; super.init(title: title, image: image) }
}
extension UIMenuElement {
    public struct Attributes: OptionSet { public let rawValue: UInt; public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let disabled = Attributes(rawValue: 1); public static let destructive = Attributes(rawValue: 2); public static let hidden = Attributes(rawValue: 4) }
    public enum State: Int { case off, on, mixed }
}
open class UIKeyCommand: UICommand {
    public let input: String?
    public let modifierFlags: UIKeyModifierFlags
    public var wantsPriorityOverSystemBehavior = false
    public var allowsAutomaticLocalization = true
    public var allowsAutomaticMirroring = true
    public init(input: String, modifierFlags: UIKeyModifierFlags, action: Selector) {
        self.input = input; self.modifierFlags = modifierFlags; super.init(title: "", image: nil, action: action)
    }
    public init(input: String, modifierFlags: UIKeyModifierFlags, action: Selector, discoverabilityTitle: String) {
        self.input = input; self.modifierFlags = modifierFlags; super.init(title: discoverabilityTitle, image: nil, action: action); self.discoverabilityTitle = discoverabilityTitle
    }
    public init(title: String = "", image: UIImage? = nil, action: Selector, input: String, modifierFlags: UIKeyModifierFlags = [], propertyList: Any? = nil,
                alternates: [AnyObject] = [], discoverabilityTitle: String? = nil, attributes: UIMenuElement.Attributes = [], state: UIMenuElement.State = .off) {
        self.input = input; self.modifierFlags = modifierFlags; super.init(title: title, image: image, action: action)
        self.discoverabilityTitle = discoverabilityTitle; self.attributes = attributes; self.state = state
    }
    public static let inputEscape = "UIKeyInputEscape"
    public static let inputUpArrow = "UIKeyInputUpArrow"
    public static let inputDownArrow = "UIKeyInputDownArrow"
    public static let inputLeftArrow = "UIKeyInputLeftArrow"
    public static let inputRightArrow = "UIKeyInputRightArrow"
    public static let inputPageUp = "UIKeyInputPageUp"
    public static let inputPageDown = "UIKeyInputPageDown"
    public static let inputHome = "UIKeyInputHome"
    public static let inputEnd = "UIKeyInputEnd"
    public static let inputDelete = "UIKeyInputDelete"
    public static let f1 = "UIKeyInputF1"
}

// MARK: feedback

open class UIFeedbackGenerator: NSObject {
    public override init() {}
    open func prepare() {}
}
open class UIImpactFeedbackGenerator: UIFeedbackGenerator {
    public enum FeedbackStyle: Int { case light, medium, heavy, soft, rigid }
    public init(style: FeedbackStyle) { super.init() }
    public override convenience init() { self.init(style: .medium) }
    open func impactOccurred() {}
    open func impactOccurred(intensity: CGFloat) {}
    open func impactOccurred(at location: CGPoint) {}
}
open class UISelectionFeedbackGenerator: UIFeedbackGenerator {
    open func selectionChanged() {}
}
open class UINotificationFeedbackGenerator: UIFeedbackGenerator {
    public enum FeedbackType: Int { case success, warning, error }
    open func notificationOccurred(_ t: FeedbackType) {}
}

// MARK: pointer & previews

open class UIPreviewParameters: NSObject {
    open var visiblePath: UIBezierPath?
    open var backgroundColor: UIColor!
    open var shadowPath: UIBezierPath?
    public override init() {}
    public init(textLineRects: [NSValue]) {}
}
open class UIPreviewTarget: NSObject {
    public let container: UIView
    public let center: CGPoint
    public init(container: UIView, center: CGPoint) { self.container = container; self.center = center }
    public init(container: UIView, center: CGPoint, transform: CGAffineTransform) { self.container = container; self.center = center }
}
open class UITargetedPreview: NSObject {
    public let view: UIView
    public let parameters: UIPreviewParameters
    public let target: UIPreviewTarget
    public var size: CGSize { view.bounds.size }
    public init(view: UIView, parameters: UIPreviewParameters, target: UIPreviewTarget) { self.view = view; self.parameters = parameters; self.target = target }
    public init(view: UIView, parameters: UIPreviewParameters) { self.view = view; self.parameters = parameters; target = UIPreviewTarget(container: view.superview ?? view, center: view.center) }
    public convenience init(view: UIView) { self.init(view: view, parameters: UIPreviewParameters()) }
}
open class UIPointerEffect: NSObject {
    public let preview: UITargetedPreview
    init(_ p: UITargetedPreview) { preview = p }
    public static func automatic(_ p: UITargetedPreview) -> UIPointerEffect { UIPointerEffect(p) }
    public static func highlight(_ p: UITargetedPreview) -> UIPointerEffect { UIPointerEffect(p) }
    public static func lift(_ p: UITargetedPreview) -> UIPointerEffect { UIPointerEffect(p) }
    public static func hover(_ p: UITargetedPreview, preferredTintMode: TintMode = .overlay, prefersShadow: Bool = false, prefersScaledContent: Bool = true) -> UIPointerEffect { UIPointerEffect(p) }
    public enum TintMode: Int { case none, overlay, underlay }
}
public enum UIPointerShape {
    case path(UIBezierPath)
    case roundedRect(CGRect, radius: CGFloat = 8)
    case verticalBeam(length: CGFloat)
    case horizontalBeam(length: CGFloat)
    public static let defaultCornerRadius: CGFloat = 8
}
open class UIPointerStyle: NSObject {
    public init(effect: UIPointerEffect, shape: UIPointerShape? = nil) {}
    public init(shape: UIPointerShape, constrainedAxes: UIAxis = []) {}
    public static func hidden() -> UIPointerStyle { UIPointerStyle(shape: .verticalBeam(length: 0)) }
    public static func system() -> UIPointerStyle { UIPointerStyle(shape: .verticalBeam(length: 0)) }
}
public struct UIAxis: OptionSet { public let rawValue: UInt; public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let horizontal = UIAxis(rawValue: 1); public static let vertical = UIAxis(rawValue: 2); public static let both: UIAxis = [.horizontal, .vertical] }
open class UIPointerRegion: NSObject {
    public let rect: CGRect
    public let identifier: AnyHashable?
    public init(rect: CGRect, identifier: AnyHashable? = nil) { self.rect = rect; self.identifier = identifier }
}
open class UIPointerRegionRequest: NSObject {
    public let location: CGPoint
    public let modifiers: UIKeyModifierFlags
    init(location: CGPoint) { self.location = location; modifiers = [] }
}
public protocol UIPointerInteractionAnimating: AnyObject {
    func addAnimations(_ animations: @escaping () -> Void)
    func addCompletion(_ completion: @escaping (Bool) -> Void)
}
public protocol UIPointerInteractionDelegate: AnyObject {
    func pointerInteraction(_ interaction: UIPointerInteraction, regionFor request: UIPointerRegionRequest, defaultRegion: UIPointerRegion) -> UIPointerRegion?
    func pointerInteraction(_ interaction: UIPointerInteraction, styleFor region: UIPointerRegion) -> UIPointerStyle?
    func pointerInteraction(_ interaction: UIPointerInteraction, willEnter region: UIPointerRegion, animator: UIPointerInteractionAnimating)
    func pointerInteraction(_ interaction: UIPointerInteraction, willExit region: UIPointerRegion, animator: UIPointerInteractionAnimating)
}
extension UIPointerInteractionDelegate {
    public func pointerInteraction(_ interaction: UIPointerInteraction, regionFor request: UIPointerRegionRequest, defaultRegion: UIPointerRegion) -> UIPointerRegion? { defaultRegion }
    public func pointerInteraction(_ interaction: UIPointerInteraction, styleFor region: UIPointerRegion) -> UIPointerStyle? { nil }
    public func pointerInteraction(_ interaction: UIPointerInteraction, willEnter region: UIPointerRegion, animator: UIPointerInteractionAnimating) {}
    public func pointerInteraction(_ interaction: UIPointerInteraction, willExit region: UIPointerRegion, animator: UIPointerInteractionAnimating) {}
}
open class UIPointerInteraction: NSObject, UIInteraction {
    public private(set) weak var delegate: UIPointerInteractionDelegate?
    public private(set) weak var view: UIView?
    open var isEnabled = true
    public init(delegate: UIPointerInteractionDelegate?) { self.delegate = delegate }
    public func willMove(to view: UIView?) {}
    public func didMove(to view: UIView?) { self.view = view }
    open func invalidate() {}
}
open class UIEditMenuConfiguration: NSObject {
    public let identifier: NSCopying?
    public let sourcePoint: CGPoint
    public init(identifier: NSCopying?, sourcePoint: CGPoint) { self.identifier = identifier; self.sourcePoint = sourcePoint }
}
public protocol UIEditMenuInteractionDelegate: AnyObject {}
open class UIEditMenuInteraction: NSObject, UIInteraction {
    public private(set) weak var delegate: UIEditMenuInteractionDelegate?
    public private(set) weak var view: UIView?
    public init(delegate: UIEditMenuInteractionDelegate?) { self.delegate = delegate }
    public func willMove(to view: UIView?) {}
    public func didMove(to view: UIView?) { self.view = view }
    open func presentEditMenu(with c: UIEditMenuConfiguration) {}
    open func dismissMenu() {}
    open func reloadVisibleMenu() {}
    open func updateVisibleMenuPosition(animated: Bool) {}
}
open class UIContextMenuInteraction: NSObject, UIInteraction {
    public private(set) weak var view: UIView?
    public init(delegate: AnyObject) {}
    public func willMove(to view: UIView?) {}
    public func didMove(to view: UIView?) { self.view = view }
}

// MARK: accessibility

public enum UIAccessibility {
    public struct Notification: RawRepresentable, Hashable { public let rawValue: UInt32; public init(rawValue: UInt32) { self.rawValue = rawValue }
        public static let screenChanged = Notification(rawValue: 1000); public static let layoutChanged = Notification(rawValue: 1001)
        public static let announcement = Notification(rawValue: 1008); public static let pageScrolled = Notification(rawValue: 1009) }
    public static var isVoiceOverRunning: Bool { false }
    public static var isSwitchControlRunning: Bool { false }
    public static var isReduceMotionEnabled: Bool { false }
    public static var isReduceTransparencyEnabled: Bool { false }
    public static var isBoldTextEnabled: Bool { false }
    public static var isSpeakSelectionEnabled: Bool { false }
    public static var isSpeakScreenEnabled: Bool { false }
    public static var isDarkerSystemColorsEnabled: Bool { false }
    public static var isInvertColorsEnabled: Bool { false }
    public static var isGrayscaleEnabled: Bool { false }
    public static var isMonoAudioEnabled: Bool { false }
    public static var isClosedCaptioningEnabled: Bool { false }
    public static var isGuidedAccessEnabled: Bool { false }
    public static var isOnOffSwitchLabelsEnabled: Bool { false }
    public static var buttonShapesEnabled: Bool { false }
    public static var prefersCrossFadeTransitions: Bool { false }
    public static var isVideoAutoplayEnabled: Bool { true }
    public static var shouldDifferentiateWithoutColor: Bool { false }
    public static func post(notification: Notification, argument: Any?) {}
    public static func convertToScreenCoordinates(_ r: CGRect, in view: UIView) -> CGRect { view.convert(r, to: nil) }
    public static func convertToScreenCoordinates(_ p: UIBezierPath, in view: UIView) -> UIBezierPath { p }
    public static func focusedElement(using id: String?) -> Any? { nil }
    public static let voiceOverStatusDidChangeNotification = Foundation.Notification.Name("UIAccessibilityVoiceOverStatusDidChangeNotification")
    public static let reduceMotionStatusDidChangeNotification = Foundation.Notification.Name("UIAccessibilityReduceMotionStatusDidChangeNotification")
    public static let reduceTransparencyStatusDidChangeNotification = Foundation.Notification.Name("UIAccessibilityReduceTransparencyStatusDidChangeNotification")
    public static let boldTextStatusDidChangeNotification = Foundation.Notification.Name("UIAccessibilityBoldTextStatusDidChangeNotification")
    public static let speakSelectionStatusDidChangeNotification = Foundation.Notification.Name("UIAccessibilitySpeakSelectionStatusDidChangeNotification")
    public static let elementFocusedNotification = Foundation.Notification.Name("UIAccessibilityElementFocusedNotification")
    public static let invertColorsStatusDidChangeNotification = Foundation.Notification.Name("UIAccessibilityInvertColorsStatusDidChangeNotification")
    public static let darkerSystemColorsStatusDidChangeNotification = Foundation.Notification.Name("UIAccessibilityDarkerSystemColorsStatusDidChangeNotification")
    public static let switchControlStatusDidChangeNotification = Foundation.Notification.Name("UIAccessibilitySwitchControlStatusDidChangeNotification")
    public static let focusedElementUserInfoKey = "UIAccessibilityFocusedElementKey"
}
public func UIAccessibilityConvertFrameToScreenCoordinates(_ r: CGRect, _ view: UIView) -> CGRect { view.convert(r, to: nil) }
public func UIAccessibilityIsVoiceOverRunning() -> Bool { false }
public func UIAccessibilityIsReduceMotionEnabled() -> Bool { false }
public func UIAccessibilityPostNotification(_ n: UIAccessibility.Notification, _ arg: Any?) {}

open class UIAccessibilityElement: UIResponder {
    open weak var accessibilityContainerObject: AnyObject?
    open var accessibilityFrameInContainerSpace: CGRect = .zero
    public init(accessibilityContainer container: Any) { accessibilityContainerObject = container as AnyObject; super.init() }
}

// MARK: menus, pasteboard, misc

open class UIMenuItem: NSObject {
    public var title: String
    public var action: Selector
    public init(title: String, action: Selector) { self.title = title; self.action = action }
}
open class UIMenuController: NSObject {
    nonisolated(unsafe) public static let shared = UIMenuController()
    public var menuItems: [UIMenuItem]?
    public var isMenuVisible: Bool { false }
    public func showMenu(from view: UIView, rect: CGRect) {}
    public func hideMenu() {}
    public func hideMenu(from view: UIView) {}
    public func update() {}
    public static let willShowMenuNotification = Notification.Name("UIMenuControllerWillShowMenuNotification")
    public static let willHideMenuNotification = Notification.Name("UIMenuControllerWillHideMenuNotification")
    public static let didHideMenuNotification = Notification.Name("UIMenuControllerDidHideMenuNotification")
}
open class UIPasteboard: NSObject {
    nonisolated(unsafe) public static let general = UIPasteboard()
    public var string: String?
    public var strings: [String]?
    public var url: URL?
    public var image: UIImage?
    public var items: [[String: Any]] = []
    public var hasStrings: Bool { string != nil }
    public var hasURLs: Bool { url != nil }
    public var hasImages: Bool { image != nil }
    public var numberOfItems: Int { items.count }
    public func setData(_ d: Data, forPasteboardType t: String) {}
    public func data(forPasteboardType t: String) -> Data? { nil }
    public func setItems(_ items: [[String: Any]], options: [String: Any] = [:]) { self.items = items }
    public func addItems(_ items: [[String: Any]]) { self.items += items }
    public static let changedNotification = Notification.Name("UIPasteboardChangedNotification")
}
public struct UIFloatRange: Equatable { public var minimum: CGFloat; public var maximum: CGFloat
    public init(minimum: CGFloat, maximum: CGFloat) { self.minimum = minimum; self.maximum = maximum }
    public static let zero = UIFloatRange(minimum: 0, maximum: 0); public static let infinite = UIFloatRange(minimum: -.infinity, maximum: .infinity) }

public func UIImageJPEGRepresentation(_ i: UIImage, _ q: CGFloat) -> Data? { i.jpegData(compressionQuality: q) }
public func UIImagePNGRepresentation(_ i: UIImage) -> Data? { i.pngData() }

/// iOS 27 reserved regions (camera housings, status corners): none in the browser.
public struct UIViewReservedRegion { public var frame: CGRect; public var isActive: Bool }
extension UIView {
    public enum ReservedRegionKind: Int { case occlusion, interaction, division }
    public func reservedRegions(kind: ReservedRegionKind) -> [UIViewReservedRegion] { [] }
}
