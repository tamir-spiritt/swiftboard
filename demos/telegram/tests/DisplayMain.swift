// Runs Telegram's real Display module on WebAssembly: an ASDisplayNode tree with an ASImageNode (image drawn by
// Display's generateImage) and Display text nodes laid out by Telegram's TextNode, then dumps the layer tree /
// display list as JSON.
import Foundation
import UIKit
import AsyncDisplayKit
import Display

let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 240))
window.backgroundColor = .white

let root = ASDisplayNode()
root.frame = window.bounds
root.backgroundColor = UIColor(rgb: 0xF7F7F7)

// avatar: a circle drawn through Display's DrawingContext
let avatar = ASImageNode()
avatar.image = generateImage(CGSize(width: 56, height: 56), rotatedContext: { size, context in
    context.clear(CGRect(origin: .zero, size: size))
    context.setFillColor(UIColor(rgb: 0x2AABEE).cgColor)
    context.fillEllipse(in: CGRect(origin: .zero, size: size))
})
avatar.frame = CGRect(x: 16, y: 16, width: 56, height: 56)
root.addSubnode(avatar)

// title: ImmediateTextNode (a TextNode) laying out one line
let title = ImmediateTextNode()
title.attributedText = NSAttributedString(string: "Telegram", font: Font.semibold(17), textColor: .black)
let titleSize = title.updateLayout(CGSize(width: 290, height: CGFloat.greatestFiniteMagnitude))
title.frame = CGRect(origin: CGPoint(x: 84, y: 18), size: titleSize)
root.addSubnode(title)

// message preview: TextNode.asyncLayout with two lines and end truncation
let makeLayout = TextNode.asyncLayout(nil)
let (layout, apply) = makeLayout(TextNodeLayoutArguments(
    attributedString: NSAttributedString(string: "Running the real Telegram iOS Display module, compiled by the Swift compiler to WebAssembly and laid out in the browser.", font: Font.regular(15), textColor: UIColor(rgb: 0x8E8E93)),
    maximumNumberOfLines: 2, truncationType: .end, constrainedSize: CGSize(width: 290, height: CGFloat.greatestFiniteMagnitude)))
let preview = apply()
preview.frame = CGRect(origin: CGPoint(x: 84, y: 42), size: layout.size)
root.addSubnode(preview)

// separator
let separator = ASDisplayNode()
separator.isLayerBacked = true
separator.backgroundColor = UIColor(rgb: 0xC8C7CC)
separator.frame = CGRect(x: 84, y: 87.5, width: 306, height: 0.5)
root.addSubnode(separator)

window.addSubview(root.view)
window.makeKeyAndVisible()

// drive the event loop like the browser does every frame (layout + display flush happen on it)
let start = CFAbsoluteTimeGetCurrent()
while CFAbsoluteTimeGetCurrent() - start < 1 {
    if webRunLoopTick() < 0 { break }
}
CALayer.webFlush()

print(WebDisplayList.json(window.layer, annotate: { layer in
    layer.asyncdisplaykit_node.map { String(describing: type(of: $0)) }
}))
print("title size: \(titleSize), preview size: \(layout.size), lines: \(layout.numberOfLines)")
print("hierarchy: avatar in window=\(avatar.isInHierarchy) title loaded=\(title.isNodeLoaded)")
