// Swiftboard web port: Swift MurmurHash3 (x86_32, seed -137723950) for Telegram's ObjC MurMurHash32 module.
import Foundation

public func murMurHash32(_ bytes: UnsafeMutableRawPointer, _ length: Int32) -> Int32 {
    let p = bytes.assumingMemoryBound(to: UInt8.self)
    let c1: UInt32 = 0xcc9e2d51, c2: UInt32 = 0x1b873593
    var h: UInt32 = UInt32(bitPattern: -137723950)
    let len = Int(length), nblocks = len / 4
    for i in 0..<nblocks {
        var k = UInt32(p[i * 4]) | UInt32(p[i * 4 + 1]) << 8 | UInt32(p[i * 4 + 2]) << 16 | UInt32(p[i * 4 + 3]) << 24
        k = k &* c1; k = (k << 15) | (k >> 17); k = k &* c2
        h ^= k; h = (h << 13) | (h >> 19); h = h &* 5 &+ 0xe6546b64
    }
    var k1: UInt32 = 0
    let tail = nblocks * 4
    switch len & 3 {
    case 3: k1 ^= UInt32(p[tail + 2]) << 16; fallthrough
    case 2: k1 ^= UInt32(p[tail + 1]) << 8; fallthrough
    case 1: k1 ^= UInt32(p[tail]); k1 = k1 &* c1; k1 = (k1 << 15) | (k1 >> 17); k1 = k1 &* c2; h ^= k1
    default: break
    }
    h ^= UInt32(len)
    h ^= h >> 16; h = h &* 0x85ebca6b; h ^= h >> 13; h = h &* 0xc2b2ae35; h ^= h >> 16
    return Int32(bitPattern: h)
}
public func murMurHash32Data(_ data: Data) -> Int32 {
    var d = data
    return d.withUnsafeMutableBytes { murMurHash32($0.baseAddress ?? UnsafeMutableRawPointer(bitPattern: 1)!, Int32($0.count)) }
}
public func murMurHashString32(_ s: UnsafePointer<CChar>) -> Int32 {
    murMurHash32(UnsafeMutableRawPointer(mutating: s), Int32(strlen(s)))
}
