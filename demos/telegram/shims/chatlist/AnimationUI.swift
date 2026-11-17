// Swiftboard web port: AnimationUI's AnimationNode (lottie-ios player). Not ported: Lottie icons (archive avatar,
// story repost, camera) show nothing.
import Foundation
import UIKit
import AsyncDisplayKit
import Display
public final class AnimationNode: ASDisplayNode {
    public var speed: CGFloat = 1.0
    public var didPlay = false
    public var completion: (() -> Void)?
    public var isPlaying: Bool { false }
    public init(animation animationName: String? = nil, colors: [String: UIColor]? = nil, scale: CGFloat = 1.0) { super.init() }
    public init(animationData: Data, colors: [String: UIColor]? = nil, scale: CGFloat = 1.0) { super.init() }
    public func makeCopy(colors: [String: UIColor]? = nil, progress: CGFloat? = nil) -> AnimationNode? { nil }
    public func seekToEnd() {}
    public func setProgress(_ progress: CGFloat) {}
    public func animate(from: CGFloat, to: CGFloat, completion: @escaping () -> Void) { completion() }
    public func setAnimation(name: String, colors: [String: UIColor]? = nil) {}
    public func setColors(colors: [String: UIColor]) {}
    public func setAnimation(data: Data) {}
    public func setAnimation(json: [String: Any]) {}
    public func play() {}
    public func playOnce() {}
    public func loop(count: Int? = nil) {}
    public func reset() {}
    public func preferredSize() -> CGSize? { nil }
}
