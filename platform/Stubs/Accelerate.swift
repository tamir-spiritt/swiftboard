// Swiftboard (MIT): the vImage calls the port needs, in plain Swift.
import Foundation
public typealias vImagePixelCount = UInt
public typealias vImage_Error = Int
public typealias vImage_Flags = UInt32
public let kvImageNoFlags: Int = 0
public let kvImageDoNotTile: Int = 16
public let kvImageNoError: vImage_Error = 0
public struct vImage_Buffer {
    public var data: UnsafeMutableRawPointer!
    public var height: vImagePixelCount
    public var width: vImagePixelCount
    public var rowBytes: Int
    public init() { data = nil; height = 0; width = 0; rowBytes = 0 }
    public init(data: UnsafeMutableRawPointer!, height: vImagePixelCount, width: vImagePixelCount, rowBytes: Int) {
        self.data = data; self.height = height; self.width = width; self.rowBytes = rowBytes
    }
}
@discardableResult
public func vImagePermuteChannels_ARGB8888(_ src: UnsafePointer<vImage_Buffer>, _ dest: UnsafePointer<vImage_Buffer>, _ map: UnsafePointer<UInt8>, _ flags: vImage_Flags) -> vImage_Error {
    let s = src.pointee, d = dest.pointee
    for y in 0..<Int(s.height) {
        let sr = s.data.advanced(by: y * s.rowBytes).assumingMemoryBound(to: UInt8.self)
        let dr = d.data.advanced(by: y * d.rowBytes).assumingMemoryBound(to: UInt8.self)
        for x in 0..<Int(s.width) {
            let p = (sr[x * 4], sr[x * 4 + 1], sr[x * 4 + 2], sr[x * 4 + 3])
            let a = [p.0, p.1, p.2, p.3]
            for c in 0..<4 { dr[x * 4 + c] = a[Int(map[c])] }
        }
    }
    return kvImageNoError
}
@discardableResult
public func vImageUnpremultiplyData_ARGB8888(_ src: UnsafePointer<vImage_Buffer>, _ dest: UnsafePointer<vImage_Buffer>, _ flags: vImage_Flags) -> vImage_Error {
    let s = src.pointee, d = dest.pointee
    for y in 0..<Int(s.height) {
        let sr = s.data.advanced(by: y * s.rowBytes).assumingMemoryBound(to: UInt8.self)
        let dr = d.data.advanced(by: y * d.rowBytes).assumingMemoryBound(to: UInt8.self)
        for x in 0..<Int(s.width) {
            let a = Int(sr[x * 4])
            dr[x * 4] = UInt8(a)
            for c in 1..<4 { dr[x * 4 + c] = a == 0 ? 0 : UInt8(min(255, Int(sr[x * 4 + c]) * 255 / a)) }
        }
    }
    return kvImageNoError
}
@discardableResult
public func vImagePremultiplyData_ARGB8888(_ src: UnsafePointer<vImage_Buffer>, _ dest: UnsafePointer<vImage_Buffer>, _ flags: vImage_Flags) -> vImage_Error {
    let s = src.pointee, d = dest.pointee
    for y in 0..<Int(s.height) {
        let sr = s.data.advanced(by: y * s.rowBytes).assumingMemoryBound(to: UInt8.self)
        let dr = d.data.advanced(by: y * d.rowBytes).assumingMemoryBound(to: UInt8.self)
        for x in 0..<Int(s.width) {
            let a = Int(sr[x * 4])
            dr[x * 4] = UInt8(a)
            for c in 1..<4 { dr[x * 4 + c] = UInt8(Int(sr[x * 4 + c]) * a / 255) }
        }
    }
    return kvImageNoError
}
