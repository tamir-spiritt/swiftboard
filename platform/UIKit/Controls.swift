// Swiftboard UIKit (MIT): controls, image views, labels, scroll views, text input, effects.
import Foundation

open class UIControl: UIView {
    public struct State: OptionSet, Hashable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let normal = State([])
        public static let highlighted = State(rawValue: 1 << 0)
        public static let disabled = State(rawValue: 1 << 1)
        public static let selected = State(rawValue: 1 << 2)
        public static let focused = State(rawValue: 1 << 3)
    }
    public struct Event: OptionSet, Hashable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let touchDown = Event(rawValue: 1 << 0)
        public static let touchDownRepeat = Event(rawValue: 1 << 1)
        public static let touchDragInside = Event(rawValue: 1 << 2)
        public static let touchDragOutside = Event(rawValue: 1 << 3)
        public static let touchDragEnter = Event(rawValue: 1 << 4)
        public static let touchDragExit = Event(rawValue: 1 << 5)
        public static let touchUpInside = Event(rawValue: 1 << 6)
        public static let touchUpOutside = Event(rawValue: 1 << 7)
        public static let touchCancel = Event(rawValue: 1 << 8)
        public static let valueChanged = Event(rawValue: 1 << 12)
        public static let primaryActionTriggered = Event(rawValue: 1 << 13)
        public static let menuActionTriggered = Event(rawValue: 1 << 14)
        public static let editingDidBegin = Event(rawValue: 1 << 16)
        public static let editingChanged = Event(rawValue: 1 << 17)
        public static let editingDidEnd = Event(rawValue: 1 << 18)
        public static let editingDidEndOnExit = Event(rawValue: 1 << 19)
        public static let allTouchEvents = Event(rawValue: 0x0FFF)
        public static let allEditingEvents = Event(rawValue: 0x000F_0000)
        public static let allEvents = Event(rawValue: 0xFFFF_FFFF)
    }
    public enum ContentHorizontalAlignment: Int { case center, left, right, fill, leading, trailing }
    public enum ContentVerticalAlignment: Int { case center, top, bottom, fill }
    struct Target { weak var target: AnyObject?; let action: Selector; let events: Event }
    private var targets: [Target] = []
    private var actionsByEvent: [(UIAction, Event)] = []
    open var isEnabled = true
    open var isSelected = false
    open var isHighlighted = false
    public internal(set) var isTracking = false
    public internal(set) var isTouchInside = false
    open var contentHorizontalAlignment: ContentHorizontalAlignment = .center
    open var contentVerticalAlignment: ContentVerticalAlignment = .center
    open var isContextMenuInteractionEnabled = false
    open var showsMenuAsPrimaryAction = false
    open var state: State {
        var s: State = []
        if isHighlighted { s.insert(.highlighted) }
        if !isEnabled { s.insert(.disabled) }
        if isSelected { s.insert(.selected) }
        return s
    }
    open func addTarget(_ target: Any?, action: Selector, for events: Event) { targets.append(Target(target: target as AnyObject?, action: action, events: events)) }
    open func removeTarget(_ target: Any?, action: Selector?, for events: Event) {
        targets.removeAll { t in (target == nil || t.target === (target as AnyObject?)) && (action == nil || t.action == action!) && !t.events.isDisjoint(with: events) }
    }
    open func addAction(_ action: UIAction, for events: Event) { actionsByEvent.append((action, events)) }
    open func removeAction(_ action: UIAction, for events: Event) { actionsByEvent.removeAll { $0.0 === action } }
    open var allTargets: Set<AnyHashable> { Set(targets.compactMap { $0.target.map { ObjectIdentifier($0) } }) }
    open var allControlEvents: Event { targets.reduce([]) { $0.union($1.events) } }
    open func actions(forTarget target: Any?, forControlEvent e: Event) -> [String]? {
        let r = targets.filter { $0.target === (target as AnyObject?) && $0.events.contains(e) }.map { $0.action.name }
        return r.isEmpty ? nil : r
    }
    open func sendActions(for events: Event) {
        for t in targets where !t.events.isDisjoint(with: events) { sendAction(t.action, to: t.target, for: nil) }
        for (a, e) in actionsByEvent where !e.isDisjoint(with: events) { a.handler(a) }
    }
    open func sendAction(_ action: Selector, to target: Any?, for event: UIEvent?) {
        if let t = target { action.perform(on: t as AnyObject, with: self, with: event) }
        else { UIApplication.shared.sendAction(action, to: nil, from: self, for: event) }
    }
    open func sendAction(_ action: UIAction) { action.handler(action) }
    open func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool { true }
    open func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool { true }
    open func endTracking(_ touch: UITouch?, with event: UIEvent?) {}
    open func cancelTracking(with event: UIEvent?) {}

    open override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isEnabled, let t = touches.first else { return }
        isTracking = beginTracking(t, with: event)
        isTouchInside = true
        isHighlighted = true
        sendActions(for: .touchDown)
    }
    open override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isTracking, let t = touches.first else { return }
        isTouchInside = bounds.insetBy(dx: -70, dy: -70).contains(t.location(in: self))
        isHighlighted = isTouchInside
        isTracking = continueTracking(t, with: event)
        sendActions(for: isTouchInside ? .touchDragInside : .touchDragOutside)
    }
    open override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isEnabled else { return }
        endTracking(touches.first, with: event)
        isTracking = false
        isHighlighted = false
        sendActions(for: isTouchInside ? [.touchUpInside, .primaryActionTriggered] : .touchUpOutside)
    }
    open override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        cancelTracking(with: event)
        isTracking = false
        isHighlighted = false
        sendActions(for: .touchCancel)
    }
}

