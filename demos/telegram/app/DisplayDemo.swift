// Browser demo of Telegram's Display module (layer 2): the DisplayMain node tree in a UIWindow, with a tap gesture
// on the avatar and on the title that re-lays out the title through Telegram's TextNode.
import Foundation
import UIKit
import AsyncDisplayKit
import Display

final class DemoHandler: NSObject {
    var taps = 0
    weak var title: ImmediateTextNode?
    func avatarTapped(_ g: UITapGestureRecognizer) {
        taps += 1
        print("[swift] avatar tapped (#\(taps)) at \(g.location(in: g.view))")
        retitle()
    }
    func titleTapped(_ g: UITapGestureRecognizer) {
        taps += 1
        print("[swift] title tapped (#\(taps))")
        retitle()
    }
    func retitle() {
        guard let title else { return }
        title.attributedText = NSAttributedString(string: "Telegram · tapped \(taps)×", font: Font.semibold(17), textColor: .black)
        let s = title.updateLayout(CGSize(width: 290, height: CGFloat.greatestFiniteMagnitude))
        title.frame = CGRect(origin: title.frame.origin, size: s)
        WebHost.generation += 1
    }
}

nonisolated(unsafe) var demoRetain: [AnyObject] = []

@_cdecl("app_start")
public func app_start() {
    let screen = UIScreen.main.bounds
    let window = UIWindow(frame: screen)
    window.backgroundColor = .white
    let handler = DemoHandler()

    let root = ASDisplayNode()
    root.frame = CGRect(x: 0, y: 59, width: screen.width, height: 240)
    root.backgroundColor = UIColor(rgb: 0xF7F7F7)

    let avatar = ASImageNode()
    avatar.image = generateImage(CGSize(width: 56, height: 56), rotatedContext: { size, context in
        context.clear(CGRect(origin: .zero, size: size))
        context.setFillColor(UIColor(rgb: 0x2AABEE).cgColor)
        context.fillEllipse(in: CGRect(origin: .zero, size: size))
    })
    avatar.frame = CGRect(x: 16, y: 16, width: 56, height: 56)
    root.addSubnode(avatar)

    let title = ImmediateTextNode()
    title.attributedText = NSAttributedString(string: "Telegram", font: Font.semibold(17), textColor: .black)
    let titleSize = title.updateLayout(CGSize(width: 290, height: CGFloat.greatestFiniteMagnitude))
    title.frame = CGRect(origin: CGPoint(x: 84, y: 18), size: titleSize)
    root.addSubnode(title)
    handler.title = title

    let makeLayout = TextNode.asyncLayout(nil)
    let (layout, apply) = makeLayout(TextNodeLayoutArguments(
        attributedString: NSAttributedString(string: "Running the real Telegram iOS Display module, compiled by the Swift compiler to WebAssembly and laid out in the browser.", font: Font.regular(15), textColor: UIColor(rgb: 0x8E8E93)),
        maximumNumberOfLines: 2, truncationType: .end, constrainedSize: CGSize(width: 290, height: CGFloat.greatestFiniteMagnitude)))
    let preview = apply()
    preview.frame = CGRect(origin: CGPoint(x: 84, y: 42), size: layout.size)
    root.addSubnode(preview)

    let separator = ASDisplayNode()
    separator.isLayerBacked = true
    separator.backgroundColor = UIColor(rgb: 0xC8C7CC)
    separator.frame = CGRect(x: 84, y: 87.5, width: screen.width - 84, height: 0.5)
    root.addSubnode(separator)

    window.addSubview(root.view)
    window.makeKeyAndVisible()

    avatar.isUserInteractionEnabled = true
    avatar.view.addGestureRecognizer(UITapGestureRecognizer(target: handler, action: Selector("avatarTapped(_:)", DemoHandler.avatarTapped(_:))))
    title.isUserInteractionEnabled = true
    title.view.addGestureRecognizer(UITapGestureRecognizer(target: handler, action: Selector("titleTapped(_:)", DemoHandler.titleTapped(_:))))

    WebHost.annotate = { $0.asyncdisplaykit_node.map { String(describing: type(of: $0)) } }
    demoRetain = [window, root, handler]
    print("[swift] Display demo started: \(screen.size) @\(UIScreen.main.scale)x")
}
