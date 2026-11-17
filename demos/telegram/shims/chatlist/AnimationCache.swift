// Swiftboard web port: AnimationCache (animated sticker frame cache on disk). Not ported: nothing is ever cached.
import Foundation
import UIKit
import SwiftSignalKit
public final class AnimationCacheItem {}
public final class AnimationCacheFetchOptions {}
public struct AnimationCacheItemResult { public var item: AnimationCacheItem?; public var isFinal: Bool }
public protocol AnimationCache: AnyObject {
    func get(sourceId: String, size: CGSize, fetch: @escaping (AnimationCacheFetchOptions) -> Disposable) -> Signal<AnimationCacheItemResult, NoError>
    func getFirstFrameSynchronously(sourceId: String, size: CGSize) -> AnimationCacheItem?
    func getFirstFrame(queue: Queue, sourceId: String, size: CGSize, fetch: ((AnimationCacheFetchOptions) -> Disposable)?, completion: @escaping (AnimationCacheItemResult) -> Void) -> Disposable
}
public final class WebEmptyAnimationCache: AnimationCache {
    public init() {}
    public func get(sourceId: String, size: CGSize, fetch: @escaping (AnimationCacheFetchOptions) -> Disposable) -> Signal<AnimationCacheItemResult, NoError> { .complete() }
    public func getFirstFrameSynchronously(sourceId: String, size: CGSize) -> AnimationCacheItem? { nil }
    public func getFirstFrame(queue: Queue, sourceId: String, size: CGSize, fetch: ((AnimationCacheFetchOptions) -> Disposable)?, completion: @escaping (AnimationCacheItemResult) -> Void) -> Disposable { EmptyDisposable }
}