open class UIAction: NSObject {
    public struct Identifier: RawRepresentable, Hashable { public let rawValue: String; public init(rawValue: String) { self.rawValue = rawValue }; public init(_ r: String) { rawValue = r } }
    public struct Attributes: OptionSet { public let rawValue: UInt; public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let disabled = Attributes(rawValue: 1); public static let destructive = Attributes(rawValue: 2); public static let hidden = Attributes(rawValue: 4) }
    public enum State: Int { case off, on, mixed }
    public var title: String
    public var image: UIImage?
    public var identifier: Identifier
    public var attributes: Attributes = []
    public var state: State = .off
    public var discoverabilityTitle: String?
    let handler: (UIAction) -> Void
    public weak var sender: AnyObject?
    public init(title: String = "", image: UIImage? = nil, identifier: Identifier? = nil, discoverabilityTitle: String? = nil, attributes: Attributes = [], state: State = .off, handler: @escaping (UIAction) -> Void) {
        self.title = title; self.image = image; self.identifier = identifier ?? Identifier(UUID().uuidString); self.discoverabilityTitle = discoverabilityTitle
        self.attributes = attributes; self.state = state; self.handler = handler
    }
}

open class UIImageView: UIView {
    open var image: UIImage? { didSet { updateContents() } }
    open var highlightedImage: UIImage? { didSet { updateContents() } }
    open var isHighlighted = false { didSet { updateContents() } }
    open var animationImages: [UIImage]?
    open var highlightedAnimationImages: [UIImage]?
    open var animationDuration: TimeInterval = 0
    open var animationRepeatCount = 0
    public private(set) var isAnimating = false
    open var preferredSymbolConfiguration: AnyObject?
    public override init(frame: CGRect) { super.init(frame: frame); isUserInteractionEnabled = false }
    public required init?(coder: NSCoder) { super.init(coder: coder) }
    public init(image: UIImage?) {
        super.init(frame: CGRect(origin: .zero, size: image?.size ?? .zero))
        isUserInteractionEnabled = false
        self.image = image
        updateContents()
    }
    public convenience init(image: UIImage?, highlightedImage: UIImage?) { self.init(image: image); self.highlightedImage = highlightedImage }
    func updateContents() {
        let i = isHighlighted ? (highlightedImage ?? image) : image
        layer.contents = i?.cgImage
        layer.contentsScale = i?.scale ?? UIScreen.main.scale
        if let i, i.capInsets != .zero {
            let s = i.size
            if s.width > 0 && s.height > 0 {
                layer.contentsCenter = CGRect(x: i.capInsets.left / s.width, y: i.capInsets.top / s.height,
                                              width: max(0, s.width - i.capInsets.left - i.capInsets.right) / s.width,
                                              height: max(0, s.height - i.capInsets.top - i.capInsets.bottom) / s.height)
            }
        } else {
            layer.contentsCenter = CGRect(x: 0, y: 0, width: 1, height: 1)
        }
        layer.webTintColor = (i?.renderingMode == .alwaysTemplate) ? tintColor.cgColor : i?.tintColor?.cgColor
    }
    open override func tintColorDidChange() { updateContents() }
    open override func sizeThatFits(_ size: CGSize) -> CGSize { image?.size ?? .zero }
    open override var intrinsicContentSize: CGSize { image?.size ?? .zero }
    open func startAnimating() { isAnimating = true }
    open func stopAnimating() { isAnimating = false }
}

extension CALayer {
    /// Tint applied to template contents by the painter.
    public var webTintColor: CGColor? {
        get { value(forKey: "webTintColor").map { $0 as AnyObject } as? CGColor }
        set { setValue(newValue, forKey: "webTintColor") }
    }
}

open class UILabel: UIView {
    open var text: String? { didSet { setNeedsDisplay() } }
    open var attributedText: NSAttributedString? { didSet { setNeedsDisplay() } }
    open var font: UIFont! = UIFont.systemFont(ofSize: 17) { didSet { setNeedsDisplay() } }
    open var textColor: UIColor! = .black { didSet { setNeedsDisplay() } }
    open var highlightedTextColor: UIColor?
    open var isHighlighted = false
    open var isEnabled = true
    open var textAlignment: NSTextAlignment = .natural { didSet { setNeedsDisplay() } }
    open var numberOfLines = 1 { didSet { setNeedsDisplay() } }
    open var lineBreakMode: NSLineBreakMode = .byTruncatingTail
    open var adjustsFontSizeToFitWidth = false
    open var minimumScaleFactor: CGFloat = 0
    open var allowsDefaultTighteningForTruncation = false
    open var preferredMaxLayoutWidth: CGFloat = 0
    open var shadowColor: UIColor?
    open var shadowOffset = CGSize(width: 0, height: -1)
    open var baselineAdjustment = 0
    public override init(frame: CGRect) { super.init(frame: frame); isUserInteractionEnabled = false; contentMode = .redraw }
    public required init?(coder: NSCoder) { super.init(coder: coder) }
    var effectiveText: NSAttributedString {
        if let a = attributedText { return a }
        let p = NSMutableParagraphStyle(); p.alignment = textAlignment
        return NSAttributedString(string: text ?? "", attributes: [.font: font as Any, .foregroundColor: textColor as Any, .paragraphStyle: p])
    }
    open func textRect(forBounds bounds: CGRect, limitedToNumberOfLines n: Int) -> CGRect {
        let r = effectiveText.boundingRect(with: CGSize(width: bounds.width, height: n == 0 ? .greatestFiniteMagnitude : CGFloat(n) * (font?.lineHeight ?? 20) + 0.5), options: .usesLineFragmentOrigin, context: nil)
        return CGRect(origin: bounds.origin, size: CGSize(width: ceil(r.width), height: ceil(r.height)))
    }
    open func drawText(in rect: CGRect) { effectiveText.draw(with: rect, options: .usesLineFragmentOrigin, context: nil) }
    open override func draw(_ rect: CGRect) {
        let r = textRect(forBounds: bounds, limitedToNumberOfLines: numberOfLines)
        drawText(in: CGRect(x: 0, y: (bounds.height - r.height) / 2, width: bounds.width, height: r.height))
    }
    open override func sizeThatFits(_ size: CGSize) -> CGSize { textRect(forBounds: CGRect(origin: .zero, size: CGSize(width: size.width == 0 ? .greatestFiniteMagnitude : size.width, height: size.height)), limitedToNumberOfLines: numberOfLines).size }
    open override var intrinsicContentSize: CGSize { sizeThatFits(CGSize(width: preferredMaxLayoutWidth == 0 ? .greatestFiniteMagnitude : preferredMaxLayoutWidth, height: .greatestFiniteMagnitude)) }
}

