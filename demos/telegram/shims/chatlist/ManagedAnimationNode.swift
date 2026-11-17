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

// Lottie-driven upstream (rlottie); the port keeps the API and shows nothing (narrow stub: animated icons only).
public enum ManagedAnimationFramePosition { case start, end }
public enum ManagedAnimationFrameRange: Equatable { case range(startFrame: Int, endFrame: Int); case still(ManagedAnimationFramePosition) }
public enum ManagedAnimationSource: Equatable { case local(String) }
public struct ManagedAnimationItem {
    public let source: ManagedAnimationSource
    public let replaceColors: [UInt32: UInt32]?
    public var frames: ManagedAnimationFrameRange?
    public var duration: Double?
    public var loop: Bool
    public init(source: ManagedAnimationSource, replaceColors: [UInt32: UInt32]? = nil, frames: ManagedAnimationFrameRange? = nil, duration: Double? = nil, loop: Bool = false, callbacks: [(Int, () -> Void)] = []) {
        self.source = source; self.replaceColors = replaceColors; self.frames = frames; self.duration = duration; self.loop = loop
    }
}
open class ManagedAnimationNode: ASDisplayNode {
    public let intrinsicSize: CGSize
    public let imageNode = ASImageNode()
    public var imageUpdated: ((UIImage) -> Void)?
    public var image: UIImage? { imageNode.image }
    public var trackStack: [ManagedAnimationItem] = []
    public var customColor: UIColor?
    public var scale: CGFloat = 1.0
    public init(size: CGSize) { intrinsicSize = size; super.init(); addSubnode(imageNode) }
    open func advance() {}
    public func trackTo(item: ManagedAnimationItem) { trackStack.append(item) }
}
