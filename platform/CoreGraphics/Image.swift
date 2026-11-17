// Swiftboard CoreGraphics (MIT): images and data providers.
// A CGImage is either pixels (bytes) or a vector recording of drawing commands (what a CGContext produced),
// which the browser replays onto a canvas. Bitmap contexts made over caller memory register their recording under
// that memory, so `CGImage(... provider:)` made from the same bytes (the common Telegram pattern) gets the drawing.
import Foundation

public final class CGDataProvider {
    public let bytes: UnsafeRawPointer?
    public let size: Int
    let owned: Data?
    let release: ((UnsafeMutableRawPointer?, UnsafeRawPointer, Int) -> Void)?
    let info: UnsafeMutableRawPointer?

    public init?(dataInfo info: UnsafeMutableRawPointer?, data: UnsafeRawPointer, size: Int, releaseData: @escaping @convention(c) (UnsafeMutableRawPointer?, UnsafeRawPointer, Int) -> Void) {
        self.bytes = data; self.size = size; owned = nil; release = releaseData; self.info = info
    }
    public init?(data: CFData) {
        let d = data as Data
        owned = d; size = d.count; bytes = nil; release = nil; info = nil
    }
    public init?(data: Data) { owned = data; size = data.count; bytes = nil; release = nil; info = nil }
    deinit { if let release, let bytes { release(info, bytes, size) } }
    public var data: CFData? {
        if let owned { return owned as NSData }
        guard let bytes else { return nil }
        return NSData(bytes: bytes, length: size)
    }
    var key: UnsafeRawPointer? { bytes }
}

public func CGDataProviderCopyData(_ p: CGDataProvider) -> CFData? { p.data }

/// Drawing commands recorded by a CGContext (see Context.swift), in that context's pixel space.
public final class CGRecording {
    public let width: Int
    public let height: Int
    public internal(set) var ops: [CGDrawOp]
    init(width: Int, height: Int, ops: [CGDrawOp]) { self.width = width; self.height = height; self.ops = ops }
}

public enum CGImageSourceKind { case pixels, recording, external }

public final class CGImage: Hashable {
    public let width: Int
    public let height: Int
    public let bitsPerComponent: Int
    public let bitsPerPixel: Int
    public let bytesPerRow: Int
    public let colorSpace: CGColorSpace?
    public let bitmapInfo: CGBitmapInfo
    public let dataProvider: CGDataProvider?
    public let shouldInterpolate: Bool
    public let renderingIntent: CGColorRenderingIntent = .defaultIntent
    /// Vector content (when made by drawing).
    public let recording: CGRecording?
    /// An image the host decodes itself (a bundle resource name or URL).
    public let externalSource: String?
    /// Region of the source used (cropping).
    public let crop: CGRect?
    public let isMask: Bool
    /// Unique per image (images are immutable): lets the painter cache rasterizations.
    public let webSerial: Int = { CGImage.serialCounter += 1; return CGImage.serialCounter }()
    nonisolated(unsafe) static var serialCounter = 0

    public var alphaInfo: CGImageAlphaInfo { CGImageAlphaInfo(rawValue: bitmapInfo.rawValue & CGBitmapInfo.alphaInfoMask.rawValue) ?? .premultipliedFirst }
    public var byteOrderInfo: CGImageByteOrderInfo { CGImageByteOrderInfo(rawValue: bitmapInfo.rawValue & 0x7000) ?? .orderDefault }
    public var utType: CFString? { nil }

