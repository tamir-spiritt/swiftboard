// Swiftboard platform (MIT): ImageIO's image-source API. Encoded image data is not decoded in Swift on the web
// (the browser decodes images it draws); sources report no images, so callers use their fallbacks.
import Foundation
import CoreGraphics
public final class CGImageSource {}
public func CGImageSourceCreateWithData(_ data: CFData, _ options: CFDictionary?) -> CGImageSource? { nil }
public func CGImageSourceCreateWithURL(_ url: CFURL, _ options: CFDictionary?) -> CGImageSource? { nil }
public func CGImageSourceGetCount(_ isrc: CGImageSource) -> Int { 0 }
public func CGImageSourceCreateImageAtIndex(_ isrc: CGImageSource, _ index: Int, _ options: CFDictionary?) -> CGImage? { nil }
public func CGImageSourceCreateThumbnailAtIndex(_ isrc: CGImageSource, _ index: Int, _ options: CFDictionary?) -> CGImage? { nil }
public func CGImageSourceCopyPropertiesAtIndex(_ isrc: CGImageSource, _ index: Int, _ options: CFDictionary?) -> CFDictionary? { nil }
public let kCGImageSourceShouldCache: CFString = "kCGImageSourceShouldCache"
public let kCGImageSourceCreateThumbnailFromImageAlways: CFString = "kCGImageSourceCreateThumbnailFromImageAlways"
public let kCGImageSourceThumbnailMaxPixelSize: CFString = "kCGImageSourceThumbnailMaxPixelSize"
public let kCGImageSourceCreateThumbnailWithTransform: CFString = "kCGImageSourceCreateThumbnailWithTransform"
public let kCGImagePropertyOrientation: CFString = "Orientation"
public let kCGImagePropertyPixelWidth: CFString = "PixelWidth"
public let kCGImagePropertyPixelHeight: CFString = "PixelHeight"