open class UIButton: UIControl {
    public enum ButtonType: Int { case custom, system, detailDisclosure, infoLight, infoDark, contactAdd, close
        public static let roundedRect = ButtonType.system; public static let plain = ButtonType.system }
    public private(set) var buttonType: ButtonType = .custom
    private var titles: [UInt: String] = [:]
    private var attributedTitles: [UInt: NSAttributedString] = [:]
    private var titleColors: [UInt: UIColor] = [:]
    private var images: [UInt: UIImage] = [:]
    private var backgroundImages: [UInt: UIImage] = [:]
    public private(set) lazy var titleLabel: UILabel? = { let l = UILabel(); addSubview(l); return l }()
    public private(set) lazy var imageView: UIImageView? = { let v = UIImageView(); addSubview(v); return v }()
    open var contentEdgeInsets: UIEdgeInsets = .zero
    open var titleEdgeInsets: UIEdgeInsets = .zero
    open var imageEdgeInsets: UIEdgeInsets = .zero
    open var adjustsImageWhenHighlighted = true
    open var adjustsImageWhenDisabled = true
    open var showsTouchWhenHighlighted = false
    open var reversesTitleShadowWhenHighlighted = false
    open var pointerStyleProvider: AnyObject?
    open var isPointerInteractionEnabled = false
    open var menu: UIMenu?
    open override var isHighlighted: Bool { didSet { update() } }
    open override var isSelected: Bool { didSet { update() } }
    open override var isEnabled: Bool { didSet { update() } }
    public convenience init(type: ButtonType) { self.init(frame: .zero); buttonType = type }
    public override init(frame: CGRect) { super.init(frame: frame) }
    public required init?(coder: NSCoder) { super.init(coder: coder) }
    public convenience init(type: ButtonType, primaryAction: UIAction?) { self.init(type: type); if let a = primaryAction { addAction(a, for: .primaryActionTriggered) } }
    public convenience init(frame: CGRect, primaryAction: UIAction?) { self.init(frame: frame); if let a = primaryAction { addAction(a, for: .primaryActionTriggered) } }
    private func value<T>(_ d: [UInt: T]) -> T? { d[state.rawValue] ?? d[0] }
    open func setTitle(_ t: String?, for s: State) { titles[s.rawValue] = t; update() }
    open func setTitleColor(_ c: UIColor?, for s: State) { titleColors[s.rawValue] = c; update() }
    open func setAttributedTitle(_ t: NSAttributedString?, for s: State) { attributedTitles[s.rawValue] = t; update() }
    open func setImage(_ i: UIImage?, for s: State) { images[s.rawValue] = i; update() }
    open func setBackgroundImage(_ i: UIImage?, for s: State) { backgroundImages[s.rawValue] = i; update() }
    open func setTitleShadowColor(_ c: UIColor?, for s: State) {}
    open func setPreferredSymbolConfiguration(_ c: AnyObject?, forImageIn s: State) {}
    open func title(for s: State) -> String? { titles[s.rawValue] ?? titles[0] }
    open func titleColor(for s: State) -> UIColor? { titleColors[s.rawValue] ?? titleColors[0] }
    open func image(for s: State) -> UIImage? { images[s.rawValue] ?? images[0] }
    open func backgroundImage(for s: State) -> UIImage? { backgroundImages[s.rawValue] ?? backgroundImages[0] }
    open func attributedTitle(for s: State) -> NSAttributedString? { attributedTitles[s.rawValue] ?? attributedTitles[0] }
    open var currentTitle: String? { value(titles) }
    open var currentImage: UIImage? { value(images) }
    open var currentAttributedTitle: NSAttributedString? { value(attributedTitles) }
    func update() {
        if let a = value(attributedTitles) { titleLabel?.attributedText = a } else { titleLabel?.text = value(titles) }
        titleLabel?.textColor = value(titleColors) ?? (buttonType == .system ? tintColor : .white)
        imageView?.image = value(images)
        setNeedsLayout()
    }
    open override func layoutSubviews() {
        let b = bounds.inset(by: contentEdgeInsets)
        let isz = imageView?.image?.size ?? .zero
        let tsz = titleLabel?.sizeThatFits(b.size) ?? .zero
        let total = isz.width + tsz.width
        var x = b.minX + (b.width - total) / 2
        imageView?.frame = CGRect(x: x, y: b.midY - isz.height / 2, width: isz.width, height: isz.height).inset(by: imageEdgeInsets)
        x += isz.width
        titleLabel?.frame = CGRect(x: x, y: b.midY - tsz.height / 2, width: tsz.width, height: tsz.height).inset(by: titleEdgeInsets)
    }
    open override func sizeThatFits(_ size: CGSize) -> CGSize {
        let isz = image(for: .normal)?.size ?? .zero
        let tsz = (title(for: .normal) != nil || attributedTitle(for: .normal) != nil) ? (titleLabel?.sizeThatFits(size) ?? .zero) : .zero
        return CGSize(width: isz.width + tsz.width + contentEdgeInsets.left + contentEdgeInsets.right,
                      height: max(isz.height, tsz.height) + contentEdgeInsets.top + contentEdgeInsets.bottom)
    }
}