    public init?(width: Int, height: Int, bitsPerComponent: Int, bitsPerPixel: Int, bytesPerRow: Int, space: CGColorSpace,
                 bitmapInfo: CGBitmapInfo, provider: CGDataProvider, decode: UnsafePointer<CGFloat>?, shouldInterpolate: Bool,
                 intent: CGColorRenderingIntent) {
        self.width = width; self.height = height; self.bitsPerComponent = bitsPerComponent; self.bitsPerPixel = bitsPerPixel
        self.bytesPerRow = bytesPerRow; self.colorSpace = space; self.bitmapInfo = bitmapInfo; self.dataProvider = provider
        self.shouldInterpolate = shouldInterpolate
        self.recording = provider.key.flatMap { CGContext.recording(forMemory: $0) }
        self.externalSource = nil; self.crop = nil; self.isMask = false
    }
    public init?(maskWidth width: Int, height: Int, bitsPerComponent: Int, bitsPerPixel: Int, bytesPerRow: Int, provider: CGDataProvider,
                 decode: UnsafePointer<CGFloat>?, shouldInterpolate: Bool) {
        self.width = width; self.height = height; self.bitsPerComponent = bitsPerComponent; self.bitsPerPixel = bitsPerPixel
        self.bytesPerRow = bytesPerRow; self.colorSpace = .deviceGray; self.bitmapInfo = CGBitmapInfo(alphaInfo: .none); self.dataProvider = provider
        self.shouldInterpolate = shouldInterpolate
        self.recording = provider.key.flatMap { CGContext.recording(forMemory: $0) }
        self.externalSource = nil; self.crop = nil; self.isMask = true
    }
    /// An image made from a recording (CGContext.makeImage).
    public init(recording: CGRecording, colorSpace: CGColorSpace?, bitmapInfo: CGBitmapInfo) {
        width = recording.width; height = recording.height; bitsPerComponent = 8; bitsPerPixel = 32; bytesPerRow = recording.width * 4
        self.colorSpace = colorSpace; self.bitmapInfo = bitmapInfo; dataProvider = nil; shouldInterpolate = true
        self.recording = recording; externalSource = nil; crop = nil; isMask = false
    }
    /// An image the host loads (e.g. a bundle PNG). `width`/`height` in pixels.
    public init(externalSource: String, width: Int, height: Int) {
        self.width = width; self.height = height; bitsPerComponent = 8; bitsPerPixel = 32; bytesPerRow = width * 4
        colorSpace = .deviceRGB; bitmapInfo = CGBitmapInfo(alphaInfo: .premultipliedFirst); dataProvider = nil; shouldInterpolate = true
        recording = nil; self.externalSource = externalSource; crop = nil; isMask = false
    }
    init(cropping source: CGImage, to rect: CGRect) {
        width = Int(rect.width); height = Int(rect.height); bitsPerComponent = source.bitsPerComponent; bitsPerPixel = source.bitsPerPixel
        bytesPerRow = source.bytesPerRow; colorSpace = source.colorSpace; bitmapInfo = source.bitmapInfo; dataProvider = source.dataProvider
        shouldInterpolate = source.shouldInterpolate; recording = source.recording; externalSource = source.externalSource
        crop = rect.offsetBy(dx: source.crop?.minX ?? 0, dy: source.crop?.minY ?? 0); isMask = source.isMask
    }

    public var sourceKind: CGImageSourceKind { recording != nil ? .recording : (externalSource != nil ? .external : .pixels) }

    public func cropping(to rect: CGRect) -> CGImage? {
        let r = rect.integral.intersection(CGRect(x: 0, y: 0, width: width, height: height))
        if r.isEmpty { return nil }
        return CGImage(cropping: self, to: r)
    }
    public func copy() -> CGImage? { self }
    public func copy(colorSpace: CGColorSpace) -> CGImage? { self }
    public func masking(_ mask: CGImage) -> CGImage? { self }

    public static func == (a: CGImage, b: CGImage) -> Bool { a === b }
    public func hash(into h: inout Hasher) { h.combine(ObjectIdentifier(self)) }
}

public func CGImageGetWidth(_ i: CGImage?) -> Int { i?.width ?? 0 }
public func CGImageGetHeight(_ i: CGImage?) -> Int { i?.height ?? 0 }
