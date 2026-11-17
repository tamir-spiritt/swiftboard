// Swiftboard web port: the lottie-ios API EmojiStatusComponent touches. Lottie playback is not ported: animations
// never decode, so callers keep their static fallback.
import Foundation
import UIKit
public final class Animation {
    public static func from(data: Data, strategy: Any? = nil) throws -> Animation { throw NSError(domain: "Lottie", code: 1) }
}
open class AnimationView: UIView {
    public var animation: Animation?
    public var loopMode: Int = 0
    public init(animation: Animation?) { self.animation = animation; super.init(frame: .zero) }
    public required init?(coder: NSCoder) { nil }
    public func play() {}
    public func stop() {}
}