open class UIMenuElement: NSObject {
    public var title: String
    public var image: UIImage?
    init(title: String, image: UIImage?) { self.title = title; self.image = image }
}
open class UIMenu: UIMenuElement {
    public struct Options: OptionSet { public let rawValue: UInt; public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let displayInline = Options(rawValue: 1); public static let destructive = Options(rawValue: 2); public static let singleSelection = Options(rawValue: 32) }
    public struct Identifier: RawRepresentable, Hashable { public let rawValue: String; public init(rawValue: String) { self.rawValue = rawValue } }
    public let children: [UIMenuElement]
    public let options: Options
    public init(title: String = "", image: UIImage? = nil, identifier: Identifier? = nil, options: Options = [], children: [UIMenuElement] = []) {
        self.children = children; self.options = options; super.init(title: title, image: image)
    }
}

open class UISwitch: UIControl {
    open var isOn = false
    open var onTintColor: UIColor?
    open var thumbTintColor: UIColor?
    open var onImage: UIImage?
    open var offImage: UIImage?
    open var preferredStyle = 0
    public override init(frame: CGRect) { super.init(frame: CGRect(origin: frame.origin, size: CGSize(width: 51, height: 31))) }
    public required init?(coder: NSCoder) { super.init(coder: coder) }
    open func setOn(_ on: Bool, animated: Bool) { isOn = on }
    open override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        if isEnabled { isOn.toggle(); sendActions(for: .valueChanged) }
    }
    open override func sizeThatFits(_ size: CGSize) -> CGSize { CGSize(width: 51, height: 31) }
}

open class UISlider: UIControl {
    open var value: Float = 0
    open var minimumValue: Float = 0
    open var maximumValue: Float = 1
    open var isContinuous = true
    open var minimumTrackTintColor: UIColor?
    open var maximumTrackTintColor: UIColor?
    open var thumbTintColor: UIColor?
    open var minimumValueImage: UIImage?
    open var maximumValueImage: UIImage?
    open func setValue(_ v: Float, animated: Bool) { value = min(max(v, minimumValue), maximumValue) }
    open func setThumbImage(_ i: UIImage?, for s: State) {}
    open func setMinimumTrackImage(_ i: UIImage?, for s: State) {}
    open func setMaximumTrackImage(_ i: UIImage?, for s: State) {}
    open func trackRect(forBounds b: CGRect) -> CGRect { CGRect(x: b.minX, y: b.midY - 1, width: b.width, height: 2) }
    open func thumbRect(forBounds b: CGRect, trackRect r: CGRect, value: Float) -> CGRect {
        let t = CGFloat((value - minimumValue) / max(0.0001, maximumValue - minimumValue))
        return CGRect(x: r.minX + t * r.width - 14, y: b.midY - 14, width: 28, height: 28)
    }
}

open class UIActivityIndicatorView: UIView {
    public enum Style: Int { case whiteLarge, white, gray, medium = 100, large = 101 }
    public var style: Style
    public var color: UIColor!
    public var hidesWhenStopped = true
    public private(set) var isAnimating = false
    public init(style: Style) { self.style = style; super.init(frame: CGRect(x: 0, y: 0, width: 20, height: 20)) }
    public override init(frame: CGRect) { style = .medium; super.init(frame: frame) }
    public required init?(coder: NSCoder) { style = .medium; super.init(coder: coder) }
    public func startAnimating() { isAnimating = true }
    public func stopAnimating() { isAnimating = false }
}

open class UIProgressView: UIView {
    open var progress: Float = 0
    open var progressTintColor: UIColor?
    open var trackTintColor: UIColor?
    open func setProgress(_ p: Float, animated: Bool) { progress = p }
}

// MARK: visual effects

open class UIVisualEffect: NSObject {}
open class UIBlurEffect: UIVisualEffect {
    public enum Style: Int { case extraLight, light, dark, extraDark, regular = 4, prominent = 5,
        systemUltraThinMaterial, systemThinMaterial, systemMaterial, systemThickMaterial, systemChromeMaterial,
        systemUltraThinMaterialLight, systemThinMaterialLight, systemMaterialLight, systemThickMaterialLight, systemChromeMaterialLight,
        systemUltraThinMaterialDark, systemThinMaterialDark, systemMaterialDark, systemThickMaterialDark, systemChromeMaterialDark }
    public let style: Style
    public init(style: Style) { self.style = style }
}
open class UIVibrancyEffect: UIVisualEffect {
    public init(blurEffect: UIBlurEffect) {}
    public init(blurEffect: UIBlurEffect, style: Int) {}
}
open class UIVisualEffectView: UIView {
    open var effect: UIVisualEffect? { didSet { layer.filters = effect is UIBlurEffect ? ["blur"] : nil } }
    public let contentView: UIView
    public init(effect: UIVisualEffect?) {
        contentView = UIView()
        super.init(frame: .zero)
        self.effect = effect
        layer.filters = effect is UIBlurEffect ? ["blur"] : nil
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(contentView)
    }
    public override convenience init(frame: CGRect) { self.init(effect: nil); self.frame = frame }
    public required init?(coder: NSCoder) { contentView = UIView(); super.init(coder: coder) }
    open override func layoutSubviews() { contentView.frame = bounds }
}

