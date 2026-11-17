// Swiftboard web port: DirectMediaImageCache (on-disk JPEG thumbnail cache, mozjpeg). Not ported: no cached images.
import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import TelegramCore
public final class DirectMediaImageCache {
    public final class GetMediaResult {
        public let image: UIImage?
        public let blurredImage: UIImage?
        public let loadSignal: Signal<UIImage?, NoError>?
        init(image: UIImage?, blurredImage: UIImage? = nil, loadSignal: Signal<UIImage?, NoError>?) { self.image = image; self.blurredImage = blurredImage; self.loadSignal = loadSignal }
    }
    public init(account: Account) {}
    public func getAvatarImage(peer: PeerReference, resource: MediaResourceReference, immediateThumbnail: Data?, size: Int, includeBlurred: Bool = false, synchronous: Bool) -> GetMediaResult? { nil }
}
