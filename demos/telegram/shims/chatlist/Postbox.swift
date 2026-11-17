// Swiftboard web port: what the compiled Postbox subset (value types, coding) needs from the rest of Postbox.
import Foundation
import SwiftSignalKit
import MurMurHash32

/// Upstream: MediaBox.swift (storage). Kept for MediaResource's API.
public enum CachedMediaRepresentationKeepDuration { case general, shortLived }
/// Upstream: MessageHistoryView.swift (live history views). Kept for ChatLocation's API.
public final class MessageHistoryViewExternalInput: Equatable {
    public let peerId: PeerId
    public let threadId: Int64
    public init(peerId: PeerId, threadId: Int64) { self.peerId = peerId; self.threadId = threadId }
    public static func == (a: MessageHistoryViewExternalInput, b: MessageHistoryViewExternalInput) -> Bool { a === b }
}

/// Upstream: MediaBox.swift (on-disk media cache, fetch pipeline). The web port has no media store: nothing is ever
/// completed, so callers fall back to their placeholders.
public final class MediaBox {
    public let basePath: String
    public init(basePath: String) { self.basePath = basePath }
    public func completedResourcePath(_ resource: MediaResource, pathExtension: String? = nil) -> String? { nil }
    public func completedResourcePath(id: MediaResourceId, pathExtension: String? = nil) -> String? { nil }
    public func resourceData(_ resource: MediaResource, pathExtension: String? = nil, option: ResourceDataRequestOption = .complete(waitUntilFetchStatus: false), attemptSynchronously: Bool = false) -> Signal<MediaResourceData, NoError> {
        .single(MediaResourceData(path: "", offset: 0, size: 0, complete: false))
    }
    public func storeResourceData(_ id: MediaResourceId, data: Data, synchronous: Bool = false) {}
}
public enum ResourceDataRequestOption { case complete(waitUntilFetchStatus: Bool); case incremental(waitUntilFetchStatus: Bool) }
public struct MediaResourceData {
    public let path: String, offset: Int64, size: Int64, complete: Bool
    public init(path: String, offset: Int64, size: Int64, complete: Bool) { self.path = path; self.offset = offset; self.size = size; self.complete = complete }
}
public enum FetchResourceSourceType { case local, remote }
public enum FetchResourceError { case generic }
extension MediaBox {
    /// No network in the web port: fetches complete without data.
    public func fetchedResource(_ resource: MediaResource, parameters: MediaResourceFetchParameters?, implNext: Bool = false) -> Signal<FetchResourceSourceType, FetchResourceError> { .complete() }
}

/// Upstream: Postbox.swift (the SQLite-backed store). The web port keeps in-memory peers for views only.
public final class Postbox {
    public let mediaBox: MediaBox
    public let seedConfiguration: Any? = nil
    public init(mediaBox: MediaBox = MediaBox(basePath: "/web")) { self.mediaBox = mediaBox }
    /// Live peer view; the web port emits one snapshot (peer only, no cached data).
    public func peerView(id: PeerId) -> Signal<PeerView, NoError> { .single(PeerView(peerId: id, cachedData: nil)) }
}
/// Upstream: PeerView.swift (live peer + cached data + presences). Snapshot form for the web port.
public final class PeerView {
    public let peerId: PeerId
    public let cachedData: CachedPeerData?
    public let peers: [PeerId: Peer] = [:]
    public let peerPresences: [PeerId: PeerPresence] = [:]
    public init(peerId: PeerId, cachedData: CachedPeerData?) { self.peerId = peerId; self.cachedData = cachedData }
}
