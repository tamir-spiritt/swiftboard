// Swiftboard web port: Telegram's ObjC GZip (zlib). No zlib in the WASI SDK: inflating returns nil.
import Foundation
public func TGGUnzipData(_ data: Data, _ sizeLimit: UInt) -> Data? { nil }
public func TGGZipData(_ data: Data, _ level: Float) -> Data { data }
