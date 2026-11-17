// Swiftboard web port: GlassBackgroundComponent's GlassBackgroundView (iOS 26 Liquid Glass: UIGlassEffect, corner
// configurations, mesh-transformed backdrops). Not ported: the web build draws a translucent rounded fill with the
// same API. ChatListItem uses it only for community avatar badges.
import Foundation
import UIKit
import Display
import ComponentFlow

public class GlassBackgroundView: UIView {
    public protocol ContentView: UIView {}
    public final class ContentImageView: UIImageView, ContentView {}

    public struct TintColor: Equatable {
        public enum CustomStyle { case `default`, clear }
        public enum Kind: Equatable {
            case panel, untinted, clear
            case custom(style: CustomStyle, color: UIColor)
        }
        public let kind: Kind
        public let innerColor: UIColor?
        public let innerInset: CGFloat
        public init(kind: Kind, innerColor: UIColor? = nil, innerInset: CGFloat = 3.0) {
            self.kind = kind; self.innerColor = innerColor; self.innerInset = innerInset
        }
    }
    public struct CornerRadii: Equatable {
        public let topLeft: CGFloat, topRight: CGFloat, bottomLeft: CGFloat, bottomRight: CGFloat
        public init(topLeft: CGFloat, topRight: CGFloat, bottomLeft: CGFloat, bottomRight: CGFloat) {
            self.topLeft = topLeft; self.topRight = topRight; self.bottomLeft = bottomLeft; self.bottomRight = bottomRight
        }
    }

    private let content = UIView()
    public var contentView: UIView { content }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(content)
    }
    public required init?(coder: NSCoder) { nil }

    public func update(size: CGSize, cornerRadius: CGFloat, isDark: Bool, tintColor: TintColor, isInteractive: Bool = false, isVisible: Bool = true, transition: ComponentTransition) {
        layer.cornerRadius = cornerRadius
        var fill = isDark ? UIColor(white: 0.12, alpha: 0.72) : UIColor(white: 1.0, alpha: 0.72)
        if case let .custom(_, color) = tintColor.kind { fill = color }
        backgroundColor = fill
        content.frame = CGRect(origin: .zero, size: size)
        alpha = isVisible ? 1 : 0
    }
    public func update(size: CGSize, cornerRadii: CornerRadii, isDark: Bool, tintColor: TintColor, isInteractive: Bool = false, isVisible: Bool = true, transition: ComponentTransition) {
        update(size: size, cornerRadius: max(cornerRadii.topLeft, cornerRadii.bottomRight), isDark: isDark, tintColor: tintColor, isInteractive: isInteractive, isVisible: isVisible, transition: transition)
    }
}