// MARK: scroll view

public protocol UIScrollViewDelegate: AnyObject {
    func scrollViewDidScroll(_ scrollView: UIScrollView)
    func scrollViewDidZoom(_ scrollView: UIScrollView)
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView)
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>)
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool)
    func scrollViewWillBeginDecelerating(_ scrollView: UIScrollView)
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView)
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView)
    func viewForZooming(in scrollView: UIScrollView) -> UIView?
    func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?)
    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat)
    func scrollViewShouldScrollToTop(_ scrollView: UIScrollView) -> Bool
    func scrollViewDidScrollToTop(_ scrollView: UIScrollView)
    func scrollViewDidChangeAdjustedContentInset(_ scrollView: UIScrollView)
}
extension UIScrollViewDelegate {
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {}
    public func scrollViewDidZoom(_ scrollView: UIScrollView) {}
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {}
    public func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {}
    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {}
    public func scrollViewWillBeginDecelerating(_ scrollView: UIScrollView) {}
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {}
    public func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {}
    public func viewForZooming(in scrollView: UIScrollView) -> UIView? { nil }
    public func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {}
    public func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {}
    public func scrollViewShouldScrollToTop(_ scrollView: UIScrollView) -> Bool { true }
    public func scrollViewDidScrollToTop(_ scrollView: UIScrollView) {}
    public func scrollViewDidChangeAdjustedContentInset(_ scrollView: UIScrollView) {}
}
public protocol UIScrollViewAccessibilityDelegate: UIScrollViewDelegate {
    func accessibilityScrollStatus(for scrollView: UIScrollView) -> String?
}
extension UIScrollViewAccessibilityDelegate {
    public func accessibilityScrollStatus(for scrollView: UIScrollView) -> String? { nil }
}

open class UIScrollView: UIView {
    public struct DecelerationRate: RawRepresentable, Hashable {
        public let rawValue: CGFloat
        public init(rawValue: CGFloat) { self.rawValue = rawValue }
        public static let normal = DecelerationRate(rawValue: 0.998)
        public static let fast = DecelerationRate(rawValue: 0.99)
    }
    public enum ContentInsetAdjustmentBehavior: Int { case automatic, scrollableAxes, never, always }
    public enum KeyboardDismissMode: Int { case none, onDrag, interactive, onDragWithAccessory, interactiveWithAccessory }
    public enum IndicatorStyle: Int { case `default`, black, white }
    open weak var delegate: UIScrollViewDelegate?
    open var contentSize: CGSize = .zero
    open var contentInset: UIEdgeInsets = .zero { didSet { delegate?.scrollViewDidChangeAdjustedContentInset(self) } }
    open var adjustedContentInset: UIEdgeInsets { contentInset }
    open var scrollIndicatorInsets: UIEdgeInsets = .zero
    open var verticalScrollIndicatorInsets: UIEdgeInsets = .zero
    open var horizontalScrollIndicatorInsets: UIEdgeInsets = .zero
    open var contentInsetAdjustmentBehavior: ContentInsetAdjustmentBehavior = .automatic
    open var automaticallyAdjustsScrollIndicatorInsets = true
    open var isScrollEnabled = true
    open var isPagingEnabled = false
    open var bounces = true
    open var bouncesZoom = true
    open var alwaysBounceVertical = false
    open var alwaysBounceHorizontal = false
    open var showsVerticalScrollIndicator = true
    open var showsHorizontalScrollIndicator = true
    open var scrollsToTop = true
    open var isDirectionalLockEnabled = false
    open var delaysContentTouches = true
    open var canCancelContentTouches = true
    open var decelerationRate: DecelerationRate = .normal
    open var keyboardDismissMode: KeyboardDismissMode = .none
    open var indicatorStyle: IndicatorStyle = .default
    open var minimumZoomScale: CGFloat = 1
    open var maximumZoomScale: CGFloat = 1
    open var zoomScale: CGFloat = 1
    open var isTracking: Bool { false }
    open var isDragging: Bool { false }
    open var isDecelerating: Bool { false }
    open var isZooming: Bool { false }
    open var isZoomBouncing: Bool { false }
    open var refreshControl: UIView?
    open var allowsKeyboardScrolling = true
    public let topEdgeEffect = UIScrollEdgeEffect()
    public let bottomEdgeEffect = UIScrollEdgeEffect()
    public let leftEdgeEffect = UIScrollEdgeEffect()
    public let rightEdgeEffect = UIScrollEdgeEffect()
    public private(set) lazy var panGestureRecognizer: UIPanGestureRecognizer = {
        let g = UIPanGestureRecognizer(target: self, action: Selector("handlePan:", UIScrollView.webHandlePan(_:)))
        addGestureRecognizer(g)
        return g
    }()
    open var pinchGestureRecognizer: UIPinchGestureRecognizer? { nil }
    public override init(frame: CGRect) { super.init(frame: frame); clipsToBounds = true; _ = panGestureRecognizer }
    public required init?(coder: NSCoder) { super.init(coder: coder) }
    open var contentOffset: CGPoint {
        get { bounds.origin }
        set {
            guard newValue != bounds.origin else { return }
            var b = bounds; b.origin = newValue; bounds = b
            delegate?.scrollViewDidScroll(self)
        }
    }
    open func setContentOffset(_ p: CGPoint, animated: Bool) {
        contentOffset = p
        if animated { DispatchQueue.main.async { [weak self] in if let s = self { s.delegate?.scrollViewDidEndScrollingAnimation(s) } } }
    }
    open func scrollRectToVisible(_ r: CGRect, animated: Bool) {
        var o = contentOffset
        if r.maxY > o.y + bounds.height { o.y = r.maxY - bounds.height }
        if r.minY < o.y { o.y = r.minY }
        setContentOffset(o, animated: animated)
    }
    open func setZoomScale(_ s: CGFloat, animated: Bool) { zoomScale = s }
    open func zoom(to r: CGRect, animated: Bool) {}
    open func flashScrollIndicators() {}
    open func touchesShouldBegin(_ touches: Set<UITouch>, with event: UIEvent?, in view: UIView) -> Bool { true }
    open func touchesShouldCancel(in view: UIView) -> Bool { !(view is UIControl) }
    private var panStart: CGPoint = .zero
    func webHandlePan(_ g: UIPanGestureRecognizer) {
        guard isScrollEnabled else { return }
        switch g.state {
        case .began: panStart = contentOffset; delegate?.scrollViewWillBeginDragging(self)
        case .changed:
            let t = g.translation(in: self)
            var o = CGPoint(x: panStart.x - (contentSize.width > bounds.width || alwaysBounceHorizontal ? t.x : 0), y: panStart.y - t.y)
            let minY = -adjustedContentInset.top, maxY = max(minY, contentSize.height + adjustedContentInset.bottom - bounds.height)
            if !bounces { o.y = min(max(o.y, minY), maxY) }
            contentOffset = o
        case .ended, .cancelled:
            var target = contentOffset
            let minY = -adjustedContentInset.top, maxY = max(minY, contentSize.height + adjustedContentInset.bottom - bounds.height)
            target.y = min(max(target.y, minY), maxY)
            withUnsafeMutablePointer(to: &target) { delegate?.scrollViewWillEndDragging(self, withVelocity: g.velocity(in: self), targetContentOffset: $0) }
            contentOffset = target
            delegate?.scrollViewDidEndDragging(self, willDecelerate: false)
        default: break
        }
    }
}

