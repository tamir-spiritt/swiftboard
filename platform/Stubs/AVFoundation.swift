// Swiftboard (MIT): AVFoundation stand-in (layer classes the UI code type-checks against).
@_exported import QuartzCore
@_exported import CoreMedia
import Foundation
open class AVSampleBufferDisplayLayer: CALayer {
    open func enqueue(_ b: CMSampleBuffer) { contents = nil }
    open func flush() {}
    open func flushAndRemoveImage() { contents = nil }
    open var videoGravity: String = "AVLayerVideoGravityResizeAspect"
    open var isReadyForMoreMediaData: Bool { true }
    open override class func webMakeLayer() -> CALayer { AVSampleBufferDisplayLayer() }
}
open class AVPlayerLayer: CALayer {
    open var videoGravity: String = "AVLayerVideoGravityResizeAspect"
    open var isReadyForDisplay: Bool { false }
    open override class func webMakeLayer() -> CALayer { AVPlayerLayer() }
}
public struct AVLayerVideoGravity: RawRepresentable, Hashable { public let rawValue: String; public init(rawValue: String) { self.rawValue = rawValue }
    public static let resizeAspect = AVLayerVideoGravity(rawValue: "AVLayerVideoGravityResizeAspect")
    public static let resizeAspectFill = AVLayerVideoGravity(rawValue: "AVLayerVideoGravityResizeAspectFill")
    public static let resize = AVLayerVideoGravity(rawValue: "AVLayerVideoGravityResize") }
