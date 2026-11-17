// Swiftboard web port: what the compiled TelegramCore subset (SyncCore value types, engine wrappers) needs from the
// rest of TelegramCore (network, API, account state). Fake data layer, no storage.
import Foundation
import Postbox
import SwiftSignalKit
import MurMurHash32

// zlib is not in the WASI SDK: widget payload compression (TelegramMediaWidget) is unavailable in the web build.
public typealias uLong = UInt
public typealias uLongf = UInt
public typealias Bytef = UInt8
public let Z_OK: Int32 = 0
public func compressBound(_ sourceLen: uLong) -> uLong { sourceLen + sourceLen / 1000 + 64 }
public func compress2(_ dest: UnsafeMutablePointer<Bytef>?, _ destLen: UnsafeMutablePointer<uLongf>?, _ source: UnsafePointer<Bytef>?, _ sourceLen: uLong, _ level: Int32) -> Int32 { -1 }
/// MtProtoKit's gzip helper (no zlib in the web build).
public final class MTGzip {
    public static func decompress(_ data: Data) -> Data? { nil }
    public static func compress(_ data: Data) -> Data? { nil }
}

/// Upstream: Account/Account.swift (network session, state manager, postbox). The web port's account is a peer id
/// and an in-memory postbox.
public final class Account {
    public let peerId: PeerId
    public let postbox: Postbox
    public init(peerId: PeerId, postbox: Postbox = Postbox()) { self.peerId = peerId; self.postbox = postbox }
}
/// Upstream: TelegramEngine (API facade). Only what the chat list calls; no network, so these complete empty.
public final class TelegramEngine {
    public let account: Account
    public init(account: Account) { self.account = account }
    public final class Peers {
        public func fetchAndUpdateCachedPeerData(peerId: PeerId) -> Signal<Bool, NoError> { .single(false) }
    }
    public final class Stickers {
        public func resolveInlineStickers(fileIds: [Int64]) -> Signal<[Int64: TelegramMediaFile], NoError> { .single([:]) }
    }
    public lazy var peers = Peers()
    public lazy var stickers = Stickers()
}
/// Upstream: Network/Network.swift (MTProto transport). Not ported; kept as a type for signatures.
public final class Network {}
/// Upstream: Network/FetchedMediaResource.swift (downloads through MTProto). No network in the web port: the fetch
/// completes immediately, and whatever MediaBox already holds is what renders.
public func fetchedMediaResource(
    mediaBox: MediaBox,
    userLocation: MediaResourceUserLocation,
    userContentType: MediaResourceUserContentType,
    reference: MediaResourceReference,
    range: (Range<Int64>, MediaBoxFetchPriority)? = nil,
    statsCategory: MediaResourceStatsCategory = .generic,
    reportResultStatus: Bool = false,
    preferBackgroundReferenceRevalidation: Bool = false,
    continueInBackground: Bool = false
) -> Signal<FetchResourceSourceType, FetchResourceError> { .complete() }
