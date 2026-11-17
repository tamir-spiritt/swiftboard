// Swiftboard web port: AvatarVideoNode (animated profile videos via the media player). Not ported: shows nothing.
import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import AccountContext
public final class AvatarVideoNode: ASDisplayNode {
    public init(context: AccountContext) { super.init() }
    public func update(markup: TelegramMediaImage.EmojiMarkup, size: CGSize, useAnimationNode: Bool = true) {}
    public func update(peer: EnginePeer, photo: TelegramMediaImage, size: CGSize) {}
    public func updateLayout(size: CGSize, cornerRadius: CGFloat, transition: ContainedViewLayoutTransition) {}
    public func updateLayout(size: CGSize, actualSize: CGSize, transition: ContainedViewLayoutTransition) {}
    public func updateVisibility(_ isVisible: Bool) {}
    public func resetPlayback() {}
}
