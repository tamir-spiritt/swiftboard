// Swiftboard web port: stand-in for Telegram module ManagedAnimationNode (API surface the chat list uses, fake data).
import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit

/// Lottie-backed animation node upstream (rlottie); the port shows nothing for these swipe-action animations.
open class SimpleAnimationNode: ASDisplayNode {
    public let size: CGSize
    public init(animationName: String, replaceColors: [UInt32: UInt32]? = nil, size: CGSize, playOnce: Bool = false, startFrame: Int? = nil) {
        self.size = size
        super.init()
    }
    public func play(immediately: Bool = false) {}
    public func reset(immediately: Bool = false) {}
    public func seekToEnd(immediately: Bool = false) {}
}
