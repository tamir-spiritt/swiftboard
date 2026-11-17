// Swiftboard (MIT): CoreMedia/CoreVideo stand-ins. Pixel buffers wrap caller memory; sample buffers carry one image.
@_exported import CoreGraphics
import Foundation
public typealias OSStatus = Int32
public typealias OSType = UInt32
public typealias CVReturn = Int32
public let kCVReturnSuccess: CVReturn = 0
public let kCVPixelFormatType_32BGRA: OSType = 0x42475241
public let kCVPixelFormatType_32ARGB: OSType = 0x20
public let kCVPixelBufferIOSurfacePropertiesKey: CFString = "IOSurfaceProperties"
public let kCVPixelBufferPixelFormatTypeKey: CFString = "PixelFormatType"
public let kCVPixelBufferWidthKey: CFString = "Width"
public let kCVPixelBufferHeightKey: CFString = "Height"
public let kCMSampleAttachmentKey_DisplayImmediately: CFString = "DisplayImmediately"
public struct CVPixelBufferLockFlags: OptionSet { public let rawValue: UInt64; public init(rawValue: UInt64) { self.rawValue = rawValue }
    public static let readOnly = CVPixelBufferLockFlags(rawValue: 1) }
public final class CVPixelBuffer {
    public let width: Int, height: Int, bytesPerRow: Int, format: OSType
    public let base: UnsafeMutableRawPointer
    let release: ((UnsafeMutableRawPointer?, UnsafeRawPointer?) -> Void)?
    let refCon: UnsafeMutableRawPointer?
    let owned: Bool
    init(width: Int, height: Int, bytesPerRow: Int, format: OSType, base: UnsafeMutableRawPointer, owned: Bool, release: ((UnsafeMutableRawPointer?, UnsafeRawPointer?) -> Void)?, refCon: UnsafeMutableRawPointer?) {
        self.width = width; self.height = height; self.bytesPerRow = bytesPerRow; self.format = format; self.base = base; self.owned = owned; self.release = release; self.refCon = refCon
    }
    deinit { release?(refCon, base); if owned { base.deallocate() } }
}
public typealias CVImageBuffer = CVPixelBuffer
@discardableResult
public func CVPixelBufferCreate(_ allocator: CFAllocator?, _ width: Int, _ height: Int, _ format: OSType, _ attrs: CFDictionary?, _ out: UnsafeMutablePointer<CVPixelBuffer?>) -> CVReturn {
    let bpr = width * 4
    let p = UnsafeMutableRawPointer.allocate(byteCount: max(1, bpr * height), alignment: 16)
    p.initializeMemory(as: UInt8.self, repeating: 0, count: max(1, bpr * height))
    out.pointee = CVPixelBuffer(width: width, height: height, bytesPerRow: bpr, format: format, base: p, owned: true, release: nil, refCon: nil)
    return kCVReturnSuccess
}
@discardableResult
public func CVPixelBufferCreateWithBytes(_ allocator: CFAllocator?, _ width: Int, _ height: Int, _ format: OSType, _ base: UnsafeMutableRawPointer, _ bytesPerRow: Int,
                                         _ release: ((UnsafeMutableRawPointer?, UnsafeRawPointer?) -> Void)?, _ refCon: UnsafeMutableRawPointer?, _ attrs: CFDictionary?,
                                         _ out: UnsafeMutablePointer<CVPixelBuffer?>) -> CVReturn {
    out.pointee = CVPixelBuffer(width: width, height: height, bytesPerRow: bytesPerRow, format: format, base: base, owned: false, release: release, refCon: refCon)
    return kCVReturnSuccess
}
public func CVPixelBufferGetBaseAddress(_ b: CVPixelBuffer) -> UnsafeMutableRawPointer? { b.base }
public func CVPixelBufferGetBytesPerRow(_ b: CVPixelBuffer) -> Int { b.bytesPerRow }
public func CVPixelBufferGetWidth(_ b: CVPixelBuffer) -> Int { b.width }
public func CVPixelBufferGetHeight(_ b: CVPixelBuffer) -> Int { b.height }
public func CVPixelBufferGetPixelFormatType(_ b: CVPixelBuffer) -> OSType { b.format }
@discardableResult public func CVPixelBufferLockBaseAddress(_ b: CVPixelBuffer, _ f: CVPixelBufferLockFlags) -> CVReturn { 0 }
@discardableResult public func CVPixelBufferUnlockBaseAddress(_ b: CVPixelBuffer, _ f: CVPixelBufferLockFlags) -> CVReturn { 0 }

public struct CMTime: Equatable {
    public var value: Int64, timescale: Int32
    public init(value: Int64, timescale: Int32) { self.value = value; self.timescale = timescale }
    public init(seconds: Double, preferredTimescale: Int32) { value = Int64(seconds * Double(preferredTimescale)); timescale = preferredTimescale }
    public var seconds: Double { timescale == 0 ? 0 : Double(value) / Double(timescale) }
    public static let zero = CMTime(value: 0, timescale: 1)
    public static let invalid = CMTime(value: 0, timescale: 0)
}
public func CMTimeMake(value: Int64, timescale: Int32) -> CMTime { CMTime(value: value, timescale: timescale) }
public struct CMSampleTimingInfo {
    public var duration: CMTime, presentationTimeStamp: CMTime, decodeTimeStamp: CMTime
    public init(duration: CMTime, presentationTimeStamp: CMTime, decodeTimeStamp: CMTime) { self.duration = duration; self.presentationTimeStamp = presentationTimeStamp; self.decodeTimeStamp = decodeTimeStamp }
}
public final class CMFormatDescription { let width: Int, height: Int; init(_ w: Int, _ h: Int) { width = w; height = h } }
public typealias CMVideoFormatDescription = CMFormatDescription
public final class CMSampleBuffer {
    public let imageBuffer: CVPixelBuffer
    public let attachments = NSMutableArray(array: [NSMutableDictionary()])
    init(_ b: CVPixelBuffer) { imageBuffer = b }
}
@discardableResult
public func CMVideoFormatDescriptionCreateForImageBuffer(allocator: CFAllocator?, imageBuffer: CVImageBuffer, formatDescriptionOut: UnsafeMutablePointer<CMVideoFormatDescription?>) -> OSStatus {
    formatDescriptionOut.pointee = CMFormatDescription(imageBuffer.width, imageBuffer.height); return 0
}
@discardableResult
public func CMSampleBufferCreateForImageBuffer(allocator: CFAllocator?, imageBuffer: CVImageBuffer, dataReady: Bool, makeDataReadyCallback: AnyObject?, refcon: UnsafeMutableRawPointer?,
                                               formatDescription: CMVideoFormatDescription, sampleTiming: UnsafePointer<CMSampleTimingInfo>, sampleBufferOut: UnsafeMutablePointer<CMSampleBuffer?>) -> OSStatus {
    sampleBufferOut.pointee = CMSampleBuffer(imageBuffer); return 0
}
public func CMSampleBufferGetSampleAttachmentsArray(_ b: CMSampleBuffer, createIfNecessary: Bool) -> CFArray? { b.attachments }
public func CMSampleBufferGetImageBuffer(_ b: CMSampleBuffer) -> CVImageBuffer? { b.imageBuffer }
