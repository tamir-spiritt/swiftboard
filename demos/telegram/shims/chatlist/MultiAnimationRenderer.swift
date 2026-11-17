// Swiftboard web port: MultiAnimationRenderer (shared animated-sticker renderer). Not ported: targets stay empty.
import Foundation
import UIKit
import SwiftSignalKit
import Display
import AnimationCache
public protocol MultiAnimationRenderer: AnyObject {
    func add(target: MultiAnimationRenderTarget, cache: AnimationCache, itemId: String, unique: Bool, size: CGSize, fetch: @escaping (AnimationCacheFetchOptions) -> Disposable) -> Disposable
    func loadFirstFrameSynchronously(target: MultiAnimationRenderTarget, cache: AnimationCache, itemId: String, size: CGSize) -> Bool
    func loadFirstFrame(target: MultiAnimationRenderTarget, cache: AnimationCache, itemId: String, size: CGSize, fetch: ((AnimationCacheFetchOptions) -> Disposable)?, completion: @escaping (Bool, Bool) -> Void) -> Disposable
    func loadFirstFrameAsImage(cache: AnimationCache, itemId: String, size: CGSize, fetch: ((AnimationCacheFetchOptions) -> Disposable)?, completion: @escaping (CGImage?) -> Void) -> Disposable
    func setFrameIndex(itemId: String, size: CGSize, frameIndex: Int, placeholder: UIImage)
}
open class MultiAnimationRenderTarget: SimpleLayer {
    public var numFrames: Int?
    public final var shouldBeAnimating: Bool = false
    public var blurredRepresentationBackgroundColor: UIColor?
    public var blurredRepresentationTarget: CALayer?
    public override init() { super.init() }
    public override init(layer: Any) { super.init(layer: layer) }
    public required init?(coder: NSCoder) { nil }
    open func updateDisplayPlaceholder(displayPlaceholder: Bool) {}
    open func transitionToContents(_ contents: AnyObject, didLoop: Bool) {}
}
public final class WebEmptyMultiAnimationRenderer: MultiAnimationRenderer {
    public init() {}
    public func add(target: MultiAnimationRenderTarget, cache: AnimationCache, itemId: String, unique: Bool, size: CGSize, fetch: @escaping (AnimationCacheFetchOptions) -> Disposable) -> Disposable { EmptyDisposable }
    public func loadFirstFrameSynchronously(target: MultiAnimationRenderTarget, cache: AnimationCache, itemId: String, size: CGSize) -> Bool { false }
    public func loadFirstFrame(target: MultiAnimationRenderTarget, cache: AnimationCache, itemId: String, size: CGSize, fetch: ((AnimationCacheFetchOptions) -> Disposable)?, completion: @escaping (Bool, Bool) -> Void) -> Disposable { completion(false, false); return EmptyDisposable }
    public func loadFirstFrameAsImage(cache: AnimationCache, itemId: String, size: CGSize, fetch: ((AnimationCacheFetchOptions) -> Disposable)?, completion: @escaping (CGImage?) -> Void) -> Disposable { completion(nil); return EmptyDisposable }
    public func setFrameIndex(itemId: String, size: CGSize, frameIndex: Int, placeholder: UIImage) {}
}