public final class UIScrollEdgeEffect: NSObject {
    public var isHidden = false
    public var style: Int = 0
}

// MARK: text input

public protocol UITextInputTraits: AnyObject {}
public protocol UIKeyInput: UITextInputTraits {
    var hasText: Bool { get }
    func insertText(_ text: String)
    func deleteBackward()
}
open class UITextPosition: NSObject { let offset: Int; init(_ o: Int) { offset = o } }
open class UITextRange: NSObject {
    public let start: UITextPosition
    public let end: UITextPosition
    init(_ s: Int, _ e: Int) { start = UITextPosition(s); end = UITextPosition(e) }
    public var isEmpty: Bool { start.offset == end.offset }
}
open class UITextInputMode: NSObject {
    public var primaryLanguage: String? { "en-US" }
    public static var activeInputModes: [UITextInputMode] { [UITextInputMode()] }
    public static let currentInputModeDidChangeNotification = Notification.Name("UITextInputCurrentInputModeDidChangeNotification")
}
public protocol UITextFieldDelegate: AnyObject {
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool
    func textFieldDidBeginEditing(_ textField: UITextField)
    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool
    func textFieldDidEndEditing(_ textField: UITextField)
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool
    func textFieldDidChangeSelection(_ textField: UITextField)
    func textFieldShouldClear(_ textField: UITextField) -> Bool
    func textFieldShouldReturn(_ textField: UITextField) -> Bool
}
extension UITextFieldDelegate {
    public func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool { true }
    public func textFieldDidBeginEditing(_ textField: UITextField) {}
    public func textFieldShouldEndEditing(_ textField: UITextField) -> Bool { true }
    public func textFieldDidEndEditing(_ textField: UITextField) {}
    public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool { true }
    public func textFieldDidChangeSelection(_ textField: UITextField) {}
    public func textFieldShouldClear(_ textField: UITextField) -> Bool { true }
    public func textFieldShouldReturn(_ textField: UITextField) -> Bool { true }
}

