// Swiftboard web port: stand-in for Telegram module CheckNode (API surface the chat list uses, fake data).
import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit

public struct CheckNodeTheme {
    public let backgroundColor: UIColor, strokeColor: UIColor, borderColor: UIColor, overlayBorder: Bool, hasInset: Bool, hasShadow: Bool
    public init(backgroundColor: UIColor, strokeColor: UIColor, borderColor: UIColor, overlayBorder: Bool, hasInset: Bool, hasShadow: Bool, filledBorder: Bool = false, borderWidth: CGFloat? = nil) {
        self.backgroundColor = backgroundColor; self.strokeColor = strokeColor; self.borderColor = borderColor; self.overlayBorder = overlayBorder; self.hasInset = hasInset; self.hasShadow = hasShadow
    }
}
/// Selection check circle (simplified port of Telegram's CheckNode).
open class CheckNode: ASDisplayNode {
    public enum Content { case check, counter(Int) }
    public var theme: CheckNodeTheme
    public var content: Content = .check
    public private(set) var selected = false
    public init(theme: CheckNodeTheme, content: Content = .check) { self.theme = theme; self.content = content; super.init(); isOpaque = false }
    public func setSelected(_ s: Bool, animated: Bool) { selected = s; setNeedsDisplay() }
    open override func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? { CheckParams(theme: theme, selected: selected) }
    final class CheckParams: NSObject { let theme: CheckNodeTheme; let selected: Bool; init(theme: CheckNodeTheme, selected: Bool) { self.theme = theme; self.selected = selected } }
    open override class func draw(_ bounds: CGRect, withParameters parameters: Any?, isCancelled: () -> Bool, isRasterizing: Bool) {
        guard let p = parameters as? CheckParams, let c = UIGraphicsGetCurrentContext() else { return }
        let r = bounds.insetBy(dx: 1, dy: 1)
        if p.selected { c.setFillColor(p.theme.backgroundColor.cgColor); c.fillEllipse(in: r) }
        else { c.setStrokeColor(p.theme.borderColor.cgColor); c.setLineWidth(1.5); c.strokeEllipse(in: r) }
    }
}
