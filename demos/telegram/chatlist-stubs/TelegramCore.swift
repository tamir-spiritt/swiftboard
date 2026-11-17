// Swiftboard web port: stand-in for Telegram module TelegramCore (API surface the chat list uses, fake data).
import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
@_exported import Postbox

// MARK: Telegram data model shapes (fake data layer for the web port)
public enum Namespaces {
    public enum Media { public static let CloudFile: Int32 = 1; public static let CloudImage: Int32 = 0; public static let LocalImage: Int32 = 3 }
    public enum Message { public static let Cloud: Int32 = 0; public static let Local: Int32 = 1; public static let ScheduledCloud: Int32 = 3 }
    public enum Peer { public static let CloudUser = EnginePeerId.Namespace(0); public static let CloudGroup = EnginePeerId.Namespace(1); public static let CloudChannel = EnginePeerId.Namespace(2); public static let SecretChat = EnginePeerId.Namespace(3) }
}
public enum EngineMedia {
    public typealias Id = MediaId
}
public final class Network {}
public enum GetWallpaperError: Error { case generic }
public func getWallpaper(network: Network, slug: String) -> Signal<TelegramWallpaper, GetWallpaperError> { .fail(.generic) }
public final class StarGift {}

public final class CloudDocumentMediaResource: MediaResource {
    public let datacenterId: Int, fileId: Int64, accessHash: Int64, fileReference: Data?, fileName: String?
    public let size: Int64?
    public init(datacenterId: Int, fileId: Int64, accessHash: Int64, size: Int64?, fileReference: Data?, fileName: String?) {
        self.datacenterId = datacenterId; self.fileId = fileId; self.accessHash = accessHash; self.size = size; self.fileReference = fileReference; self.fileName = fileName
    }
    public var id: MediaResourceIdString { MediaResourceIdString("doc\(fileId)") }
}
public final class CloudDocumentSizeMediaResource: MediaResource {
    public let datacenterId: Int32, documentId: Int64, accessHash: Int64, sizeSpec: String, fileReference: Data?
    public init(datacenterId: Int32, documentId: Int64, accessHash: Int64, sizeSpec: String, fileReference: Data?) {
        self.datacenterId = datacenterId; self.documentId = documentId; self.accessHash = accessHash; self.sizeSpec = sizeSpec; self.fileReference = fileReference
    }
    public var id: MediaResourceIdString { MediaResourceIdString("docsize\(documentId)\(sizeSpec)") }
    public var size: Int64? { nil }
}
public struct TelegramMediaImageRepresentation: Equatable {
    public enum TypeHint: Int32 { case generic, animated, video }
    public let dimensions: PixelDimensions
    public let resource: MediaResource
    public let progressiveSizes: [Int32]
    public let immediateThumbnailData: Data?
    public let hasVideo: Bool
    public let isPersonal: Bool
    public let typeHint: TypeHint
    public init(dimensions: PixelDimensions, resource: MediaResource, progressiveSizes: [Int32], immediateThumbnailData: Data?, hasVideo: Bool = false, isPersonal: Bool = false, typeHint: TypeHint = .generic) {
        self.dimensions = dimensions; self.resource = resource; self.progressiveSizes = progressiveSizes; self.immediateThumbnailData = immediateThumbnailData
        self.hasVideo = hasVideo; self.isPersonal = isPersonal; self.typeHint = typeHint
    }
    public static func == (a: Self, b: Self) -> Bool { a.dimensions == b.dimensions && a.resource === b.resource }
}
public enum TelegramMediaFileAttribute {
    case FileName(fileName: String)
    case ImageSize(size: PixelDimensions)
    case Animated
    case Sticker(displayText: String, packReference: AnyObject?, maskData: AnyObject?)
    case Video(duration: Double, size: PixelDimensions, flags: Int32, preloadSize: Int32?, coverTime: Double?, videoCodec: String?)
    case Audio(isVoice: Bool, duration: Int, title: String?, performer: String?, waveform: Data?)
    case HasLinkedStickers
    case hintFileIsLarge
    case NoPremium
    case CustomEmoji(isPremium: Bool, isSingleColor: Bool, alt: String, packReference: AnyObject?)
}
public final class TelegramMediaFile: Media, Equatable {
    public let fileId: MediaId
    public let partialReference: AnyObject?
    public let resource: MediaResource
    public let previewRepresentations: [TelegramMediaImageRepresentation]
    public let videoThumbnails: [AnyObject]
    public let immediateThumbnailData: Data?
    public let mimeType: String
    public let size: Int64?
    public let attributes: [TelegramMediaFileAttribute]
    public let alternativeRepresentations: [Media]
    public var id: MediaId? { fileId }
    public init(fileId: MediaId, partialReference: AnyObject?, resource: MediaResource, previewRepresentations: [TelegramMediaImageRepresentation], videoThumbnails: [AnyObject], immediateThumbnailData: Data?, mimeType: String, size: Int64?, attributes: [TelegramMediaFileAttribute], alternativeRepresentations: [Media]) {
        self.fileId = fileId; self.partialReference = partialReference; self.resource = resource; self.previewRepresentations = previewRepresentations
        self.videoThumbnails = videoThumbnails; self.immediateThumbnailData = immediateThumbnailData; self.mimeType = mimeType; self.size = size
        self.attributes = attributes; self.alternativeRepresentations = alternativeRepresentations
    }
    public static func == (a: TelegramMediaFile, b: TelegramMediaFile) -> Bool { a === b || a.fileId == b.fileId }
    public var isVideo: Bool { attributes.contains { if case .Video = $0 { return true }; return false } }
    public var isAnimated: Bool { attributes.contains { if case .Animated = $0 { return true }; return false } }
    public var isSticker: Bool { attributes.contains { if case .Sticker = $0 { return true }; return false } }
    public var isVoice: Bool { attributes.contains { if case let .Audio(v, _, _, _, _) = $0 { return v }; return false } }
    public var isMusic: Bool { attributes.contains { if case let .Audio(v, _, _, _, _) = $0 { return !v }; return false } }
    public var isInstantVideo: Bool { false }
    public var isAnimatedSticker: Bool { false }
    public var isVideoSticker: Bool { false }
    public var isCustomEmoji: Bool { attributes.contains { if case .CustomEmoji = $0 { return true }; return false } }
    public var fileName: String? { for a in attributes { if case let .FileName(n) = a { return n } }; return nil }
    public var dimensions: PixelDimensions? { for a in attributes { if case let .ImageSize(s) = a { return s } }; return nil }
}