open class UITextField: UIControl, UIKeyInput {
    public enum BorderStyle: Int { case none, line, bezel, roundedRect }
    public enum ViewMode: Int { case never, whileEditing, unlessEditing, always }
    open var text: String? { get { attributedText?.string } set { attributedText = NSAttributedString(string: newValue ?? "", attributes: defaultTextAttributes) } }
    open var attributedText: NSAttributedString? { didSet { setNeedsDisplay() } }
    open var placeholder: String?
    open var attributedPlaceholder: NSAttributedString?
    open var font: UIFont? = UIFont.systemFont(ofSize: 17)
    open var textColor: UIColor? = .black
    open var textAlignment: NSTextAlignment = .natural
    open weak var delegate: UITextFieldDelegate?
    open var borderStyle: BorderStyle = .none
    open var clearButtonMode: ViewMode = .never
    open var leftView: UIView?
    open var rightView: UIView?
    open var leftViewMode: ViewMode = .never
    open var rightViewMode: ViewMode = .never
    open var clearsOnBeginEditing = false
    open var adjustsFontSizeToFitWidth = false
    open var minimumFontSize: CGFloat = 0
    open var defaultTextAttributes: [NSAttributedString.Key: Any] = [:]
    open var typingAttributes: [NSAttributedString.Key: Any]?
    open var allowsEditingTextAttributes = false
    open var keyboardType: UIKeyboardType = .default
    open var keyboardAppearance: UIKeyboardAppearance = .default
    open var returnKeyType: UIReturnKeyType = .default
    open var autocapitalizationType: UITextAutocapitalizationType = .sentences
    open var autocorrectionType: UITextAutocorrectionType = .default
    open var spellCheckingType: UITextSpellCheckingType = .default
    open var smartQuotesType: UITextSmartQuotesType = .default
    open var smartDashesType: UITextSmartDashesType = .default
    open var smartInsertDeleteType: UITextSmartInsertDeleteType = .default
    open var textContentType: UITextContentType?
    open var enablesReturnKeyAutomatically = false
    open var isSecureTextEntry = false
    open var tokenizer: AnyObject? { nil }
    open override var inputAccessoryView: UIView? { get { _accessory } set { _accessory = newValue } }
    private var _accessory: UIView?
    open override var inputView: UIView? { get { _input } set { _input = newValue } }
    private var _input: UIView?
    public var isEditing: Bool { isFirstResponder }
    open var selectedTextRange: UITextRange?
    open var markedTextRange: UITextRange? { nil }
    open var beginningOfDocument: UITextPosition { UITextPosition(0) }
    open var endOfDocument: UITextPosition { UITextPosition((text ?? "").utf16.count) }
    open override var canBecomeFirstResponder: Bool { isEnabled }
    open func position(from p: UITextPosition, offset: Int) -> UITextPosition? { UITextPosition(p.offset + offset) }
    open func offset(from a: UITextPosition, to b: UITextPosition) -> Int { b.offset - a.offset }
    open func textRange(from a: UITextPosition, to b: UITextPosition) -> UITextRange? { UITextRange(a.offset, b.offset) }
    open func caretRect(for p: UITextPosition) -> CGRect { .zero }
    open func firstRect(for r: UITextRange) -> CGRect { .zero }
    open var hasText: Bool { !(text ?? "").isEmpty }
    open func insertText(_ t: String) { text = (text ?? "") + t; sendActions(for: .editingChanged) }
    open func deleteBackward() { if var s = text, !s.isEmpty { s.removeLast(); text = s; sendActions(for: .editingChanged) } }
    open func borderRect(forBounds b: CGRect) -> CGRect { b }
    open func textRect(forBounds b: CGRect) -> CGRect { b }
    open func placeholderRect(forBounds b: CGRect) -> CGRect { textRect(forBounds: b) }
    open func editingRect(forBounds b: CGRect) -> CGRect { textRect(forBounds: b) }
    open func clearButtonRect(forBounds b: CGRect) -> CGRect { CGRect(x: b.maxX - 24, y: b.midY - 12, width: 24, height: 24) }
    open func leftViewRect(forBounds b: CGRect) -> CGRect { CGRect(origin: b.origin, size: leftView?.frame.size ?? .zero) }
    open func rightViewRect(forBounds b: CGRect) -> CGRect { let s = rightView?.frame.size ?? .zero; return CGRect(x: b.maxX - s.width, y: b.minY, width: s.width, height: s.height) }
    open func drawText(in rect: CGRect) {}
    open func drawPlaceholder(in rect: CGRect) {}
    public static let textDidBeginEditingNotification = Notification.Name("UITextFieldTextDidBeginEditingNotification")
    public static let textDidEndEditingNotification = Notification.Name("UITextFieldTextDidEndEditingNotification")
    public static let textDidChangeNotification = Notification.Name("UITextFieldTextDidChangeNotification")
}

public protocol UITextViewDelegate: UIScrollViewDelegate {
    func textViewShouldBeginEditing(_ textView: UITextView) -> Bool
    func textViewShouldEndEditing(_ textView: UITextView) -> Bool
    func textViewDidBeginEditing(_ textView: UITextView)
    func textViewDidEndEditing(_ textView: UITextView)
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool
    func textViewDidChange(_ textView: UITextView)
    func textViewDidChangeSelection(_ textView: UITextView)
}
extension UITextViewDelegate {
    public func textViewShouldBeginEditing(_ textView: UITextView) -> Bool { true }
    public func textViewShouldEndEditing(_ textView: UITextView) -> Bool { true }
    public func textViewDidBeginEditing(_ textView: UITextView) {}
    public func textViewDidEndEditing(_ textView: UITextView) {}
    public func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool { true }
    public func textViewDidChange(_ textView: UITextView) {}
    public func textViewDidChangeSelection(_ textView: UITextView) {}
}

