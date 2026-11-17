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
public let kvImageTruncateKernel: Int = 8
public let kvImageEdgeExtend: Int = 8
/// Box blur (kernel kw x kh, odd) with truncated edges, in place allowed (src may equal dest).
@discardableResult
public func vImageBoxConvolve_ARGB8888(_ src: UnsafePointer<vImage_Buffer>, _ dest: UnsafePointer<vImage_Buffer>, _ tempBuffer: UnsafeMutableRawPointer?,
                                        _ srcOffsetToROI_X: vImagePixelCount, _ srcOffsetToROI_Y: vImagePixelCount,
                                        _ kernel_height: UInt32, _ kernel_width: UInt32, _ backgroundColor: UnsafePointer<UInt8>?, _ flags: vImage_Flags) -> vImage_Error {
    let s = src.pointee, d = dest.pointee
    let w = Int(s.width), h = Int(s.height), rx = Int(kernel_width) / 2, ry = Int(kernel_height) / 2
    guard w > 0, h > 0 else { return kvImageNoError }
    var tmp = [Int](repeating: 0, count: w * h * 4)
    // horizontal pass into tmp (sums), then vertical pass into dest (averages)
    for y in 0..<h {
        let row = s.data.advanced(by: y * s.rowBytes).assumingMemoryBound(to: UInt8.self)
        for x in 0..<w {
            let x0 = max(0, x - rx), x1 = min(w - 1, x + rx), n = x1 - x0 + 1
            for c in 0..<4 {
                var sum = 0
                for xx in x0...x1 { sum += Int(row[xx * 4 + c]) }
                tmp[(y * w + x) * 4 + c] = sum / n
            }
        }
    }
    for y in 0..<h {
        let out = d.data.advanced(by: y * d.rowBytes).assumingMemoryBound(to: UInt8.self)
        let y0 = max(0, y - ry), y1 = min(h - 1, y + ry), n = y1 - y0 + 1
        for x in 0..<w {
            for c in 0..<4 {
                var sum = 0
                for yy in y0...y1 { sum += tmp[(yy * w + x) * 4 + c] }
                out[x * 4 + c] = UInt8(sum / n)
            }
        }
    }
    return kvImageNoError
}
/// Color matrix multiply: out[c] = sum_k in[k] * matrix[k*4 + c] / divisor (channel order as stored).
@discardableResult
public func vImageMatrixMultiply_ARGB8888(_ src: UnsafePointer<vImage_Buffer>, _ dest: UnsafePointer<vImage_Buffer>, _ matrix: UnsafePointer<Int16>,
                                          _ divisor: Int32, _ pre_bias: UnsafePointer<Int16>?, _ post_bias: UnsafePointer<Int32>?, _ flags: vImage_Flags) -> vImage_Error {
    let s = src.pointee, d = dest.pointee
    for y in 0..<Int(s.height) {
        let sr = s.data.advanced(by: y * s.rowBytes).assumingMemoryBound(to: UInt8.self)
        let dr = d.data.advanced(by: y * d.rowBytes).assumingMemoryBound(to: UInt8.self)
        for x in 0..<Int(s.width) {
            let p = (0..<4).map { Int32(sr[x * 4 + $0]) + Int32(pre_bias?[$0] ?? 0) }
            for c in 0..<4 {
                var sum: Int32 = 0
                for k in 0..<4 { sum += p[k] * Int32(matrix[k * 4 + c]) }
                sum += post_bias?[c] ?? 0
                dr[x * 4 + c] = UInt8(max(0, min(255, sum / max(1, divisor))))
            }
        }
    }
    return kvImageNoError
}