public struct WallpaperSettings: Equatable {
    public var blur: Bool, motion: Bool, colors: [UInt32], intensity: Int32?, rotation: Int32?
    public init(blur: Bool = false, motion: Bool = false, colors: [UInt32] = [], intensity: Int32? = nil, rotation: Int32? = nil) {
        self.blur = blur; self.motion = motion; self.colors = colors; self.intensity = intensity; self.rotation = rotation
    }
}
public enum TelegramWallpaper: Equatable {
    public struct Gradient: Equatable {
        public var id: Int64?, colors: [UInt32], settings: WallpaperSettings
        public init(id: Int64?, colors: [UInt32], settings: WallpaperSettings) { self.id = id; self.colors = colors; self.settings = settings }
    }
    public struct File: Equatable {
        public var id: Int64, accessHash: Int64, isCreator: Bool, isDefault: Bool, isPattern: Bool, isDark: Bool, slug: String, file: TelegramMediaFile, settings: WallpaperSettings
        public init(id: Int64, accessHash: Int64, isCreator: Bool, isDefault: Bool, isPattern: Bool, isDark: Bool, slug: String, file: TelegramMediaFile, settings: WallpaperSettings) {
            self.id = id; self.accessHash = accessHash; self.isCreator = isCreator; self.isDefault = isDefault; self.isPattern = isPattern; self.isDark = isDark; self.slug = slug; self.file = file; self.settings = settings
        }
    }
    case builtin(WallpaperSettings)
    case color(UInt32)
    case gradient(Gradient)
    case image([TelegramMediaImageRepresentation], WallpaperSettings)
    case file(File)
    case emoticon(String)
    public var settings: WallpaperSettings? {
        switch self {
        case let .builtin(s), let .image(_, s): return s
        case let .gradient(g): return g.settings
        case let .file(f): return f.settings
        default: return nil
        }
    }
    public var isBuiltin: Bool { if case .builtin = self { return true }; return false }
    public var isPattern: Bool { if case let .file(f) = self { return f.isPattern }; return false }
    public var isColorOrGradient: Bool { switch self { case .color, .gradient: return true; default: return false } }
    public func withUpdatedSettings(_ s: WallpaperSettings) -> TelegramWallpaper {
        switch self {
        case .builtin: return .builtin(s)
        case let .image(r, _): return .image(r, s)
        case var .gradient(g): g.settings = s; return .gradient(g)
        case var .file(f): f.settings = s; return .file(f)
        default: return self
        }
    }
}