open class NSTextContainer: NSObject {
    public var size: CGSize
    public var lineFragmentPadding: CGFloat = 5
    public var maximumNumberOfLines = 0
    public var lineBreakMode: NSLineBreakMode = .byWordWrapping
    public var widthTracksTextView = true
    public var heightTracksTextView = false
    public var exclusionPaths: [UIBezierPath] = []
    public weak var layoutManager: NSLayoutManager?
    public init(size: CGSize) { self.size = size }
    public override convenience init() { self.init(size: .zero) }
}
open class NSTextStorage: NSMutableAttributedString {}
open class NSLayoutManager: NSObject {
    public private(set) var textContainers: [NSTextContainer] = []
    public weak var textStorage: NSTextStorage?
    public var allowsNonContiguousLayout = false
    public func addTextContainer(_ c: NSTextContainer) { textContainers.append(c); c.layoutManager = self }
    public func ensureLayout(for c: NSTextContainer) {}
    public var numberOfGlyphs: Int { textStorage?.length ?? 0 }
    @discardableResult
    public func lineFragmentRect(forGlyphAt index: Int, effectiveRange: UnsafeMutablePointer<NSRange>?) -> CGRect {
        effectiveRange?.pointee = NSRange(location: 0, length: max(1, numberOfGlyphs))
        return usedRect(for: textContainers.first ?? NSTextContainer(size: .zero))
    }
    public func usedRect(for c: NSTextContainer) -> CGRect {
        guard let s = textStorage else { return .zero }
        return s.boundingRect(with: CGSize(width: c.size.width == 0 ? .greatestFiniteMagnitude : c.size.width, height: .greatestFiniteMagnitude), options: .usesLineFragmentOrigin, context: nil)
    }
    public func glyphRange(for c: NSTextContainer) -> NSRange { NSRange(location: 0, length: textStorage?.length ?? 0) }
}

open class UITextView: UIScrollView, UIKeyInput {
    open var text: String! { get { attributedText.string } set { attributedText = NSAttributedString(string: newValue ?? "", attributes: typingAttributes) } }
    open var attributedText: NSAttributedString! = NSAttributedString(string: "") { didSet { textStorage.setAttributedString(attributedText); setNeedsDisplay() } }
    open var font: UIFont? = UIFont.systemFont(ofSize: 12)
    open var textColor: UIColor? = .black
    open var textAlignment: NSTextAlignment = .natural
    open var isEditable = true
    open var isSelectable = true
    open var selectedRange = NSRange(location: 0, length: 0)
    open var typingAttributes: [NSAttributedString.Key: Any] = [:]
    open var textContainerInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
    open var dataDetectorTypes = 0
    open var linkTextAttributes: [NSAttributedString.Key: Any]!
    open var allowsEditingTextAttributes = false
    open var clearsOnInsertion = false
    open var keyboardType: UIKeyboardType = .default
    open var keyboardAppearance: UIKeyboardAppearance = .default
    open var returnKeyType: UIReturnKeyType = .default
    open var autocapitalizationType: UITextAutocapitalizationType = .sentences
    open var autocorrectionType: UITextAutocorrectionType = .default
    open var spellCheckingType: UITextSpellCheckingType = .default
    open var smartQuotesType: UITextSmartQuotesType = .default
    open var smartDashesType: UITextSmartDashesType = .default
    open var smartInsertDeleteType: UITextSmartInsertDeleteType = .default
    open var textContentType: UITextContentType?
    open var enablesReturnKeyAutomatically = false
    open var isSecureTextEntry = false
    public let textContainer: NSTextContainer
    public let layoutManager: NSLayoutManager
    public let textStorage: NSTextStorage
    open var selectedTextRange: UITextRange?
    open var markedTextRange: UITextRange? { nil }
    open var beginningOfDocument: UITextPosition { UITextPosition(0) }
    open var endOfDocument: UITextPosition { UITextPosition(attributedText.length) }
    open override var inputAccessoryView: UIView? { get { _accessory } set { _accessory = newValue } }
    private var _accessory: UIView?
    open override var inputView: UIView? { get { _input } set { _input = newValue } }
    private var _input: UIView?
    open override var canBecomeFirstResponder: Bool { isEditable }
    public init(frame: CGRect, textContainer: NSTextContainer?) {
        self.textContainer = textContainer ?? NSTextContainer(size: frame.size)
        layoutManager = self.textContainer.layoutManager ?? NSLayoutManager()
        textStorage = NSTextStorage(string: "")
        super.init(frame: frame)
        if self.textContainer.layoutManager == nil { layoutManager.addTextContainer(self.textContainer) }
        layoutManager.textStorage = textStorage
    }
    public override convenience init(frame: CGRect) { self.init(frame: frame, textContainer: nil) }
    public required init?(coder: NSCoder) {
        textContainer = NSTextContainer(size: .zero); layoutManager = NSLayoutManager(); textStorage = NSTextStorage(string: "")
        super.init(coder: coder)
    }
    open var hasText: Bool { attributedText.length > 0 }
    open func insertText(_ t: String) {
        let m = NSMutableAttributedString(attributedString: attributedText)
        m.append(NSAttributedString(string: t, attributes: typingAttributes))
        attributedText = m
    }
    open func deleteBackward() {
        guard attributedText.length > 0 else { return }
        let m = NSMutableAttributedString(attributedString: attributedText)
        m.deleteCharacters(in: NSRange(location: m.length - 1, length: 1))
        attributedText = m
    }
    open func scrollRangeToVisible(_ r: NSRange) {}
    open func caretRect(for p: UITextPosition) -> CGRect { .zero }
    open func firstRect(for r: UITextRange) -> CGRect { .zero }
    open func position(from p: UITextPosition, offset: Int) -> UITextPosition? { UITextPosition(p.offset + offset) }
    open func offset(from a: UITextPosition, to b: UITextPosition) -> Int { b.offset - a.offset }
    open func textRange(from a: UITextPosition, to b: UITextPosition) -> UITextRange? { UITextRange(a.offset, b.offset) }
    open func unmarkText() {}
    public static let textDidBeginEditingNotification = Notification.Name("UITextViewTextDidBeginEditingNotification")
    public static let textDidEndEditingNotification = Notification.Name("UITextViewTextDidEndEditingNotification")
    public static let textDidChangeNotification = Notification.Name("UITextViewTextDidChangeNotification")
}
