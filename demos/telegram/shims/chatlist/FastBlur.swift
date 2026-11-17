// Swiftboard web port: Telegram's ObjC FastBlur (box blur of tiny thumbnails). Not ported: pixels stay unblurred.
import Foundation
public func telegramFastBlurMore(_ imageWidth: Int32, _ imageHeight: Int32, _ imageStride: Int32, _ pixels: UnsafeMutableRawPointer) {}
public func telegramFastBlur(_ imageWidth: Int32, _ imageHeight: Int32, _ imageStride: Int32, _ pixels: UnsafeMutableRawPointer) {}
public func stickerThumbnailAlphaBlur(_ imageWidth: Int32, _ imageHeight: Int32, _ imageStride: Int32, _ pixels: UnsafeMutableRawPointer) {}
